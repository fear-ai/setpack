# Claw Info

Sanitized inventory of the observed local OpenClaw environment: current files,
paths, versions, command resolution, and runtime surfaces. This file is
descriptive rather than architectural.

## 1. Scope

This file records what exists now on the observed machine. The tracked copy is
sanitized for source control.

## 2. Inventory

The sections below are organized by current source location and current runtime surface.

## 3. `~/.openclaw-repo/openclaw.json`

### 3.1 Meta and Wizard

- `meta.lastTouchedVersion`: `2026.2.25`
- `meta.lastTouchedAt`: `2026-02-26T08:56:23.364Z`
- `wizard.lastRunAt`: `2026-02-26T08:56:23.350Z`
- `wizard.lastRunVersion`: `2026.2.25`
- `wizard.lastRunCommand`: `configure`
- `wizard.lastRunMode`: `local`

### 3.2 Browser, Auth, and Model Defaults

- `browser.enabled`: `false`
- auth profiles declared in `openclaw.json`:
  - `anthropic:anthropic` -> `provider=anthropic`, `mode=token`
  - `openai:api-key` -> `provider=openai`, `mode=api_key`
  - `openai-codex:codex-cli` -> `provider=openai-codex`, `mode=token`
  - `google:free` -> `provider=google`, `mode=api_key`
  - `google:paid` -> `provider=google`, `mode=api_key`
  - `openai-codex:default` -> `provider=openai-codex`, `mode=oauth`
- auth order:
  - `openai-codex`: `openai-codex:default`, `openai-codex:codex-cli`
- `agents.defaults.model.primary`: `openai-codex/gpt-5.3-codex-spark`
- `agents.defaults.model.fallbacks`:
  - `openai-codex/gpt-5.3-codex`
  - `google/gemini-2.5-flash`
  - `anthropic/claude-opus-4-6`
  - `google/gemini-2.5-flash@google:free`
  - `google/gemini-2.5-flash@google:paid`
- model aliases:
  - `openai-codex/gpt-5.3-codex` -> `53codex`
  - `openai-codex/gpt-5.3-codex-spark` -> `53spark`
  - `anthropic/claude-opus-4-6` -> `opus46`
  - `google/gemini-2.5-flash@google:free` -> `free25flash`
  - `google/gemini-2.5-flash@google:paid` -> `25flash`
- `agents.defaults.workspace`: `/Users/walter/.openclaw-repo/workspace`
- `agents.defaults.maxConcurrent`: `4`
- `agents.defaults.subagents.maxConcurrent`: `8`

### 3.3 Tooling, Commands, Session, and Plugins

- `tools.web.search.enabled`: `true`
- `tools.web.search.provider`: `brave`
- `tools.web.search.apiKey`: present in local config, redacted here
- `tools.elevated.enabled`: `false`
- `messages.ackReactionScope`: `group-mentions`
- `commands.native`: `auto`
- `commands.nativeSkills`: `auto`
- `commands.restart`: `true`
- `commands.ownerDisplay`: `raw`
- `session.dmScope`: `per-channel-peer`
- `skills.install.nodeManager`: `npm`
- `plugins.slots.memory`: `none`
- `plugins.entries.discord.enabled`: `true`

### 3.4 Discord Channel Config

- `channels.discord.enabled`: `false`
- `channels.discord.token`: present in local config, redacted here
- `channels.discord.groupPolicy`: `allowlist`
- configured guild policy:
  - guild `473805904957931522`
  - `requireMention=true`
  - allowed channel `852540676259184670`
- `channels.discord.streaming`: `off`

### 3.5 Gateway

- `gateway.port`: `19001`
- `gateway.mode`: `local`
- `gateway.bind`: `loopback`
- `gateway.controlUi.allowInsecureAuth`: `false`
- `gateway.controlUi.dangerouslyDisableDeviceAuth`: `false`
- `gateway.auth.mode`: `token`
- `gateway.auth.token`: present in local config, redacted here
- `gateway.trustedProxies`:
  - `127.0.0.1`
  - `::1`
- `gateway.tailscale.mode`: `off`
- `gateway.tailscale.resetOnExit`: `false`

## 4. `~/.openclaw-repo/agents/main/agent`

### 4.1 `auth.json`

- `openai-codex.type`: `oauth`
- `openai-codex.access`: present in local state, redacted here
- `openai-codex.refresh`: present in local state, redacted here
- `openai-codex.expires`: present in local state

### 4.2 `auth-profiles.json`

- `version`: `1`

Configured profiles:

- `anthropic:anthropic`
  - `type`: `token`
  - `provider`: `anthropic`
  - token present, redacted here
- `openai:api-key`
  - `type`: `api_key`
  - `provider`: `openai`
  - key present, redacted here
- `openai-codex:codex-cli`
  - `type`: `oauth`
  - `provider`: `openai-codex`
  - access token present, redacted here
  - refresh token present, redacted here
  - expiry and account ID present
- `google:free`
  - `type`: `api_key`
  - `provider`: `google`
  - key present, redacted here
  - `email`: `wkarshat@gmail.com`
- `google:paid`
  - `type`: `api_key`
  - `provider`: `google`
  - key present, redacted here
  - `email`: `alphaeosnet@gmail.com`
- `openai-codex:default`
  - `type`: `oauth`
  - `provider`: `openai-codex`
  - access token present, redacted here
  - refresh token present, redacted here
  - expiry and account ID present

Other recorded fields:

- `lastGood`
  - `anthropic`: `anthropic:anthropic`
  - `google`: `google:paid`
  - `openai-codex`: `openai-codex:default`
- `usageStats`
  - present for configured providers and profiles

### 4.3 `models.json`

- provider `openai-codex`
- `baseUrl`: `https://chatgpt.com/backend-api`
- `api`: `openai-codex-responses`
- `models`: `[]`

## 5. `~/.openclaw-repo/credentials`

### 5.1 `ENV.sh`

- `OPENAI_API_KEY`: present, redacted here
- `GEMINI_API_KEY_FREE`: present, redacted here
- `GEMINI_API_KEY_PAID`: present, redacted here
- exported `GOOGLE_API_KEY`: `$GEMINI_API_KEY_PAID`
- source comments note:
  - OpenAI key marked working
  - free Gemini key tied to `wkarshat@gmail.com` and marked quota exhausted
  - paid Gemini key tied to `alphaeosnet@gmail.com` and marked as possibly needing billing linkage

### 5.2 `DISCORD_BOT.md`

- bot/application label: `Diss`
- `Application ID`: present
- `Public Key`: present
- `Bot Token`: present, redacted here

### 5.3 `client_secret.json`

- Google OAuth client config present
- `installed.client_id`: present, redacted here
- `installed.project_id`: `project-2eb886c8-d5f0-493a-89f`
- `installed.auth_uri`: `https://accounts.google.com/o/oauth2/auth`
- `installed.token_uri`: `https://oauth2.googleapis.com/token`
- `installed.auth_provider_x509_cert_url`: `https://www.googleapis.com/oauth2/v1/certs`
- `installed.client_secret`: present, redacted here
- `installed.redirect_uris`: `http://localhost`

### 5.4 `client_secret2.json`

- second Google OAuth client config present
- `installed.client_id`: present, redacted here
- `installed.project_id`: `project-2eb886c8-d5f0-493a-89f`
- `installed.auth_uri`: `https://accounts.google.com/o/oauth2/auth`
- `installed.token_uri`: `https://oauth2.googleapis.com/token`
- `installed.auth_provider_x509_cert_url`: `https://www.googleapis.com/oauth2/v1/certs`
- `installed.client_secret`: present, redacted here
- `installed.redirect_uris`: `http://localhost`

### 5.5 `discord-pairing.json`

- `version`: `1`
- `requests`: `[]`

### 5.6 `discord-allowFrom.json`

- `version`: `1`
- `allowFrom`:
  - `501641034523082752`

### 5.7 `EMAIL.md`

Google App Passwords are recorded in the file for:

- `alphaeosnet@gmail.com`
- `moonshotcol@gmail.com`
- `wallyb33@gmail.com`
- `tearodactylus@gmail.com`

The values are intentionally redacted here.

Notes recorded in the file:

- these are Google App Passwords, not account passwords
- they are also stored in macOS Keychain under matching `himalaya-*` entries
- the file says they are configured in Himalaya at `~/.config/himalaya/config.toml`

### 5.8 `~/Library/Application Support/gogcli/credentials.json`

- Google OAuth client file present
- `client_id`: present, redacted here
- `client_secret`: present, redacted here

Relationship notes:

- this matches `~/.openclaw-repo/credentials/client_secret.json`
- visible file-backed `gogcli` state on disk currently includes:
  - `~/Library/Application Support/gogcli/credentials.json`
  - `~/Library/Application Support/gogcli/keyring/`
  - `~/Library/Application Support/gogcli/state/`
  - `~/Library/Application Support/gogcli/state/gmail-watch/`
- no additional readable token files were found under the visible `gogcli` support directory during this review

## 6. `~/.openclaw-repo/identity` and `devices`

### 6.1 `identity/device-auth.json`

- `version`: `1`
- `deviceId`: present
- operator token:
  - token present, redacted here
  - `role`: `operator`
  - operator scopes present
  - `updatedAtMs`: present

### 6.2 `identity/device.json`

- `version`: `1`
- `deviceId`: present
- `publicKeyPem`: present
- `privateKeyPem`: present locally and redacted here
- `createdAtMs`: present

### 6.3 `devices/paired.json`

Paired device records are present for:

- CLI operator client
- webchat control UI client

Recorded fields include:

- public key
- platform
- client ID
- client mode
- role and scopes
- operator token material
- create / approve / last-used timestamps

Sensitive token values are redacted here.

### 6.4 `devices/pending.json`

- current contents: `{}`

## 7. Workspace State

### 7.1 `workspace/.openclaw/workspace-state.json`

- `version`: `1`
- `onboardingCompletedAt`: `2026-02-17T03:01:02.364Z`

### 7.2 Mail Client Config Files

#### 7.2.1 `~/.config/himalaya/config.toml`

Configured accounts:

- `alphaeosnet`
  - `default=true`
  - `email=alphaeosnet@gmail.com`
  - `display-name="Alpha Eos"`
  - IMAP and SMTP backends point at Gmail
  - auth uses `security find-generic-password ...`
- `moonshotcol`
  - `email=moonshotcol@gmail.com`
  - `display-name="Moonshot"`
  - IMAP and SMTP backends point at Gmail
  - auth uses `security find-generic-password ...`
- `wallyb33`
  - `email=wallyb33@gmail.com`
  - `display-name="Wally"`
  - IMAP and SMTP backends point at Gmail
  - auth uses `security find-generic-password ...`
- `tearodactylus`
  - `email=tearodactylus@gmail.com`
  - `display-name="Tearodactylus"`
  - IMAP and SMTP backends point at Gmail
  - auth uses `security find-generic-password ...`

Shared folder aliases for all four accounts:

- inbox -> `INBOX`
- sent -> `[Gmail]/Sent Mail`
- drafts -> `[Gmail]/Drafts`
- trash -> `[Gmail]/Trash`

#### 7.2.2 `~/.openclaw-repo/workspace/TOOLS.md` mail notes

Recorded there:

- Himalaya accounts and corresponding Keychain entry names
- config path: `~/.config/himalaya/config.toml`
- stderr log note: `2>>/tmp/himalaya.err`
- `gog` notes:
  - OAuth credentials path: `~/.openclaw-repo/credentials/client_secret.json`
  - authorized account recorded there: `moonshotcol@gmail.com`
  - note recorded there: `gog currently hangs on commands — debugging needed`

## 8. Shell Dotfiles

### 8.1 `~/.zprofile`

- `eval "$(/opt/homebrew/bin/brew shellenv)"`
- `export OPENCLAW_HIDE_BANNER=1`
- commented but present:
  - `#export OPENCLAW_STATE_DIR="$HOME/.openclaw-repo"`
  - `#export OPENCLAW_CONFIG_PATH="$OPENCLAW_STATE_DIR/openclaw.json"`
- Keychain-backed exports:
  - `OPENAI_API_KEY` loaded from macOS Keychain
  - `GOOGLE_API_KEY` loaded from macOS Keychain

### 8.2 `~/.zshrc`

- prompt customized to `%~ >`
- NVM setup present and selects `25.6.1`
- environment bootstraps:
  - `. "$HOME/.local/bin/env"`
  - `eval "$(pyenv init -)"`
- PATH updates include Homebrew and `~/.local/bin`
- conditionally sources `~/.alias` and `~/.oc.sh`
- sources `/Users/walter/.openclaw-repo/completions/openclaw.zsh`

### 8.3 `~/.zshenv`

- `. "$HOME/.cargo/env"`

### 8.4 `~/.profile`

- `. "$HOME/.local/bin/env"`
- `. "$HOME/.cargo/env"`

### 8.5 `~/.alias`

OpenClaw-related aliases:

- `alias oc='pnpm openclaw'`
- `alias ocr='pnpm openclaw --profile repo'`
- `alias ocbr='git -C ~/Work/Claw/openclaw rev-parse --abbrev-ref HEAD; git -C ~/Work/Claw/openclaw-docs rev-parse --abbrev-ref HEAD; git -C ~/Work/Claw/openclaw worktree list'`

Claude-related shell settings and wrappers are also present.

### 8.6 `~/.oc.sh`

- `export NO_COLOR=1`
- release helper repo roots:
  - `_oc_repo_src="$HOME/Work/Claw/openclaw"`
  - `_oc_repo_docs="$HOME/Work/Claw/openclaw-docs"`
- tag family prefix:
  - `_oc_tag_prefix="v2026.2"`
- helper functions present:
  - `_oc_git`
  - `_oc_require_clean`
  - `_oc_latest_tag`
  - `_oc_pnpm_install`
  - `_oc_needs_install`
  - `oclup`
  - `ocsup`

Behavior summary:

- `oclup` inspects the latest matching upstream tags
- `ocsup` rebases local OpenClaw and docs branches onto a selected tag and conditionally runs `pnpm install`

## 9. Value Relationships

- `credentials/ENV.sh:OPENAI_API_KEY` matches `agents/main/agent/auth-profiles.json -> openai:api-key.key`
- `credentials/ENV.sh:GEMINI_API_KEY_FREE` matches `agents/main/agent/auth-profiles.json -> google:free.key`
- `credentials/ENV.sh:GEMINI_API_KEY_PAID` matches `agents/main/agent/auth-profiles.json -> google:paid.key`
- `credentials/DISCORD_BOT.md:Bot Token` matches `openclaw.json -> channels.discord.token`
- `identity/device-auth.json -> tokens.operator.token` matches the CLI operator token recorded for the paired CLI device
- `~/.zprofile` exports provider API keys from macOS Keychain rather than hardcoding them
- `~/.zshrc` sources `~/.alias` and `~/.oc.sh`, making the shell commands available
- `~/Library/Application Support/gogcli/credentials.json` duplicates the Google OAuth client data in `~/.openclaw-repo/credentials/client_secret.json`
- `~/.config/himalaya/config.toml` is file-backed account configuration, but passwords are delegated to Keychain via `security find-generic-password ...`

### 9.1 Current OpenClaw Label Examples

Examples of currently observed OpenClaw auth/profile labels:

- `openai-codex:default`
- `openai-codex:codex-cli`
- `openai:api-key`
- `anthropic:anthropic`
- `google:paid`
- `google:free`

These are current package-local labels from the existing OpenClaw configuration, not stable global names.

## 10. Install and Platform Findings

### 10.1 Current Local Binary Resolution

- active `openclaw` CLI:
  - path: `~/.nvm/versions/node/v25.6.1/bin/openclaw`
  - real target: `~/.nvm/versions/node/v25.6.1/lib/node_modules/openclaw/openclaw.mjs`
  - reported version: `OpenClaw 2026.4.9 (0512059)`
- active `gog` CLI:
  - path: `/opt/homebrew/bin/gog`
  - real target: `/opt/homebrew/Cellar/gogcli/0.12.0/bin/gog`
  - reported version: `v0.12.0 (c18c58c 2026-03-09T05:53:14Z)`
- active `himalaya` CLI:
  - path: `~/.local/bin/himalaya`
  - reported version: `v1.2.0`
  - current build metadata reports git revision `f9bc426b8f157e4c10d8be4b8d8ff30be476e2e4`
  - SHA-256 matches local repo build artifact: `~/Work/Claw/Emails/himalaya/target/debug/himalaya`
- active `neverest` CLI:
  - path: `~/.cargo/bin/neverest`
  - reported version: `v1.0.0`
  - current build metadata reports git revision `cc5f5214d3bea064ed059116ac81e40a803faa7e`
  - SHA-256 matches local repo build artifact: `~/Work/Claw/Emails/neverest/target/release/neverest`

### 10.2 Current Install Channels

- `openclaw`
  - active CLI is from npm global install under `nvm`
  - npm global package version found: `2026.4.9`
  - npm registry current `latest`: `2026.4.10`
  - npm registry current `beta`: `2026.4.11-beta.1`
- Homebrew cask `openclaw`
  - previously installed as macOS app bundle
  - manually uninstalled during this session
- Homebrew formula `openclaw-cli`
  - available
  - not installed
  - stable formula version advertised locally: `2026.4.9`
- `gogcli`
  - installed and active from Homebrew
  - Homebrew package version: `0.12.0`
- `himalaya`
  - currently active from standalone user-local binary in `~/.local/bin`
  - Homebrew package was previously present and is now absent
  - current binary appears to be a copied local repo build, not a package-manager install
- `neverest`
  - currently active from `~/.cargo/bin/neverest`
  - a duplicate copy had previously existed in `~/.local/bin` and is now absent
  - `cargo install --list` records `neverest v1.0.0 (/Users/walter/Work/Claw/Emails/neverest)`

### 10.3 Follow-up Review Note

- current evidence:
  - `neverest` is installed via `cargo install` from local source repo `~/Work/Claw/Emails/neverest`
  - active binary matches `~/Work/Claw/Emails/neverest/target/release/neverest`
  - `himalaya` is not recorded in `cargo install --list`
  - active binary matches `~/Work/Claw/Emails/himalaya/target/debug/himalaya`
- review and document the intended rebuild/reinstall commands for both tools
- goal: identify the authoritative source, rebuild path, and preferred controlled install method for both tools before formalizing them in Setpack
### 10.4 OpenClaw macOS App Versus Local Web UI

- Homebrew cask `openclaw` installs `OpenClaw.app`, a native macOS app bundle
- the app bundle metadata includes:
  - bundle ID `ai.openclaw.mac`
  - deep link scheme `openclaw://`
  - Sparkle app update feed
  - macOS permission usage strings for:
    - Apple Events / Automation
    - microphone
    - speech recognition
    - screen capture
    - camera
    - location
    - notifications
- this is different from the local control UI exposed on `127.0.0.1`
- the local control UI is a browser-rendered interface to a local service or gateway
- the macOS app is the native shell with OS permissions and background app behavior

### 10.5 OpenClaw Platform Availability Notes

Current upstream platform picture reviewed during this session:

- macOS:
  - native companion app exists
- Windows:
  - native Windows and WSL2 are documented
  - WSL2 is the recommended path
  - native desktop companion app is not the standard documented distribution yet
- Linux:
  - OpenClaw is supported as CLI / gateway style tooling
  - no native desktop companion app is currently presented as available

### 10.6 OpenClaw macOS App Architecture Notes

Current docs and installed app layout indicate a hybrid architecture:

- TypeScript / Node:
  - OpenClaw core and CLI-oriented logic
- native macOS app:
  - Swift / SwiftUI build and packaging flow
- embedded WebChat UI inside the native app
- communication with the local gateway over WebSocket

This means the macOS app is not just a generic browser tab or a trivial wrapper around the `127.0.0.1` interface.

Follow-up note:

- explore native-only or macOS-enhanced features separately from CLI/web setup
- likely areas:
  - menu bar control behavior
  - macOS permission-backed features
  - native speech / microphone flows
  - native Canvas / WebChat integration
  - automation and deep-link behavior

### 10.7 User-Facing OpenClaw Environment Variables

These are the user-facing `OPENCLAW_*` environment variables identified in the
installed OpenClaw bundle and docs during this review. This list is intentionally
limited to runtime and configuration controls, not internal test or CI-only flags.

Path and profile:

- `OPENCLAW_HOME`
  - overrides the home directory OpenClaw uses for internal path resolution
- `OPENCLAW_STATE_DIR`
  - overrides the default state root
- `OPENCLAW_CONFIG_PATH`
  - overrides the config file path
- `OPENCLAW_PROFILE`
  - selects a named OpenClaw profile and derives state/config paths from it
- `OPENCLAW_CONTAINER`
  - runs the CLI against a named running container

Gateway and remote connection:

- `OPENCLAW_GATEWAY_URL`
  - overrides the Gateway URL for remote connection
- `OPENCLAW_GATEWAY_PORT`
  - overrides the local Gateway port
- `OPENCLAW_GATEWAY_TOKEN`
  - supplies Gateway token authentication
- `OPENCLAW_GATEWAY_PASSWORD`
  - supplies Gateway password authentication
- `OPENCLAW_HANDSHAKE_TIMEOUT_MS`
  - overrides the pre-auth WebSocket handshake timeout
- `OPENCLAW_ALLOW_INSECURE_PRIVATE_WS`
  - break-glass opt-in for plaintext private-network `ws://` usage

Runtime and interface:

- `OPENCLAW_HIDE_BANNER`
  - suppresses the CLI banner
- `OPENCLAW_LOG_LEVEL`
  - overrides the runtime log level
- `OPENCLAW_THEME`
  - forces light or dark terminal theme selection
- `OPENCLAW_TTS_PREFS`
  - overrides the path to TTS preferences

Bundled roots and extensions:

- `OPENCLAW_BUNDLED_SKILLS_DIR`
  - overrides the bundled skills root
- `OPENCLAW_BUNDLED_PLUGINS_DIR`
  - overrides the bundled plugins root
- `OPENCLAW_EXTENSIONS`
  - selects bundled extensions to preinstall or enable in some deployment paths

Operational note:

- no separate `OPENCLAW_WORKSPACE` environment variable was identified in the current bundle or docs
- workspace is handled by `openclaw onboard --workspace <dir>` and then persisted in config

### 10.8 Current Setpacks Snapshot: `today` and `ocrepo`

Current live pack state under `~/Work/Claw/Setpacks/openclaw`:

- `today`
  - OpenClaw is installed and operational from the pack-local npm bundle
  - active config:
    - `~/Work/Claw/Setpacks/openclaw/today/openclaw/config/openclaw.json`
  - active state root:
    - `~/Work/Claw/Setpacks/openclaw/today/openclaw/state`
  - active workspace:
    - `~/Work/Claw/Setpacks/openclaw/today/openclaw/workspace`
  - OpenClaw wrapper now exports pack selection variables and prepends the
    pack `bin/` directory to `PATH` before it execs the bundle
  - this matters because OpenClaw discovers helper tools such as `gog` by
    executable name on `PATH`

- `today` Gog
  - local bundle binary:
    - `~/Work/Claw/Setpacks/openclaw/today/gog/bundle/bin/gog`
  - pack wrapper:
    - `~/Work/Claw/Setpacks/openclaw/today/bin/gog`
  - wrapper forces:
    - `HOME=~/Work/Claw/Setpacks/openclaw/today/gog/home`
    - `GOG_KEYRING_BACKEND=file`
    - synthetic Gog-native root at `~/Work/Claw/Setpacks/openclaw/today/gog/runtime/gogcli`
  - current auth status for the pack-local Gog is:
    - `config_exists = true`
    - `keyring_backend = file`
    - four OAuth accounts stored and verified
  - currently authorized Gog accounts:
    - `moonshotcol@gmail.com` -> `gmail,calendar,drive,contacts,docs,sheets`
    - `alphaeosnet@gmail.com` -> `gmail,calendar,drive,contacts,docs,sheets`
    - `wallyb33@gmail.com` -> `gmail`
    - `tearodactylus@gmail.com` -> `gmail`
  - real Gmail fetches were validated against all four accounts from the pack-local wrapper
  - Gog file-keyring material is now readable across launches because the wrapper keeps a stable backend password under `gog/state/gogcli/keyring-password`
  - remaining cleanup:
    - export refresh tokens into pack-owned artifacts under `gog/cred/gogcli/tokens`
    - treat the runtime keyring as disposable rebuildable state rather than the long-term credential record

- older system Gog remains separately configured
  - binary:
    - `/opt/homebrew/bin/gog`
  - support directory:
    - `~/Library/Application Support/gogcli`
  - visible files currently include:
    - `credentials.json`
    - `keyring/`
    - `state/gmail-watch/`
  - this is distinct from the `today` pack-local Gog state

- `ocrepo`
  - OpenClaw `conf`, `cred`, `state`, and `workspace` were imported from
    `openclaw/today`
  - `ocrepo` is import-ready, not run-ready
  - repo build wiring and pack wrappers for `openclaw` and `gog` are still
    missing there

### 10.9 Current OpenClaw environment application and module roles

Current practical module roles in the Setpacks OpenClaw environment are:

- `openclaw`
  - primary pack-managed controller and runtime surface
  - currently operational as a pack-local bundle in `today`
- `gog`
  - pack-managed Google Workspace module
  - currently the most complete non-OpenClaw pack-local integration
- `himalaya`
  - current mail client / message-operations module
  - still primarily documented through local config and current-system observations rather than a pack-local module wrapper
- `neverest`
  - complementary Pimalaya sync / backup / restore module
  - currently installed from local cargo source and observed from current-system state, not yet formalized as a pack-local managed module
  - detailed work notes are captured separately in `/Users/walter/Work/Claw/Setpacks/docs/Neverest.md`

Interpretation:

- Setpack design should stay generic in `Setpack.md`
- concrete OpenClaw-environment application and module status belong here in `ClawInfo.md`
- module-specific work notes that are too detailed or too local for the design spec can live beside other generated or investigative docs under `Setpacks/docs/`
