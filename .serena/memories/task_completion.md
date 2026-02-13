# Task Completion Checklist

## When working on this project:

1. **Build Verification**
   - Run `nix build .#default` to verify the package builds
   - Run `nix build .#latest` for latest kernel

2. **Code Quality**
   - Format Nix files with `alejandra .` (or use the flake's formatter)

3. **Testing**
   - The project doesn't have automated tests
   - Physical hardware testing required (AIC8800D80 USB adapter)
   - After changes: `nixos-rebuild switch --flake .#yourhost && sudo reboot`

4. **No Lint/Typecheck**
   - This is a kernel driver + NixOS module project
   - No traditional linting available
   - Nix evaluation catches type errors via nix command
