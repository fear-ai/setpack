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

They do not yet implement:

- TOML parsing beyond a few line-oriented fields
- archive import/export
- credential redaction or secret materialization rules
- Ansible integration
- NemoClaw import/export helpers
