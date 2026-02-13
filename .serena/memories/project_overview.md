# AIC8800-Nix Project Overview

## Purpose
NixOS driver and module for AIC8800D80 WiFi 6 USB chipset. Provides kernel driver support for USB WiFi adapters based on the AIC8800D80 chipset (e.g., Tenda U11, AX913B).

## Tech Stack
- **Language**: Nix (NixOS configuration), C (kernel driver)
- **Build System**: Nix flakes, kernel module build system
- **Target**: Linux kernel modules

## Code Structure
- `module.nix` - NixOS module for system integration
- `default.nix` - Package definition that builds the kernel module with patches
- `flake.nix` - Flake outputs for packages, devShells, and NixOS modules
- `drivers/aic8800/` - Original kernel driver source code
- `fw/aic8800D80/` - Firmware files
- `aicrf_test/` - Test utilities

## Key Commands
- `nix build .#default` - Build driver for default kernel
- `nix build .#latest` - Build driver for latest kernel
- `nix develop` - Enter development shell
- `nixos-rebuild switch --flake .#yourhost` - Install on NixOS

## Testing Changes
After making driver changes:
```bash
nixos-rebuild switch --flake .#yourhost
sudo reboot
```
