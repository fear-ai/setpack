# Setpack

## 1. Purpose

This document is a technical reference for `setpack`, the proposed controller for constructing, naming, running, saving, restoring, and validating local Claw environments.

It describes the target system, not the current machine state.

Current local facts, installed binaries, live config, live credentials, and observed package behavior are documented in `ClawInfo.md`.

The immediate target is the current stack:

- `openclaw`
- `gogcli`
- `himalaya` and related Pimalaya programs
- future add-ons

The core problem is not just program versions. It is the combination of:

- installable program artifacts
- package and library dependencies
- component-specific config
- credentials in different formats and backends
- persistent state
- runtime state
- path wiring between all of the above

Putting credentials, config, workspace, and runtime state into the same `~/.openclaw*` tree invites accidental commits, unsafe image baking, and ambiguous restore behavior.

## 2. Decision

Use a hybrid model:

- one unified **set** for each deployment family, such as `openclaw`
- one or more **packs** inside that set, such as `today`, `dev`, or `prod`
- separate **per-component parameterization** under each pack

This is the right tradeoff.

Unified-only is too coarse:

- it makes per-component restore and substitution awkward
- it encourages one giant mutable state tree

Per-package-only is too fragmented:

- it makes deployment selection awkward
- it loses the convenience of one stable operator-facing name

The model here is:

- one set names the deployment family
- one pack names the concrete runnable deployment inside that set
- each package under that pack has its own bundle, config set, cred set, persistent state, and runtime paths
- the pack manifest decides which package refs are combined

## 3. Naming

These terms should be used consistently.

### 3.1 Set

A named deployment family that contains one or more packs.

Examples:

- `openclaw`
- `clawdbot`

A set groups related packs under one stable top-level name.

### 3.2 Pack

A concrete runnable deployment inside a set.

Examples:

- `today`
- `dev`
- `prod`

A pack is a composition of component-specific refs.

### 3.3 Component

A distinct managed member inside a pack.

Examples:

- `openclaw`
- `gogcli`
- `himalaya`
- future add-ons such as `neverest`, `email-oauth2-proxy`, or a custom sidecar

### 3.4 Bundle

An immutable installable package artifact.

Examples:

- an npm-built OpenClaw dist pinned to a specific lockfile and commit
- a downloaded `gogcli` release tarball
- a specific `himalaya` binary release or source build

Bundles should describe how they were produced, but they do not need to contain every runtime utility used around them.

### 3.5 Toolchain Ref

A separately versioned runtime or build dependency used by one or more bundles.

Examples:

- `node@25.6.1`
- `pnpm@10.8.1`
- `python@3.12.9`
- `rust@1.86.0`

Toolchain refs are supported, but optional.

Reason:

- sometimes per-pack toolchain pinning is important for reproducibility
- sometimes it is unnecessary operational complexity
- the model should support both cases without forcing either

### 3.5 Config Set

Non-secret package configuration.

Examples:

- `openclaw.json` template values
- `himalaya` account layout and folder aliases
- CLI ports, paths, model routing, feature flags

### 3.6 Cred Set

Credential material or credential references used by a package.

Examples:

- OpenAI API key
- Discord bot token
- `gogcli` OAuth client file
- a Keychain reference for a Himalaya Gmail app password

### 3.7 State Snapshot

Portable persistent state captured from a package or an entire instance.

Examples:

- `openclaw` agent auth profiles and device identity
- `gogcli` token/keyring export
- workspace memory pack

### 3.8 Runtime State

Ephemeral or disposable state.

Examples:

- logs
- sessions
- temporary watch state
- pending pairings

### 3.9 Ref

A distinctive identifier for a bundle, config set, cred set, or snapshot.

Recommended format:

```text
<name>@<version-or-timestamp>[+<build-or-commit>][#sha256:<digest>]
```

Examples:

- `openclaw@2026.2.25+git.78ddb1e9df#sha256:...`
- `gogcli@0.12.0+c18c58c#sha256:...`
- `openclaw-config@mail-v3#sha256:...`
- `himalaya-cred@2026-04-11#sha256:...`
- `openclaw-state@2026-04-11T21:30:00Z#sha256:...`

This aligns with common industry patterns:

- semantic versions where available
- commit/build metadata where needed
- content hash for uniqueness and integrity

### 3.10 Setup Components

Setpack should treat these as ordinary setup components:

- A. system and third-party tools
  examples: `node`, `pnpm`, `python`, `rust`, `nvm`
- B. code or binary components
  examples: `openclaw`, `gogcli`, `himalaya`
- C. per-component runtime inputs
  `config`, `cred`, and `state`

Phase 1 assumptions:

- each component owns its own `config`, `cred`, and `state`
- default component locations such as `~/.config/...` or component-specific dotfiles are allowed
- one component may use one primary state location even if the real component later grows multiple state roots
- overlaps between component credential formats are noted but not reconciled automatically yet

Later phases may reconcile overlaps and split one package's state into multiple declared subcomponents.

### 3.11 Phase 0 Capture Strategy

Before relocating installs or building reproducible bundles, the first practical step should be:

- keep current system or user-global installs in place
- capture all parametrization and setup around them

That means:

- treat the currently resolved binary as the package bundle source
- move or copy only `config`, `cred`, and `state` into controlled locations
- run packages through controlled wrappers even while the binaries remain system-managed

This is the lowest-risk validation step because it changes execution wiring and persistence layout before it changes the package install method.

## 4. Placement and Permissions Model

The controller should be named `setpack`.

This document remains Claw-specific where needed, but the controller naming should stay generic.

`packer` is too overloaded, and `runconf` is too narrow for install, archive, validate, and run orchestration.

`setpack` is the best fit of the three.

The system should not require any specific top-level tree such as XDG, `~/...`, or account-local dotfiles.

The important abstraction is:

- `placement`
  where an artifact lives
- `class`
  what kind of artifact it is
- `permissions`
  who may read, write, or execute it

These must be modeled separately.

### 4.1 Why Location and Access Control Must Not Be Conflated

Directory conventions such as:

- `~/.config`
- `~/.local/state`
- `/opt`
- `/var/lib`
- `/etc`

describe placement conventions, not access-control policy.

Examples:

- a secret in an account-attached location can still be dangerously permissive
- a bundle in a shared system path can still be safe if it is immutable and tightly owned
- a config can live beside a bundle if write permissions are controlled

Setpack therefore treats path placement and permission policy as independent inputs.

### 4.2 Storage Classes

Every managed artifact belongs to one of these classes:

- `bundle`
- `toolchain`
- `config`
- `cred`
- `state`
- `runtime`

### 4.3 Placement Profiles

Setpack should support multiple placement profiles.

Examples:

- `xdg-user`
- `account-local`
- `system-local`
- `mixed`
- `custom`

`xdg-user` is only one convenient default, not the required model.

### 4.4 Path Registry

Each instance should resolve to a path registry rather than assume one fixed directory tree.

Example:

```toml
[paths]
bundle_root = "/opt/setpack/bundles"
toolchain_root = "/opt/setpack/toolchains"
config_root = "/etc/setpack/instances/prod"
cred_root = "/Users/walter/.setpack-cred/prod"
state_root = "/var/lib/setpack/instances/prod"
runtime_root = "/var/run/setpack/instances/prod"
```

Nothing in the model requires these roots to be siblings or to live under the same account.

### 4.5 Permission Profiles

Permissions should be declared explicitly.

Recommended logical profiles:

- `immutable_shared`
- `instance_owner_rw`
- `service_account_rw`
- `ephemeral_rw`
- `cred_owner_only`

Examples:

- bundle dirs: `immutable_shared`
- toolchain dirs: `immutable_shared`
- config dirs: `instance_owner_rw` or `service_account_rw`
- cred dirs: `cred_owner_only`
- runtime dirs: `ephemeral_rw`

## 5. Toolchain and Install Method Model

### 5.1 Toolchain and System Version Policy

System utilities such as `node` should be versioned per pack only when they
materially affect reproducibility.

Default approach:

- allow `system` toolchains by default
- support `nvm` as a practical Node version source
- pin a pack-local toolchain only when build or runtime behavior depends on it
- allow a component to declare either a minimum acceptable system version or an
  exact pinned version even when the current implementation still uses the
  present system install

Examples where per-pack toolchain pinning is desirable:

- OpenClaw built from source with Node and pnpm
- components with native modules sensitive to Node ABI
- reproducible CI or release builds

Examples where per-pack toolchain pinning is optional:

- a downloaded standalone `gogcli` binary
- a static `himalaya` release binary

Decision:

- toolchain refs are supported natively
- toolchain refs are optional per component
- they should not be forced onto every package
- system-global installs remain valid package sources when explicitly declared

### 5.1.1 Relationship to `pyenv` and `nvm`

Setpack should not behave primarily like a language-version shim manager.

Comparison:

- `pyenv`
  uses one global shims directory early in `PATH` and resolves commands like
  `python` and `pip` dynamically
- `nvm`
  usually mutates the current shell `PATH` so `node` and `npm` resolve directly
  from one selected Node install
- `setpack`
  should be wrapper-first per pack and per package

Implications for Setpack:

- Setpack may use `nvm`, `pyenv`, or other version managers as toolchain
  sources
- Setpack should not require a single account-global dynamic shims directory as
  the primary execution model
- pack activation may export pack identity variables and prepend a pack-local
  `bin/` directory to `PATH`
- managed package execution should still resolve through generated pack wrappers
  rather than through a generic shim multiplexer
- `PATH` mutation in Setpack is mainly for child-process helper discovery, not
  for general shell-wide runtime switching

For system-managed tools and binaries, Setpack should support both policies in
principle:

- `version_policy = "minimum"`
  accept any system version at or above a declared floor
- `version_policy = "pinned"`
  require one exact version and reject other resolved system versions

That policy should apply both to toolchains and to system-managed component
bundles. The first implementation can center on today's system installs and
validation only, but the spec should preserve the ability to:

- verify the resolved system version
- reject a version that does not satisfy the declared policy
- select an approved system-installed alternative when more than one is present
- fall back to a localized install later when the system version is not
  acceptable

Example policy shape:

```toml
[components.openclaw.toolchain]
source = "nvm"
name = "node"
version_policy = "pinned"
version = "25.6.1"

[components.gog.bundle]
install_adapter = "system-existing"
source = "brew"
version_policy = "minimum"
min_version = "0.12.0"
```

### 5.2 Install Adapters

Each bundle should declare an install adapter.

Recommended adapter kinds:

- `system-existing`
- `brew`
- `npm-dist`
- `npm-source-build`
- `curl-tarball`
- `git-build`
- `cargo-build`
- `manual`

The install adapter is part of the bundle definition.

`system-existing` is important for Phase 0.

It means:

- do not reinstall the existing system copy in place
- record the currently resolved binary path and version
- treat that resolved binary as the source input for validation and wrapper generation
- allow the pack bootstrap to duplicate or wrap that binary inside the pack
- keep the door open to replace it later with a fully pack-managed bundle

`system-existing` does not mean “never install locally.”
It means:

- the current step uses an already-installed system copy as the source of truth
- Setpack still records and validates the version policy for that source
- a later step may replace that source with a localized or specialized install
  if policy or reproducibility requires it

Example:

```toml
[components.openclaw.bundle]
ref = "openclaw@2026.2.25+git.78ddb1e9df#sha256:..."
install_adapter = "npm-source-build"

[components.openclaw.bundle.inputs]
repo = "git@github.com:.../openclaw.git"
commit = "78ddb1e9df"
toolchain_ref = "node@25.6.1"
package_manager_ref = "pnpm@10.8.1"
lockfile_hash = "sha256:..."
```

```toml
[components.gog.bundle]
ref = "gogcli@0.12.0+c18c58c#sha256:..."
install_adapter = "curl-tarball"

[components.gog.bundle.inputs]
url = "https://..."
sha256 = "..."
```

```toml
[components.gog.bundle]
ref = "gogcli@0.12.0+c18c58c"
install_adapter = "system-existing"
version_policy = "minimum"
min_version = "0.12.0"

[components.gog.bundle.inputs]
source = "brew"
binary = "/opt/homebrew/bin/gog"
```

### 5.3 Execution Search Paths

Execution search paths should be generated per instance.

Setpack should compute, in order:

1. component-local wrapper path
2. component bundle binary path
3. optional toolchain binary path
4. optional system fallback path

For example:

```text
<instance>/bin
<bundle-root>/openclaw/.../bin
<toolchain-root>/node@25.6.1/bin
/usr/local/bin
/opt/homebrew/bin
/usr/bin
```

This should be explicit in generated wrappers and lock records.

## 6. Package Path Model

Each package gets the same path classes, even if some packages do not use all of them.

### 6.1 Required Path Classes

- `bundle_dir`
- `toolchain_dir` when applicable
- `config_dir` or `config_file`
- `cred_dir` or materialized credential file path
- `state_dir`
- `runtime_dir`

### 6.2 Package Conventions

#### OpenClaw

- `bundle_dir`
  immutable installed OpenClaw build
- `config_file`
  rendered `openclaw.json`
- `cred_dir`
  materialized credential-bearing fragments or env files
- `state_dir`
  auth profiles, identity, workspace, paired devices, durable package state
- `runtime_dir`
  logs, sessions, temporary files

#### gogcli

- `bundle_dir`
  exact `gogcli` binary distribution
- `config_file`
  rendered non-secret CLI config, if used
- `cred_dir`
  OAuth client file and exported/imported token material
- `state_dir`
  file-backed keyring or durable local state
- `runtime_dir`
  temporary watch state and transient runtime files

#### himalaya / Pimalaya

- `bundle_dir`
  exact binary distribution
- `config_file`
  rendered `config.toml`
- `cred_dir`
  app-password materialization or references
- `state_dir`
  any future non-secret local state
- `runtime_dir`
  logs and temporary files

## 7. Pack Manifest

Each pack should have one manifest at:

```text
<set>/<pack>/pack.toml
```

The first implementation should use a restricted TOML profile:

- lower-case names only
- `name=true|false` entries for membership tables
- no arrays
- no inline objects
- no quoted names in membership tables

Example:

```toml
set="openclaw"
pack="today"

[components]
openclaw=true
gog=true

[paths]
bundle_root = "/opt/setpack/bundles"
toolchain_root = "/opt/setpack/toolchains"
config_root = "/etc/setpack/instances/prod"
cred_root = "/Users/walter/.setpack-cred/prod"
state_root = "/var/lib/setpack/instances/prod"
runtime_root = "/var/run/setpack/instances/prod"

[permissions]
bundle = "immutable_shared"
toolchain = "immutable_shared"
config = "service_account_rw"
cred = "cred_owner_only"
state = "service_account_rw"
runtime = "ephemeral_rw"
```

This is where mix-and-match happens.

Examples:

- keep `openclaw` on one bundle while moving `gogcli` to a newer one
- share one `himalaya` config set between `dev` and `prod`
- restore an older `openclaw` state snapshot into a newer bundle for debugging

### 7.1 Component Inclusion and Pack-Level Parameters

The pack manifest should explicitly list which components belong to the pack.

Use:

```toml
[components]
openclaw=true
gog=true
himalaya=true
```

This is better than relying only on directory discovery because it answers:

- what the pack is supposed to contain
- what is intentionally excluded

In the restricted profile, membership is expressed by lower-case keys set to
`true` or `false`. Ordering is not carried here.

Each component should also allow a generalized parameter block for pack-level
choices that are not part of the component bundle/config/cred/state refs
themselves.

Use:

```toml
[components.<name>.params]
install_mode = "managed"
cred_mode = "hybrid"
state_mode = "pack-local"
```

This gives the controller one place to express pack intent per component without
forcing everything into component-specific manifests.

### 7.2 LLM Access Is Provider Plus Account Plus Model

LLM access should not be represented as a single flat provider name.

The configuration needs separate fields for:

- provider
  `openai`, `anthropic`, `google`, `ollama`, `router`
- account
  a specific credential-bearing access path under that provider
- model
  vendor model label such as `gpt-5.4`, `gemini-2.5-pro`, or `claude-sonnet-4`

This is necessary because:

- one provider may have multiple accounts with different credentials and quotas
- one account may expose many models
- model labels change over time
- one package or one agent may need a different model than another

`openai-codex` should therefore not be treated as a provider name.

It is better represented as one of:

- an OpenAI account
- an OpenAI transport
- an OpenAI model-access mode

depending on which behavior is actually different.

### 7.3 Component and Agent Model Selection

Model access should be configurable at multiple scopes:

- instance default
- package default
- agent override

This allows:

- one package to prefer one provider account by default
- another package to use a different provider account
- one agent to pin one model directly
- another agent to use a different direct model selection

Route aliases are a later phase and should not be part of the first implementation.

### 7.3 Router Coverage

A router can provide much of the normalization and fallback behavior the stack needs.

That usually includes:

- one credential path for multiple upstream providers
- routing by cost or availability
- common request format
- centralized fallback

It is still not sufficient as the only abstraction layer.

Reasons:

- native provider features often appear before router support
- provider-specific auth, quotas, and governance still matter
- local models such as `ollama` are outside a hosted router path
- some packages may need direct provider selection for correctness or policy reasons

So the design should treat `router` as one provider kind, typically `broker`, not as the whole model-access architecture.

Task:

- validate basic direct provider/account/model configuration first
- try `router` only after package install, config, cred, and state handling are stable

## 8. Cred Component

In Phase 1, `cred` should be treated as just another package setup component, alongside `config` and `state`.

### 8.1 Phase 1 Rules

- each package owns its own credential location
- default package credential locations are allowed
- package credential formats are preserved as-is
- archive and restore happen per package

Examples:

- `openclaw` may use JSON files and env-backed values
- `gogcli` may use its existing JSON file layout
- `himalaya` may use `config.toml` plus app-password references or materialized files

### 8.2 Overlap Is Allowed for Now

If two packages access the same external resource with different formats, that is acceptable in Phase 1.

Example:

- `gogcli` Gmail OAuth files
- `himalaya` Gmail IMAP/SMTP credentials

Those may point to the same mailbox and still remain separate package credential components.

The drift concern is real:

- duplicated values can fall out of sync
- rotation can become a manual multi-file chore
- audit becomes harder

That concern should be documented now and postponed to a later reconciliation phase.

### 8.3 Cred Record Shape

Recommended fields:

```json
{
  "credential_id": "openclaw.discord.diss",
  "package": "openclaw",
  "target": "discord:diss",
  "format": "bot_token",
  "storage_kind": "encrypted_file",
  "persistence": "portable",
  "rotation": "manual",
  "materializations": [
    {
      "kind": "json_field",
      "target_file": "openclaw.json",
      "field": "channels.discord.token"
    }
  ]
}
```

### 8.4 Recommended Cred Fields

- `credential_id`
- `package`
- `target`
- `format`
- `storage_kind`
- `storage_ref`
- `persistence`
- `rotation`
- `materializations`
- `notes`

### 8.5 Supported Formats

- `api_key`
- `oauth_client`
- `oauth_refresh_token`
- `oauth_access_token`
- `bot_token`
- `app_password`
- `keychain_ref`
- `generated_token`

### 8.6 Supported Storage Kinds

- `encrypted_file`
- `keychain_ref`
- `env_ref`
- `generated`
- `materialized_file`
- `external_secret_manager`

### 8.7 Supported Persistence Kinds

- `portable`
- `host_bound`
- `ephemeral`

### 8.8 Materialization Rules

Credentials should be materialized into package-specific views.

Examples:

- inject a Discord token into `openclaw.json`
- write a `gogcli` `credentials.json`
- render a Himalaya `backend.auth.cmd`
- export env vars for a wrapper script

This avoids keeping all credentials in the same tree as the package config or workspace.

Automatic overlap reconciliation is a later phase.

Compatibility note:

- if a package insists on an encrypted local token store plus a second local
  decrypt key stored beside it, that pair should be treated as compatibility
  state rather than as a strong security boundary
- the portable source of truth should remain explicit exported credential
  artifacts, not an opaque runtime keystore plus adjacent unlock material

### 8.9 Interactive OAuth and CI

For user OAuth providers, first-time authorization is still interactive even on
headless machines.

Implications:

- a `--remote` or manual flow only splits the browser consent and token
  exchange into separate steps
- it does not remove the need for one human web consent flow somewhere
- CI should not be expected to perform first-time personal OAuth login

Recommended CI pattern:

- perform the interactive OAuth setup once on a trusted machine
- export the resulting refresh-token artifact explicitly
- store that exported token artifact as a `cred` component
- in CI or other headless environments, materialize the OAuth client file and
  import the exported refresh-token artifact non-interactively
- use service-account or access-token flows only where the underlying package
  and provider genuinely support them

## 9. Save and Restore Model

Exports and restores should happen at two scopes:

- `pack`
- `package`

And at four kinds:

- `bundle`
- `config`
- `cred`
- `state`

### 9.1 Required Commands

Recommended operator-facing commands:

```text
setpack apply <set> <pack>
setpack run <set> <pack> <package> [-- ...]
setpack export <set> <pack> [--package <name>] --kind <bundle|config|cred|state>
setpack import <set> <pack> [--package <name>] --kind <bundle|config|cred|state> <ref-or-path>
setpack snapshot <set> <pack> [--package <name>]
setpack doctor <set> <pack>
setpack lock <set> <pack>
```

### 9.2 Export Rules

- `bundle`
  immutable artifact export or manifest capture
- `config`
  non-secret rendered config
- `cred`
  encrypted export or keychain-reference manifest
- `state`
  persistent non-runtime state only

### 9.3 Do Not Include by Default

- logs
- sessions
- temporary watch state
- pending pairings
- ephemeral access tokens unless explicitly requested

### 9.4 Package Component Archives

Each package should archive and restore components separately.

Required component kinds:

- `config`
- `cred`
- `state`
- `runtime`

Meaning:

- `config`
  rendered non-secret package configuration
- `cred`
  package-specific secret material or secret references
- `state`
  persistent mutable state worth carrying between installs or deployments
- `runtime`
  disposable current-run material, excluded by default

Examples:

`openclaw`

- `config`
  `openclaw.json`, non-secret workspace templates, route and model settings
- `cred`
  provider auth material, channel tokens, OAuth client files, auth-profile secret fragments
- `state`
  workspace memory, device identity, selected pairing state, durable auth continuity data
- `runtime`
  sessions, logs, transient watch/process state

`gogcli`

- `config`
  non-secret CLI configuration
- `cred`
  OAuth client file, exported refresh-token artifacts, keyring references
- `state`
  durable local CLI state worth preserving, including any compatibility
  keyring-unlock material required to read a package-mandated local token store
- `runtime`
  transient watch state and temporary files

`himalaya`

- `config`
  rendered `config.toml`
- `cred`
  app password material or keychain references
- `state`
  any future durable local state
- `runtime`
  temporary logs and runtime files

### 9.5 Archive Ref Format

Each component archive should have its own ref.

Examples:

- `openclaw-config@mail-v3#sha256:...`
- `openclaw-cred@2026-04-11#sha256:...`
- `openclaw-state@2026-04-11T21:30:00Z#sha256:...`
- `gogcli-cred@moonshotcol-v1#sha256:...`
- `himalaya-config@mail-v2#sha256:...`

### 9.6 Archive Content Structure

Phase 1 archive format should be simple and inspectable.

Recommended archive names:

- `bundle.tar.zst`
- `config.tar.zst`
- `cred.tar.zst`
- `state.tar.zst`

Each archive should include:

- `manifest.json`
  package name, component kind, ref, source paths, created time, tool version
- `payload/`
  copied files in restored relative layout
- `checksums.txt`
  per-file digest list

For `cred` archives:

- allow either encrypted payload or reference-only manifest
- support host-bound references such as Keychain items without exporting raw values

### 9.7 Archive and Restore Rules

- `config` archives must restore independently from `cred` and `state`
- `cred` archives must restore independently from `config` and `state`
- `state` archives must restore independently from `config` and `cred`
- package restore must work without requiring full-instance restore
- instance restore is just ordered package restore plus validation

## 10. Implementation Model

`setpack` should be implemented as a manifest-driven controller with package adapters.

### 10.1 Core Files

Required control files:

- `instance.toml`
  package refs, path registry, permission policy, execution ordering
- `lock.toml`
  what was actually assembled and validated
- `cred.toml`
  per-package credential references and materialization instructions
- package adapter definitions
  install, render, validate, export, import logic per package

Recommended supporting directories:

- `instances/<instance>/`
  `instance.toml`, `lock.toml`, generated wrappers
- `packages/<package>/`
  adapter code and package defaults
- `archives/`
  imported or exported `config`, `cred`, and `state` archives

### 10.2 Content Structures

`instance.toml`

```toml
instance = "prod"
description = "Primary local Claw deployment"

[packages.openclaw]
bundle_ref = "openclaw@2026.2.25+git.78ddb1e9df#sha256:..."
toolchain_ref = "node@25.6.1"
config_ref = "openclaw-config@mail-v3#sha256:..."
cred_ref = "openclaw-cred@2026-04-11#sha256:..."
state_ref = "openclaw-state@2026-04-11T21:30:00Z#sha256:..."

[packages.openclaw.models.default]
provider = "openai"
account = "chatgpt-main"
model = "gpt-5.4"

[packages.gogcli]
bundle_ref = "gogcli@0.12.0+c18c58c#sha256:..."
config_ref = "gogcli-config@default-v1#sha256:..."
cred_ref = "gogcli-cred@2026-04-11#sha256:..."
state_ref = "gogcli-state@2026-04-11T21:30:00Z#sha256:..."
```

`cred.toml`

```toml
[[cred]]
package = "openclaw"
credential_id = "openclaw.openai.chatgpt-main"
target = "openai:chatgpt-main"
format = "api_key"
storage_kind = "keychain_ref"
storage_ref = "openai-api-key"

[[cred.materialize]]
kind = "json_field"
target_file = "openclaw.json"
field = "providers.openai.apiKey"

[[cred]]
package = "gogcli"
credential_id = "gogcli.gmail.moonshotcol"
target = "gmail:moonshotcol@gmail.com"
format = "oauth_client"
storage_kind = "encrypted_file"
storage_ref = "gogcli-cred@2026-04-11"

[[cred.materialize]]
kind = "file"
target_file = "credentials.json"
```

`lock.toml`

```toml
instance = "prod"
validated_at = "2026-04-11T22:30:00Z"
validator_version = "setpack@0.1.0"

[packages.openclaw]
bundle_ref = "openclaw@2026.2.25+git.78ddb1e9df#sha256:..."
config_ref = "openclaw-config@mail-v3#sha256:..."
cred_ref = "openclaw-cred@2026-04-11#sha256:..."
state_ref = "openclaw-state@2026-04-11T21:30:00Z#sha256:..."
resolved_provider = "openai"
resolved_account = "chatgpt-main"
resolved_model = "gpt-5.4"
```

### 10.3 Core Commands

Minimum command set:

```text
setpack apply <set> <pack>
setpack validate <set> <pack>
setpack update <set> <pack> [--package <name>]
setpack export <set> <pack> [--package <name>] --kind <bundle|config|cred|state>
setpack import <set> <pack> [--package <name>] --kind <bundle|config|cred|state> <ref-or-path>
setpack run <set> <pack> <package> [-- ...]
setpack lock <set> <pack>
```

### 10.4 Package Adapter Interface

Each package adapter should implement:

- `resolve()`
  resolve refs and paths
- `install()`
  populate bundle and optional toolchain location
- `render_config()`
  render package config
- `materialize_cred()`
  materialize package-visible credential files or references
- `restore_state()`
  restore persistent state
- `validate()`
  verify install/config/cred/state coherence
- `export_component(kind)`
  export `config`, `cred`, or `state`
- `import_component(kind)`
  import `config`, `cred`, or `state`
- `run()`
  exec through controlled wrapper path

### 10.5 Generated Wrappers

`setpack` should generate one wrapper per package per instance.

Examples:

- `setpack run prod openclaw`
- generated wrapper path:
  - `<instance-control-root>/bin/openclaw`
  - `<instance-control-root>/bin/gog`
  - `<instance-control-root>/bin/himalaya`

Wrappers should:

- set all package paths explicitly
- prepend package bundle and toolchain paths
- avoid dependence on account-global shell dotfiles
- remain concrete per-package entrypoints rather than one generic dynamic shim
  dispatcher

Wrapper path resolution should be relative to the wrapper's own location, not
hardcoded to one account home such as `"$HOME/Work/Claw/Setpacks/..."`.

Required approach:

- derive `SCRIPT_DIR` from `dirname "$0"`
- derive `PACK_ROOT` from `SCRIPT_DIR/..`
- derive component-local paths from that resolved `PACK_ROOT`

That keeps wrappers relocatable and prevents pack behavior from depending on one
specific account name or one specific home-directory layout.

Do not generate wrappers that embed:

- a literal pack root under one user's home directory
- a second copied path registry that can drift from the manifest
- component child paths that can be derived from `PACK_ROOT` and component name

## 11. Validation Model

Validation must be explicit and automated.

### 11.1 Validation Stages

Setpack should run validation in this order:

1. manifest validation
2. ref resolution validation
3. path and permission validation
4. bundle/toolchain validation
5. config render validation
6. credential materialization validation
7. state restore validation
8. package command smoke validation

### 11.2 Required Validation Checks

- bundle refs resolve to actual immutable artifacts
- required executables exist
- configured execution search paths are correct
- expected config files were rendered
- cred records are complete and materialized to expected files or references
- state restore landed only in declared package state locations
- runtime directories are writable
- no secrets were written into bundle or checked-in config locations
- declared default package locations match what the adapter actually used

### 11.3 Package Smoke Checks

Examples:

- `openclaw`
  validate binary version, config parse, auth profile load, and basic startup
- `gogcli`
  validate binary version, client credential visibility, and auth subcommand availability
- `himalaya`
  validate binary version, config parse, and account listing/config load

### 11.4 Lock Record

After successful validation, `setpack` should write a lock record containing:

- instance label
- package refs
- toolchain refs
- path registry
- permission policy
- validation timestamp
- validator version
- component archive refs actually applied
- resolved provider/account/model selections per package or agent where applicable

## 12. Incremental Update Model

Updates should be component-aware and package-aware.

### 12.1 Supported Update Types

- bundle-only update
- toolchain-only update
- config-only update
- cred-only update
- state-only update
- full package update
- full instance update

### 12.2 Update Rules

- updating a bundle must not implicitly overwrite `config`, `cred`, or `state`
- updating `config` must not implicitly overwrite `cred` or `state`
- updating `cred` must not implicitly overwrite `config` or `state`
- updating `state` must not implicitly overwrite `config` or `cred`
- every update must end in validation and a new lock record

### 12.3 Incremental Update Flow

Recommended flow:

1. resolve target refs
2. diff current lock vs requested refs
3. run only affected package adapter phases
4. validate affected packages
5. write new lock record

### 12.4 Promotion Between Instances

Promoting from `dev` to `prod` should mean:

- copy or reference approved bundle refs
- copy or reference approved config refs
- copy only explicitly approved credential refs
- copy only explicitly approved state refs
- validate the target instance after promotion

## 13. Install / Config / Run Method

### 13.1 Install

Install should populate only `bundle_dir` and, when needed, `toolchain_dir`.

This is where pinned package managers, build inputs, and dependency closures belong.

For example:

- `openclaw`
  built from a pinned Node version and lockfile into an immutable bundle dir
- `gogcli`
  unpacked from a pinned release artifact
- `himalaya`
  unpacked from a pinned release artifact or built once into a bundle dir

The install step should not mutate environment config or credential material.

### 13.2 Apply Config

`setpack apply <instance>` should:

- resolve the instance manifest
- render package config from config sets
- materialize package cred files or references from cred sets
- prepare per-package paths
- apply or restore selected component archives
- write a lock record describing what was actually assembled

### 13.3 Run

Packages should always be started through wrapper scripts that set explicit paths.

For example:

```bash
SETPACK_INSTANCE=prod
SETPACK_PACKAGE=openclaw
SETPACK_CONFIG_DIR=...
SETPACK_STATE_DIR=...
SETPACK_RUNTIME_DIR=...
SETPACK_CRED_DIR=...
exec openclaw ...
```

This avoids dependence on account-global dotfiles and reduces accidental state crossover.

Operational requirement:

- the wrapper must also make executable lookup explicit for child processes
- if a component discovers helpers by name, the wrapper should prepend the
  pack `bin/` directory to `PATH` before it execs the managed binary
- this is required for setups like OpenClaw + Gog, where OpenClaw spawns
  `gog` by executable name and must resolve the pack-local wrapper rather than
  a system-global binary

Clarification:

- prepending the pack `bin/` directory to `PATH` is not meant to turn Setpack
  into a `pyenv`-style global shim layer
- it is a narrow execution rule so child helpers resolve to the same pack-local
  wrappers as the parent package
- the user-facing invocation path should still be explicit pack wrappers such as
  `<pack-root>/bin/openclaw` and `<pack-root>/bin/gog`

### 13.4 Phase 0 Walkthrough: Capture Parametrization Around Existing Installs

The first end-to-end validation should not replace current installations.

It should:

- keep the current installed binaries
- capture `config`, `cred`, and `state` into controlled non-default locations
- switch execution to wrappers
- validate manual and automated changes

Recommended walkthrough:

1. discover the currently resolved binaries
2. record each package as `install_adapter = "system-existing"`
3. define controlled package paths for `config`, `cred`, `state`, and `runtime`
4. manually copy or recreate current package parametrization into those paths
5. generate wrappers that force those paths
6. run each package through the wrapper only
7. observe any files still written to default locations
8. adjust package config or wrapper env vars until writes land only in declared locations
9. archive `config`, `cred`, and `state`
10. automate the setup with `setpack apply`
11. validate with `setpack validate`

This validates the model before changing how packages are installed.

### 13.5 Manual and Automated Operations in Phase 0

Manual operations:

- identify package default config and state files
- choose which of them belong to `config`, `cred`, and `state`
- copy them into the controlled locations
- perform first-time auth or account setup when required
- verify package behavior through wrappers

Automated operations:

- create directories and permissions
- copy or template `config`
- materialize `cred`
- restore `state`
- generate wrappers
- run smoke validation

The goal is to convert a manually working captured setup into an automated re-apply without changing the installed binaries yet.

### 13.6 Validation Checklist for Phase 0

For each package, validate:

- wrapper resolves the expected binary
- binary version matches the declared bundle ref
- package reads `config` from the controlled location
- package reads `cred` from the controlled location or declared host-bound references
- package writes durable state only into the controlled `state` location
- package writes runtime artifacts only into the controlled `runtime` location when applicable
- no new undeclared files appear under default package locations after startup or basic operations

Examples of package actions to validate:

- `openclaw`
  basic startup, config parse, provider/account/model selection, workspace state write
- `gogcli`
  version check, auth visibility, one command that touches durable local state
- `himalaya`
  config parse, account listing, one command that confirms mailbox access

## 14. Decision on Unified vs Per-Package Parameterization

The correct answer is:

- unified **instance label**
- per-package **parameterization**

Specifically:

- one label chooses the deployment
- each package owns its own config, cred, state, and runtime paths
- shared policies live at the instance level
- package-specific persistence lives at the package level

This supports:

- native mix-and-match of package refs
- reliable per-package save/restore
- full-instance save/restore
- future add-ons without redesign

## 15. OpenClaw-Specific Mapping

This appendix isolates Claw-specific mapping examples from the generic `setpack` design.

Machine-local observations belong in `ClawInfo.md`.

### 15.1 Naming Notes From Current OpenClaw Config

Current OpenClaw labels and profile names should be treated as package-local
artifacts, not as stable global naming.

### 15.2 Move to Config Set

- rendered `openclaw.json`
- non-secret workspace templates
- package routing and feature flags

### 15.3 Move to Cred Set

- provider API keys
- Discord / Telegram tokens
- OAuth client files
- any exported refresh-token files

### 15.4 Move to Persistent State

- agent auth profiles when continuity is desired
- device identity
- paired device metadata if intentionally portable
- workspace memory if intentionally portable

### 15.5 Move to Runtime State

- sessions
- logs
- transient watch state

### 15.6 Current OpenClaw Env Inventory

The current user-facing `OPENCLAW_*` environment-variable inventory belongs in
`ClawInfo.md`, not in this design spec.

Design implication:

- `setpack` should use wrapper env vars for OpenClaw state and config
- workspace should be injected via `openclaw onboard --workspace <dir>` or persisted in config

## 16. Reliability Rules

- Never treat one mutable home-directory tree as the authoritative environment definition.
- Never place credentials in the same tree as version-controlled package config by default.
- Never bake raw secret material into images or immutable bundles.
- Always record exact bundle refs, config refs, cred refs, and state refs in an instance lock record.
- Always allow package-level restore independent of full-instance restore.
- Always keep runtime state disposable by default.
- Always make placement configurable independently from permission policy.
- Always make install method explicit as part of the bundle definition.
- Always make executable search paths explicit in wrappers and lock records.
- Always keep `config`, `cred`, and `state` archivable and restorable as separate package components.

## 17. Ansible-Based Hybrid Implementation

The recommended implementation is:

- `setpack` as the semantic control layer
- Ansible as the execution engine

This keeps the hard design decisions in one place while reusing a mature apply mechanism.

### 17.1 Responsibility Split

`setpack` should own:

- `instance.toml`, `cred.toml`, and `lock.toml`
- package refs and archive refs
- path and permission policy
- package adapter semantics
- provider/account/model selection
- preflight validation rules
- post-apply lock writing

Ansible should own:

- creating directories
- setting owners and modes
- installing or linking bundles
- rendering config templates
- materializing cred files or references
- restoring `state` archives
- generating wrappers
- running smoke commands

### 17.2 Before / During / After Flow

Before Ansible:

1. `setpack plan <instance>`
2. resolve refs
3. validate manifests and component inputs
4. generate an Ansible inventory and vars file for the target instance
5. stage `config`, `cred`, and `state` archives

During Ansible:

1. create required paths
2. install or link bundles and toolchains
3. render config
4. materialize cred files or host-bound references
5. restore state
6. generate wrappers
7. run package-level smoke checks

After Ansible:

1. `setpack verify <instance>`
2. collect realized versions and resolved paths
3. compare expected vs actual component placement
4. write `lock.toml`
5. emit a report of installed packages, restored components, and validation outcomes

### 17.3 Generated Ansible Inputs

`setpack` should generate at least:

- `inventory.ini`
- `group_vars/<instance>.yml`
- `host_vars/<host>.yml` when needed
- one role parameter block per package

Recommended generated variable structure:

```yaml
setpack_instance: prod
setpack_paths:
  bundle_root: /opt/setpack/bundles
  toolchain_root: /opt/setpack/toolchains
  config_root: /etc/setpack/instances/prod
  cred_root: /Users/walter/.setpack-cred/prod
  state_root: /var/lib/setpack/instances/prod
  runtime_root: /var/run/setpack/instances/prod

setpack_packages:
  openclaw:
    bundle_ref: openclaw@2026.2.25+git.78ddb1e9df#sha256:...
    toolchain_ref: node@25.6.1
    config_ref: openclaw-config@mail-v3#sha256:...
    cred_ref: openclaw-cred@2026-04-11#sha256:...
    state_ref: openclaw-state@2026-04-11T21:30:00Z#sha256:...
```

### 17.4 Suggested Ansible Roles

Recommended roles:

- `setpack_common`
  path creation, ownership, shared validation helpers
- `setpack_bundle`
  install or link package bundles and toolchains
- `setpack_config`
  render package config from templates or archives
- `setpack_cred`
  materialize package credential files or references
- `setpack_state`
  restore package state archives
- `setpack_wrapper`
  generate launcher scripts
- `setpack_validate`
  run smoke commands and assert file placement

### 17.5 Package Adapter to Ansible Mapping

Each package adapter should emit Ansible-ready actions.

Examples:

- `install()`
  becomes role inputs for `setpack_bundle`
- `render_config()`
  becomes template or archive extraction actions in `setpack_config`
- `materialize_cred()`
  becomes copy/template/command actions in `setpack_cred`
- `restore_state()`
  becomes archive extraction or sync actions in `setpack_state`
- `validate()`
  becomes assertions plus smoke commands in `setpack_validate`

### 17.6 Validation in an Ansible-Based Run

Validation should happen both inside and outside Ansible.

Pre-Ansible validation by `setpack`:

- manifest schema
- ref existence
- incompatible path or permission plans
- missing credential refs
- invalid provider/account/model combinations

In-Ansible validation:

- file existence
- ownership and mode checks
- archive extraction success
- config parse checks
- package smoke commands

Post-Ansible validation by `setpack`:

- final path audit
- lockfile generation
- drift baseline capture

### 17.7 Why This Hybrid Is Preferred

This hybrid is the best fit for the current scope because:

- it does not require Docker or sandbox isolation
- it works with system installs, user installs, and mixed layouts
- it lets `setpack` stay small and semantic
- it avoids rewriting a large amount of idempotent file orchestration

## 18. Comparison With Nix / Devbox

The “1.” family from the earlier comparison is:

- Nix
- Devbox
- similar toolchain-first environment managers

These are useful, but they solve a narrower slice of the problem.

### 18.1 What Nix / Devbox Solve Well

- exact toolchain selection
- reproducible shells
- pinned package versions
- predictable PATH construction
- build-time dependency control

If the problem were only:

- Node version
- pnpm version
- package install closure

then this family would likely be enough.

### 18.2 What They Do Not Solve Completely Here

They do not by themselves define:

- per-package `config`, `cred`, and `state` archive semantics
- host-bound credential references such as Keychain usage
- package-native config materialization rules
- package-native state restore rules
- per-agent provider/account/model selection
- lock records that combine bundle, cred, and state refs

So they are helpful components, not the whole control plane.

### 18.3 Practical Use of Nix / Devbox Inside This Design

They can still be used underneath `setpack`.

Examples:

- use `nvm` or Devbox for the OpenClaw Node toolchain
- use Nix or Devbox to build a reproducible OpenClaw bundle
- use a system package or tarball for `gogcli`
- use a system package or tarball for `himalaya`

That means:

- `setpack` remains the environment controller
- Nix / Devbox remain optional bundle or toolchain providers

### 18.4 Choice Guidance

Use Nix or Devbox when:

- toolchain reproducibility is the main pain
- one package build is fragile
- you want reproducible developer shells

Use the Ansible hybrid when:

- path layout, permissions, and install location matter
- package config and credential materialization matter
- package state archive and restore matter
- the target is a real machine, not just a shell environment

Current recommendation:

- keep Nix / Devbox optional
- build the first working system around `setpack + Ansible`
- add a Nix or Devbox-backed bundle path later only where it clearly helps

## 19. Recommended Next Step

Implement `setpack` in this order:

1. Phase 0 capture around current system installs using `system-existing`
2. instance manifest format
3. placement and permission resolver
4. toolchain and install-adapter schema
5. package cred schema and materialization rules
6. package component archive format for `config`, `cred`, and `state`
7. `apply`, `validate`, `update`, `export`, `import`, and `lock` commands

## 18. Automation Sketch

This section sketches the first script layout for `setpack`.

The goal is not a finished implementation. The goal is to make the controller
boundaries concrete enough that the next phase can be built incrementally.

### 18.1 Generic Controller Scripts

Recommended first scripts:

```text
setpack/scripts/
  lib/setpack-common.sh
  setpack-plan.sh
  setpack-apply.sh
  setpack-validate.sh
  adapters/install-package.sh
  adapters/openclaw-package.sh
```

Roles:

- `setpack-plan.sh`
  resolve a set and pack into component directories, manifests, wrappers, and
  install adapters
- `setpack-apply.sh`
  run component apply steps in pack order
- `setpack-validate.sh`
  verify wrappers, config roots, state roots, and component-specific smoke checks
- `adapters/install-package.sh`
  dispatch install work by adapter kind
- `adapters/openclaw-package.sh`
  add component-specific behavior for OpenClaw

The controller layer should stay generic.

It should know about:

- sets
- packs
- component manifests
- install adapters
- pack-level validation

It should not contain:

- component-specific credential semantics
- component-specific workspace import logic
- component-specific sandbox behavior

Those belong in component adapters.

### 18.2 Set and Pack Resolution

The generic scripts should resolve:

```text
<setpacks-root>/<set>/<pack>/
```

For example:

```text
/Users/walter/Work/Claw/Setpacks/openclaw/today/
```

The first implementation should accept:

- `SETPACK_PACKS_ROOT`
- `<set>`
- `<pack>`

and infer component directories under that pack by looking for:

```text
<component>/comp.toml
```

This avoids prematurely requiring one large central manifest parser before the
controller shape is proven.

The first implementation should:

- read `[components]` from `pack.toml`
- treat keys set to `true` as the authoritative included-component set
- use directory discovery only as a fallback or consistency check

### 18.2a One-Root Derivation Rule

Path construction should follow one-root derivation.

Meaning:

- resolve one canonical `pack_root`
- resolve one canonical `component_root` per included component
- derive child paths from those roots by convention

Examples of derived child paths:

- `<pack_root>/bin`
- `<component_root>/bundle`
- `<component_root>/config`
- `<component_root>/cred`
- `<component_root>/state`
- `<component_root>/runtime`
- `<component_root>/home`

This avoids a path-registry explosion where the same directory tree is repeated
across:

- `pack.toml`
- `<component>/comp.toml`
- generated wrappers
- bootstrap scripts

The repeated absolute child paths are not the source of truth. The root is.

### 18.3 Component Adapter Contract

Each component adapter should support these conceptual operations:

- `plan`
- `apply`
- `validate`
- `export_config`
- `export_cred`
- `export_state`
- `import_config`
- `import_cred`
- `import_state`

The first shell sketches only implement `apply` and `validate`.

### 18.4 Install Specialization

The generic install dispatcher should branch by `install_adapter`.

The first supported adapter names should be:

- `system-existing`
- `brew`
- `npm-dist`
- `npm-source-build`
- `curl-tarball`
- `git-build`
- `cargo-build`
- `manual`

Expected responsibilities:

- `system-existing`
  record binary path and version, validate declared version policy, then refresh wrappers and config/cred/state
  placement around the existing install
- `brew`
  install or verify Homebrew package presence, then record the resolved binary
- `npm-dist`
  install from npm into the component `bundle/` root
- `git-build`
  clone or refresh a pinned repo, then build a component-local bundle
- `cargo-build`
  compile a pinned Rust repo into a component-local bundle

### 18.5 Groups of Projects

Setpack needs to support both:

- one pack for one package family
- one pack spanning multiple related projects

Examples:

- `openclaw/today`
  one pack containing `openclaw`, `gog`, `himalaya`
- `mailstack/dev`
  one pack containing multiple mail-related repos and tools

The generic scripts should therefore operate on package directories discovered
inside a pack, not assume the set name and package name are the same.

### 18.6 OpenClaw-Specific Automation

OpenClaw needs a package adapter because it has package-native behaviors that
are more specific than generic `config`, `cred`, and `state`.

The first adapter should handle:

- `openclaw.json` rendering
- wrapper generation with:
  - `OPENCLAW_STATE_DIR`
  - `OPENCLAW_CONFIG_PATH`
- default workspace handling for `onboard`
- package-local workspace placement
- package-local auth profile store
- `models status` smoke checks

Install specialization inside the OpenClaw adapter should cover:

- `system-existing`
  wrap an existing npm or Homebrew CLI install
- `npm-dist`
  install a pinned OpenClaw version into `bundle/`
- `git-build`
  build OpenClaw from repo using pinned Node and package-manager refs

### 18.7 Sandboxing Specialization

Sandboxing should remain an adapter specialization, not a controller primitive.

Two initial OpenClaw-specific sandbox directions should be supported later:

- native OpenClaw techniques
  examples:
  - dedicated state/config roots
  - built-in profile isolation where useful
  - local gateway and web UI wrapped inside a pack
- NemoClaw techniques
  examples:
  - workspace export/import
  - memory pack restore
  - bootstrap of package-local workspace notes

The key design rule is:

- bundle installation
- configuration materialization
- workspace import/export
- sandbox wrapping

must remain separate steps, even when they are run by one `setpack apply`.

### 18.8 First Validation Shape

The first scripts should validate:

- pack exists
- `pack.toml` exists
- package manifests exist
- pack wrapper exists for each package
- expected package config/state/workspace roots exist
- package-specific smoke checks run

For OpenClaw, the first smoke checks should include:

- `openclaw --version`
- `openclaw config file`
- `openclaw config validate`
- `openclaw models status --json`

For `gog`, the first smoke checks should include:

- `gog --version`
- auth command availability
- confirmation that its isolated home/config roots are used

### 18.9 Why These Are Sketches

The shell files added alongside this document are intentionally narrow.

They are there to make the architecture executable in outline:

- generic controller
- package adapter boundary
- install specialization boundary
- OpenClaw-specific extension points

They are not yet the final product.

### 18.10 Credential Setup Modes

Credential setup should be selectable per package and per integration.

The first implementation should support three modes:

- `automated`
  copy or materialize credentials directly from an approved source into the
  target pack
- `hybrid`
  automate package install and config, then stop for a native provider login,
  token paste, or browser OAuth step, then validate and capture the result
- `manual`
  operator performs package-native auth manually, then `setpack` records status
  and validates placement afterward

This applies differently by package:

- `openclaw`
  provider and channel credentials may be mixed between automated and manual
  steps
- `gog`
  OAuth client material may be automated while account auth remains hybrid
- `himalaya`
  config rendering may be automated while app-password entry remains manual or
  hybrid

### 18.11 Credential Sources

Credential material may come from:

- another pack
- a dedicated cred store
- selected system config

This must stay selective.

The controller should not blindly ingest all host credentials.

The first supported patterns should be:

- `from-pack`
  copy specific files or fields from another pack
- `from-store`
  materialize from an explicit cred root or encrypted export
- `from-system`
  import from host config only when explicitly named

Each use should be recorded in pack status.

### 18.12 Pack Status Model

Every pack should keep one status file separate from the lockfile.

Recommended file:

```text
<pack-root>/status.toml
```

The lockfile answers:

- what was assembled

The status file answers:

- what lifecycle stage each subsystem or integration is in
- what was attempted
- what completed
- what validated
- what still needs operator action

The status model should distinguish:

- per-subsystem status
  examples:
  - `subsystem.openclaw.bundle`
  - `subsystem.openclaw.config`
  - `subsystem.openclaw.cred`
  - `subsystem.gog.bundle`
  - `subsystem.gog.cred`
- cross-integration status
  examples:
  - `integration.openclaw.ollama`
  - `integration.openclaw.openai`
  - `integration.openclaw.openai_codex`
  - `integration.gog.gmail`
- overall pack readiness

This lets a pack be:

- partially installed
- credentialed but not validated
- validated for one subsystem but not another
- operational for one integration while another remains planned

Use one enum stage plus milestone flags.

- `.status`
  lifecycle stage such as `planned`, `completed`, `configured`, `imported`,
  `validated`, or `available`
- `.attempted`
  whether any apply, import, or setup action has been attempted
- `.completed`
  whether the intended action completed
- `.validated`
  whether post-apply checks passed

The enum and flags are not duplicates. The enum says where the subsystem is in
its lifecycle. The flags record what evidence exists about that lifecycle.

Recommended meaning by field:

- `.status`
  the current lifecycle stage or operator-visible state
- `.attempted`
  at least one relevant action was attempted
- `.completed`
  the intended action finished without stopping mid-step
- `.validated`
  the declared post-step checks passed

Recommended lifecycle stages, in normal execution order:

- `planned`
  declared in the pack but no action taken yet
- one post-action stage
  exactly one of:
  - `completed`
    a build, install, copy, or wrapper action finished, but no validation has
    been recorded yet
  - `configured`
    config or credential material is present, but not yet validated
  - `initialized`
    pack-local state or workspace was created, but not yet validated
  - `imported`
    material was copied from another pack or source, but not yet validated in
    the target pack
- `validated`
  the subsystem or integration has passed its expected checks

Special case:

- `available`
  use only for operator surfaces such as TUI or web UI when the current claim is
  limited to “it is present and launches” and there is no stronger validation
  step defined yet

The first implementation should stop there. More specialized stages can be
added later when the scripts and status processing actually use them.

Recommended flag interpretation:

- `attempted = "yes"`
  the operator or automation has already touched this item
- `completed = "yes"`
  the action reached a stable end state, even if follow-up validation is still
  pending
- `validated = "yes"`
  the pack-specific checks passed for that stable end state

Example matrix:

| Use case | `.status` | `.attempted` | `.completed` | `.validated` |
| --- | --- | --- | --- | --- |
| Declared but untouched system tool | `planned` | `no` | `no` | `no` |
| `system-existing` binary recorded, wrapper written, no smoke check yet | `completed` | `yes` | `yes` | `no` |
| API key or OAuth login entered, config updated, not yet checked | `configured` | `yes` | `yes` | `no` |
| State directory or workspace created, not yet exercised | `initialized` | `yes` | `yes` | `no` |
| `conf` copied from another pack, target pack not yet adjusted or checked | `imported` | `yes` | `yes` | `no` |
| `system-existing` binary recorded and smoke-checked | `validated` | `yes` | `yes` | `yes` |
| Imported config adjusted for a new default model and then validated | `validated` | `yes` | `yes` | `yes` |
| TUI or web UI surface exists and launches, but deeper provider checks are separate | `available` | `yes` | `yes` | `no` |

Usage guidance:

- Use `.status` for the human summary and next-action decision.
- Use the flags for reporting and automation gates.
- Treat `validated = "yes"` as the only signal that post-step checks passed.
- Do not infer validation from `completed = "yes"`.
- Choose the post-action stage by the kind of work that was just done:
  - `completed` for build/install/copy/wrapper work
  - `configured` for config or credential setup
  - `initialized` for first creation of durable state or workspace
  - `imported` for material copied from another pack or source
- Prefer `imported` over `completed` when the source-of-truth is another pack
  and target-pack validation still matters.
- Prefer `configured` over `completed` for credentials and provider setup
  because the operator meaning is clearer.
- Use `available` only for surfaces. Do not use it for bundles, config, creds,
  state, or imports.

Possible deviations or out-of-sequence cases:

- A component can go straight from `planned` to `validated` if one command both
  performs the action and immediately proves it.
- An imported role can stay `imported` for a while even if other roles in the
  same component are already `validated`.
- A surface can remain `available` while its backing provider integration is
  still only `configured` or `planned`.
- Re-running import or config steps does not require inventing a new stage; keep
  the same post-action stage until validation changes it.

Mapping to common pack use cases:

- Fresh OpenClaw npm install into `bundle/`
  start `planned`, then `completed`, then `validated` after version and config
  checks pass
- Pack-local `gog` copied from a system Homebrew binary
  use `completed` after copy, then `validated` after `gog --version` and wrapper
  checks pass
- OpenClaw provider auth entered in the native wizard
  use `configured` until `models status` or equivalent proves the provider works
- Gemini planned for tomorrow
  keep `integration.openclaw.google.status = "planned"` until the work is
  actually attempted
- `ocrepo` importing `conf`, `cred`, `state`, and `workspace` from `today`
  mark each imported role as `imported`, then move to `validated` only after the
  repo-built wrapper and target config checks pass
- Imported config with local fallback changes
  import first as `imported`, then after adjustment and validation mark the
  target role or integration `validated`

### 18.13a Import Modes

Import should be explicit and selective.

Recommended modes:

- full role import
  copy one complete role directory such as `conf`, `cred`, `state`, or
  `workspace`
- import-and-adjust
  copy a role, then immediately edit or normalize it for the target pack
- partial merge
  copy only specific files or subtrees from the source role

The first implementation only needs full role import plus post-import manual
adjustment. Partial merge can be a later refinement once the stable role
boundaries are clearer.

### 18.13b Source, Initialization, and Adjustment Specification

The hierarchy should be carried by directory structure and one manifest at each
level, not by deep labels such as `components.openclaw.blocks.conf`.

The file format is generic for now. TOML examples are only placeholders.

Use this split:

- `pack.toml`
  lists included components
- `<component>/comp.toml`
  lists included blocks for that component in this pack
- one section per block in `comp.toml`
  carries the approved block parameters

Specification files should stay semantic and compact.

That means:

- `pack.toml` should describe set, pack, included components, and other intent
- `<component>/comp.toml` should describe component identity, refs, adapter
  choice, block inclusion, and semantic parameters
- neither file should duplicate every realized absolute child path under the
  pack unless there is a demonstrated need that cannot be derived from
  directory structure

Expanded absolute paths in specification files create drift risk because the
same values then need to be maintained in:

- manifests
- generated wrappers
- bootstrap scripts
- status or lock records

In contrast, realized records may carry absolute paths when those paths are
historical facts rather than configuration.

Examples of realized records:

- `status.toml`
- `lock.toml`
- bundle provenance files such as `SOURCE.toml`

Those files are closer to receipts than manifests. They may record:

- the exact resolved binary that was copied
- the exact wrapper or config file that was validated
- the exact local pack root on the machine where validation happened

Receipt-style repetition is acceptable because it answers `what happened here?`
Specification-style repetition is not acceptable when it tries to answer `how
should this instance be constructed?`

Minimal approved shape:

```toml
# pack.toml
[components]
openclaw=true
gog=true
```

```toml
# openclaw/comp.toml
[blocks]
conf=true
cred=true
state=true
workspace=true
bundle=true
bin=true

[conf]
included=true

[cred]
included=true

[state]
included=true
```

Use `block` rather than `role` here. A block is a logical setup unit. Today it
usually maps to a subdirectory such as `conf/` or `state/`, but in principle it
could later define:

- one file
- one subtree
- one section of a file

For now, do not standardize additional block fields beyond:

- block name
- `include = true|false`

Source selection, initialization rules, and adjustment formats are still needed,
but their exact field names and syntax are not fixed yet. Do not over-specify
them until we have a demonstrated use case and approved processing model.

### 18.13 OpenClaw Pack Bootstrap Script

For an OpenClaw-centered pack, it is reasonable to keep one pack-local script
that duplicates the pack install and wrapper setup.

Example:

```text
<pack-root>/bin/setpack
```

That script should be allowed to:

- create or refresh the approved pack directory layout
- install the pinned OpenClaw npm distribution into the pack bundle
- refresh pack wrappers
- record system-existing companion tools such as `gog`
- update `status.toml`

It should not silently move or import credentials.

Credential setup should remain explicit through one of the modes above.
8. OpenClaw package adapter
9. `gogcli` package adapter
10. Himalaya package adapter
11. router trial after direct provider/account/model validation succeeds

That will solve the immediate local consistency problem before extending the same model to remote and sandboxed deployments.
