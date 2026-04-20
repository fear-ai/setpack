# Neverest

This note captures the current Neverest-specific work around the OpenClaw and Setpacks environment.

Use `Setpack.md` for the general Setpack design, `Setplan.md` for active
planning, `ClawInfo.md` for current inventory, and `Setpimalaya.md` for the
coordinated Setpack-facing treatment of `himalaya` + `neverest`.

It is intentionally kept out of `Setpack.md`.

Reason:

- `Setpack.md` is the general design and architecture document for sets, packs, components, refs, validation, and restore behavior
- this note is about one concrete module and the current local work done around it
- current inventory belongs in `ClawInfo.md`
- coordinated Pimalaya integration work belongs in `Setpimalaya.md`
- deeper mail-domain and upstream-tool work belongs in
  `/Users/walter/Work/Claw/Emails/Emails.md`
- this file remains as an older Neverest-specific working note

## 1. Role

`neverest` is a complementary Pimalaya-family tool for mailbox synchronization, backup, restore, and repair-oriented workflows.

It is not the same thing as `himalaya`.

Current working split:

- `himalaya`
  - message-level operations
  - read, compose, reply, forward, organize mail
- `neverest`
  - synchronize mailboxes
  - maintain backup / mirror workflows
  - support restore and recovery-oriented operations
  - run provider and store health checks via `doctor`

## 2. Current local state

Observed local binary:

- path: `/Users/walter/.cargo/bin/neverest`
- version: `neverest v1.0.0 +wizard +imap +maildir`

Earlier local review concluded:

- Neverest should be treated as a separate skill from Himalaya
- it should not be folded into the bundled `himalaya` skill as if they were one tool
- local OpenClaw work should prefer workspace or managed-extension approaches over editing bundled `node_modules` skills unless preparing upstream changes

## 3. OpenClaw skill work completed

A workspace skill draft was created for Neverest at:

- `/Users/walter/Work/Claw/Setpacks/openclaw/today/openclaw/workspace/skills/neverest/SKILL.md`

That draft was written to be self-contained and practically usable.

Covered there:

- when to use Neverest versus Himalaya
- expected config structure
- minimal TOML example
- `neverest doctor`
- `neverest configure`
- `neverest synchronize`
- dry-run and safety workflow
- provider notes for Gmail, Proton Bridge, Outlook, and iCloud
- JSON output and debugging guidance

The skill was also checked with OpenClaw skill loading and was recognized as eligible.

## 4. Why it has its own document

Neverest details do not belong in the high-level Setpack design doc.

They are too specific to:

- current OpenClaw module usage
- the Pimalaya tool split
- the local deployment and documentation effort
- current operator questions about sync versus message actions

This file is the right place for:

- local module rationale
- detailed CLI notes
- integration status
- future packaging notes specific to Neverest

## 5. Commands and workflow currently considered important

Useful Neverest commands from the current work:

- `neverest configure`
- `neverest doctor`
- `neverest synchronize`

Recommended operating posture:

1. validate config first
2. run `doctor`
3. prefer conservative or dry-run-style checks when available
4. only then run real synchronization against the intended account/store

## 6. Relationship to Setpack and ClawInfo

- `Setpack.md`
  - should stay generic and architecture-only
- `Setplan.md`
  - should track active decisions and prioritization
- `Setpimalaya.md`
  - should absorb the Setpack-facing implications of `neverest` and
    `himalaya` together
- `ClawInfo.md`
  - should stay closer to current-state inventory
- `Emails.md`
  - should hold the deeper Pimalaya and email-tool research

## 7. Follow-up candidates

Possible later follow-up, if Neverest becomes a first-class managed component:

- define a pack-local Neverest wrapper and runtime layout
- define config-set, cred-set, persistent-state, and runtime-state expectations
- add validation and import/export rules for Neverest-specific artifacts
- decide how much of the current workspace skill should be upstreamed versus kept local

For now, this note is the durable home for the current Neverest work details.
