# ChannelResolve

OpenClaw channel secret-resolution failure note for Slack, Telegram, and
Discord. This file records the observed failures, root causes, selected fixes,
affected files, validation, and the resulting runtime behavior after the
changes.

## 1. Introduction

The immediate problem was that OpenClaw could fail gateway startup too early
when channel credentials were present as active SecretRef surfaces but resolved
to empty values or stayed unresolved at runtime.

That failure mode was wrong for channels such as Slack, Telegram, and Discord.
Those channels already have downstream runtime checks that can classify an
account as unconfigured. Startup should therefore degrade with warnings rather
than abort before channel runtime code gets a chance to do that work.

The work here separated:

1. failures in the shared secrets runtime
2. failures in per-channel account resolution

It did not attempt to flatten all channel auth into one common treatment.
WhatsApp in particular remains a different auth class.

## 2. Symptoms And Failure Messages

### 2.1 Startup abort in shared secret resolution

The failing startup path showed messages of this form:

- `channels.slack.botToken resolved to a non-string or empty value.`
- `channels.slack.appToken resolved to a non-string or empty value.`
- `channels.telegram.botToken resolved to a non-string or empty value.`
- `channels.discord.token resolved to a non-string or empty value.`

In the concrete gateway log, Slack produced:

- `[SECRETS_RELOADER_DEGRADED] Error: channels.slack.botToken resolved to a non-string or empty value.`
- `Gateway failed to start: Error: Startup failed: required secrets are unavailable. Error: channels.slack.botToken resolved to a non-string or empty value.`

### 2.2 Per-channel account resolution throwing on unresolved SecretRef

The second class of symptom was a direct throw during account resolution when a
channel token was still a SecretRef object rather than a resolved string.

That showed up in tests and runtime paths as:

- `channels.telegram.botToken: unresolved SecretRef ...`
- `channels.discord.token: unresolved SecretRef ...`

Before the fix, that meant some code paths never reached the normal
`isConfigured` / `tokenSource === "none"` handling and instead aborted
immediately.

### 2.3 Wrong operational outcome

The operational outcome before the fix was:

1. gateway startup could fail
2. channel plugin loading could fail
3. a channel that should have been treated as merely unconfigured was instead
   treated as a fatal startup error

## 3. Root Cause Analysis

### 3.1 Shared secrets runtime was too eager and too strict

The shared secrets runtime collected active SecretRef assignments for channel
credential fields and then validated them as if they were all hard
requirements.

That design was reasonable for truly fatal surfaces, but it was too strict for
channel token surfaces that already have runtime-level “configured vs
unconfigured” semantics.

The relevant shared logic is in:

- [runtime-shared.ts](/Users/walter/Work/Claw/openclaw/src/secrets/runtime-shared.ts:1)
- [runtime.ts](/Users/walter/Work/Claw/openclaw/src/secrets/runtime.ts:1)
- [channel-secret-basic-runtime.ts](/Users/walter/Work/Claw/openclaw/src/secrets/channel-secret-basic-runtime.ts:1)

### 3.2 Channel credential surfaces were being resolved before channel policy

Slack, Telegram, and Discord token fields are all declared as credential
surfaces and are active at startup when their channel surface is active.

Examples:

- [extensions/discord/src/secret-config-contract.ts](/Users/walter/Work/Claw/openclaw/extensions/discord/src/secret-config-contract.ts:85)
- Slack and Telegram equivalent secret-contract modules loaded through the
  bundled channel secret contract API

Those surfaces were being resolved and validated before the channel account
resolver got a chance to decide “configured” vs “not configured”.

### 3.3 Some account resolvers still treated unresolved SecretRef as exceptional

Even after nonfatal behavior was added to the shared runtime, channel-local
account resolution still mattered.

Slack, Telegram, and Discord all have account resolution functions that
ultimately produce:

- a token string or no token
- a token source such as `config`, `env`, or `none`
- account config used by the plugin base

If those resolvers throw on unresolved SecretRef objects, the plugin still
fails too early even if the shared runtime no longer aborts startup.

### 3.4 WhatsApp is not the same problem

WhatsApp is not a simple token surface in the same way. Its primary runtime
state is centered on auth directories and persisted creds, not just a single
token string.

Relevant files:

- [extensions/whatsapp/src/accounts.ts](/Users/walter/Work/Claw/openclaw/extensions/whatsapp/src/accounts.ts:47)
- [extensions/whatsapp/src/security-contract.ts](/Users/walter/Work/Claw/openclaw/extensions/whatsapp/src/security-contract.ts:8)

The code explicitly marks:

- `channels.whatsapp.creds.json`
- `channels.whatsapp.accounts.*.creds.json`

as unsupported SecretRef surfaces. That means WhatsApp should not receive the
same “token missing => nonfatal unconfigured channel” treatment without a
separate design review.

## 4. Selected Fixes And Justifications

### 4.1 Shared runtime: add a nonfatal unavailable path

Selected fix:

1. allow a secret assignment to declare `onUnavailable: "warn"`
2. keep such assignments unresolved when the resolved value is missing or empty
3. emit a warning with code `SECRETS_REF_UNAVAILABLE_NONFATAL`
4. continue startup

Justification:

- preserves strict behavior for fatal surfaces
- avoids weakening secret validation globally
- lets runtime channel logic mark accounts unconfigured in the normal way

Rejected alternative:

- loosening the base secret-value validators globally

That would have been too broad. Many callers do need hard failure semantics.

### 4.2 Shared runtime: separate fatal and nonfatal assignment handling

Selected fix:

1. keep fatal assignments on the existing bulk resolution path
2. resolve nonfatal assignments individually
3. swallow per-assignment resolution failures only for the nonfatal class

Justification:

- keeps the existing fatal path simple
- limits degraded behavior to explicitly opted-in assignments
- avoids a full redesign of the resolver contract

### 4.3 Channel collectors: mark token-like channel credential surfaces nonfatal

Selected fix:

- `collectSimpleChannelFieldAssignments`
- `collectConditionalChannelFieldAssignments`
- `collectNestedChannelFieldAssignments`

now pass `onUnavailable: "warn"` for the collected channel secret assignments.

Justification:

- the collector layer already knows it is dealing with channel credential
  surfaces
- this is the narrowest place to express “warn, do not abort”
- it avoids duplicating the same decision in each channel contract

### 4.4 Slack, Telegram, and Discord: resolve account to `source: "none"` on unresolved SecretRef

Selected fix:

- Slack resolves token fields through a small safe wrapper
- Telegram resolves token through a local `resolveTokenOrNone`
- Discord now catches unresolved SecretRef errors in `resolveDiscordAccount`

Justification:

- keeps the change local to account resolution
- preserves setup, probe, and explicit token helper behavior elsewhere
- matches the existing meaning of `tokenSource: "none"`

Rejected alternative:

- changing the base token helper functions to stop throwing everywhere

That would affect setup and probe flows that still benefit from explicit
failure.

### 4.5 Do not treat WhatsApp similarly

Selected fix:

- no WhatsApp code change in this pass

Justification:

- WhatsApp is auth-dir / creds-file based
- the code already documents unsupported SecretRef surfaces there
- making it “similar” without design work would blur two different auth models

## 5. Structure Of The Fixes

The patch naturally split into two layers.

### 5.1 Shared secrets-runtime layer

Responsibilities:

- classify some secret assignments as nonfatal
- keep unresolved nonfatal values in place
- emit structured warnings
- preserve strict behavior for everything else

Main files:

- [src/secrets/runtime-shared.ts](/Users/walter/Work/Claw/openclaw/src/secrets/runtime-shared.ts:1)
- [src/secrets/runtime.ts](/Users/walter/Work/Claw/openclaw/src/secrets/runtime.ts:1)
- [src/secrets/channel-secret-basic-runtime.ts](/Users/walter/Work/Claw/openclaw/src/secrets/channel-secret-basic-runtime.ts:1)

### 5.2 Channel account-resolution layer

Responsibilities:

- treat unresolved SecretRef token inputs as unavailable
- return empty token plus `source: "none"`
- let plugin `isConfigured` logic decide the runtime state

Main files:

- [extensions/slack/src/accounts.ts](/Users/walter/Work/Claw/openclaw/extensions/slack/src/accounts.ts:1)
- [extensions/telegram/src/accounts.ts](/Users/walter/Work/Claw/openclaw/extensions/telegram/src/accounts.ts:1)
- [extensions/discord/src/accounts.ts](/Users/walter/Work/Claw/openclaw/extensions/discord/src/accounts.ts:1)

### 5.3 Test layer

Responsibilities:

- prove nonfatal unresolved channel-secret behavior in the shared runtime
- prove account resolvers no longer throw for Slack, Telegram, and Discord

Main files:

- [src/secrets/runtime-channel-unconfigured-secrets.test.ts](/Users/walter/Work/Claw/openclaw/src/secrets/runtime-channel-unconfigured-secrets.test.ts:1)
- [extensions/slack/src/accounts.test.ts](/Users/walter/Work/Claw/openclaw/extensions/slack/src/accounts.test.ts:1)
- [extensions/telegram/src/accounts.test.ts](/Users/walter/Work/Claw/openclaw/extensions/telegram/src/accounts.test.ts:1)
- [extensions/discord/src/accounts.test.ts](/Users/walter/Work/Claw/openclaw/extensions/discord/src/accounts.test.ts:1)

## 6. Files Affected

### 6.1 Source files changed

- [extensions/discord/src/accounts.ts](/Users/walter/Work/Claw/openclaw/extensions/discord/src/accounts.ts:1)
- [extensions/discord/src/accounts.test.ts](/Users/walter/Work/Claw/openclaw/extensions/discord/src/accounts.test.ts:1)
- [extensions/slack/src/accounts.ts](/Users/walter/Work/Claw/openclaw/extensions/slack/src/accounts.ts:1)
- [extensions/slack/src/accounts.test.ts](/Users/walter/Work/Claw/openclaw/extensions/slack/src/accounts.test.ts:1)
- [extensions/telegram/src/accounts.ts](/Users/walter/Work/Claw/openclaw/extensions/telegram/src/accounts.ts:1)
- [extensions/telegram/src/accounts.test.ts](/Users/walter/Work/Claw/openclaw/extensions/telegram/src/accounts.test.ts:1)
- [src/secrets/channel-secret-basic-runtime.ts](/Users/walter/Work/Claw/openclaw/src/secrets/channel-secret-basic-runtime.ts:1)
- [src/secrets/runtime-shared.ts](/Users/walter/Work/Claw/openclaw/src/secrets/runtime-shared.ts:1)
- [src/secrets/runtime.ts](/Users/walter/Work/Claw/openclaw/src/secrets/runtime.ts:1)
- [src/secrets/runtime-channel-unconfigured-secrets.test.ts](/Users/walter/Work/Claw/openclaw/src/secrets/runtime-channel-unconfigured-secrets.test.ts:1)

### 6.2 Live pack bundle files mirrored for immediate apr20 testing

These were mirrored into the live pack bundle so the behavior could be tested
without rebuilding the whole pack:

- `/Users/walter/Work/Claw/Setpacks/openclaw/apr20/openclaw/bundle/node_modules/openclaw/dist/runtime-shared-BkCh59TV.js`
- `/Users/walter/Work/Claw/Setpacks/openclaw/apr20/openclaw/bundle/node_modules/openclaw/dist/runtime-B-1Vt5_c.js`
- `/Users/walter/Work/Claw/Setpacks/openclaw/apr20/openclaw/bundle/node_modules/openclaw/dist/channel-secret-basic-runtime-DSrZqlDA.js`
- `/Users/walter/Work/Claw/Setpacks/openclaw/apr20/openclaw/bundle/node_modules/openclaw/dist/accounts-j_d7sG84.js`
- `/Users/walter/Work/Claw/Setpacks/openclaw/apr20/openclaw/bundle/node_modules/openclaw/dist/preview-streaming-DlkIvlwp.js`
- `/Users/walter/Work/Claw/Setpacks/openclaw/apr20/openclaw/bundle/node_modules/openclaw/dist/accounts-CqTJGEO5.js`

The bundle changes are tactical. The authoritative implementation remains the
source tree under `/Users/walter/Work/Claw/openclaw`.

## 7. Validation And Test

### 7.1 Focused Vitest pass

Focused validation command:

```bash
cd /Users/walter/Work/Claw/openclaw
pnpm exec vitest run \
  extensions/discord/src/accounts.test.ts \
  extensions/slack/src/accounts.test.ts \
  extensions/telegram/src/accounts.test.ts \
  src/secrets/runtime-channel-unconfigured-secrets.test.ts
```

Result:

- `Test Files  4 passed (4)`
- `Tests 46 passed (46)`

### 7.2 Diff hygiene

`git diff --check` passed after the final indentation cleanup in
`channel-secret-basic-runtime.ts`.

### 7.3 Direct gateway smoke test against apr20

A temporary copy of the `apr20` config and secrets payload was used with:

- Discord enabled, token empty
- Telegram enabled, bot token empty
- Slack enabled, bot token empty
- Slack app token empty

Result:

1. gateway reached `ready`
2. startup emitted `SECRETS_REF_UNAVAILABLE_NONFATAL` warnings
3. startup no longer aborted

Observed startup messages included:

- `channels.discord.token: ... Leaving it unresolved so runtime channel checks can mark the account unconfigured.`
- `channels.telegram.botToken: ... Leaving it unresolved so runtime channel checks can mark the account unconfigured.`
- `channels.slack.botToken: ... Leaving it unresolved so runtime channel checks can mark the account unconfigured.`
- `channels.slack.appToken: ... Leaving it unresolved so runtime channel checks can mark the account unconfigured.`

## 8. Resulting Behavior

### 8.1 What now happens

For Slack, Telegram, and Discord:

1. an empty or unavailable SecretRef on an active channel credential surface no
   longer aborts startup
2. the unresolved value is left in place
3. a structured warning is emitted
4. the channel account resolves with no token and `source: "none"`
5. the plugin can classify the channel as unconfigured

### 8.2 What still fails intentionally

The patch does not turn all secret resolution into best-effort behavior.

Fatal surfaces should still fail hard, including cases where the application
really cannot continue without the resolved value.

This was an intentional boundary of the fix.

### 8.3 WhatsApp remains different

WhatsApp still requires its own auth/creds handling review. The present work
does not claim that its unsupported SecretRef surfaces should behave like
Slack, Telegram, or Discord token fields.

## 9. Suggested Commit Message And PR Message

### 9.1 Suggested commit message

```text
Handle unresolved channel SecretRefs as nonfatal for Slack, Telegram, and Discord
```

### 9.2 Suggested PR title

```text
Degrade channel secret resolution failures for Slack, Telegram, and Discord
```

### 9.3 Suggested PR body

```text
## Summary

Make active channel SecretRef failures nonfatal for Slack, Telegram, and
Discord when the runtime can instead treat the account as unconfigured.

## Changes

- add nonfatal unavailable handling to secrets runtime assignments
- warn instead of abort for channel credential surfaces collected through the
  shared channel secret helpers
- update Slack, Telegram, and Discord account resolution to treat unresolved
  SecretRefs as `source: "none"` instead of throwing
- add focused regression tests for shared runtime and per-channel account
  resolution

## Validation

- focused Vitest pass: 4 files, 46 tests passed
- direct apr20 smoke run reached gateway `ready` with Discord, Slack, and
  Telegram credentials empty, while emitting structured nonfatal warnings

## Non-goals

- no WhatsApp auth-surface redesign in this pass
- no global loosening of secret validation semantics
```

## 10. Suggested Vitest Integration

### 10.1 Keep the new tests where they are

The current placement is already aligned with the repo’s shard structure:

- `src/secrets/runtime-channel-unconfigured-secrets.test.ts` belongs in the
  `secrets` shard via [vitest.secrets.config.ts](/Users/walter/Work/Claw/openclaw/vitest.secrets.config.ts:1)
- `extensions/telegram/src/accounts.test.ts` is already covered by
  [vitest.extension-telegram.config.ts](/Users/walter/Work/Claw/openclaw/vitest.extension-telegram.config.ts:1)
- `extensions/discord/src/accounts.test.ts` and
  `extensions/slack/src/accounts.test.ts` already live under channel-routed
  extension roots covered by [vitest.channels.config.ts](/Users/walter/Work/Claw/openclaw/vitest.channels.config.ts:1)

### 10.2 Do not create a new shard just for this fix

No new shard appears justified yet. The current tests are small and belong to
existing ownership lanes:

- shared runtime secret behavior: `secrets`
- Slack and Discord account/channel behavior: `channels`
- Telegram extension behavior: `extension-telegram`

### 10.3 If the pattern grows, consider one focused channel-secret-resolve lane

Only if more channels adopt the same pattern and the test volume grows should a
dedicated shard be considered. If that happens, the most coherent split would
be:

1. keep `src/secrets/**` in `vitest.secrets.config.ts`
2. keep per-channel account tests beside the channel implementation
3. add a narrowly named shared lane only for channel credential-resolution
   regressions that no longer fit comfortably into `channels` or per-extension
   configs

At present, that would be premature.

## 11. Launchd State Notes

### 11.1 Symptom

After the channel-secret work, `openclaw gateway status` still emitted:

- `LaunchAgent label cached but plist missing. Clear with: launchctl bootout gui/$UID/...`

That warning was false for the `apr20` pack. The actual plist existed at:

- [ai.openclaw.gateway.plist](/Users/walter/Library/LaunchAgents/ai.openclaw.gateway.plist)

and the loaded LaunchAgent was already using the `apr20` config and state.

### 11.2 Root cause

The status path was mixing two different environment concerns:

1. host-side service-manager metadata
2. pack-local runtime isolation

The installed LaunchAgent command intentionally carries a pack-local runtime
home such as:

- `HOME=/Users/walter/Work/Claw/Setpacks/openclaw/apr20/openclaw/home`

That runtime `HOME` is appropriate for the supervised gateway process itself,
but it is not the correct home directory for launchd metadata.

The false positive happened because status gathering merged the installed
service environment into the inspection environment and then used that merged
`HOME` while checking whether the LaunchAgent plist exists.

That caused launchd inspection to probe the wrong path shape:

- `/Users/walter/Work/Claw/Setpacks/openclaw/apr20/openclaw/home/Library/LaunchAgents/...`

instead of the actual host path:

- `/Users/walter/Library/LaunchAgents/...`

When that wrong lookup failed, OpenClaw set `cachedLabel: true` and printed
the misleading cleanup warning.

Relevant source references:

- [src/daemon/launchd.ts](/Users/walter/Work/Claw/openclaw/src/daemon/launchd.ts:290)
- [src/daemon/service.ts](/Users/walter/Work/Claw/openclaw/src/daemon/service.ts:80)
- [src/cli/daemon-cli/status.gather.ts](/Users/walter/Work/Claw/openclaw/src/cli/daemon-cli/status.gather.ts:132)
- [src/cli/daemon-cli/status.print.ts](/Users/walter/Work/Claw/openclaw/src/cli/daemon-cli/status.print.ts:253)

### 11.3 Selected fix

Selected fix:

1. keep merging pack-specific `OPENCLAW_*` values from the installed service
2. preserve host `HOME` and `USERPROFILE` for service-manager inspection
3. apply that rule in both service-state reading and daemon status gathering

Justification:

- the service runtime still needs the pack-local isolated home
- launchd metadata always lives in the signed-in user’s real host home
- the warning should only appear when the host-side plist is actually absent

This was intentionally fixed at the environment-merge points rather than by
loosening the `cachedLabel` display condition. The display logic was acting on
bad state; the right repair was to compute the state correctly.

### 11.4 Files changed for the launchd-state fix

- [src/daemon/service.ts](/Users/walter/Work/Claw/openclaw/src/daemon/service.ts:80)
- [src/daemon/service.test.ts](/Users/walter/Work/Claw/openclaw/src/daemon/service.test.ts:83)
- [src/cli/daemon-cli/status.gather.ts](/Users/walter/Work/Claw/openclaw/src/cli/daemon-cli/status.gather.ts:132)
- [src/cli/daemon-cli/status.gather.test.ts](/Users/walter/Work/Claw/openclaw/src/cli/daemon-cli/status.gather.test.ts:244)

### 11.5 Validation and tests

The regression coverage now checks both affected layers.

Service-state regression:

- `readGatewayServiceState()` preserves host `HOME` while still merging the
  installed service config env

Daemon-status regression:

- `gatherDaemonStatus()` preserves host `HOME` when the installed service
  overrides `HOME` for pack-local runtime isolation

Validation command used:

```bash
cd /Users/walter/Work/Claw/openclaw
node scripts/test-projects.mjs \
  src/daemon/service.test.ts \
  src/cli/daemon-cli/status.gather.test.ts
```

Result:

- `src/daemon/service.test.ts`: `10` tests passed
- `src/cli/daemon-cli/status.gather.test.ts`: `16` tests passed

### 11.6 Resulting behavior

After this fix:

1. a pack may still set a pack-local runtime `HOME` for the supervised gateway
2. launchd inspection uses the host user home for plist discovery
3. `cachedLabel` only reflects a genuinely missing host-side LaunchAgent plist
4. the earlier warning should disappear once the source fix is rebuilt and
   redeployed into the live pack bundle

## 12. References

- [src/secrets/runtime-shared.ts](/Users/walter/Work/Claw/openclaw/src/secrets/runtime-shared.ts:1)
- [src/secrets/runtime.ts](/Users/walter/Work/Claw/openclaw/src/secrets/runtime.ts:1)
- [src/secrets/channel-secret-basic-runtime.ts](/Users/walter/Work/Claw/openclaw/src/secrets/channel-secret-basic-runtime.ts:1)
- [src/daemon/launchd.ts](/Users/walter/Work/Claw/openclaw/src/daemon/launchd.ts:1)
- [src/daemon/service.ts](/Users/walter/Work/Claw/openclaw/src/daemon/service.ts:1)
- [src/cli/daemon-cli/status.gather.ts](/Users/walter/Work/Claw/openclaw/src/cli/daemon-cli/status.gather.ts:1)
- [src/cli/daemon-cli/status.print.ts](/Users/walter/Work/Claw/openclaw/src/cli/daemon-cli/status.print.ts:1)
- [extensions/slack/src/accounts.ts](/Users/walter/Work/Claw/openclaw/extensions/slack/src/accounts.ts:1)
- [extensions/telegram/src/accounts.ts](/Users/walter/Work/Claw/openclaw/extensions/telegram/src/accounts.ts:1)
- [extensions/discord/src/accounts.ts](/Users/walter/Work/Claw/openclaw/extensions/discord/src/accounts.ts:1)
- [extensions/whatsapp/src/accounts.ts](/Users/walter/Work/Claw/openclaw/extensions/whatsapp/src/accounts.ts:1)
- [extensions/whatsapp/src/security-contract.ts](/Users/walter/Work/Claw/openclaw/extensions/whatsapp/src/security-contract.ts:1)
- [vitest.config.ts](/Users/walter/Work/Claw/openclaw/vitest.config.ts:1)
- [vitest.channels.config.ts](/Users/walter/Work/Claw/openclaw/vitest.channels.config.ts:1)
- [vitest.secrets.config.ts](/Users/walter/Work/Claw/openclaw/vitest.secrets.config.ts:1)
- [vitest.extension-telegram.config.ts](/Users/walter/Work/Claw/openclaw/vitest.extension-telegram.config.ts:1)
