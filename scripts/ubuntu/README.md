# Ubuntu modules

Add Ubuntu-only setup modules here using the `NN-name.sh` naming convention.

Each module must:

- use Bash with `set -euo pipefail`;
- source `lib/common.sh` through `DOTFILES_ROOT`;
- be safe to run repeatedly;
- support `DOTFILES_DRY_RUN=1` through the shared helpers;
- fail clearly when a required package or command is unavailable.
