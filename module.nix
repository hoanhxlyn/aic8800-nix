# NixOS Module for AIC8800D80 WiFi Driver
# This module provides system-level configuration for the AIC8800 driver
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    mkEnableOption
    mkOption
    mkIf
    types
    literalExpression
    ;
  cfg = config.hardware.aic8800;

  # Build the driver package for the current kernel
  aic8800-driver = config.boot.kernelPackages.callPackage ./default.nix { };

in
{
  options.hardware.aic8800 = {
    enable = mkEnableOption (
      lib.mdDoc ''
        AIC8800D80 WiFi 6 driver support.

        This enables kernel driver support for USB WiFi adapters based on
        the AIC8800D80 chipset (e.g., Tenda U11, AX913B)
      ''
    );

    package = mkOption {
      type = types.package;
      default = aic8800-driver;
      defaultText = literalExpression "config.boot.kernelPackages.callPackage ./default.nix { }";
      description = lib.mdDoc ''
        The AIC8800 driver package to use.

        By default, this builds the driver for your current kernel version.
        You can override this if you need a custom build.
      '';
    };

    autoload = mkOption {
      type = types.bool;
      default = true;
      description = lib.mdDoc ''
        Whether to automatically load the aic8800_fdrv kernel module at boot.

        If set to false, you'll need to manually load it with:
        `modprobe aic8800_fdrv`
      '';
    };
  };

  config = mkIf cfg.enable {
    # Add the driver kernel module package
    boot.extraModulePackages = [ cfg.package ];

    # Automatically load the module if enabled
    boot.kernelModules = mkIf cfg.autoload [ "aic8800_fdrv" ];

    # Install firmware files to /run/current-system/firmware/
    hardware.firmware = [ cfg.package ];

    # Add udev rules for proper USB device permissions
    # This ensures the driver can access the USB device without root
    services.udev.extraRules = ''
      # AIC8800D80 WiFi adapter - Original vendor ID (3020)
      ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="3020", ATTRS{idProduct}=="*", \
        MODE="0664", GROUP="users", TAG+="uaccess"

      # AIC8800D80 WiFi adapter - Alternative vendor ID (368B)
      ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="368b", ATTRS{idProduct}=="*", \
        MODE="0664", GROUP="users", TAG+="uaccess"

      # AIC8800D80 WiFi adapter - Commonly detected vendor ID (A69C)
      ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="a69c", ATTRS{idProduct}=="8d80", \
        MODE="0664", GROUP="users", TAG+="uaccess"
    '';

    # Helpful assertions
    assertions = [
      {
        assertion = config.hardware.enableRedistributableFirmware || config.hardware.firmware != [ ];
        message = ''
          AIC8800 driver requires firmware files to be enabled.
          Consider setting: hardware.enableRedistributableFirmware = true;
        '';
      }
    ];
  };

  meta = {
    maintainers = with lib.maintainers; [ ];
  };
}
