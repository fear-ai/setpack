# ModelNames

OpenClaw model naming note covering canonical model ids, aliases, provider and
profile distinctions, picker labels, and runtime model-selection behavior.

This note traces the current OpenClaw model labels, canonical names, aliases, and where they are coming from.

It stays focused on naming, picker interpretation, aliasing, and runtime model
selection rather than general application behavior.

## 1. Summary

The model picker appears to be showing a mix of:

1. UI wrapper labels like `Default (...)`
2. custom aliases from config, like `GPT`
3. canonical model ids, like `openai/gpt-5.4`
4. configured or allowed provider inventory entries, including some `configured,missing` variants

## 2. Current Primary And Fallback Settings

Source: `/Users/walter/Work/Claw/Setpacks/openclaw/today/openclaw/config/openclaw.json`

```json
{
  "primary": "openai/gpt-5.4",
  "fallbacks": [
    "ollama/qwen3.5:latest",
    "anthropic/claude-opus-4-6",
    "claude-cli/claude-opus-4-6"
  ]
}
```

Interpretation:

- Current primary/default model is `openai/gpt-5.4`
- Fallback #1 is `ollama/qwen3.5:latest`
- Fallback #2 is `anthropic/claude-opus-4-6`
- Fallback #3 is `claude-cli/claude-opus-4-6`

## 3. Current Alias Map

Source: `agents.defaults.models` in the same config file.

```json
{
  "openai/gpt-5.4": { "alias": "GPT" },
  "openai-codex/gpt-5.4": {},
  "\"openai-codex/gpt-5.4\"": { "alias": "codex" },
  "ollama/qwen3.5:latest": {},
  "claude-cli/claude-opus-4-6": { "alias": "opus" },
  "claude-cli/claude-sonnet-4-6": {},
  "claude-cli/claude-opus-4-5": {},
  "claude-cli/claude-sonnet-4-5": {},
  "claude-cli/claude-haiku-4-5": {}
}
```

## 4. Visible Picker Entry Mapping

### 4.1 `Default (GPT)`

- `Default` comes from the UI showing the current primary model
- `(GPT)` comes from the alias on `openai/gpt-5.4`

Underlying source:

- primary: `openai/gpt-5.4`
- alias: `GPT`

### 4.2 `GPT`

- explicit alias from config
- source model: `openai/gpt-5.4`

### 4.3 `GPT-5.4`

- humanized or canonical display form of `openai/gpt-5.4`

### 4.4 `qwen3.5:latest`

- canonical Ollama model id shown by the provider inventory
- source: fallback #1 and Ollama model discovery

### 4.5 `Claude Opus 4.6`

This could be shown as a humanized label for one of two configured models:

- `anthropic/claude-opus-4-6` (Anthropic API path)
- `claude-cli/claude-opus-4-6` (Claude Code / Claude CLI path)

At the moment both exist, but only the Claude CLI one has an explicit alias:

- `claude-cli/claude-opus-4-6` -> alias `opus`

### 4.6 `claude-sonnet-4-6`, `claude-opus-4-5`, `claude-sonnet-4-5`, `claude-haiku-4-5`

These came from Claude CLI provider configuration and inventory exposure.

Current state from `openclaw models list`:

- `claude-cli/claude-sonnet-4-6` -> configured
- `claude-cli/claude-opus-4-5` -> configured,missing
- `claude-cli/claude-sonnet-4-5` -> configured,missing
- `claude-cli/claude-haiku-4-5` -> configured,missing

Interpretation:

- they are in the configured/allowed set
- some are not currently fully available, so they show as `configured,missing`
- they are still eligible to appear in a model picker/catalog UI

## 5. Trace Of `codex`

### 5.1 Current Finding

There is a real `openai-codex/gpt-5.4` entry, but the alias `codex` is attached to a second key that includes literal quotes:

```json
"openai-codex/gpt-5.4": {}
"\"openai-codex/gpt-5.4\"": { "alias": "codex" }
```

That means the config currently contains:

1. the normal model key: `openai-codex/gpt-5.4`
2. a second malformed or quoted-string key: `"openai-codex/gpt-5.4"`

This is why `openclaw models list` shows both:

- `openai-codex/gpt-5.4` -> configured
- `"openai-codex/gpt-5.4"` -> configured,missing

### 5.2 Timeline Finding For `codex`

The `codex` alias predates the Claude CLI work in this session.

Evidence:

- present in `openclaw.json.bak.4` from `2026-04-13 17:45`
- present in `openclaw.json.bak.3` from `2026-04-13 19:32`
- present in `openclaw.json.bak.2` from `2026-04-13 19:32`
- present in `openclaw.json.bak.1` from `2026-04-13 20:13`
- present in current `openclaw.json`

So:

- `codex` was **not created** by the recent Claude setup
- it was already in the config before today’s later changes
- its alias is attached to the quoted/malformed duplicate key, not the clean canonical key

### 5.3 Best Explanation For `codex`

Most likely this alias came from an earlier config write that accidentally stored the model id with quotes included in the key name.

That would explain:

- why `codex` exists as an alias
- why the clean `openai-codex/gpt-5.4` entry has no alias
- why a weird duplicate `"openai-codex/gpt-5.4"` appears as `configured,missing`

## 6. Trace Of `opus`

### 6.1 Current Finding

`opus` is attached to:

```json
"claude-cli/claude-opus-4-6": { "alias": "opus" }
```

This is clean and not malformed.

### 6.2 Timeline Finding For `opus`

`opus` did **not** exist in the older backups before Claude CLI setup.

Evidence:

- `openclaw.json.bak.4` at `17:45` has no `claude-cli/*` entries and no `opus` alias
- `openclaw.json.bak.3` at `19:32` has no `claude-cli/*` entries and no `opus` alias
- `openclaw.json.bak.2` at `19:32` has no `claude-cli/*` entries and no `opus` alias
- `openclaw.json.bak.1` at `20:13` still has no `claude-cli/*` entries and no `opus` alias
- current `openclaw.json.bak` and current `openclaw.json` do include `claude-cli/*` entries and `alias: "opus"`

### 6.3 Best Explanation For `opus`

This alias was introduced by the Claude CLI auth step:

```bash
openclaw models auth login --provider anthropic --method cli
```

That command reported:

- auth profile created: `anthropic:claude-cli (claude-cli/oauth)`
- default model available: `claude-cli/claude-sonnet-4-6`
- migrated allowlist entries including Claude CLI models

After that step, the config began containing:

- `claude-cli/claude-opus-4-6` with alias `opus`
- other Claude CLI model entries

So `opus` appears to be a new alias created by the Claude CLI provider setup flow.

## 7. Anthropic API Versus Claude CLI Provider Findings

### 7.1 Anthropic API Path

From auth status:

- provider: `anthropic`
- auth type: static API key / token-backed static profile
- model catalog available through `openclaw models list --provider anthropic --all`

Examples available:

- `anthropic/claude-opus-4-6`
- `anthropic/claude-sonnet-4-6`
- many historical and variant Claude models

### 7.2 Claude CLI Path

From auth status:

- provider: `claude-cli`
- profile: `anthropic:claude-cli`
- auth type: OAuth

Configured Claude CLI models currently exposed:

- `claude-cli/claude-opus-4-6`
- `claude-cli/claude-sonnet-4-6`
- `claude-cli/claude-opus-4-5`
- `claude-cli/claude-sonnet-4-5`
- `claude-cli/claude-haiku-4-5`

## 8. Current Model Inventory Snapshot

From `openclaw models list`:

- `openai/gpt-5.4` -> default, configured, alias `GPT`
- `ollama/qwen3.5:latest` -> fallback #1, configured
- `anthropic/claude-opus-4-6` -> fallback #2
- `claude-cli/claude-opus-4-6` -> fallback #3, configured, alias `opus`
- `openai-codex/gpt-5.4` -> configured
- `"openai-codex/gpt-5.4"` -> configured,missing
- `claude-cli/claude-sonnet-4-6` -> configured
- `claude-cli/claude-opus-4-5` -> configured,missing
- `claude-cli/claude-sonnet-4-5` -> configured,missing
- `claude-cli/claude-haiku-4-5` -> configured,missing

## 9. Conclusions

### 9.1 Stable Findings

- `GPT` is a real alias from config for `openai/gpt-5.4`
- `Default (GPT)` is almost certainly the UI combining current default + alias
- `qwen3.5:latest` is a real fallback model id from Ollama
- `anthropic/claude-opus-4-6` is a real Anthropic API fallback model
- `claude-cli/claude-opus-4-6` is a real Claude CLI fallback model with alias `opus`

### 9.2 `codex` Finding

- `codex` exists because of a malformed quoted config key
- the alias is on `"openai-codex/gpt-5.4"`, not on the clean model key
- this likely explains duplicate or confusing picker entries

### 9.3 `opus` Finding

- `opus` was introduced by the Claude CLI setup flow
- it is attached cleanly to `claude-cli/claude-opus-4-6`
- it is newer than the older `GPT` and `codex` alias entries

## 10. Auto-Switching And Runtime Model-Selection Points

The model picker, the configured default, and the live session model are related but not identical concepts.

### 10.1 Default Versus Live Session Model

OpenClaw can run a session on a model that differs from the current agent default.

Observed behavior later in this review stream:

- agent default model was `claude-opus-4-6`
- live main-session model was `openai/gpt-5.4`
- session state carried:
  - `providerOverride = openai`
  - `modelOverride = gpt-5.4`
  - `modelOverrideSource = auto`
  - `authProfileOverride = openai:default`
  - `authProfileOverrideSource = auto`

Interpretation:

- the session had been automatically moved or pinned onto `openai/gpt-5.4`
- this was not a manual `/model` change
- later turns started from the persisted session override rather than the current agent default

### 10.2 Meaning Of `modelOverrideSource = auto`

`auto` indicates a system-driven model selection outcome rather than an explicit user-driven switch.

Practical implications:

- a session can keep running on an automatically selected model after defaults change elsewhere
- inspecting only the current config default is not enough to know what model a session is actually using
- runtime diagnosis has to look at both default config and persisted session state

### 10.3 Fallback And Persistence Implications

OpenClaw persists fallback-owned override fields before retrying a model handoff.
That means a failover decision can become visible as durable session state, not just an in-memory retry detail.

This matters for design because a controller or diagnostic tool needs to distinguish:

1. configured default model order
2. allowed fallback chain
3. live session override state
4. auth-profile override state

### 10.4 Notification Implication

OpenClaw does not appear to expose a simple built-in user-notification toggle for automatic model switches.
Observed operator paths are instead:

- inspect current live model via status/session state
- use logs or diagnostics for runtime observation
- use custom hooks or watcher logic if explicit notifications are desired

## 11. Suggested Cleanup Targets Later

Not acting yet, just documenting likely cleanup targets.

1. Remove or repair the malformed quoted key:
   - `"openai-codex/gpt-5.4"`
2. Decide whether the picker should expose both:
   - `anthropic/claude-opus-4-6`
   - `claude-cli/claude-opus-4-6`
3. Decide whether to keep or hide the `configured,missing` Claude CLI variants:
   - `claude-opus-4-5`
   - `claude-sonnet-4-5`
   - `claude-haiku-4-5`
4. Decide whether the aliases should stay as:
   - `GPT`
   - `codex`
   - `opus`

Until then, the picker is behaving consistently with the current config, even if the list is a bit messy.
