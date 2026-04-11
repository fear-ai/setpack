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
- package-specific config
- credentials in different formats and backends
- persistent state
- runtime state
- path wiring between all of the above

Putting credentials, config, workspace, and runtime state into the same `~/.openclaw*` tree invites accidental commits, unsafe image baking, and ambiguous restore behavior.

## 2. Decision

Use a hybrid model:

- one unified **instance label** for each runnable environment, such as `dev`, `prod`, or `claw_today`
- separate **per-package parameterization** under that instance

This is the right tradeoff.

Unified-only is too coarse:

- it makes per-package restore and substitution awkward
- it encourages one giant mutable state tree

Per-package-only is too fragmented:

- it makes deployment selection awkward
- it loses the convenience of one stable operator-facing name

The model here is:

- one instance label names the deployment
- each package under that instance has its own bundle, config set, cred set, persistent state, and runtime paths
- the instance manifest decides which package refs are combined

## 3. Naming

These terms should be used consistently.

### 3.1 Instance

A named runnable environment.

Examples:

- `dev`
- `prod`
- `claw_today`

An instance is a composition of package-specific refs.

### 3.2 Package

A distinct program managed by the stack.

Examples:

- `openclaw`
- `gogcli`
- `himalaya`
- future add-ons such as `neverest`, `email-oauth2-proxy`, or a custom sidecar

### 3.3 Bundle

An immutable installable package artifact.

Examples:

- an npm-built OpenClaw dist pinned to a specific lockfile and commit
- a downloaded `gogcli` release tarball
- a specific `himalaya` binary release or source build

Bundles should describe how they were produced, but they do not need to contain every runtime utility used around them.

### 3.4 Toolchain Ref

A separately versioned runtime or build dependency used by one or more bundles.

Examples:

- `node@25.6.1`
- `pnpm@10.8.1`
- `python@3.12.9`
- `rust@1.86.0`

Toolchain refs are supported, but optional.

Reason:

- sometimes per-instance toolchain pinning is important for reproducibility
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
- B. code or binary packages
  examples: `openclaw`, `gogcli`, `himalaya`
- C. per-package runtime inputs
  `config`, `cred`, and `state`

Phase 1 assumptions:

- each package owns its own `config`, `cred`, and `state`
- default package locations such as `~/.config/...` or package-specific dotfiles are allowed
- one package may use one primary state location even if the real package later grows multiple state roots
- overlaps between package credential formats are noted but not reconciled automatically yet

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

### 5.1 Toolchain Versioning

System utilities such as `node` should be versioned per instance only when they materially affect reproducibility.

Default approach:

- allow `system` toolchains by default
- support `nvm` as a practical Node version source
- pin a package-local toolchain only when build or runtime behavior depends on it

Examples where per-instance toolchain pinning is desirable:

- OpenClaw built from source with Node and pnpm
- packages with native modules sensitive to Node ABI
- reproducible CI or release builds

Examples where per-instance toolchain pinning is optional:

- a downloaded standalone `gogcli` binary
- a static `himalaya` release binary

Decision:

- toolchain refs are supported natively
- toolchain refs are optional per package
- they should not be forced onto every package
- system-global installs remain valid package sources when explicitly declared

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

- do not reinstall the package
- record the currently resolved binary path and version
- treat that path as the package bundle input for validation and wrapper generation

Example:

```toml
[packages.openclaw.bundle]
ref = "openclaw@2026.2.25+git.78ddb1e9df#sha256:..."
install_adapter = "npm-source-build"

[packages.openclaw.bundle.inputs]
repo = "git@github.com:.../openclaw.git"
commit = "78ddb1e9df"
toolchain_ref = "node@25.6.1"
package_manager_ref = "pnpm@10.8.1"
lockfile_hash = "sha256:..."
```

```toml
[packages.gogcli.bundle]
ref = "gogcli@0.12.0+c18c58c#sha256:..."
install_adapter = "curl-tarball"

[packages.gogcli.bundle.inputs]
url = "https://..."
sha256 = "..."
```

### 5.3 Execution Search Paths

Execution search paths should be generated per instance.

Setpack should compute, in order:

1. package-local wrapper path
2. package bundle binary path
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

## 7. Instance Manifest

Each instance should have one manifest at:

```text
~/.config/setpack/instances/<instance-label>/instance.toml
```

Example:

```toml
instance = "prod"
description = "Primary local production-like Claw environment"

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

[[packages.openclaw.models.default.fallback]]
provider = "google"
account = "paid"
model = "gemini-2.5-pro"

[[packages.openclaw.models.default.fallback]]
provider = "anthropic"
account = "work"
model = "claude-sonnet-4"

[packages.openclaw.agents.main.model]
provider = "openai"
account = "chatgpt-main"
model = "gpt-5.4"

[packages.openclaw.agents.research.model]
provider = "google"
account = "paid"
model = "gemini-2.5-pro"

[packages.gogcli]
bundle_ref = "gogcli@0.12.0+c18c58c#sha256:..."
config_ref = "gogcli-config@default-v1#sha256:..."
cred_ref = "gogcli-cred@2026-04-11#sha256:..."
state_ref = "gogcli-state@2026-04-11T21:30:00Z#sha256:..."

[packages.himalaya]
bundle_ref = "himalaya@1.2.0#sha256:..."
config_ref = "himalaya-config@mail-v2#sha256:..."
cred_ref = "himalaya-cred@2026-04-11#sha256:..."
state_ref = "himalaya-state@empty#sha256:..."

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

### 7.1 LLM Access Is Provider Plus Account Plus Model

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

### 7.2 Package and Agent Model Selection

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

## 9. Save and Restore Model

Exports and restores should happen at two scopes:

- `instance`
- `package`

And at four kinds:

- `bundle`
- `config`
- `cred`
- `state`

### 9.1 Required Commands

Recommended operator-facing commands:

```text
setpack apply <instance>
setpack run <instance> <package> [-- ...]
setpack export <instance> [--package <name>] --kind <bundle|config|cred|state>
setpack import <instance> [--package <name>] --kind <bundle|config|cred|state> <ref-or-path>
setpack snapshot <instance> [--package <name>]
setpack doctor <instance>
setpack lock <instance>
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
  OAuth client file, token exports, keyring references
- `state`
  durable local CLI state worth preserving
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
setpack apply <instance>
setpack validate <instance>
setpack update <instance> [--package <name>]
setpack export <instance> [--package <name>] --kind <bundle|config|cred|state>
setpack import <instance> [--package <name>] --kind <bundle|config|cred|state> <ref-or-path>
setpack run <instance> <package> [-- ...]
setpack lock <instance>
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

The current `~/.openclaw-repo` layout should eventually be decomposed by class, not merely by moving everything to a different account-attached tree.

### 15.1 Naming Notes From Current OpenClaw Config

Some current OpenClaw profile names are historical artifacts.

Examples:

- `openai-codex:default`
- `openai-codex:codex-cli`
- `openai:api-key`
- `anthropic:anthropic`
- `google:paid`
- `google:free`

For `setpack`, these should be treated as package-local labels from the current OpenClaw configuration, not as stable global naming.

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
8. OpenClaw package adapter
9. `gogcli` package adapter
10. Himalaya package adapter
11. router trial after direct provider/account/model validation succeeds

That will solve the immediate local consistency problem before extending the same model to remote and sandboxed deployments.
