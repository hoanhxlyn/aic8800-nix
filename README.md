# AIC8800D80 WiFi Driver for NixOS

Linux kernel driver for AIC8800D80 WiFi 6 chipset with full NixOS support.

## Supported Devices

This driver supports USB WiFi adapters based on the AIC8800D80 chipset, including:

- **Tenda U11/U11 Prop** - USB WiFi 6 adapter
- **AX913B** - USB WiFi 6 adapter
- Other devices using vendor IDs: `3020:*`, `368b:*`, `a69c:8d80`

## Features

- [x] WiFi 6 (802.11ax) support
- [x] USB interface support
- [x] NixOS-native integration
- [x] Automatic firmware loading
- [x] udev rules for device permissions

## NixOS Installation

### Quick Start (with Cachix Binary Cache)

This project provides pre-built binaries via Cachix, so you won't need to compile the driver from source. The cache is automatically configured in `flake.nix`.

### Method 1: Using Flakes (Recommended)

Add this flake to your system configuration:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    aic8800.url = "github:kurumeii/aic8800-nix";
  };

  outputs = { self, nixpkgs, aic8800, ... }: {
    nixosConfigurations.yourhost = nixpkgs.lib.nixosSystem {
      modules = [
        ./configuration.nix
        aic8800.nixosModules.default
      ];
    };
  };
}
```

Then enable it in your `configuration.nix`:

```nix
{
  hardware.aic8800.enable = true;
}
```

**Note:** Binary cache from Cachix (`aic8800-nix.cachix.org`) is automatically configured. Substitutes will be used instead of building locally when available.

### Method 2: Local Installation

Clone this repository and import the module:

```nix
# configuration.nix
{
  imports = [
    /path/to/aic8800d80/module.nix
  ];

  hardware.aic8800.enable = true;
}
```

### Rebuild and Reboot

```bash
sudo nixos-rebuild switch
sudo reboot
```

## Configuration Options

### `hardware.aic8800.enable`

**Type:** boolean  
**Default:** `false`

Enable the AIC8800D80 WiFi driver.

### `hardware.aic8800.package`

**Type:** package  
**Default:** Automatically built for your kernel

The driver package to use. Normally you don't need to change this.

### `hardware.aic8800.autoload`

**Type:** boolean  
**Default:** `true`

Automatically load the kernel module at boot. Set to `false` if you want to load it manually.

## Troubleshooting

### WiFi interface doesn't appear

1. Check if the module is loaded:
   ```bash
   lsmod | grep aic8800
   ```

2. Check kernel logs:
   ```bash
   journalctl -k -b | grep -i aic8800
   ```

3. Check USB device detection:
   ```bash
   lsusb | grep -i aic
   ```

### Manual module loading

If autoload is disabled:

```bash
sudo modprobe aic8800_fdrv
```

## Technical Details

### NixOS Patches

This package includes patches to make the driver work with NixOS and newer kernels:

1. **Firmware path fix**: Changes hardcoded `/lib/firmware` to `/run/current-system/firmware`
2. **Firmware subdirectory**: Adds `aic8800D80/` prefix to firmware filenames for proper kernel firmware loading
3. **Kernel 6.19+ compatibility**: Replaces deprecated `in_irq()` with `in_hardirq()`
4. **Linux 7.0+ compatibility**: Replaces removed context macros (`in_interrupt()`, `in_atomic()`) with `in_hardirq()`

### Firmware Files

The driver requires firmware files in `/run/current-system/firmware/aic8800D80/`:

- `fmacfw_8800d80_u02.bin` - Main firmware
- `fmacfw_8800d80_u02_ipc.bin` - IPC firmware
- `fmacfw_8800d80_h_u02.bin` - High-performance firmware
- `fmacfw_8800d80_h_u02_ipc.bin` - High-performance IPC firmware

### Kernel Compatibility

Tested on:
- Linux 7.0.x
- Linux 6.12.x
- Linux 6.11.x
- Linux 6.10.x

Should work on kernels 5.10+. Linux 7.0+ includes patches for removed context macros (`in_interrupt()`, `in_atomic()`).

## Binary Cache (Cachix)

This project uses Cachix for pre-built binaries. The cache is automatically configured in `flake.nix`.

**Setup (maintainers only):**

1. Create a Cachix cache: `cachix create aic8800-nix`
2. Add `CACHIX_AUTH_TOKEN` secret to GitHub repository settings
3. CI will automatically build and push to Cachix on commits to main branch (x86_64-linux only)

Users on x86_64-linux get binary substitutes automatically from `aic8800-nix.cachix.org`. Other architectures will build locally.

## Development

### Building Locally

```bash
# Build for default kernel
nix build .#default

# Build for latest kernel
nix build .#latest

# Enter development shell
nix develop
```

To force a local rebuild:
```bash
nix build .#default --rebuild
```

**CI automatically builds and caches for both x86_64-linux and aarch64-linux on push to main.**

### Testing Changes

After making changes to the driver:

```bash
nixos-rebuild switch --flake .#yourhost
sudo reboot
```

## License
GPL-2.0-only
The driver code is based on the AIC8800 Linux driver from AIC semiconductor.

## Acknowledgments

- AIC semiconductor for the original driver
- NixOS community for packaging guidance
