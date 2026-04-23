# Setclaw

OpenClaw-specific Setpack note for config, auth, state, wrapper behavior, and
related integration decisions. Keep this file on OpenClaw consequences rather
than general architecture or raw environment inventory.

## 1. Purpose

This file covers OpenClaw-specific Setpack handling: config, auth, state,
wrappers, gateway behavior, and model/provider/profile treatment.

## 2. Scope

Examples of material that belongs here:

- `openclaw.json` placement and normalization
- `auth-profiles.json` usage and role
- where API keys, OAuth profiles, and SecretRefs should live
- provider, profile, model, label, and alias presentation
- pack-local wrapper behavior
- gateway installation and service behavior
- what OpenClaw expects from companion tools such as `gog`
- OpenClaw plus helper-app combination behavior

## 3. Current Themes

### 3.1 Config vs Auth vs State

OpenClaw already has native auth-store behavior through `auth-profiles.json`
and related files. Setpack should align with that instead of embedding provider
credentials into the main app config where avoidable.

### 3.2 Model and Alias Handling

OpenClaw model presentation currently mixes:

- canonical model ids
- aliases
- provider inventory
- picker labels
- auth profile context

The Setpack-facing presentation should keep those concerns explicit and
separate.

### 3.3 Gateway and Channel Credentials

OpenClaw also carries credentials that are not LLM provider keys, including:

- gateway token
- Discord token
- plugin/API credentials such as web-search providers

These should be treated according to blast radius and external exposure, not as
one undifferentiated bucket.

Gateway and service state also matter during pack switching. When a developer
changes the default pack, a previously launched gateway can keep running with
the older pack's config, token, `HOME`, and helper-path assumptions. That is
why Setpack now distinguishes between ordinary shell-selection updates and the
explicit `repack --force` path that tears down the LaunchAgent and pack-managed
runtime processes before rewriting the default selection.

### 3.4 Combination Layer Around OpenClaw

OpenClaw should not absorb all companion-tool behavior into one monolithic app
handler. There is a separate combination layer for OpenClaw plus the tools it
expects to call.

Examples:

- OpenClaw plus `gog`, where helper discovery depends on executable name and
  pack-local `PATH`
- OpenClaw plus local model backends such as Ollama
- OpenClaw plus future helper tools that need pack-local wrappers but remain
  separate components

This file should capture the OpenClaw side of those combinations. The generic
pack substrate belongs in `Setpack.md`, and pure companion-app internals belong
in their own subsystem notes.

### 3.5 Session Persistence And Test Residue

OpenClaw session visibility and OpenClaw session persistence are separate
concerns. Changing session-tool visibility can expose older stored sessions,
but it does not create them. Disabling a channel also does not remove its
stored session history.

This matters for pack validation work. Explicit smoke or fallback-test
sessions can linger in the normal session store and show up beside real
operator sessions unless they are cleaned up deliberately after the test run.

### 3.6 Discord Guild And Channel Gating

For Discord, guild allowlisting and channel allowlisting are different layers.
A guild-level allowlist entry without a nested `channels` block allows every
channel in that guild. In that mode, the channels that later appear in stored
session history are determined by where traffic actually happened, not by a
per-channel config choice.

The current `apr20` pack has now moved from guild-wide allowance to an explicit
channel allowlist inside guild `473805904957931522`. That keeps future Discord
handling bounded to named channel ids instead of treating the whole guild as
implicitly open.

Operationally, config edits of this kind should be treated as restart-class
changes. A full gateway restart is preferred over a lighter reload when the
goal is to be certain that channel policy, token state, and pack-local runtime
assumptions are all re-read from disk.

### 3.7 Recent Gateway Findings

Recent `apr20` validation work produced several gateway-facing observations
that are worth recording but not yet worth deep diagnosis.

- The local CLI/backend device fell into a partial pairing state where ordinary
  read-style status worked, but higher-scope calls still failed with
  `pairing required` until the pending repair request was approved locally.
- After that approval, status and secret-resolution behavior recovered, but the
  browser Control UI still needed a page reload before it reconnected cleanly
  with the upgraded scope state.
- One `status --all` run reported `Gateway self: unknown`, while a later
  `status --json` run from the same `apr20` pack reported a valid gateway self
  entry (`WalterPro`, `192.168.1.209`, `2026.4.10`, `macos 26.3`).
- `status --json` also reported that some local secret paths were resolved
  after an incomplete gateway snapshot, which supports treating the earlier
  `unknown` self output as an incomplete-snapshot/reporting inconsistency
  rather than as a real gateway identity loss.
- The `apr20` config file is already normalized to Discord per-channel
  `enabled` flags, but status still reports a legacy-warning message claiming
  `channels.discord.guilds.<id>.channels.<id>.allow` is present. Until this is
  rechecked against a newer upstream build, treat it as a likely false
  positive rather than as evidence of current pack drift.

These findings are postponed low-priority items. Before deeper investigation,
recheck them against a newer upstream release, especially `2026.4.21`, because
they may already be fixed or reshaped upstream.

### 3.8 Current Channel Status

The current `apr20` channel work is OpenClaw-specific. It should not be treated
as general Setpack architecture.

Discord currently probes as connected, but Discord configuration work is
postponed for now. The useful facts to preserve are:

- the bot/application identity visible in Discord is `Diss`
- guild `473805904957931522` is configured with `groupPolicy=allowlist`
- `requireMention=false` is configured at the guild level
- `#zero-general` (`473820999171702784`) is disabled in the config
- `#zero-tip` (`566973676608552972`) is disabled in the config
- `#zero-games` (`1404621978500862023`) remains enabled
- channel `852540676259184670` remains configured as enabled, but the probe
  reports `Missing Access`
- stored Discord sessions do not disappear merely because a channel is later
  disabled

Slack currently probes as connected in socket mode. This confirms that the app
token and bot token route are viable for a local pack that should not expose an
HTTP webhook. The remaining Slack work is not token setup; it is channel
allowlisting. With `groupPolicy=allowlist`, Slack group use still needs explicit
channel ids before it should be considered finished.

Telegram currently probes as connected in polling mode as `@WaKaTeleBot`. The
operator Telegram user id has been allowlisted and the pairing request file is
clear. No Telegram group id has been captured yet, and there is no
`agent:main:telegram:*` session in the current session store. Direct Bot API
checks showed no pending updates. Since OpenClaw itself is polling Telegram, an
inbound group message can be consumed before a manual `getUpdates` check sees
it. Group setup therefore still needs one controlled capture step before a
`channels.telegram.groups` entry can be written.

### 3.9 Workspace Persona Leakage

The Discord app did not rename itself to `Nova`. The Discord-visible bot app is
still `Diss`.

The assistant signing a Discord reply as `Nova` comes from OpenClaw workspace
bootstrap material. In the current `apr20` workspace:

- `workspace/IDENTITY.md` names the assistant `Nova`
- `workspace/TOOLS.md` includes an example TTS preference mentioning `Nova`

Those files are loaded into the OpenClaw agent context as workspace-scoped
identity and local notes. They can therefore affect replies across channels,
including Discord.

The corrective action is not Discord configuration. It is a workspace prompt
cleanup:

- remove or replace the `Nova` identity if it is not desired
- add an explicit instruction not to sign routine replies unless asked
- clear or restart affected sessions if old persona context persists

This belongs in OpenClaw integration tracking because it is about OpenClaw's
workspace bootstrap and session context, not about Setpack's generic pack
selection or wrapper model.

## 4. Current Work Targets

- keep OpenClaw-specific integration consequences here
- avoid duplicating deep email-tool analysis that belongs in `Emails.md`
- use this file as the staging area before promoting durable architectural
  conclusions back into `Setpack.md`
- keep transient channel validation status here only while it affects OpenClaw
  pack setup; move durable scheduling and cleanup tasks to `Setplan.md`

## 5. Migration Intent

Over time, this file should absorb:

- OpenClaw-specific integration findings now scattered through `ClawInfo.md`
- current wrapper/config/auth observations that are specific to OpenClaw as an
  application
- settled model/provider/profile presentation guidance

`ClawInfo.md` should then shrink toward a more inventory-like record.
