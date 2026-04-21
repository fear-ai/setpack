# Setpimalaya

Setpack-facing note for the coordinated Pimalaya subsystem, especially
`himalaya` and `neverest` as a paired environment with shared config,
credential, state, and local-store concerns.

## 1. Purpose

This file covers Setpack-specific handling of the coordinated Pimalaya
subsystem, especially `himalaya` and `neverest` as a paired environment with
shared config, credentials, state, wrappers, and local-store concerns.

## 2. Scope

This file should hold the Setpack consequences of that subsystem rather than
the broader provider or upstream research around it.

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

It is also a combination layer rather than a generic pack concern. The general
set and pack substrate belongs in `Setpack.md`. This file is for the
cooperation-specific handling of `himalaya` and `neverest` as one managed
subsystem.

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
remain in `Claw/Emails/Emails.md`.
