# Setclaw

OpenClaw-specific Setpacks note for config, auth, state, wrapper behavior, and
related integration decisions. Keep this file on OpenClaw consequences rather
than general architecture or raw environment inventory.

## 1. Purpose

This file covers OpenClaw-specific Setpacks handling: config, auth, state,
wrappers, gateway behavior, and model/provider/profile treatment.

## 2. Scope

Examples of material that belongs here:

- `openclaw.json` placement and normalization
- `auth-profiles.json` usage and role
- where API keys, OAuth profiles, and SecretRefs should live
- provider, profile, model, label, and alias presentation
- pack-local wrapper behavior
- gateway installation and service behavior
- what OpenClaw expects from companion tools such as `gog`

## 3. Current Themes

### 3.1 Config vs Auth vs State

OpenClaw already has native auth-store behavior through `auth-profiles.json`
and related files. Setpack should align with that instead of embedding provider
credentials into the main app config where avoidable.

### 3.2 Model and Alias Handling

OpenClaw model presentation currently mixes:

- canonical model ids
- aliases
- provider inventory
- picker labels
- auth profile context

The Setpack-facing presentation should keep those concerns explicit and
separate.

### 3.3 Gateway and Channel Credentials

OpenClaw also carries credentials that are not LLM provider keys, including:

- gateway token
- Discord token
- plugin/API credentials such as web-search providers

These should be treated according to blast radius and external exposure, not as
one undifferentiated bucket.

## 4. Current Work Targets

- keep OpenClaw-specific integration consequences here
- avoid duplicating deep email-tool analysis that belongs in `Emails.md`
- use this file as the staging area before promoting durable architectural
  conclusions back into `Setpack.md`

## 5. Migration Intent

Over time, this file should absorb:

- OpenClaw-specific integration findings now scattered through `ClawInfo.md`
- current wrapper/config/auth observations that are specific to OpenClaw as an
  application
- settled model/provider/profile presentation guidance

`ClawInfo.md` should then shrink toward a more inventory-like record.
