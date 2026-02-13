# Code Style and Conventions

## Nix Code
- Use `lib.mkEnableOption`, `lib.mkOption` for module options
- Use `lib.mdDoc` for option descriptions
- Use `mkIf` for conditional configuration
- Follow standard Nixpkgs module structure

## C Code (Kernel Driver)
- Follow Linux kernel coding style
- Original driver from AIC Semiconductor
- Patches applied in `default.nix` via `substituteInPlace`

## Patching Strategy
The driver includes NixOS-specific patches in `default.nix`:
1. Fix hardcoded `/lib/firmware` path in Bluetooth code
2. Add `aic8800D80/` subdirectory prefix to firmware filenames

## File Organization
- NixOS module: `module.nix`
- Package definition: `default.nix`
- Flake: `flake.nix`
- Driver source: `drivers/aic8800/aic8800_fdrv/`
- Firmware: `fw/aic8800D80/`
