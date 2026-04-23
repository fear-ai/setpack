# Setpack

Setpack is an effort to create coordinated, self-contained packs of working
executables, configuration, credentials, and state for validation, debugging,
incremental rollout, and eventual deployment. The intended operator is an
individual developer or a small self-organizing team that needs fast iteration
without surrendering control to heavyweight deployment machinery.

## 1. Introduction

Modern software environments often fail not because one binary is missing but
because the executable, its configuration, its credentials, and its runtime
history have drifted apart. A developer may be able to launch a system today
yet still be unable to reproduce the same result tomorrow, replicate it on
another machine, or explain which combination of state, config, and auth made
the difference.

Setpack starts from that operational failure mode. The goal is not to replace
every build, packaging, or deployment tool. The goal is to make a working
environment explicit enough to validate, reproduce, inspect, and evolve
incrementally.

## 2. Operating Problem

The practical friction appears in overlapping layers:

- binaries and scripts are easy to install but hard to pin as a coordinated set
- configuration often lives in convenient default locations that are poorly
  tracked
- credentials follow provider-specific policies and rarely fit one uniform
  storage model
- runtime and persistent state accumulate in places that are hard to inspect,
  export, or recreate
- debugging and validation often require mixing one known-good component with
  several changing ones

The result is familiar:

- a local setup works but cannot be reconstructed cleanly
- migration to another machine becomes guesswork
- CI or containerized validation becomes brittle and over-constrained
- credentials are duplicated, misplaced, or accidentally left exposed
- durable history leaks into supposedly clean validation sessions

## 3. Limits Of Existing Approaches

Setpack is motivated partly by the limits of common alternatives.

### 3.1 Containers

Docker and similar systems solve some problems well:

- isolation
- packaging of explicit runtime dependencies
- repeatable startup behavior for narrow, well-defined services

They become awkward when the target environment depends on:

- host user identity
- browser-mediated authentication
- desktop or account-local toolchains
- mutable local configuration with operator edits
- long-lived runtime history that matters to behavior

In those cases, containerization often introduces more friction than control.
The operator ends up translating a human-maintained machine into an artificial
runtime that still needs exceptions, mounts, secret injection, copied state, and
environment-specific repair.

### 3.2 CI And Deployment Machinery

CI pipelines and standard deployment systems are optimized for repeatable
promotion of already-structured artifacts. They are much less comfortable as the
primary place to discover what a working environment actually consists of.

Typical friction points:

- first-time authentication is interactive
- credentials need different handling in local, shared, and hosted contexts
- runtime history is usually treated as disposable even when it is behaviorally
  important
- the validation target is often a rapidly changing developer environment, not a
  final service image

### 3.3 Package Managers

Tools such as `nvm`, `pyenv`, Homebrew, Cargo, npm, and similar managers remain
useful. They do not by themselves describe a complete working pack. They mostly
manage one layer:

- a runtime
- a package manager
- a binary install path

They do not usually coordinate:

- per-tool config
- segregated credential sets
- exported state
- runtime receipts
- controlled mixing of system-installed and locally pinned components

## 4. Setpack Approach

Setpack takes a narrower and more operator-centered approach.

### 4.1 Pack As The Working Unit

A pack is a coordinated set of:

- executables
- configuration
- credentials or credential references
- persistent state
- runtime state
- wrapper and path wiring
- validation context and receipts needed to explain what was run

The unit of control is not only the installed binary. It is the working
combination.

### 4.2 Execution Model

The current design is wrapper-first:

- generated or maintained per-pack wrappers are the intended entrypoints
- pack-local `bin/` precedence is used for helper resolution
- that `PATH` handling is narrow and deliberate, not a generic global shim
  system

This matters in practice. OpenClaw discovers helper tools such as `gog` by
executable name. If the pack does not control wrapper resolution and helper
lookup, the system silently drifts back toward whatever binary happens to win on
the host `PATH`.

### 4.3 Current Host-Level Mechanisms

The present implementation reality is host-shaped rather than abstract:

- user-path changes and related dotfiles still matter
- wrappers are used to inject pack selection and pack-local paths
- configuration directories are connected explicitly rather than discovered by
  one universal convention
- some tools still require controlled `HOME`, config-path, or state-path
  indirection

The current bootstrap chain is already concrete:

- `~/.setpack` selects the default root, set, and pack in a managed block
- `repack` updates that managed block from the repo-local `dot.setpack`
  template
- `.setpack.pack.sh` publishes resolved pack variables back into the shell
- `setpack` materializes pack layout, component directories, wrappers, and
  status tracking

This is not an accident in the design. It is the current operational surface
that Setpack is trying to make explicit and manageable.

One operational lesson now needs to remain attached to that chain. A managed
shell selector that only sets values when variables are unset is not strong
enough for this project. Long-lived terminals, tool hosts, and helper
processes can carry stale `SETPACK_*` variables and stale setpack `PATH`
entries forward even after the user has selected a new default pack. The
managed shell block and generated `.setpack.pack.sh` files therefore clear
prior setpack selector variables and scrub old setpack path entries before
setting the new pack authoritatively.

The same logic justifies a distinct forced mode on `repack`. Ordinary `repack`
changes what future shells and future launches resolve. `repack --force`
exists for the developer case where predictability matters more than preserving
already-running pack-managed processes. In that explicit mode, Setpack tears
down the OpenClaw LaunchAgent and pack-root processes before rewriting the
managed default selection so that old runtime state does not keep operating
under the previous pack unnoticed.

### 4.4 Layered Controller Shape

The controller shape should be separated into three layers.

First is general set and pack setup. This layer is not about OpenClaw, Gog, or
any other application. It is responsible for:

- selecting the active set and pack
- resolving `pack_root` and related pack paths
- managing the shell block and pack env export
- creating pack-level `bin/` directories and wrapper search precedence
- recording pack status and validation receipts
- providing generic import, export, and role-copy operations

Second is application-specific component handling. This is where one app knows
how to install, wrap, validate, or import its own material:

- `openclaw`
- `gog`
- `himalaya`
- `neverest`
- later components with their own config, cred, and state rules

Third is combination handling for cooperating applications. This layer is for
cases where one managed app expects to call, discover, or coordinate with
another:

- OpenClaw plus helper tools it calls by executable name
- OpenClaw plus `gog`
- the `himalaya` and `neverest` subsystem
- later multi-tool combinations that share paths, state, or wrapper behavior

The intent is that higher-level scripts orchestrate lower-level ones. General
set and pack setup should not hardcode app behavior. App-specific handlers
should not own pack selection. Combination handlers should express cooperation
rules without reimplementing the generic substrate.

### 4.5 Component Acquisition And Mixing

Setpack must support more than one way to obtain a working executable:

- pack-local bundles built or copied into the pack
- system-installed binaries that remain in place but are wrapped and recorded
- locally built tools from active source trees

The preserved script-design notes still matter here:

- component handling should be generic at the controller level
- application-specific behavior should live in app-focused hooks
- `system-existing` remains a valid mode when the goal is to wrap and record an
  already-installed tool instead of reinstalling it immediately

That is directly relevant to the current environment:

- OpenClaw is already functioning as a pack-local bundle
- `gog` has both a system-installed path and a validated pack-local wrapper path
- `himalaya` and `neverest` are still closer to current-system and local-build
  observations than fully formalized pack-local modules

### 4.6 Working Style

The approach is intentionally biased toward:

- rapid local validation
- explicit composition
- reversible changes
- incremental replacement of specific components
- controlled reuse of known-good binaries, configs, or state

It does not assume mandatory virtualization, sandboxing, image builds, or full
automation.

## 5. Configuration, State, And Runtime Surfaces

Configuration is only part of the system. Runtime history and persistent state
are equally important, and they do not behave the same way across tools.

### 5.1 Configuration Surfaces

Different tools expose configuration through different mechanisms:

- explicit config files
- environment variables
- derived profile paths
- pack-owned wrappers that inject the final path or home directory

Current examples already visible in the working environment:

- Gog can be made pack-local by forcing a controlled `HOME` and a synthetic
  Gog-native root under the pack
- Himalaya is strongly file-config driven, while passwords are delegated through
  command lookups into the host keychain
- Neverest carries its own config and mailbox assumptions, but still interacts
  with shared local mail state
- OpenClaw supports explicit config and state path handling and persists a
  workspace association
- OpenClaw also separates some provider credentials from ordinary app config via
  `auth-profiles.json`

That diversity is why Setpack cannot define one simplistic “config directory”
rule and expect every tool to fit it cleanly.

### 5.2 Persistent State And Identity

Persistent state includes more than obvious user data. It can also include:

- cached auth material
- device identity
- paired-client state
- onboarding markers
- model usage history
- mailbox sync cursors and local indexes
- watch registrations and provider-side integration state

Current examples from the working environment show this clearly:

- Gog watch state and related support files affect how Gmail-backed operations
  continue across launches
- Maildir-backed state under `~/.Mail` matters to the Pimalaya subsystem even
  when the executable itself is replaced
- `auth-profiles.json` and related auth files affect which providers are usable
- device and pairing state affect whether a control surface is trusted
- workspace state changes how OpenClaw behaves on the next run

### 5.3 Runtime Residue Versus Durable History

One of Setpack's jobs is to force an explicit distinction between:

- durable history worth keeping
- disposable runtime residue
- receipts that explain what happened during validation

Those categories often get mixed together in practice, and they cannot always be
classified once and for all in the abstract. The same file may be disposable in
one tool and behaviorally important in another. Setpack therefore needs a way to
record the distinction per tool and per integration instead of pretending the
boundary is already universal.

Examples:

- a refresh token export may be durable credential material
- a file-keyring cache may be rebuildable runtime state
- a validation record explaining which binary and config were used is not the
  same thing as either config or state
- a temporary log may be disposable, while a sync cursor is not

This distinction matters because not every stateful file should be archived, and
not every runtime artifact should be ignored.

### 5.4 Validation And Receipts

Setpack needs a place for realized facts about a validation run:

- the resolved binary
- the wrapper that won command resolution
- the active config root and state root
- the selected credential source
- the helper binaries reached through the pack-local `PATH`
- the setup actions that completed, were only attempted, or were later validated

These are closer to receipts than configuration. They should explain what was
validated without being mistaken for the desired long-term specification.

The current implementation already hints at this split:

- `status.toml` records staged completion and validation markers
- per-component manifests such as `openclaw/comp.toml` and `gog/comp.toml`
  declare intended source and handling
- generated wrappers and exported pack env files express the realized execution
  path more clearly than a static manifest alone

### 5.5 Present Implementation Specifics

The current environment already demonstrates several concrete mechanisms that
Setpack should absorb rather than ignore:

- pack-local wrappers export pack selection variables before they exec
- pack-local `bin/` directories are prepended so helper discovery stays inside
  the same pack
- repo-root `setpack` is the authoritative materialization script
- repo-root `repack` updates the managed default-pack selection block in
  `~/.setpack`
- repo-root `repack --force` is the explicit teardown path when the developer
  wants stale gateways, wrappers, and pack-managed processes cleared before the
  new default selection is written
- `.setpack.pack.sh` reflects resolved pack variables back into interactive
  shells
- Gog validation currently relies on a controlled `HOME` and a synthetic
  runtime root under the pack
- stable file-keyring support for Gog is being achieved through pack-owned state
  rather than through a machine-global secret store alone
- OpenClaw distinguishes ordinary config from provider auth material through
  separate auth-profile handling
- Himalaya delegates password retrieval to host commands rather than storing
  everything in one file-backed secret format
- Neverest and Himalaya share local-store implications even when they are not
  yet packaged the same way

### 5.6 Why This Section Matters

The environment fails when these surfaces are treated as one blob called
“config.” Setpack exists partly to stop that simplification. A working pack must
be able to say, with specificity:

- configuration
- credential material
- durable state
- disposable runtime state
- validation receipts

## 6. Credential Complexity

Credentials are one of the main reasons the environment must be treated as a
coordinated pack rather than a list of installed programs.

### 6.1 No Unified Credentials

The current environment already spans materially different kinds of auth:

- LLM provider API keys
- OAuth client definitions used to start browser-based authorization
- refresh and access token artifacts produced by OAuth flows
- email app passwords
- gateway and other internal service tokens
- plugin or connector keys such as search-provider credentials
- local-only backends such as Ollama that may require no external provider
  secret at all

These do not share the same lifecycle, scope, recovery path, or transport
story. Treating them as one bucket produces confusion and operator error.

### 6.2 Provider And Tool Diversity

Different tools impose different auth behavior:

- OpenClaw uses provider-specific auth profiles and can hold several primary and
  fallback provider definitions at once
- Google-facing tools such as `gog` or `gws` rely on OAuth client material plus
  per-account token artifacts
- `himalaya` and `neverest` may depend on IMAP or mail-provider credentials,
  host keychain lookups, or app-password-style access
- chat and gateway integrations such as Discord or internal OpenClaw gateway
  tokens have a different blast radius from LLM API keys

Even within one provider, there may be more than one valid auth route depending
on the service surface, account type, or whether the flow is interactive,
restored, headless, or local-only.

### 6.3 Common Failure Modes

Credential handling is one of the main sources of avoidable operator mistakes:

- keys or tokens are committed to Git repositories
- refresh artifacts are copied around without clear ownership or expiry review
- default home directories silently accumulate account state across experiments
- test and production credentials are mixed in the same config path
- broad-scope tokens are treated like low-risk local settings

OpenClaw increases this pressure because provider auth, gateway credentials,
channel integrations, browser-mediated onboarding, and helper tools can all
coexist in one operator environment. The risk is often confusion and accidental
exposure rather than one dramatic exploit path.

### 6.4 Setpack Response

Setpack therefore treats credentials as:

- associated with a pack
- explicitly segregated from ordinary configuration
- selectable for incremental validation sessions
- replaceable without forcing wholesale environment rebuilds
- classed by type and blast radius rather than flattened into “secrets”

The goal during development is a rapid, controlled, and error-resistant method
for mixing and matching configurations with the associated but deliberately
separated credential sets they require.

This also affects automation. First-time OAuth in a browser is a bootstrap
activity, not a suitable primitive for CI. Restore and CI flows should prefer
import of already-exported portable auth artifacts where the underlying tool
supports it.

## 7. Inspiration From OpenClaw

This complexity is the immediate inspiration for the Setpack effort.

### 7.1 Why OpenClaw Presses On The Design

OpenClaw is a strong forcing case because it commonly needs several primary and
fallback LLM providers at once. Those providers may use different auth schemes,
different model catalogs, and different failure behavior. The working
environment is therefore not just “an app plus a key.” It is a coordinated
matrix of:

- provider choice
- fallback order
- auth profile selection
- model naming and alias handling
- gateway and channel settings
- helper binary resolution

### 7.2 What The Current Implementation Already Shows

The current pack-local OpenClaw design is concrete rather than hypothetical:

- the OpenClaw bundle lives under `openclaw/bundle`
- the generated wrapper exports `OPENCLAW_STATE_DIR` and
  `OPENCLAW_CONFIG_PATH`
- the wrapper injects a pack-local workspace on `openclaw onboard` unless the
  caller overrides it
- the wrapper prepends the pack `bin/` directory so helper tools such as `gog`
  resolve inside the same pack when present
- ordinary app config and provider auth material are already treated as
  different surfaces

This is exactly the kind of behavior Setpack needs to preserve and explain.

### 7.3 Why Companion Tools Matter

OpenClaw sits beside binaries such as `gog`, `himalaya`, and `neverest` that
may be installed, updated, and authenticated on different schedules. Their
configuration and runtime history are behaviorally important, yet they do not
arrive as one neatly versioned subsystem.

That mixed reality matters:

- `gog` may be wrapped pack-locally while still reflecting Google account state
- `himalaya` and `neverest` share mail-state implications even when their
  packaging mode differs
- local models such as Ollama reduce external credential pressure for some runs
  but not for provider-backed fallback paths

Setpack is an attempt to make these combinations inspectable and reproducible
without forcing them prematurely into a single rigid deployment mold.

## 8. Comparison With Alternatives

Setpack should be understood as complementary to existing approaches rather
than as a total replacement.

### 8.1 Compared With Containers

Container systems such as Docker, Podman, and Docker Compose are strong when the
runtime can be described as an image plus a small set of mounted inputs. Setpack
prefers direct host coordination when the environment is already fundamentally
host-shaped:

- user-local paths matter
- desktop auth flows matter
- account-local state matters
- incremental debugging outranks isolation purity

That is the shape of the current OpenClaw and `gog` work: browser OAuth,
developer dotfiles, managed shell paths, pack-local wrappers, and account-tied
state are all part of the behavior. A container can still help around the
edges, but it is not the natural primary unit here.

### 8.2 Compared With CI

CI systems such as GitHub Actions, GitLab CI, and Buildkite are strong once the
thing being tested is already structured for unattended remote execution.
Setpack is stronger earlier in the lifecycle:

- discovering what the working environment really contains
- preserving and reusing local state and credentials in controlled form
- validating incremental environment changes before promotion

This matters for flows like OpenClaw plus Google OAuth helpers, where first-time
auth is interactive and the pack may depend on imported local artifacts before
there is anything robust enough for CI to exercise remotely.

CI remains stronger later for:

- repeatable remote execution of already-structured artifacts
- promotion gates
- automated regression checks

### 8.3 Compared With Traditional Deployment Systems

Traditional deployment systems such as Ansible, NixOS-style system descriptions,
Kubernetes manifests, Helm charts, or Terraform are built to declare and
operate formal environments. Setpack is intentionally lighter and more
local-first.

It is not trying to replace those systems with a full fleet manager. It is
trying to preserve a working, developer-shaped environment well enough that it
can be validated, debugged, and then, where appropriate, promoted toward a more
formal deployment model with fewer hidden assumptions.

### 8.4 Compared With Runtime Selectors Such As `pyenv` Or `nvm`

Setpack shares one important trait with tools such as `pyenv` and `nvm`: it
uses shell-visible path selection and wrapper indirection to control which
binary wins.

The difference is scope. `pyenv` or `nvm` primarily switch one runtime family.
Setpack coordinates several tools at once and must also account for:

- config placement
- credential segregation
- persistent and runtime state
- helper binary discovery across cooperating applications
- receipts explaining which combination was actually validated

In that sense Setpack is not a language runtime manager. It is a broader working
environment selector.

## 9. Appendix: Repo Map

### 9.1 Documents

- `Setpack.md`: architecture, design direction, and system-level comparisons
- `Setplan.md`: active planning, unresolved design work, and near-term tasks
- `apps/Setclaw.md`: OpenClaw-specific handling and OpenClaw-plus-helper
  combination consequences
- `apps/Setpimalaya.md`: Setpack-facing combination-layer notes for the
  Himalaya and Neverest subsystem
- `apps/ClawInfo.md`: sanitized observed OpenClaw environment inventory
- `apps/ModelNames.md`: model, provider, profile, alias, and label naming notes
- `apps/Neverest.md`: narrower Neverest-specific note while broader subsystem
  work is still settling
- `Claw/Emails/Emails.md`: deeper mail-domain, provider, client, and upstream
  tool research outside this repo-local document set

### 9.2 Scripts

- `setpack`: stable top-level orchestrator that calls the narrower scripts
- `repack`: stable top-level wrapper for the managed-shell updater
- `scripts/`: authoritative script collection, split into generic substrate,
  application-specific handlers, and combination handlers
- `dot.setpack`: template for the managed shell block consumed by `repack`
