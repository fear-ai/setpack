# Setplan

Active planning notebook for the Setpack work: open questions, sequencing,
unsettled design choices, and current priorities. Stable architecture does not
belong here.

## 1. Purpose

This file tracks work that is still moving: sequencing, unresolved design
choices, migration staging, and near-term priorities. Once a conclusion is
stable, it should stop living here.

## 2. Current Direction

The current documentation and implementation work should separate:

- stable Setpack design
- current observed OpenClaw and pack state
- OpenClaw-specific integration work
- Pimalaya-specific integration work
- deep email-tool and provider research

Current configuration direction:

- prefer SecretRef to `file` by default for credential-bearing parameters
- avoid environment-variable storage as the default project credential path,
  because env-backed secrets tend to sprawl into shell startup files and drift
  away from project-associated and repo-associated credential handling
- do not introduce long-lived OpenClaw config "profiles" as a first-class
  Setpack concept; materially different configurations should become distinct
  packs
- still allow limited in-pack config fiddling for manual debug and validation
  work when useful
- for provider routes that are operationally distinct, prefer labels that say
  so explicitly, for example:
  - `anthropic [API]`
  - `claude-cli [OAuth]`
  - `openai [API]`
  - `codex [OAuth]`
- treat a pack as a definitive collection, not as a dumping ground for every
  possible account or provider permutation
- do not push toward wider use of short model aliases; prefer one stable
  canonical name even when it is long or somewhat cryptic

Immediate documentation targets:

1. keep `Setpack.md` architecture-only
2. move active decisions and prioritization here
3. concentrate OpenClaw-specific integration notes in `apps/Setclaw.md`
4. concentrate Setpack-facing `himalaya` + `neverest` notes in
   `apps/Setpimalaya.md`
5. keep `Emails.md` as the deep home for:
   - Pimalaya family
   - `gogcli`
   - `gws`
   - Maildir and local mail/data surfaces

## 3. Current Status By Topic

### 3.1 Documentation

- `Setpack.md` remains the stable architecture and project-design document.
- `Setplan.md` is now the active tracker for decisions, tasks, sequencing, and
  deferred issues.
- `apps/Setclaw.md` is the OpenClaw-specific integration note.
- `apps/ClawModels.md` is the detailed OpenClaw model/provider/auth reference.
- `Emails.md` remains the deep notebook for mail-domain and tool research,
  including Pimalaya, `gogcli`, and `gws`.

### 3.2 Generic Setpack Substrate

- The current controller direction is layered:
  - generic set/pack setup and wrapper/path materialization
  - application-specific component handlers
  - combination handlers for apps that call or coordinate with other apps
- `repack --force` intentionally prioritizes predictable developer behavior by
  killing pack-managed runtime processes and clearing stale LaunchAgent state
  before rewriting the selected pack.
- Ordinary `repack` changes future shell and launch resolution only.

### 3.3 OpenClaw `apr20`

- `apr20` is the active pack under direct validation.
- OpenClaw config, state, and credentials are intentionally separated:
  - config: `openclaw/config/openclaw.json`
  - state: `openclaw/state`
  - credentials: `openclaw/cred`
- Gateway pairing was recovered by approving a local device scope-upgrade
  request; the browser Control UI required a page reload afterward.
- Slack socket mode is enabled and probes as connected, but no Slack channel
  allowlist entries have been configured yet.
- Telegram probes as connected in polling mode as `@WaKaTeleBot`; the supplied
  Telegram user id is allowlisted, but no Telegram group id has been captured
  or configured yet.
- Discord probes as connected. Current channel work is postponed except for
  preserving the observed state and cleanup tasks.
- The assistant signing as `Nova` is workspace-persona leakage from OpenClaw
  workspace files, not a Discord bot-name change.

### 3.4 Models And Provider Auth

- Current model direction is to keep canonical refs visible and avoid relying
  on short aliases.
- API-backed and OAuth-backed routes remain operationally distinct:
  - `anthropic [API]`
  - `claude-cli [OAuth]`
  - `openai [API]`
  - `codex [OAuth]`
- No Google Gemini routes are currently intended for this pack.
- Broader OpenClaw model-catalog and UI-label cleanup remains deferred.

### 3.5 Email And Google Tools

- `gogcli` remains the practical Gmail-first Google-native operations CLI.
- `gws` remains the schema-first Google Workspace API CLI.
- `himalaya` and `neverest` should be treated as the coordinated Pimalaya
  subsystem, not as unrelated mail tools.

## 4. Coded Tracker

### 4.1 Planning And Documentation

- `PLAN-001`: keep `Setplan.md` organized by topic and scheduling window
  rather than by raw chronology.
- `PLAN-002`: keep stable short codes on actionable items so discussions do not
  depend on section order.
- `DOC-001`: finish the documentation split cleanly, with stable architecture
  in `Setpack.md` and active work here.
- `DOC-002`: preserve findings before applying large configuration changes.
- `DOC-003`: keep component boundaries explicit in docs before enforcing them
  in code.
- `DOC-004`: decide what remains in `apps/ClawInfo.md` after OpenClaw
  integration findings move into `apps/Setclaw.md` and model findings move into
  `apps/ClawModels.md`.

### 4.2 Pack Substrate And Scripts

- `PKG-001`: revisit the strengthened `repack --force` behavior after more use;
  confirm kill scope, document exact boundaries, and decide whether process
  teardown should stay root-wide or narrow to the previously selected pack.
- `PKG-002`: design script layering so higher-level pack scripts call narrower
  app-specific or combination-specific scripts rather than absorbing all logic.
- `PKG-003`: define `reversible changes` precisely enough to either keep or
  replace the term.
- `PKG-004`: decide which hybrid deployment and validation patterns are real
  design targets rather than speculative examples.
- `CFG-001`: keep pack-level configuration variation modeled as separate packs,
  not as a first-class runtime profile system.
- `CFG-002`: define the boundary between acceptable in-pack debug edits and a
  change large enough to justify a separate pack.
- `CFG-003`: revisit fragment-based source config assembly only as a deferred
  packaging question, not as an OpenClaw-native runtime capability.

### 4.3 Credentials And Auth Stores

- `CRED-001`: make SecretRef-to-file the default Setpack credential pattern
  unless there is a specific reason to prefer another source.
- `CRED-002`: define when env-backed SecretRefs are still acceptable despite
  not being the default.
- `CRED-003`: decide how Setpack should handle external CLI homes reused by
  OpenClaw, especially `.codex`, `.claude`, and explicit `CODEX_HOME` or
  `CLAUDE_CONFIG_DIR` overrides.
- `CRED-004`: keep credential-bearing OpenClaw stores such as
  `auth-profiles.json` and `auth.json` with pack credentials, exposing them into
  OpenClaw state only when OpenClaw requires that path.
- `CRED-005`: review user-facing metadata leakage before public release,
  including whether account email addresses appear in wrapper output, state
  filenames, reports, or diagnostics.

### 4.4 OpenClaw Gateway And Runtime

- `GATEWAY-001`: recheck the following `apr20` observations against a newer
  upstream build, especially `2026.4.21`, before spending time on code
  analysis:
  - occasional incomplete gateway snapshots in status commands
  - transient `Gateway self: unknown` output despite later runs showing valid
    gateway self presence
  - likely false-positive Discord legacy warning claiming
    `channels.discord.guilds.<id>.channels.<id>.allow` is still present after
    the pack config was already normalized to `enabled`
- `GATEWAY-002`: document and test the LaunchAgent state transitions that matter
  for pack switching:
  - stop
  - bootout
  - reinstall
  - restart
  - status after UI reload
- `STATE-001`: decide how validation and smoke-test OpenClaw sessions should be
  handled so they do not persist unintentionally in the normal session
  inventory; options include explicit cleanup, a separate test store, or a
  hidden/test-marked class of sessions.

### 4.5 OpenClaw Channels

- `CHAN-001`: postpone Discord channel policy work until the current gateway and
  upstream-version questions are settled; preserve current observations only.
- `CHAN-002`: resolve the configured Discord channel that probes as `Missing
  Access` before treating it as an enabled channel.
- `CHAN-003`: decide whether to delete old disabled Discord session state or
  preserve it as validation residue.
- `CHAN-004`: finish Telegram group setup by capturing the target negative
  group id and adding a `channels.telegram.groups` allowlist entry.
- `CHAN-005`: decide whether Telegram BotFather privacy should be disabled for
  OpenClaw group use, or whether group messages must mention `@WaKaTeleBot`.
- `CHAN-006`: finish Slack group setup by adding explicit Slack channel ids
  under the socket-mode allowlist.
- `CHAN-007`: remove or rewrite OpenClaw workspace persona material that causes
  assistant replies to sign as `Nova`, and clear or restart affected sessions
  if prior context persists.

### 4.6 Models

- `MODEL-001`: keep API and OAuth routes visibly distinct in OpenClaw model
  documentation and pack review.
- `MODEL-002`: avoid carrying multiple low-end or exploratory accounts inside a
  definitive pack unless the pack explicitly validates that permutation.
- `MODEL-003`: avoid expanding short aliases; prefer canonical refs even when
  long.
- `MODEL-004`: postpone broader review of separate label paths for configured
  options, default wrappers, onboarding choices, and catalog entries until
  immediate pack and model-configuration work settles.

### 4.7 Email And Google Tooling

- `EMAIL-001`: keep `Emails.md` as the deep notebook for mail-domain and tool
  research.
- `EMAIL-002`: keep Pimalaya material grouped as one family, with `neverest`
  and `himalaya` treated as coordinated tools.
- `EMAIL-003`: keep `gogcli` and `gws` documented as different Google tooling
  surfaces rather than substitutes.
- `EMAIL-004`: decide which mail and Google tools become first-class managed
  components versus remain wrapped system tools.

## 5. Scheduling

### 5.1 Now

1. keep `Setpack.md` architecture-only
2. keep new OpenClaw channel/persona facts in `apps/Setclaw.md`
3. finish Telegram group id capture or explicitly postpone it
4. add Slack channel ids when known
5. avoid more Discord changes until the gateway/upstream recheck is scheduled

### 5.2 Next

1. validate `repack --force` behavior through a full pack switch and gateway
   restart cycle
2. review the precise kill scope and document what is intentionally terminated
3. decide how to clean or isolate OpenClaw smoke-test sessions
4. normalize OpenClaw credential-bearing files into the credential placement
   strategy
5. review OpenClaw workspace prompt files for persona leakage and operator
   safety

### 5.3 Later

1. evaluate fragment-based source config assembly for application configs
2. evaluate generated or symlinked runtime config targets as a standard
   Setpack pattern
3. decide whether Pimalaya-specific notes in `/Users/walter/Work/Claw/Emails`
   should eventually split into a dedicated `Pimalaya.md`
4. investigate OpenClaw gateway snapshot and legacy-warning behavior only after
   rechecking a newer upstream OpenClaw build

## 6. Legacy Script Notes To Preserve Before Disposition

The notes below refer to the earlier removed shell sketch tree, not to the
current repo-local `scripts/` collection. That older shell was not an
authoritative controller. It carried stale path assumptions and incomplete
logic, but several design points were still worth preserving.

### 6.1 Intended Controller Boundaries

The old script sketches captured a useful split of responsibilities:

- planning reads a set/pack layout and reports what would be operated
- apply walks components and dispatches to install or materialization adapters
- validate performs pack-level and component-level checks
- generic adapter dispatch should stay separate from per-application hooks
- application-specific logic should live in app-focused hooks rather than in a
  monolithic controller path

This remains relevant even if the concrete shell implementation is discarded.

### 6.2 Wrapper-First Execution

The sketches correctly pointed toward wrapper-first execution as the primary
Setpack model:

- generated per-component wrappers are the intended command entrypoints
- pack `bin/` PATH injection exists for helper resolution, not as a dynamic
  global shim mechanism
- Setpack should continue to differ from `pyenv` or `nvm` style global shim
  interception

This aligns with the current repo-root `setpack` direction and should stay part
of the approved execution model.

### 6.3 Adapter Model Still Worth Keeping

The old scripts also captured a still-useful abstraction:

- generic install/materialization handling can classify components by adapter
  strategy
- application-specific hooks can refine behavior for tools such as `openclaw`
- `system-existing` remains a valid concept when the goal is to wrap and record
  an already-installed tool rather than reinstall it

The shell implementation should not be reused directly, but the adapter split
is still a sound design idea.

### 6.4 CI And Headless Auth Direction

One of the most useful preserved points from the script notes is the CI
direction:

- first-time OAuth login should not be expected to happen inside CI
- CI and restore flows should import already-exported portable token artifacts
- the credential source of truth should be transportable artifacts, not
  interactive browser startup

This remains especially relevant for Google-facing tools such as `gogcli` and
`gws`, and for any future automated restore or validation workflow.

### 6.5 What Not To Preserve As Active Design

The following parts of the old removed script tree should be treated as obsolete
implementation detail rather than something to repair in place:

- line-oriented pseudo-TOML parsing
- hardcoded assumptions about legacy pack roots
- shell sketches that only log intended behavior without enforcing it
- any implication that the old `scripts/` tree is authoritative

### 6.6 Later Disposition

When referring back to that earlier shell work, preserve only these captured
design points, not the old implementation as current operational guidance.
