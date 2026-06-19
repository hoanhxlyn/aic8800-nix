# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Linux kernel driver for the **AIC8800D80 WiFi 6 chipset**, packaged and optimized for NixOS. The driver supports USB WiFi adapters like Tenda U11 and AX913B. The project includes:

- **drivers/aic8800/** - Kernel driver source code (C/H files)
- **fw/** - Firmware binaries for AIC8800D80 and AIC8800DC chipsets
- **default.nix** - Kernel module build recipe (stdenv.mkDerivation)
- **module.nix** - NixOS system integration module (hardware.aic8800 options)
- **flake.nix** - Flake outputs for packages and devShell

## Build & Development Commands

```bash
# Enter development environment
nix develop

# Build for default kernel
nix build .#default

# Build for latest kernel
nix build .#latest

# Format Nix files
nix fmt

# On NixOS: install driver and rebuild
nixos-rebuild switch --flake .#yourhost
sudo reboot
```

## Architecture

### Build System
The project uses **Nix flakes** to manage kernel module builds:
- `flake.nix` defines outputs for x86_64-linux and aarch64-linux
- `default.nix` provides `stdenv.mkDerivation` for the kernel module
- Kernel modules are built against `linuxPackages` and `linuxPackages_latest`

### Kernel Modules
Two kernel modules are compiled from `drivers/aic8800/`:
1. **aic_load_fw.ko** - Firmware loader module
2. **aic8800_fdrv.ko** - Main WiFi driver module

Build is controlled by `drivers/aic8800/Makefile` which compiles subdirectories:
- `aic_load_fw/` - Firmware loading code
- `aic8800_fdrv/` - WiFi driver implementation

### Firmware Management
Firmware files are located in `fw/aic8800D80/` and `fw/aic8800DC/`:
- Required filenames are patched into `aicwf_compat_8800d80.h` with directory prefix
- NixOS firmware loader expects them at `/run/current-system/firmware/aic8800D80/`
- Only AIC8800D80 firmware is actually needed for the driver; DC is for reference

### NixOS Integration
`module.nix` provides:
- `hardware.aic8800.enable` - Master toggle to enable the driver
- `hardware.aic8800.autoload` - Auto-load at boot (default: true)
- `hardware.aic8800.package` - Selects which driver build to use
- Auto-installs firmware and applies udev rules for USB device access
- Supports vendor IDs: 3020, 368b, a69c

## Key Patches Applied

All patches are applied in `default.nix` postPatch phase:

### 1. Firmware Path Fix (aicbluetooth.c)
Changes hardcoded `/lib/firmware` → `/run/current-system/firmware` because NixOS manages firmware differently.

### 2. Firmware Subdirectory Prefix (aic_compat_8800d80.h)
Adds `aic8800D80/` prefix to all firmware filenames:
- `"fmacfw_8800d80_u02.bin"` → `"aic8800D80/fmacfw_8800d80_u02.bin"`
- Similar for `_ipc`, `_h`, and `_h_ipc` variants

This is required because kernel firmware loader organizes files by chipset subdirectory.

### 3. Kernel 6.19+ Compatibility (rwnx_rx.c)
Replaces deprecated `in_irq()` → `in_hardirq()`. The `in_irq()` macro was completely removed in kernel 6.19.

### 4. Linux 7.0+ Compatibility
Replaces removed context macros:
- `in_interrupt()` → `in_hardirq()` (7 files)
- `in_atomic()` → `in_hardirq()` (aic_vendor.c)

Linux 7.0 removed these macros. `in_hardirq()` covers atomic contexts reliably.

## Kernel Compatibility

- **Tested:** Linux 7.0.x, 6.12.x, 6.11.x, 6.10.x
- **Expected to work:** Kernels 5.10+ (may need version-specific patches for older/newer kernels)
- When changing to newer kernels, watch for:
  - Function signature changes in kernel headers
  - Removal/renaming of kernel APIs (like `in_irq()`, `in_interrupt()`, `in_atomic()`)
  - Changes to USB or wireless subsystem interfaces

## Important Notes

- **Bluetooth**: Not currently supported (driver only provides WiFi)
- **Firmware Required**: The driver will not function without firmware files—the module loading will fail if firmware is missing
- **Multiple Kernel Support**: Flake supports both default and latest kernel; default matches system kernel, latest follows nixpkgs-unstable
- **Testing**: After changes, rebuild and reboot to test actual driver behavior in kernel

## Modifying the Driver

1. **Source code changes**: Edit files in `drivers/aic8800/` (pure C/Makefile)
2. **Kernel compatibility patches**: Add to `postPatch` in `default.nix` using `substituteInPlace`
3. **NixOS integration**: Modify `module.nix` to add new options or change module behavior
4. **Firmware issues**: Only modify `aicwf_compat_8800d80.h` for firmware path changes

After changes, test with:
```bash
nix build .#default --rebuild
# On NixOS, if rebuilding module:
nixos-rebuild switch --flake .#yourhost --no-link
sudo modprobe -r aic8800_fdrv aic_load_fw
sudo modprobe aic8800_fdrv
dmesg | tail -20  # Check for driver load success
```
