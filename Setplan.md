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

## 3. Current Work Areas

### 3.1 Documentation Restructuring

- keep `Emails.md` as the deep notebook for mail-domain and tool research
- concentrate Pimalaya material there into one large family section
- keep `gogcli` after Pimalaya
- keep `gws` after `gogcli`
- use repo-local app notes for Setpack-facing integration consequences only

### 3.2 OpenClaw / Setpack Integration

- normalize where OpenClaw config, auth, state, and secrets belong
- continue separating:
  - `openclaw.json`
  - `auth-profiles.json`
  - external credential artifacts
- keep model/provider/profile/alias handling explicit and uniform
- continue documenting wrapper and gateway behavior from a Setpack point of
  view
- review user-facing metadata leakage before any public release, including
  whether account email addresses appear in:
  - wrapper-visible output
  - state filenames
  - reports or exported diagnostics
- split work cleanly between:
  - generic pack substrate
  - OpenClaw component-specific handling
  - OpenClaw plus helper-app combinations such as `gog`

### 3.3 Pimalaya / Setpack Integration

- treat `himalaya` and `neverest` as one coordinated subsystem
- keep the split explicit:
  - `neverest` for sync / mirror / backup / restore / doctor
  - `himalaya` for message interaction
- document Setpack-specific consequences:
  - config placement
  - cred placement
  - state placement
  - wrapper expectations
  - local store expectations
- keep the generic pack substrate separate from subsystem-specific wrapper or
  store logic

### 3.4 Google Tooling Positioning

- keep `gogcli` as the practical Gmail-first Google-native operations CLI
- keep `gws` as the more schema-first Google Workspace API CLI
- document the difference rather than treating them as substitutes

## 4. Open Questions

- What should become first-class managed components versus remain external
  system tools?
- Which responsibilities belong to:
  - the general set/pack substrate
  - application-specific component handlers
  - higher-level combination handlers for cooperating apps?
- How much of current app configuration should be materialized versus left in
  native tool stores?
- What should `reversible changes` mean precisely in Setpack terms:
  - wrapper and path rollback
  - credential-set swapping
  - component downgrade or replacement
  - isolation of validation residue from long-term state
- How should shared credential sources be handled across:
  - OpenClaw
  - `gogcli`
  - `gws`
  - Pimalaya tools
- What is the right steady-state role of `apps/ClawInfo.md` once material is
  absorbed into `apps/Setclaw.md` and `apps/Setpimalaya.md`?
- Which hybrid patterns should become first-class instead of ad hoc:
  - pack-local wrappers around system-installed binaries
  - local validation followed by CI promotion
  - host-shaped tools coordinated beside containerized sidecars
  - eventual handoff into more formal deployment systems

## 5. Issues And Decisions To Sort

- `PLAN-001`: restructure `Setplan.md` itself so active items are grouped more
  clearly into decisions, open issues, implementation tasks, and deferred work
- `PLAN-002`: assign stable short codes to tracked items so discussion can
  reference them without depending on section order or wording
- `CRED-001`: make SecretRef-to-file the default Setpack credential pattern
  unless there is a specific reason to prefer another source
- `CRED-002`: define when env-backed SecretRefs are still acceptable despite
  not being the default
- `CRED-003`: decide how Setpack should handle external CLI homes reused by
  OpenClaw, especially `.codex`, `.claude`, and any explicit `CODEX_HOME`
  override
- `CFG-001`: keep pack-level configuration variation modeled as separate packs,
  not as a first-class runtime profile system
- `CFG-002`: define the boundary between acceptable in-pack debug edits and a
  change large enough to justify a separate pack
- `CFG-003`: revisit fragment-based source config assembly only as a deferred
  packaging question, not as an OpenClaw-native runtime capability

## 6. Immediate Priorities

1. finish the documentation split cleanly
2. preserve findings before applying large configuration changes
3. keep component boundaries explicit in docs before enforcing them in code
4. sort decisions by subject and by application before implementation changes
5. define `reversible changes` well enough to either keep or replace the term
6. decide which hybrid deployment and validation patterns are real design targets
   rather than speculative examples
7. design script layering so higher-level pack scripts call narrower
   app-specific or combination-specific scripts rather than absorbing all logic
8. restructure `Setplan.md` into a clearer coded tracker before it grows
   further

## 7. Deferred

- broad cleanup of older historical notes
- deciding whether `apps/ModelNames.md` remains separate or is absorbed into
  `apps/Setclaw.md`
- deciding whether Pimalaya-specific notes inside `/Users/walter/Work/Claw/Emails`
  should eventually split into a dedicated `Pimalaya.md`
- evaluating a fragment-based config source layout for application configs,
  where component-specific files such as Discord are authored separately and
  merged into one runtime `openclaw.json`
- evaluating whether generated or symlinked runtime config targets are worth
  standardizing as a Setpack pattern, instead of keeping the final runtime
  config as the only authoritative file

## 8. Legacy Script Notes To Preserve Before Disposition

The notes below refer to the earlier removed shell sketch tree, not to the
current repo-local `scripts/` collection. That older shell was not an
authoritative controller. It carried stale path assumptions and incomplete
logic, but several design points were still worth preserving.

### 8.1 Intended Controller Boundaries

The old script sketches captured a useful split of responsibilities:

- planning reads a set/pack layout and reports what would be operated
- apply walks components and dispatches to install or materialization adapters
- validate performs pack-level and component-level checks
- generic adapter dispatch should stay separate from per-application hooks
- application-specific logic should live in app-focused hooks rather than in a
  monolithic controller path

This remains relevant even if the concrete shell implementation is discarded.

### 8.2 Wrapper-First Execution

The sketches correctly pointed toward wrapper-first execution as the primary
Setpack model:

- generated per-component wrappers are the intended command entrypoints
- pack `bin/` PATH injection exists for helper resolution, not as a dynamic
  global shim mechanism
- Setpack should continue to differ from `pyenv` or `nvm` style global shim
  interception

This aligns with the current repo-root `setpack` direction and should stay part
of the approved execution model.

### 8.3 Adapter Model Still Worth Keeping

The old scripts also captured a still-useful abstraction:

- generic install/materialization handling can classify components by adapter
  strategy
- application-specific hooks can refine behavior for tools such as `openclaw`
- `system-existing` remains a valid concept when the goal is to wrap and record
  an already-installed tool rather than reinstall it

The shell implementation should not be reused directly, but the adapter split
is still a sound design idea.

### 8.4 CI And Headless Auth Direction

One of the most useful preserved points from the script notes is the CI
direction:

- first-time OAuth login should not be expected to happen inside CI
- CI and restore flows should import already-exported portable token artifacts
- the credential source of truth should be transportable artifacts, not
  interactive browser startup

This remains especially relevant for Google-facing tools such as `gogcli` and
`gws`, and for any future automated restore or validation workflow.

### 8.5 What Not To Preserve As Active Design

The following parts of the old removed script tree should be treated as obsolete
implementation detail rather than something to repair in place:

- line-oriented pseudo-TOML parsing
- hardcoded assumptions about legacy pack roots
- shell sketches that only log intended behavior without enforcing it
- any implication that the old `scripts/` tree is authoritative

### 8.6 Later Disposition

When referring back to that earlier shell work, preserve only these captured
design points, not the old implementation as current operational guidance.
