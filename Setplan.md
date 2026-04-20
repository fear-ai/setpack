# Setplan

## 1. Purpose

This document is the active planning notebook for the Setpack project.

Use it for:

- ongoing work
- open questions
- design decisions in progress
- issue and task planning
- prioritization

Do not use it for the stable architecture itself. Approved core design belongs
in `Setpack.md`.

Do not use it as the deep technical notebook for email tools. That work belongs
under `/Users/walter/Work/Claw/Emails`, especially `Emails.md`.

## 2. Document Map

- `Setpack.md`
  - core architecture, terminology, invariants, and approved design
- `apps/Setclaw.md`
  - OpenClaw-specific Setpack integration work
- `apps/Setpimalaya.md`
  - Setpack-facing integration work for the Pimalaya subsystem
- `apps/ClawInfo.md`
  - current-state inventory and older captured facts
- `apps/ModelNames.md`
  - focused model/provider/profile/alias naming notes
- `/Users/walter/Work/Claw/Emails/Emails.md`
  - email-domain and mail-tool research

## 3. Current Direction

The current documentation and implementation work should separate:

- stable Setpack design
- current observed OpenClaw and pack state
- OpenClaw-specific integration work
- Pimalaya-specific integration work
- deep email-tool and provider research

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

## 4. Current Work Areas

### 4.1 Documentation Restructuring

- keep `Emails.md` as the deep notebook for mail-domain and tool research
- concentrate Pimalaya material there into one large family section
- keep `gogcli` after Pimalaya
- keep `gws` after `gogcli`
- use repo-local app notes for Setpack-facing integration consequences only

### 4.2 OpenClaw / Setpack Integration

- normalize where OpenClaw config, auth, state, and secrets belong
- continue separating:
  - `openclaw.json`
  - `auth-profiles.json`
  - external credential artifacts
- keep model/provider/profile/alias handling explicit and uniform
- continue documenting wrapper and gateway behavior from a Setpack point of
  view

### 4.3 Pimalaya / Setpack Integration

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

### 4.4 Google Tooling Positioning

- keep `gogcli` as the practical Gmail-first Google-native operations CLI
- keep `gws` as the more schema-first Google Workspace API CLI
- document the difference rather than treating them as substitutes

## 5. Open Questions

- What should become first-class managed components versus remain external
  system tools?
- How much of current app configuration should be materialized versus left in
  native tool stores?
- How should shared credential sources be handled across:
  - OpenClaw
  - `gogcli`
  - `gws`
  - Pimalaya tools
- What is the right steady-state role of `apps/ClawInfo.md` once material is
  absorbed into `apps/Setclaw.md` and `apps/Setpimalaya.md`?

## 6. Immediate Priorities

1. finish the documentation split cleanly
2. preserve findings before applying large configuration changes
3. keep component boundaries explicit in docs before enforcing them in code
4. sort decisions by subject and by application before implementation changes

## 7. Deferred

- broad cleanup of older historical notes
- deciding whether `apps/ModelNames.md` remains separate or is absorbed into
  `apps/Setclaw.md`
- deciding whether Pimalaya-specific notes inside `/Users/walter/Work/Claw/Emails`
  should eventually split into a dedicated `Pimalaya.md`

## 8. Legacy Script Notes To Preserve Before Disposition

The material under `scripts/` should not be treated as the active Setpack
controller. It is a sketch tree with stale path assumptions and incomplete
shell logic. The shell itself is a disposition candidate, but several design
points are still worth preserving here before the directory is moved.

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

The following parts of the old script tree should be treated as obsolete
implementation detail rather than something to repair in place:

- line-oriented pseudo-TOML parsing
- hardcoded assumptions about legacy pack roots
- shell sketches that only log intended behavior without enforcing it
- any implication that the old `scripts/` tree is authoritative

### 8.6 Later Disposition

When the `scripts/` directory is moved or archived, preserve only these
captured design points, not the old shell as current operational guidance.
