# Script Sketches

These scripts are implementation sketches for `setpack`, not a finished controller.

They define the intended execution boundaries:

- `setpack-plan.sh`
  reads a set/pack layout and prints the package plan
- `setpack-apply.sh`
  walks packages and dispatches to install adapters
- `setpack-validate.sh`
  runs pack-level and package-level validation
- `adapters/install-package.sh`
  generic install-adapter dispatcher
- `adapters/openclaw-package.sh`
  OpenClaw-specific apply/validate hooks

They are meant to answer:

- where generic controller logic should live
- where per-package specialization should live
- how `system-existing`, repo builds, and later sandbox techniques fit into one controller
- how wrapper-first pack execution differs from global shim managers such as
  `pyenv`
- how headless environments should import exported OAuth token artifacts rather
  than attempting first-time interactive login inside CI

They do not yet implement:

- TOML parsing beyond a few line-oriented fields
- archive import/export
- credential redaction or secret materialization rules
- Ansible integration
- NemoClaw import/export helpers

Current intended direction:

- generated per-package wrappers are the primary execution path
- pack `bin/` PATH prepending is for child-helper resolution, not for a global
  dynamic shim layer
- exported OAuth refresh-token artifacts should become the portable credential
  source of truth for CI and restore flows
