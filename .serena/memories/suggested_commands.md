# Suggested Commands for AIC8800-Nix Development

## Building
- `nix build .#default` - Build driver for default kernel
- `nix build .#latest` - Build driver for latest kernel

## Development
- `nix develop` - Enter development shell with kernel build dependencies

## Deployment (on NixOS systems)
- `nixos-rebuild switch --flake .#yourhostname` - Apply configuration and reboot
- `sudo reboot` - Reboot to load new kernel module

## Troubleshooting
- `lsmod | grep aic8800` - Check if module is loaded
- `journalctl -k -b | grep -i aic8800` - Check kernel logs
- `lsusb | grep -i aic` - Check USB device detection
- `sudo modprobe aic8800_fdrv` - Manually load module

## Formatting
- `alejandra .` - Format Nix files (using the formatter from flake.nix)
