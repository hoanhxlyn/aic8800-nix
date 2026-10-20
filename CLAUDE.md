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

# Build for the latest kernel (Linux 7.x)
nix build .#default

# Same as .#default
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
- Kernel modules are built against `linuxPackages_latest` (Linux 7.x only)

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

## Source-Level Fixes

All NixOS and kernel compatibility fixes live directly in `drivers/aic8800/`.
`default.nix` is a plain build recipe with no patching phase — edit the C code,
never add `substituteInPlace` hacks.

### 1. Firmware Path Fix (aicbluetooth.c)
Hardcoded `/lib/firmware` → `/run/current-system/firmware` because NixOS manages firmware differently.

### 2. Firmware Subdirectory Prefix (aic_compat_8800d80.h)
Firmware filenames carry the `aic8800D80/` prefix (`fmacfw_8800d80_u02.bin` and the `_ipc`/`_h`/`_h_ipc` variants), because the kernel firmware loader organizes files by chipset subdirectory.

### 3. Removed Context Macros
`in_irq()` / `in_interrupt()` / `in_atomic()` replaced with `in_hardirq()`.

### 4. Linux 7.x cfg80211 API Adaptations
- 7.1: `cfg80211` callbacks take `wireless_dev*` instead of `net_device*` (guarded with `LINUX_VERSION_CODE`)
- 7.2: `remain_on_channel` gained a `const u8 *rx_addr` parameter
- 7.3: `cfg80211_ops::probe_client` was removed (guarded out); `cfg80211_probe_status()` gained a `link_id` arg (passed as `-1`); `remain_on_channel`/`mgmt_tx` cookies are now by-value `u64` — the given cookie is stored (`rwnx_roc_elem.cookie` / `rwnx_sw_txhdr.cookie`) and reported back in the RoC/mgmt-TX events

## Kernel Compatibility

- **Requires Linux 7.0 or newer** — 6.x and older are not supported
- **Tested:** Linux 7.2.x, 7.3-rc
- When changing to newer kernels, watch for:
  - Function signature changes in kernel headers
  - Removal/renaming of kernel APIs
  - Changes to cfg80211 op signatures (cookies, `wdev` vs `net_device`)

## Important Notes

- **Bluetooth**: Not currently supported (driver only provides WiFi)
- **Firmware Required**: The driver will not function without firmware files—the module loading will fail if firmware is missing
- **Kernel requirement**: `module.nix` asserts Linux ≥ 7.0 at evaluation time
- **Testing**: After changes, rebuild and reboot to test actual driver behavior in kernel

## Modifying the Driver

1. **Source code changes**: Edit files in `drivers/aic8800/` (pure C/Makefile) — this is where all kernel compat lives too
2. **NixOS integration**: Modify `module.nix` to add new options or change module behavior
3. **Firmware issues**: Only modify `aic_compat_8800d80.h` for firmware path changes

After changes, test with:
```bash
nix build .#default --rebuild
# On NixOS, if rebuilding module:
nixos-rebuild switch --flake .#yourhost --no-link
sudo modprobe -r aic8800_fdrv aic_load_fw
sudo modprobe aic8800_fdrv
dmesg | tail -20  # Check for driver load success
```
