# Setpimalaya

## 1. Purpose

This note is the Setpack-facing integration document for the coordinated
Pimalaya subsystem.

In this project, that means:

- `himalaya`
- `neverest`

Use it for:

- Setpack-specific handling of their config, cred, state, and wrapper needs
- the tandem split between sync/mirror operations and message interaction
- local-store implications for `~/.Mail` and related Maildir use
- how the Pimalaya tools should be represented in Setpack packs and OpenClaw
  integration

Do not use it as the deep notebook for Pimalaya itself. That belongs under
`/Users/walter/Work/Claw/Emails/Emails.md`.

## 2. Scope

This document should gradually absorb the Setpack-specific consequences of the
Pimalaya work that are currently spread across:

- `apps/Neverest.md`
- `apps/ClawInfo.md`
- local pack notes

It should not duplicate the broad domain and upstream-repo review that already
exists in `Emails.md`.

## 3. Working Model

Treat `himalaya` and `neverest` as one coordinated subsystem, not as unrelated
CLI tools.

Current functional split:

- `neverest`
  - synchronize
  - mirror
  - back up
  - restore
  - validate mailbox health with `doctor`
- `himalaya`
  - list, read, and inspect messages
  - reply, forward, and compose
  - move, copy, flag, and delete

This split should remain visible in Setpack docs and future component handling.

## 4. Setpack-Relevant Themes

### 4.1 Config Placement

Both tools are strongly config-driven and already use native config files.

Setpack work here should decide:

- how much native config is preserved as-is
- how much is materialized from Setpack-owned input
- how shared account information should be represented

### 4.2 Credential Handling

Current local reality uses command-based password lookup and system keychain
integration. Setpack needs a clear stance on:

- native `auth.cmd` style lookup
- file-backed secrets
- shared mail-account secret sources

### 4.3 State and Local Stores

The Pimalaya subsystem is closely tied to local mail stores, especially
Maildir-backed state under `~/.Mail`.

That means Setpack-facing notes here need to stay aware of:

- when mail stores are external operator state
- when they should be treated as managed state
- how `neverest` and `himalaya` interact with the same local stores

## 5. Migration Intent

Over time, this file should absorb:

- the Setpack-specific parts of `apps/Neverest.md`
- coordinated `himalaya` + `neverest` integration decisions
- wrapper/layout/import/export implications for a future managed Pimalaya
  component or component pair

The deep technical review, upstream notes, and broader ecosystem analysis should
remain in `/Users/walter/Work/Claw/Emails/Emails.md`.
