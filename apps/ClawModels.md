# ClawModels

OpenClaw model and provider reference for Setpack work. This document records
how OpenClaw currently represents model refs, provider ids, aliases, generated
state, runtime auth overlays, user-facing labels, and session-level model
selection, with code and documentation anchors for later review.

## 1. Introduction

This file covers general OpenClaw behavior that matters when reasoning about
models, providers, auth-backed provider availability, and user-facing model
selection. It is not the place for Setpack shell wiring, path rewrites, or
pack-bootstrap mechanics except where those directly affect OpenClaw model
behavior.

The main audience is:

1. a power user configuring primary and fallback model sequences
2. a developer reviewing or reworking OpenClaw model/provider/name/display
   handling

The main problem is that OpenClaw exposes several related but different model
surfaces:

- authored config refs
- generated provider state
- persisted auth state
- runtime-only external auth overlays
- live gateway catalog
- control UI labels
- onboarding and configure-time model choices
- session-level runtime overrides

Those surfaces do not currently line up cleanly. This document maps them.

## 2. Scope

This file includes:

- model refs in `openclaw.json`
- generated `models.json`
- `auth-profiles.json` and legacy `auth.json`
- external runtime auth sources such as `~/.codex`
- gateway catalog behavior
- control UI display behavior
- onboarding/default-model chooser behavior
- runtime session override behavior
- local docs, source files, and changelog anchors worth tracking

This file does not try to be:

- the full OpenClaw config reference
- a record of every historical pack-specific misconfiguration

This file does include the Setpack-side conclusions that follow from the
OpenClaw behavior described here, specifically for:

- how model routes should be represented in a pack
- when a pack should or should not carry multiple account paths
- how model credentials should be saved and separated from config

## 3. Reference Map

The quickest accurate mental model is:

1. `openclaw.json` is the authored model-selection surface
2. `models.json` is a generated provider snapshot, not the full live catalog
3. `auth-profiles.json` is the main persisted auth store, but not the only
   runtime auth input
4. external homes such as `~/.codex` and `~/.claude` can influence runtime
   behavior
5. the gateway catalog starts from generated/provider state and then augments it
   through plugin hooks
6. the control UI reformats model entries for display
7. onboarding/configure uses the live catalog, but with separate filtering and
   choice logic
8. a running session can diverge from the configured default model through
   persisted runtime overrides

If a user sees a model in the UI, that does not by itself mean:

- the model is explicitly configured in `openclaw.json`
- the provider appears in `models.json`
- the auth store contains a persisted local profile for that provider

For Setpack, the immediate consequence is:

- authored config should prefer canonical refs over UI-facing names
- pack-local credential design should be based on the real auth source, not on
  what a picker happens to display

## 4. Setpack Decisions

### 4.1 Canonical refs over friendly labels

Setpack should treat the canonical ref as authoritative:

- `provider/model`
- `provider/model@profile`

Friendly labels are useful for display, but not as durable configuration keys.
They are projections assembled by UI and CLI code that can drift over time.

Setpack consequence:

- save and review model configuration in canonical form
- do not treat UI wording as the source of truth
- prefer configuration that remains understandable even if UI labels change

### 4.2 Distinguish provider routes explicitly

When two routes point at a similar model family but use different providers or
auth methods, Setpack should keep that distinction visible instead of hiding it
behind a single family name.

Current preferred wording:

- `anthropic [API]`
- `claude-cli [OAuth]`
- `openai [API]`
- `codex [OAuth]`

These are presentation labels, not replacements for canonical refs. For
example, the display label `claude-cli [OAuth]` still maps to canonical refs
such as `claude-cli/claude-opus-4-6`.

The reason to keep `claude-cli` visible is simple: that is the upstream backend
id OpenClaw actually registers and tests, not a Setpack-local nickname.

Why:

- provider id is operationally meaningful
- auth mode is operationally meaningful
- routing, availability, and fallback behavior can differ even when the model
  family looks similar

Setpack consequence:

- a pack should not blur API and OAuth routes into one undifferentiated
  “Anthropic” or “OpenAI” bucket
- if both routes are present in one pack, they should be presented as separate
  choices with their auth path made obvious

### 4.3 A pack is definitive, not combinatorial

A pack should be a deliberate working set, not a dumping ground for every
possible model account, fallback, or provider permutation that might be usable.

Why:

- too many parallel routes make the pack harder to validate
- duplicated low-tier account permutations create noise without improving
  clarity
- troubleshooting becomes harder when many half-equivalent routes are present

Setpack consequence:

- if two accounts or routes are materially different and both need to be
  preserved, that should be an explicit design choice
- if one provider has multiple accounts, the pack should normally select one
  intended account path rather than carrying all of them by default
- a profile-qualified ref such as `provider/model@profile` should appear only
  when that exact profile choice is part of the pack's intended behavior
- if an account permutation is only “maybe useful later”, it should not be
  included by default in the pack
- if materially different routing matters enough, that may justify a different
  pack rather than more clutter inside one pack

### 4.4 Prefer stable canonical names over aliases

Setpack should not rely on short aliases as a general model-configuration
pattern.

Why:

- aliases add another naming layer on top of already fragmented UI and runtime
  labels
- aliases age badly when providers, auth methods, or preferred routes change
- a long or slightly cryptic canonical name is still more stable than an ad hoc
  short name with shifting meaning

Setpack consequence:

- prefer the canonical ref in config review and documentation
- treat aliases as optional convenience only, not as the primary naming scheme
- avoid introducing new aliases unless they solve a specific recurring problem
  that the canonical ref cannot reasonably handle

### 4.5 Save credentials according to auth type

The credential-storage decision should follow the auth type, not the provider
marketing name.

Static credential paths:

- API keys
- static bearer tokens

Preferred Setpack handling:

- keep them outside the authored model config when possible
- use pack-local credential storage and SecretRef-to-file where supported
- keep those files under pack `cred`, not mixed into versioned config or
  transient runtime state

OAuth credential paths:

- refresh/access token state
- provider-native login artifacts
- external CLI homes such as `.codex` and `.claude`

Preferred Setpack handling:

- do not pretend OAuth behaves like a static API key
- when OpenClaw persists OAuth-bearing `auth-profiles.json`, keep that store
  under pack-managed credential placement rather than leaving it buried in
  generic state
- when a route depends on external CLI homes, either document that dependency
  explicitly or override it deliberately; do not let ambient host state remain
  an invisible dependency

### 4.6 Why `auth-profiles.json` belongs with credentials

OpenClaw treats `auth-profiles.json` as the main persisted auth store, and it
can contain API keys, tokens, and OAuth-bearing profile state.

That makes it credential material, not ordinary runtime noise.

Setpack consequence:

- `auth-profiles.json` should be treated as credential-bearing data
- if it must exist at the agent state path for OpenClaw, it is still reasonable
  to place the real file under pack `cred` and expose it into state by symlink
- this keeps saved credentials with other credential-bearing artifacts instead
  of scattering them across generated runtime trees

### 4.7 Why ambient external homes are not good enough

OpenClaw can reuse external homes such as `~/.codex` and `~/.claude`, but
ambient reuse is not a good long-term Setpack default.

Why:

- it weakens reproducibility
- it hides the real credential dependency
- it makes pack behavior depend on whichever host account happens to be logged
  in

Setpack consequence:

- ambient external-home reuse can be tolerated during exploration
- it should be replaced by explicit documented dependency or explicit override
  when the pack is meant to be validated, moved, or handed to another operator

## 5. User-Facing Model Surfaces

### 5.1 Authored config refs

The main authored surface is the pack-local OpenClaw config file, for example
[apr20 `openclaw.json`](</Users/walter/Work/Claw/Setpacks/openclaw/apr20/openclaw/config/openclaw.json>).

This is where OpenClaw reads:

- `agents.defaults.model.primary`
- `agents.defaults.model.fallbacks`
- `agents.defaults.models`

The authored notation is the raw model ref:

- `provider/model`
- `provider/model@profile`

Examples:

- `openai/gpt-5.4`
- `openai-codex/gpt-5.4`
- `anthropic/claude-opus-4-6`
- `ollama/qwen3.5:latest`
- `google/gemini-2.5-flash@google:paid`

This raw notation is the canonical configuration form. It is more stable and
more precise than any UI display label.

Important limit:

- authored `openclaw.json` is not always the exact runtime-visible model map
- OpenClaw applies config-default normalization after reading the file
- that normalization can synthesize aliases and, in some builds, additional
  allowlist entries

### 5.2 Control UI display labels

The control UI does not simply show raw refs. It reformats catalog entries for
display in the built UI bundle
[index-Bs4iQELM.js](/Users/walter/Work/Claw/Setpacks/openclaw/apr20/openclaw/bundle/node_modules/openclaw/dist/control-ui/assets/index-Bs4iQELM.js:4).

Observed display behavior:

- prefer configured alias when one exists
- otherwise prefer catalog `name`
- otherwise fall back to a provider-disambiguated label
- convert `provider/model` into `model · provider` in some fallback paths
- append provider when names collide

This explains why the UI often shows:

- spaces instead of raw id punctuation
- capitalization not present in the raw id
- a provider suffix such as `· cerebras`

The display label is therefore a UI-layer projection, not a canonical model
identity.

### 5.3 Configured-option labels and default label wrappers

There is a second UI-layer label path for configured options in the settings
and agent views.

In
[agents-utils.ts](/Users/walter/Work/Claw/openclaw/ui/src/ui/views/agents-utils.ts:555),
configured model entries are assembled by iterating the literal
`agents.defaults.models` keys and then applying:

- `alias (provider/model)` when an alias exists
- the raw trimmed key when no alias exists
- `Current (provider/model)` if the current value is not otherwise present

This is a different projection from the catalog-facing chat selector.

Separately, the chat model select state wraps the resolved default model as
`Default (...)` in
[chat-model-select-state.ts](/Users/walter/Work/Claw/openclaw/ui/src/ui/chat-model-select-state.ts:103).

Practical consequence:

- `Default (GPT)` is a UI wrapper over the current default display
- `GPT` can be a configured alias
- `GPT-5.4` can be a catalog or humanized display string for the same or a
  related configured target

Those are different label shapes for related but non-identical surfaces.

Because configured-option labels iterate the literal config keys, malformed
keys are not normalized away at this layer. A quoted or otherwise malformed
model key can therefore surface as a separate configured option unless earlier
validation blocks it.

The more important current finding is that there is a pre-UI mutation step in
OpenClaw defaults handling. In
[defaults.ts](/Users/walter/Work/Claw/openclaw/src/config/defaults.ts:14),
OpenClaw defines built-in alias defaults such as:

- `opus -> anthropic/claude-opus-4-6`
- `sonnet -> anthropic/claude-sonnet-4-6`
- `gpt -> openai/gpt-5.4`

Then, in
[defaults.ts](/Users/walter/Work/Claw/openclaw/src/config/defaults.ts:254),
it walks `agents.defaults.models` and injects those aliases for configured
entries whose `alias` is still undefined.

Practical consequence:

- `models status` can show aliases that do not exist in authored
  `openclaw.json`
- removing empty `alias` fields from config is not enough to suppress them
- any “canonical names only” policy has to account for this runtime defaulting

### 5.4 Onboarding and configure-time chooser

The onboarding/default-model chooser is a separate flow in
[model-picker.ts](/Users/walter/Work/Claw/openclaw/src/flows/model-picker.ts:408).

It uses the live catalog, but then applies additional policy:

- allowlist filtering
- auth checks
- hidden-router filtering
- preferred-provider filtering
- setup and route hints

Its option `label` is the raw `provider/model` key rather than the control UI
friendly label: [model-picker.ts](/Users/walter/Work/Claw/openclaw/src/flows/model-picker.ts:169).

This is one reason the onboarding picker and the control UI picker do not look
the same even when they are drawing from related catalog data.

### 5.5 CLI and diagnostic surfaces

CLI-facing tools such as `openclaw models list`, `openclaw models auth ...`,
doctor commands, and status/reporting flows consume related but not always
identical information.

Important consequence:

- a user can see one naming shape in config
- another in the control UI
- another in onboarding
- another in CLI diagnostics

The naming problem is therefore not limited to the web UI.

The CLI model list also introduces tags such as:

- `default`
- `configured`
- `fallback#N`
- `alias:...`
- `missing`

Those tags come from the model-list row-building path:

- [list.rows.ts](/Users/walter/Work/Claw/openclaw/src/commands/models/list.rows.ts:34)
- [list.registry.ts](/Users/walter/Work/Claw/openclaw/src/commands/models/list.registry.ts:127)
- [list.format.ts](/Users/walter/Work/Claw/openclaw/src/commands/models/list.format.ts:15)

That means CLI output is not just another display skin. It is also exposing a
distinct status vocabulary about configured, resolved, aliased, and unresolved
entries.

## 6. Identity Terms

### 6.1 Provider id

Examples:

- `openai`
- `openai-codex`
- `anthropic`
- `claude-cli`
- `ollama`

This is the provider identifier used in raw model refs, registration logic, and
plugin/provider ownership.

### 6.2 Model id

Examples:

- `gpt-5.4`
- `claude-opus-4-6`
- `qwen3.5:latest`

This is the provider-local model identifier.

### 6.3 Canonical model ref

The canonical authored form is:

- `provider/model`

Examples:

- `openai/gpt-5.4`
- `openai-codex/gpt-5.4`
- `claude-cli/claude-opus-4-6`
- `ollama/qwen3.5:latest`

### 6.4 Profile-qualified model ref

Some refs are further qualified by auth profile:

- `provider/model@profile`

This matters when one provider has multiple auth routes or accounts.

### 6.5 Alias

Aliases live under `agents.defaults.models`. They are user-facing short names
layered onto canonical refs.

An alias is not the same thing as:

- provider id
- model id
- catalog `name`
- control UI display label

### 6.6 Catalog name

Catalog entries also carry a `name`. This is often a more legible label than
the raw model id.

Examples found in bundled catalogs:

- `Qwen3 Coder 480B`
- `Kimi K2.5`
- `GPT-5.4-Mini`

### 6.7 Display label

A display label is the user-facing projection of a model entry after alias and
catalog-name logic have been applied, sometimes with provider disambiguation.

The important rule is:

- do not treat display labels as canonical identities

## 7. Files And Runtime Inputs

### 7.1 Authored config file

The authored configuration surface is `openclaw.json`. In `apr20`, that is
[apr20 `openclaw.json`](</Users/walter/Work/Claw/Setpacks/openclaw/apr20/openclaw/config/openclaw.json>).

This file may be:

- hand-edited
- wizard-written
- normalized or rewritten by OpenClaw flows

### 7.2 Generated `models.json`

OpenClaw writes `models.json` through
[models-config.ts](/Users/walter/Work/Claw/openclaw/src/agents/models-config.ts:138).

In `apr20`, the current file is
[state `models.json`](</Users/walter/Work/Claw/Setpacks/openclaw/apr20/openclaw/state/agents/main/agent/models.json>).

Observed current `apr20` providers:

- `openai-codex`
- `codex`
- `ollama`

Observed current omissions:

- no direct `anthropic`
- no direct `google`

This file is not the full live catalog. It is a generated provider snapshot
used by the underlying registry path.

### 7.3 Persisted `auth-profiles.json`

The primary persisted auth surface is `auth-profiles.json`. OpenClaw documents
that in [wizard.md](/Users/walter/Work/Claw/openclaw/docs/reference/wizard.md:66).

In `apr20`, the state path
[state `auth-profiles.json`](</Users/walter/Work/Claw/Setpacks/openclaw/apr20/openclaw/state/agents/main/agent/auth-profiles.json>)
is a symlink to the pack-local cred path
[cred `auth-profiles.json`](</Users/walter/Work/Claw/Setpacks/openclaw/apr20/openclaw/cred/agents/main/agent/auth-profiles.json>).

Observed current `apr20` state:

- the persisted file exists
- the persisted `profiles` map is empty

### 7.4 Legacy `auth.json`

OpenClaw still carries a compatibility path for `auth.json` because the older
Pi/model-registry path expects it. The bridge is
[pi-auth-json.ts](/Users/walter/Work/Claw/openclaw/src/agents/pi-auth-json.ts:38).

Its explicit role:

- OpenClaw stores credentials in `auth-profiles.json`
- the registry path still expects `auth.json`
- OpenClaw can bridge credentials into `agentDir/auth.json`

In `apr20`, `auth.json` is currently absent until something writes it.

### 7.5 Runtime-only auth overlays

Persisted auth state is not the whole story. OpenClaw overlays external auth
profiles into the in-memory auth view through
[external-auth.ts](/Users/walter/Work/Claw/openclaw/src/agents/auth-profiles/external-auth.ts:63).

For OpenAI Codex, the source is the Codex CLI auth file read by
[openai-codex-cli-auth.ts](/Users/walter/Work/Claw/openclaw/extensions/openai/openai-codex-cli-auth.ts:25).

Default resolution:

- use `CODEX_HOME` if set
- otherwise use `~/.codex`
- read `auth.json` there

That is one direct reason the UI can work even when persisted
`auth-profiles.json` is empty.

### 7.6 Credential precedence and SecretRef applicability

The newer credential docs make an important distinction that the older model
notes did not capture clearly enough.

For provider auth resolution, OpenClaw documents the standard order as:

1. `auth-profiles.json`
2. environment variables
3. `models.providers.*.apiKey`

Reference:
[configuration-reference.md](/Users/walter/Work/Claw/openclaw/docs/gateway/configuration-reference.md:2223).

For static credentials, OpenClaw also documents SecretRef support inside
`auth-profiles.json`:

- `api_key` profiles can use `keyRef`
- `token` profiles can use `tokenRef`

Reference:
[authentication.md](/Users/walter/Work/Claw/openclaw/docs/gateway/authentication.md:79).

The important limit is that OAuth-mode auth profiles do not support SecretRef
credential fields. That restriction is both documented and enforced in the
unsupported-surface policy:

- [authentication.md](/Users/walter/Work/Claw/openclaw/docs/gateway/authentication.md:82)
- [unsupported-surface-policy.ts](/Users/walter/Work/Claw/openclaw/src/secrets/unsupported-surface-policy.ts:5)

Practical consequence:

- SecretRef-to-file is a good fit for static API keys and static bearer tokens
- SecretRef is not the answer for OAuth refresh/access-token state
- OAuth remains tied to provider-native login flows, external CLI homes, or
  persisted OpenClaw auth stores

### 7.7 Generated residues and audit coverage

`models.json` is generated, but it is still a credential-relevant surface.

OpenClaw's secret audit explicitly checks for:

- plaintext values in `openclaw.json`
- plaintext values in `auth-profiles.json`
- plaintext values in `.env`
- plaintext sensitive provider residues in generated `models.json`
- precedence shadowing where `auth-profiles.json` wins over `openclaw.json`
  refs

Reference:
[secrets.md](/Users/walter/Work/Claw/openclaw/docs/gateway/secrets.md:449).

This matters because `models.json` can look like harmless generated state while
still containing security-relevant residues. It should be treated as generated,
inspectable runtime state rather than dismissed as an internal cache.

## 8. External Homes And Non-Pack Inputs

### 8.1 `.codex`

`~/.codex` is not an OpenClaw-owned state directory. It is a Codex CLI home
that OpenClaw knows how to reuse.

Observed OpenClaw handling:

- reads OAuth from `CODEX_HOME/auth.json` or `~/.codex/auth.json`
- uses the same home path in CLI credential helpers
- test tooling also knows about `~/.codex/auth.json` and `~/.codex/config.toml`

Source anchors:

- [extensions/openai/openai-codex-cli-auth.ts](/Users/walter/Work/Claw/openclaw/extensions/openai/openai-codex-cli-auth.ts:25)
- [src/agents/cli-credentials.ts](/Users/walter/Work/Claw/openclaw/src/agents/cli-credentials.ts:138)
- [docs/help/testing.md](/Users/walter/Work/Claw/openclaw/docs/help/testing.md:643)

Conclusions:

- entries in `~/.codex` can pre-date OpenClaw
- runtime behavior can inherit from that pre-existing state
- `CODEX_HOME` is a real override point, not an incidental environment variable

### 8.2 `.claude` And `.claude.json*`

Observed OpenClaw handling:

- reads Claude CLI credentials from `~/.claude/.credentials.json`
- doctor/workspace health logic expects `~/.claude/projects/...`
- plugin tooling looks at `~/.claude/plugins/known_marketplaces.json`
- test harness documentation mentions `.claude.json`,
  `~/.claude/.credentials.json`, `~/.claude/settings.json`, and
  `~/.claude/settings.local.json`
- Claude CLI backend handling explicitly clears `CLAUDE_CONFIG_DIR` from child
  environments

Source anchors:

- [src/agents/cli-credentials.ts](/Users/walter/Work/Claw/openclaw/src/agents/cli-credentials.ts:13)
- [src/commands/doctor-claude-cli.ts](/Users/walter/Work/Claw/openclaw/src/commands/doctor-claude-cli.ts:169)
- [src/plugins/marketplace.ts](/Users/walter/Work/Claw/openclaw/src/plugins/marketplace.ts:28)
- [extensions/anthropic/cli-shared.ts](/Users/walter/Work/Claw/openclaw/extensions/anthropic/cli-shared.ts:57)
- [extensions/anthropic/openclaw.plugin.json](/Users/walter/Work/Claw/openclaw/extensions/anthropic/openclaw.plugin.json:8)
- [extensions/anthropic/index.test.ts](/Users/walter/Work/Claw/openclaw/extensions/anthropic/index.test.ts:19)
- [docs/help/testing.md](/Users/walter/Work/Claw/openclaw/docs/help/testing.md:645)
- [docs/cli/plugins.md](/Users/walter/Work/Claw/openclaw/docs/cli/plugins.md:136)

Conclusions:

- OpenClaw can reuse substantial host Claude state without owning it
- `CLAUDE_CONFIG_DIR` is relevant when reasoning about reproducibility
- `.claude.json*` appears to matter mainly in test/live-harness contexts rather
  than as the main OpenClaw auth store

### 8.3 `.ollama`

Observed OpenClaw handling:

- OpenClaw supports Ollama as a provider
- the main assumptions are a reachable Ollama host, a base URL, and discovered
  model inventory
- the default local URL is `http://127.0.0.1:11434`
- provider config and discovery center on `models.providers.ollama`,
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

Conclusion:

- for now, Ollama should be treated as a host-local service and model-inventory
  source, not as a pack-managed OpenClaw home tree

## 9. Implementation Paths

### 9.1 Generated provider snapshot path

`models.json` is generated by
[ensureOpenClawModelsJson](/Users/walter/Work/Claw/openclaw/src/agents/models-config.ts:138).

That path:

1. resolves config input
2. computes a fingerprint
3. reads any existing `models.json`
4. plans changes
5. writes or reuses the file

This is a generated-state path, not a user-facing catalog path.

### 9.2 Live model catalog path

The live gateway catalog comes from
[server-model-catalog.ts](/Users/walter/Work/Claw/openclaw/src/gateway/server-model-catalog.ts:17),
which delegates to
[loadModelCatalog](/Users/walter/Work/Claw/openclaw/src/agents/model-catalog.ts:83).

That path:

1. ensures `models.json` exists
2. loads the underlying registry from `models.json`
3. augments the entries with provider plugin contributions through
   [provider-runtime.ts](/Users/walter/Work/Claw/openclaw/src/plugins/provider-runtime.ts:890)

This is why the UI can show more models than `models.json` contains.

### 9.3 Runtime config-default mutation path

OpenClaw does not stop at “read config, then display config”. It also applies
defaults logic that can mutate the effective model surface after load.

Confirmed current mutation paths:

- default alias synthesis in
  [defaults.ts](/Users/walter/Work/Claw/openclaw/src/config/defaults.ts:254)
- Claude CLI allowlist expansion in the installed `apr20` bundle's
  [config-defaults-tnqStTSx.js](/Users/walter/Work/Claw/Setpacks/openclaw/apr20/openclaw/bundle/node_modules/openclaw/dist/config-defaults-tnqStTSx.js:140)

The alias synthesis is an upstream OpenClaw behavior.

The Claude CLI allowlist expansion was observed in the installed `apr20`
bundle before Setpack patched it. The Setpack-side mitigation now lives in
[setpack-openclaw.sh](/Users/walter/Work/Claw/setpack/scripts/lib/setpack-openclaw.sh:101),
which patches the installed bundle after `npm install` so the effective
allowlist stays explicit in `openclaw.json`.

### 9.4 `catalog.run` versus `discovery.run`

OpenClaw normalizes these through one selector in
[provider-discovery.ts](/Users/walter/Work/Claw/openclaw/src/plugins/provider-discovery.ts:14),
which uses `provider.catalog ?? provider.discovery`.

Observed practical distinction:

- `catalog.run`
  - provider can materialize itself when auth or runtime conditions are met
- `discovery.run`
  - provider probes ambient runtime state and synthesizes config from what is
    reachable

Examples:

- `openai-codex` `catalog.run`:
  [openai-codex-provider-C_KMICUl.js](/Users/walter/Work/Claw/Setpacks/openclaw/apr20/openclaw/bundle/node_modules/openclaw/dist/openai-codex-provider-C_KMICUl.js:216)
- `codex` `catalog.run`:
  [provider-CO11jseK.js](/Users/walter/Work/Claw/Setpacks/openclaw/apr20/openclaw/bundle/node_modules/openclaw/dist/provider-CO11jseK.js:58)
- `ollama` `discovery.run`:
  [provider-discovery.js](/Users/walter/Work/Claw/Setpacks/openclaw/apr20/openclaw/bundle/node_modules/openclaw/dist/extensions/ollama/provider-discovery.js:82)

### 9.5 Legacy bridge path

The old Pi/model-registry path still depends on `auth.json`, which is why
OpenClaw still contains:

- auth-profile to `auth.json` bridging
- registry-oriented compatibility code
- changelog entries about syncing credentials into `auth.json`

This is one reason model/auth handling remains harder to reason about than it
should be.

## 10. Runtime Selection And Overrides

### 10.1 Why overrides matter

The configured default model and the model actually used by a running session
are not necessarily the same thing.

The important distinction is between:

1. configured default model order
2. allowed fallback chain
3. live session override state
4. auth-profile override state

If only the config is inspected, runtime behavior can be misread.

### 10.2 What the override discussion means

The earlier override discussion refers to persisted per-session runtime state
such as:

- `providerOverride`
- `modelOverride`
- `modelOverrideSource`
- `authProfileOverride`
- `authProfileOverrideSource`

The relevant source paths are:

- [sessions/model-overrides.ts](/Users/walter/Work/Claw/openclaw/src/sessions/model-overrides.ts:1)
- [agent-runner-execution.ts](/Users/walter/Work/Claw/openclaw/src/auto-reply/reply/agent-runner-execution.ts:123)

The key point is that a session can continue running on an automatically
selected model even after the configured default elsewhere has changed.

`modelOverrideSource = auto` means:

- the model switch was system-driven rather than an explicit user command
- the running session may have been moved because of failover, provider
  availability, or other automatic selection logic
- later turns can inherit that persisted override state

This is operationally important because it means:

- the default config does not by itself tell you what model is actually active
- diagnostics need both config and session state
- a failover can become durable session state rather than a one-shot in-memory
  retry

### 10.3 Why this matters for users and developers

For users:

- a session can appear to “stick” to a model they did not manually select

For developers:

- model-selection logic has to be audited across config load, fallback,
  auth-profile selection, session persistence, and UI reporting

This area is under-documented and deserves its own deeper review.

## 11. Observed Behaviors And Likely Explanations

### 11.1 Why the UI list is larger than `models.json`

Because `models.json` is only the generated provider snapshot. The live gateway
catalog starts there and then adds plugin-supplied model entries through
[augmentModelCatalogWithProviderPlugins](/Users/walter/Work/Claw/openclaw/src/plugins/provider-runtime.ts:890).

### 11.2 Why `models.json` contains `codex`, `openai-codex`, and `ollama`

Those providers currently participate in the implicit provider resolution path
through `catalog` or `discovery` hooks.

### 11.3 Why `anthropic` and `google` are absent from `models.json`

The current evidence points to an OpenClaw implementation distinction:

- those providers can be active and usable
- but they do not currently appear in the same implicit provider persistence
  path used to build `models.json`

This should not be explained as an API limitation on Anthropic or Google.

### 11.4 Why the UI can work with an empty persisted `auth-profiles.json`

Because runtime auth can come from more than one place:

- runtime-only external auth overlays
- environment credentials
- `models.json`-backed provider data in some probe paths

Reference:
[authentication.md](/Users/walter/Work/Claw/openclaw/docs/gateway/authentication.md:97).

### 11.5 Why onboarding differs from the control UI

Because onboarding is a curated selection flow over the live catalog, while the
control UI is a display transform over the already-built gateway catalog.

### 11.6 Why aliases can appear when config has none

Because OpenClaw injects default aliases at config-default time rather than
requiring them to be authored explicitly.

Confirmed current examples:

- `anthropic/claude-opus-4-6 -> opus`
- `openai/gpt-5.4 -> gpt`

Those come from
[DEFAULT_MODEL_ALIASES in defaults.ts](/Users/walter/Work/Claw/openclaw/src/config/defaults.ts:14)
and are applied by
[applyModelDefaults in defaults.ts](/Users/walter/Work/Claw/openclaw/src/config/defaults.ts:254).

This means:

- `models status` aliases are not proof that `openclaw.json` authored them
- pack review must distinguish authored aliases from synthesized aliases
- a strict canonical-only policy needs either upstream change or local patching

### 11.7 Why extra Claude CLI entries appeared beyond the pack allowlist

In the installed `apr20` bundle, OpenClaw's anthropic config-default logic
expanded the effective allowlist whenever:

- auth mode resolved to OAuth
- Claude CLI model selection was in use

The original bundled logic used
`CLAUDE_CLI_DEFAULT_ALLOWLIST_REFS` to add:

- `claude-cli/claude-sonnet-4-6`
- `claude-cli/claude-opus-4-5`
- `claude-cli/claude-sonnet-4-5`
- `claude-cli/claude-haiku-4-5`

That behavior was observed in the installed bundle at
[config-defaults-tnqStTSx.js](/Users/walter/Work/Claw/Setpacks/openclaw/apr20/openclaw/bundle/node_modules/openclaw/dist/config-defaults-tnqStTSx.js:140)
before the Setpack-local patch was applied.

Current `apr20` status:

- the bundle has been patched so the effective allowlist remains explicit
- `openclaw models status --json` now reports only the five configured `apr20`
  entries
- the Setpack install path applies the same mitigation for future packs

### 11.8 Why apparently duplicate Claude entries can both be valid

Two entries can look similar in humanized form while still being meaningfully
different because provider identity is part of the canonical ref.

Example pattern:

- `anthropic/claude-opus-4-6`
- `claude-cli/claude-opus-4-6`

These are not duplicates in the canonical configuration sense. They represent
different provider paths, different auth modes, and potentially different
runtime behavior.

The confusion comes from label projection. Once the provider is humanized,
suppressed, or shown only as a suffix, two distinct canonical refs can look
like variants of the same thing instead of distinct execution routes.

### 11.9 Why `configured,missing` style entries appear

The CLI list row builder marks a configured entry as `missing` when the config
entry exists but OpenClaw cannot resolve it to a current model object in the
registry path:

- if no model resolves, the row is emitted with `missing: true`
- if a model resolves but availability is limited, the row can still be present
  with a different availability state

Reference:
[list.registry.ts](/Users/walter/Work/Claw/openclaw/src/commands/models/list.registry.ts:145).

This explains why stale, malformed, forward-compat, or provider-incomplete
entries can remain visible as configured rows instead of disappearing.

## 12. Gaps, Likely Mistakes, And Improvement Targets

### 12.1 Documentation gaps

The stock docs describe many pieces of this system, but not one consolidated
map of:

- raw config refs
- generated `models.json`
- persisted `auth-profiles.json`
- legacy `auth.json`
- external runtime auth overlays
- gateway catalog augmentation
- control UI label formatting
- onboarding chooser logic
- session-level runtime overrides

This document exists partly because that map is missing elsewhere.

### 12.2 User-facing naming fragmentation

There are still separate naming rules for:

- config refs
- aliases
- catalog `name`
- control UI labels
- onboarding option labels
- CLI-facing diagnostics

That fragmentation looks like a real implementation problem, not merely a docs
problem.

### 12.3 External homes are under-explained

The docs discuss Codex and Claude reuse in several places, but they do not
cleanly distinguish:

- external homes OpenClaw reads at runtime
- files only mounted in the test harness
- provider services OpenClaw talks to without owning a corresponding home tree

### 12.4 Generated-state versus live-catalog confusion

The distinction between generated `models.json` and the much broader live
gateway catalog is easy to miss and should probably be made much more explicit
in code comments, docs, or diagnostics.

### 12.5 Likely implementation weaknesses

These are not all confirmed bugs, but they are credible review targets:

- direct providers such as `anthropic` and `google` being absent from
  `models.json` while still being usable elsewhere creates a confusing mental
  model
- default alias synthesis makes “configured” model naming diverge from authored
  config unless the reader knows about config-default mutation
- in some installed builds, Claude CLI allowlist expansion widens the effective
  allowlist beyond authored config unless the bundle is patched
- runtime-only auth overlays make behavior harder to inspect from pack-local
  files alone
- SecretRef support is now fairly strong for static credentials, but OAuth
  still sits on a separate path, which makes the overall credential story feel
  split in two
- legacy `auth.json` compatibility keeps older assumptions alive inside the
  model/auth path
- user-facing model labels are assembled differently across UI, onboarding, and
  other surfaces
- provider-distinct routes can collapse into deceptively similar humanized
  labels
- configured-but-unresolved rows remain visible, which is operationally useful
  but easily reads as picker noise without stronger explanation
- session-level automatic override persistence is powerful, but not adequately
  surfaced to users

### 12.6 Possible improvements

- define one canonical identity vocabulary and make every UI surface respect it
- distinguish display label from canonical model ref everywhere
- make provider-distinct routes visibly distinct when names would otherwise
  collide
- expose clearer diagnostics for:
  - persisted auth
  - runtime overlay auth
  - generated provider snapshot
  - live catalog source
  - session override state
- reduce legacy `auth.json` dependence if the underlying registry path can be
  modernized
- make provider/plugin ownership more transparent when augmented catalog models
  are shown

## 13. Further Investigation

The next worthwhile investigations are:

- normative rules for user-facing naming and label generation
- clearer representation of profile-qualified refs in UI and CLI surfaces
- whether provider availability should be represented more consistently between
  `models.json`, gateway catalog, and onboarding
- whether Setpack should explicitly manage `CODEX_HOME` and related external
  home overrides
- whether legacy bridging into `auth.json` should remain part of the long-term
  architecture
- how aggregator-style providers should fit this picture

That last point matters for future work around providers or services that expose
many third-party models behind one surface. Ollama already acts like a local
inventory source, and services such as OpenRouter raise similar questions from
the opposite direction. It will be worth reviewing whether OpenClaw should
borrow, imitate, or delegate more of its provider/model presentation model to
that style of system.

### 13.1 Concrete review targets

If this file is used as a cleanup guide, the most concrete next review targets
are:

1. unify user-facing naming rules across config, onboarding, UI, and CLI
2. make the source of each visible model entry inspectable:
   generated snapshot, plugin augmentation, external home, env, or static config
3. decide whether `models.json` should continue acting as both generated cache
   and credential-adjacent runtime input
4. reduce or retire `auth.json` bridging if the remaining registry path can be
   modernized
5. surface session override state more clearly in status and UI flows
6. decide whether external homes such as `.codex` and `.claude` should stay
   ambient or become explicitly managed runtime inputs
7. decide how configured-but-unresolved entries should be shown in pickers and
   status views
8. decide whether any narrow alias policy is still worth keeping after the
   current preference for canonical refs

## 14. References

### 14.1 Documentation

- [docs/reference/wizard.md](/Users/walter/Work/Claw/openclaw/docs/reference/wizard.md:36)
- [docs/start/wizard-cli-reference.md](/Users/walter/Work/Claw/openclaw/docs/start/wizard-cli-reference.md:133)
- [docs/concepts/oauth.md](/Users/walter/Work/Claw/openclaw/docs/concepts/oauth.md:58)
- [docs/concepts/model-failover.md](/Users/walter/Work/Claw/openclaw/docs/concepts/model-failover.md:64)
- [docs/help/faq.md](/Users/walter/Work/Claw/openclaw/docs/help/faq.md:1398)
- [docs/gateway/configuration-reference.md](/Users/walter/Work/Claw/openclaw/docs/gateway/configuration-reference.md:3296)
- [docs/gateway/authentication.md](/Users/walter/Work/Claw/openclaw/docs/gateway/authentication.md:74)
- [docs/gateway/secrets.md](/Users/walter/Work/Claw/openclaw/docs/gateway/secrets.md:449)
- [docs/help/testing.md](/Users/walter/Work/Claw/openclaw/docs/help/testing.md:643)
- [docs/cli/plugins.md](/Users/walter/Work/Claw/openclaw/docs/cli/plugins.md:136)
- [docs/gateway/local-models.md](/Users/walter/Work/Claw/openclaw/docs/gateway/local-models.md:14)

### 14.2 Source

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
- [extensions/anthropic/cli-shared.ts](/Users/walter/Work/Claw/openclaw/extensions/anthropic/cli-shared.ts:4)
- [extensions/anthropic/openclaw.plugin.json](/Users/walter/Work/Claw/openclaw/extensions/anthropic/openclaw.plugin.json:8)
- [extensions/anthropic/index.test.ts](/Users/walter/Work/Claw/openclaw/extensions/anthropic/index.test.ts:19)
- [extensions/ollama/src/setup.ts](/Users/walter/Work/Claw/openclaw/extensions/ollama/src/setup.ts:12)
- [extensions/ollama/src/stream.ts](/Users/walter/Work/Claw/openclaw/extensions/ollama/src/stream.ts:39)

### 14.3 Changelog

- `OpenAI Codex/Auth: bridge OpenClaw OAuth profiles into pi auth.json`
  - [CHANGELOG.md](/Users/walter/Work/Claw/openclaw/CHANGELOG.md:4035)
- `Models/CLI: sync auth-profiles credentials into agent auth.json`
  - [CHANGELOG.md](/Users/walter/Work/Claw/openclaw/CHANGELOG.md:3758)
- `read Codex CLI keychain tokens on macOS before falling back to ~/.codex/auth.json`
  - [CHANGELOG.md](/Users/walter/Work/Claw/openclaw/CHANGELOG.md:5666)
