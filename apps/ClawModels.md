# ClawModels

OpenClaw model-provider reference for Setpack work. This file records how
provider ids, model ids, aliases, profile-qualified refs, generated files,
runtime auth overlays, UI labels, and onboarding choices currently relate to
each other, with source anchors for later review and diff tracking.

## 1. Purpose

This note is for two audiences:

1. a power user configuring more involved primary and fallback model sequences
2. a developer reviewing or reworking OpenClaw model naming, provider
   discovery, display labels, and auth-backed provider availability

It is intentionally broader than a simple naming note. It covers the actual
surfaces a user sees, the files a pack carries, the files OpenClaw generates,
and the runtime-only sources that can affect behavior without appearing in the
pack itself.

## 2. Boundaries

This file is about OpenClaw model and provider handling.

It includes:

- model refs in `openclaw.json`
- generated `models.json`
- `auth-profiles.json` and legacy `auth.json`
- runtime import from external Codex storage
- gateway catalog behavior
- control UI display behavior
- onboarding/default-model picker behavior
- local documentation and changelog anchors worth tracking

It does not try to be the full OpenClaw config reference, nor the final
Setpack-wide policy for every application.

## 3. Model Surfaces

### 3.1 Configured model refs

The pack-authored configuration surface is the OpenClaw config file, for
example [apr20 `openclaw.json`](</Users/walter/Work/Claw/Setpacks/openclaw/apr20/openclaw/config/openclaw.json>).

This is where OpenClaw reads:

- `agents.defaults.model.primary`
- `agents.defaults.model.fallbacks`
- `agents.defaults.models`

Those settings use raw refs such as:

- `provider/model`
- `provider/model@profile`

The raw config notation is the canonical authored notation. It is not the same
as the display labels shown in the UI.

### 3.2 Generated provider snapshot

OpenClaw also maintains `models.json` in the agent directory. The write path is
[models-config.ts](/Users/walter/Work/Claw/openclaw/src/agents/models-config.ts:138).

This file is not the full live model catalog. It is a generated provider
snapshot used by the underlying model registry path. In `apr20` the current
file is [state `models.json`](</Users/walter/Work/Claw/Setpacks/openclaw/apr20/openclaw/state/agents/main/agent/models.json>).

Observed current `apr20` contents:

- provider `openai-codex`
- provider `codex`
- provider `ollama`

Observed current omissions:

- no direct `anthropic` provider entry
- no direct `google` provider entry

That omission is a result of OpenClaw handling, not an Anthropic or Google API
property.

### 3.3 Persisted auth store

The primary persisted auth surface is `auth-profiles.json`. OpenClaw documents
that as the main auth-profile store in
[wizard.md](/Users/walter/Work/Claw/openclaw/docs/reference/wizard.md:66).

For `apr20`, the state path
[state `auth-profiles.json`](</Users/walter/Work/Claw/Setpacks/openclaw/apr20/openclaw/state/agents/main/agent/auth-profiles.json>)
is a symlink to
[cred `auth-profiles.json`](</Users/walter/Work/Claw/Setpacks/openclaw/apr20/openclaw/cred/agents/main/agent/auth-profiles.json>).

Observed current `apr20` state:

- the persisted `auth-profiles.json` file is present
- the persisted `profiles` map is currently empty

### 3.4 Legacy compatibility bridge

OpenClaw still has a legacy compatibility file `auth.json` for the Pi/model
registry path. The bridging helper is
[pi-auth-json.ts](/Users/walter/Work/Claw/openclaw/src/agents/pi-auth-json.ts:38).

Its role is explicit in source:

- OpenClaw stores credentials in `auth-profiles.json`
- the registry path still expects `auth.json`
- OpenClaw can bridge credentials into `agentDir/auth.json`

In `apr20`, `auth.json` is currently absent until something writes it.

### 3.5 Runtime-only external auth overlays

The persisted auth store is not the whole story. OpenClaw overlays external
runtime auth profiles into memory at runtime through
[external-auth.ts](/Users/walter/Work/Claw/openclaw/src/agents/auth-profiles/external-auth.ts:63).

For OpenAI Codex, that external source is the Codex CLI auth file read by
[openai-codex-cli-auth.ts](/Users/walter/Work/Claw/openclaw/extensions/openai/openai-codex-cli-auth.ts:25).

Default resolution:

- use `CODEX_HOME` if set
- otherwise use `~/.codex`
- then read `auth.json` under that directory

This means `~/.codex/auth.json` is an external runtime source that can affect
OpenClaw even when the pack-local `auth-profiles.json` is empty.

### 3.6 Live gateway catalog

The gateway model catalog comes from
[server-model-catalog.ts](/Users/walter/Work/Claw/openclaw/src/gateway/server-model-catalog.ts:17),
which simply calls [loadModelCatalog](/Users/walter/Work/Claw/openclaw/src/agents/model-catalog.ts:83).

That path:

1. ensures `models.json` exists
2. loads the underlying registry from `models.json`
3. augments the resulting entries with provider plugin contributions

The augmentation step is in
[model-catalog.ts](/Users/walter/Work/Claw/openclaw/src/agents/model-catalog.ts:158)
and [provider-runtime.ts](/Users/walter/Work/Claw/openclaw/src/plugins/provider-runtime.ts:890).

This live catalog is what the control UI and other runtime surfaces consume.

### 3.7 Onboarding and default-model chooser

The onboarding/default-model picker is a separate flow:
[model-picker.ts](/Users/walter/Work/Claw/openclaw/src/flows/model-picker.ts:408).

It uses the live catalog, but then applies more policy:

- allowlist filtering
- auth checks
- hidden-router filtering
- preferred-provider filtering
- setup and route hints

Its option label is the raw `provider/model` key rather than the control UI
friendly label. See
[model-picker.ts](/Users/walter/Work/Claw/openclaw/src/flows/model-picker.ts:169).

## 4. Current `apr20` File Map

### 4.1 Pack-authored or user-maintained files

- [apr20 `openclaw.json`](</Users/walter/Work/Claw/Setpacks/openclaw/apr20/openclaw/config/openclaw.json>)
  - primary authored config surface
  - may be normalized or rewritten by OpenClaw flows
- [apr20 cred `auth-profiles.json`](</Users/walter/Work/Claw/Setpacks/openclaw/apr20/openclaw/cred/agents/main/agent/auth-profiles.json>)
  - pack-local persisted auth store target
  - currently empty

### 4.2 Generated or regenerated files

- [apr20 state `models.json`](</Users/walter/Work/Claw/Setpacks/openclaw/apr20/openclaw/state/agents/main/agent/models.json>)
  - generated provider snapshot
  - currently differs from `apr16` and `today`
  - not a symlink in `apr20`

### 4.3 Indirection and symlinks

- [apr20 state `auth-profiles.json`](</Users/walter/Work/Claw/Setpacks/openclaw/apr20/openclaw/state/agents/main/agent/auth-profiles.json>)
  - symlink to the `cred` location

### 4.4 External non-pack source

- `~/.codex/auth.json`
  - not owned by the pack
  - not OpenClaw-native state
  - reused by OpenClaw when present

## 5. Naming And Identity Terms

### 5.1 Provider id

Examples:

- `openai`
- `openai-codex`
- `anthropic`
- `ollama`

This is the provider identifier used in raw model refs and in various plugin
registration paths.

### 5.2 Model id

Examples:

- `gpt-5.4`
- `claude-opus-4-6`
- `qwen3.5:latest`

This is the provider-local model identifier.

### 5.3 Canonical model ref

The canonical authored form is:

- `provider/model`

Examples:

- `openai/gpt-5.4`
- `openai-codex/gpt-5.4`
- `ollama/qwen3.5:latest`

### 5.4 Profile-qualified model ref

Some refs can also be profile-qualified:

- `provider/model@profile`

This matters when the same provider has more than one auth profile or usage
route.

### 5.5 Alias

Aliases are configured under `agents.defaults.models`. They are user-facing
short names layered onto canonical refs.

An alias is neither the provider id nor the catalog display name.

### 5.6 Catalog name

Catalog entries also carry a `name`. This is frequently a nicer display string
than the raw model id.

Examples seen in bundled catalogs:

- `Qwen3 Coder 480B`
- `Kimi K2.5`
- `GPT-5.4-Mini`

### 5.7 Display label

The control UI does not show raw refs directly. It applies label logic that:

- prefers alias or catalog `name`
- falls back to `id · provider`
- can transform `provider/model` into `model · provider`
- appends provider when names collide

The relevant display helpers are in the built UI bundle:
[index-Bs4iQELM.js](/Users/walter/Work/Claw/Setpacks/openclaw/apr20/openclaw/bundle/node_modules/openclaw/dist/control-ui/assets/index-Bs4iQELM.js:4).

## 6. Why The Surfaces Differ

### 6.1 Why the UI list is larger than `models.json`

`models.json` is only the generated provider snapshot. The live gateway catalog
starts there, then adds plugin-supplied model entries through
[augmentModelCatalogWithProviderPlugins](/Users/walter/Work/Claw/openclaw/src/plugins/provider-runtime.ts:890).

That is why the UI can show many more providers and models than `models.json`
contains.

### 6.2 Why `models.json` contains `codex`, `openai-codex`, and `ollama`

Those providers currently participate in the implicit provider resolution path
through `catalog` or `discovery` hooks.

Hook dispatch is defined in
[provider-discovery.ts](/Users/walter/Work/Claw/openclaw/src/plugins/provider-discovery.ts:14).

Observed examples:

- `openai-codex` uses `catalog.run`
- `codex` uses `catalog.run`
- `ollama` uses `discovery.run`

### 6.3 Why `anthropic` and `google` are absent from `models.json`

The current evidence points to an OpenClaw implementation distinction:

- those providers can be active and usable
- but they do not currently appear in the same implicit provider persistence
  path used to build `models.json`

This is a handling distinction inside OpenClaw. It should not be explained as a
provider API limitation.

### 6.4 Why onboarding differs from the control UI

The onboarding/default-model chooser uses the catalog, but it is a curated
selection flow. It applies filtering and setup guidance in
[model-picker.ts](/Users/walter/Work/Claw/openclaw/src/flows/model-picker.ts:429).

The control UI is showing the live catalog with a separate display transform.

So there are at least two user-facing model-selection surfaces with different
selection rules and different label rules.

### 6.5 Why the UI can work with an empty persisted `auth-profiles.json`

Because OpenClaw overlays runtime-only external auth profiles into the auth
store view. For Codex, the source is `~/.codex/auth.json` by default via
[openai-codex-cli-auth.ts](/Users/walter/Work/Claw/openclaw/extensions/openai/openai-codex-cli-auth.ts:25).

That is the direct explanation for a working UI in `apr20` even though the
persisted `cred/.../auth-profiles.json` is currently empty.

## 7. `catalog.run` And `discovery.run`

OpenClaw currently normalizes those through one selector:
[provider-discovery.ts](/Users/walter/Work/Claw/openclaw/src/plugins/provider-discovery.ts:14).

Observed practical difference:

- `catalog.run`
  - provider can materialize itself when some auth or runtime condition is met
- `discovery.run`
  - provider probes the environment and synthesizes config from what is
    reachable

Examples:

- `openai-codex` `catalog.run`:
  [openai-codex-provider-C_KMICUl.js](/Users/walter/Work/Claw/Setpacks/openclaw/apr20/openclaw/bundle/node_modules/openclaw/dist/openai-codex-provider-C_KMICUl.js:216)
- `codex` `catalog.run`:
  [provider-CO11jseK.js](/Users/walter/Work/Claw/Setpacks/openclaw/apr20/openclaw/bundle/node_modules/openclaw/dist/provider-CO11jseK.js:58)
- `ollama` `discovery.run`:
  [provider-discovery.js](/Users/walter/Work/Claw/Setpacks/openclaw/apr20/openclaw/bundle/node_modules/openclaw/dist/extensions/ollama/provider-discovery.js:82)

## 8. `~/.codex` Provenance

`~/.codex` is not an OpenClaw state directory. It is the Codex CLI home that
OpenClaw knows how to reuse.

Source anchors:

- default resolution to `~/.codex`:
  [openai-codex-cli-auth.ts](/Users/walter/Work/Claw/openclaw/extensions/openai/openai-codex-cli-auth.ts:25)
- documentation that onboarding may reuse `~/.codex/auth.json`:
  [wizard.md](/Users/walter/Work/Claw/openclaw/docs/reference/wizard.md:36)

For local analysis this means:

- entries in `~/.codex` can pre-date OpenClaw
- some runtime-auth behavior seen in OpenClaw may actually be inherited from
  pre-existing Codex CLI state
- Setpack should treat `~/.codex` as an external dependency unless the pack
  explicitly takes ownership of it

## 9. External CLI Homes And User-Level State

OpenClaw does not limit itself to files under its own state directory. It can
reuse or inspect other user-level tool homes. For Setpack, these need to be
treated separately from pack-owned config and cred material.

### 9.1 `.codex`

Observed OpenClaw handling:

- reads Codex CLI OAuth from `CODEX_HOME/auth.json` or `~/.codex/auth.json`
- uses the same home path in the CLI credential helpers
- test tooling also knows about `~/.codex/auth.json` and `~/.codex/config.toml`

Source anchors:

- [extensions/openai/openai-codex-cli-auth.ts](/Users/walter/Work/Claw/openclaw/extensions/openai/openai-codex-cli-auth.ts:25)
- [src/agents/cli-credentials.ts](/Users/walter/Work/Claw/openclaw/src/agents/cli-credentials.ts:138)
- [docs/help/testing.md](/Users/walter/Work/Claw/openclaw/docs/help/testing.md:643)

Setpack consequence:

- `CODEX_HOME` is a real override point and should be considered explicitly
- if Setpack does nothing, OpenClaw may still inherit pre-existing Codex CLI
  state from the user account

### 9.2 `.claude` And `.claude.json*`

Observed OpenClaw handling:

- reads Claude CLI credentials from `~/.claude/.credentials.json`
- doctor and workspace health logic expect Claude project directories under
  `~/.claude/projects/...`
- plugin tooling looks at `~/.claude/plugins/known_marketplaces.json`
- the test harness treats `.claude.json`,
  `~/.claude/.credentials.json`, `~/.claude/settings.json`, and
  `~/.claude/settings.local.json` as external auth/config files worth mounting
- Claude CLI backend handling explicitly clears `CLAUDE_CONFIG_DIR` from child
  environments

Source anchors:

- [src/agents/cli-credentials.ts](/Users/walter/Work/Claw/openclaw/src/agents/cli-credentials.ts:13)
- [src/commands/doctor-claude-cli.ts](/Users/walter/Work/Claw/openclaw/src/commands/doctor-claude-cli.ts:169)
- [src/plugins/marketplace.ts](/Users/walter/Work/Claw/openclaw/src/plugins/marketplace.ts:28)
- [extensions/anthropic/cli-shared.ts](/Users/walter/Work/Claw/openclaw/extensions/anthropic/cli-shared.ts:57)
- [docs/help/testing.md](/Users/walter/Work/Claw/openclaw/docs/help/testing.md:645)
- [docs/cli/plugins.md](/Users/walter/Work/Claw/openclaw/docs/cli/plugins.md:136)

Setpack consequence:

- OpenClaw can reuse substantial host Claude state even when a pack keeps its
  own OpenClaw state clean
- `CLAUDE_CONFIG_DIR` and the default `~/.claude` tree should be treated as
  external-home inputs when evaluating reproducibility
- `.claude.json*` appears in testing/live-harness documentation, but it is not
  the main OpenClaw-owned auth store

### 9.3 `.ollama`

Observed OpenClaw handling:

- OpenClaw supports Ollama as a provider
- the main runtime assumptions are a reachable Ollama host, a base URL, and
  discovered model inventory
- the default local URL is `http://127.0.0.1:11434`
- provider config and discovery are centered on `models.providers.ollama`,
  `OLLAMA_API_KEY`, and host probing

Source anchors:

- [extensions/ollama/src/setup.ts](/Users/walter/Work/Claw/openclaw/extensions/ollama/src/setup.ts:12)
- [extensions/ollama/src/stream.ts](/Users/walter/Work/Claw/openclaw/extensions/ollama/src/stream.ts:39)
- [docs/reference/wizard.md](/Users/walter/Work/Claw/openclaw/docs/reference/wizard.md:43)
- [docs/gateway/local-models.md](/Users/walter/Work/Claw/openclaw/docs/gateway/local-models.md:14)

Negative finding:

- no direct OpenClaw code or docs references were found that make `~/.ollama`
  itself a first-class OpenClaw input in the same way `~/.codex` and
  `~/.claude` are

Setpack consequence:

- for now, Ollama should be treated primarily as a host-local service and model
  inventory source, not as a pack-managed or OpenClaw-managed user-home tree
- if Setpack needs stronger reproducibility around Ollama, that likely belongs
  in separate host/service guidance rather than in OpenClaw auth-store rules

## 10. Local Documentation And Implementation Anchors

### 10.1 Documentation worth tracking

- [docs/reference/wizard.md](/Users/walter/Work/Claw/openclaw/docs/reference/wizard.md:36)
- [docs/start/wizard-cli-reference.md](/Users/walter/Work/Claw/openclaw/docs/start/wizard-cli-reference.md:133)
- [docs/concepts/oauth.md](/Users/walter/Work/Claw/openclaw/docs/concepts/oauth.md:58)
- [docs/concepts/model-failover.md](/Users/walter/Work/Claw/openclaw/docs/concepts/model-failover.md:64)
- [docs/help/faq.md](/Users/walter/Work/Claw/openclaw/docs/help/faq.md:1398)
- [docs/gateway/configuration-reference.md](/Users/walter/Work/Claw/openclaw/docs/gateway/configuration-reference.md:3296)
- [docs/help/testing.md](/Users/walter/Work/Claw/openclaw/docs/help/testing.md:643)
- [docs/cli/plugins.md](/Users/walter/Work/Claw/openclaw/docs/cli/plugins.md:136)
- [docs/gateway/local-models.md](/Users/walter/Work/Claw/openclaw/docs/gateway/local-models.md:14)

### 10.2 Source files worth tracking

- [src/agents/model-catalog.ts](/Users/walter/Work/Claw/openclaw/src/agents/model-catalog.ts:83)
- [src/agents/models-config.ts](/Users/walter/Work/Claw/openclaw/src/agents/models-config.ts:138)
- [src/plugins/provider-discovery.ts](/Users/walter/Work/Claw/openclaw/src/plugins/provider-discovery.ts:14)
- [src/plugins/provider-runtime.ts](/Users/walter/Work/Claw/openclaw/src/plugins/provider-runtime.ts:890)
- [src/flows/model-picker.ts](/Users/walter/Work/Claw/openclaw/src/flows/model-picker.ts:408)
- [src/agents/auth-profiles/external-auth.ts](/Users/walter/Work/Claw/openclaw/src/agents/auth-profiles/external-auth.ts:63)
- [src/agents/pi-auth-json.ts](/Users/walter/Work/Claw/openclaw/src/agents/pi-auth-json.ts:38)
- [extensions/openai/openai-codex-cli-auth.ts](/Users/walter/Work/Claw/openclaw/extensions/openai/openai-codex-cli-auth.ts:25)
- [src/agents/cli-credentials.ts](/Users/walter/Work/Claw/openclaw/src/agents/cli-credentials.ts:13)
- [src/commands/doctor-claude-cli.ts](/Users/walter/Work/Claw/openclaw/src/commands/doctor-claude-cli.ts:169)
- [src/plugins/marketplace.ts](/Users/walter/Work/Claw/openclaw/src/plugins/marketplace.ts:28)
- [extensions/ollama/src/setup.ts](/Users/walter/Work/Claw/openclaw/extensions/ollama/src/setup.ts:12)
- [extensions/ollama/src/stream.ts](/Users/walter/Work/Claw/openclaw/extensions/ollama/src/stream.ts:39)

### 10.3 Changelog anchors worth tracking

- `OpenAI Codex/Auth: bridge OpenClaw OAuth profiles into pi auth.json`
  - [CHANGELOG.md](/Users/walter/Work/Claw/openclaw/CHANGELOG.md:4035)
- `Models/CLI: sync auth-profiles credentials into agent auth.json`
  - [CHANGELOG.md](/Users/walter/Work/Claw/openclaw/CHANGELOG.md:3758)
- `read Codex CLI keychain tokens on macOS before falling back to ~/.codex/auth.json`
  - [CHANGELOG.md](/Users/walter/Work/Claw/openclaw/CHANGELOG.md:5666)

## 11. Current Documentation Gaps And Deviations

### 11.1 Pack-local auth layout differs from stock docs

The stock docs describe `~/.openclaw/...` paths. Our pack layout relocates the
state and, in `apr20`, further redirects `auth-profiles.json` through a symlink
into `cred`.

That is an intentional Setpack deviation and should be documented explicitly
where pack layout is described.

### 11.2 The docs do not fully explain the surface split

The current docs describe auth/profile/model behavior in pieces, but do not
present one consolidated explanation of:

- raw config refs
- generated `models.json`
- runtime overlay auth
- live gateway catalog
- onboarding chooser
- control UI label formatting

This file exists partly to cover that gap.

### 11.3 `auth-profiles.json` as primary store is true but incomplete

The docs are broadly right that `auth-profiles.json` is the primary persisted
store. They are incomplete if read literally, because runtime behavior can also
depend on external auth overlays such as `~/.codex/auth.json`.

### 11.4 User-visible naming remains fragmented

There are still separate naming rules for:

- config refs
- aliases
- catalog `name`
- control UI labels
- onboarding option labels

That fragmentation should be treated as an implementation problem rather than a
documentation-only problem.

### 11.5 External homes are under-explained

The docs discuss Codex and Claude reuse in several places, but they do not give
one concise map of which external homes are actually consulted by OpenClaw and
which are merely test-harness artifacts.

For Setpack purposes, it is important to distinguish:

- external homes OpenClaw really reads at runtime
- files the test harness mounts for live testing
- provider services OpenClaw talks to without owning a corresponding home tree

## 12. Next Work

- compare this file against [ModelNames.md](/Users/walter/Work/Claw/setpack/apps/ModelNames.md)
- decide which naming rules should become normative
- decide whether pack policy should explicitly suppress unwanted provider/plugin
  catalog expansion in user-facing pickers
- review how profile-qualified refs should be shown in UI and CLI surfaces
- decide whether generated `auth.json` should also move under pack-managed
  credential indirection
- decide whether Setpack should explicitly manage `CODEX_HOME`, whether it
  should expose a parallel override for Claude state, and which of those
  choices belong in pack bootstrap versus optional expert configuration
