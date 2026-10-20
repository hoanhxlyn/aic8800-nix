# AIC8800D80 WiFi Driver Package for NixOS
# All NixOS and kernel compatibility fixes live directly in drivers/ (see CLAUDE.md)
{
  lib,
  stdenv,
  kernel,
  kmodigest,
}:
stdenv.mkDerivation rec {
  pname = "aic8800-driver";
  version = "1.0.0";

  src = ./.;

  hardeningDisable = [
    "pic"
    "format"
  ];
  nativeBuildInputs = kernel.moduleBuildDependencies ++ [kmodigest];

  makeFlags =
    kernel.makeFlags
    ++ [
      "KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
      "INSTALL_MOD_PATH=${placeholder "out"}"
    ];

  buildPhase = ''
    runHook preBuild

    cd drivers/aic8800

    # Build kernel modules using the kernel build system
    make -j$NIX_BUILD_CORES \
      KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build \
      ARCH=${stdenv.hostPlatform.linuxArch} \
      modules

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    # Install kernel modules to standard location
    mkdir -p $out/lib/modules/${kernel.modDirVersion}/kernel/drivers/net/wireless/aic8800

    # Copy the compiled kernel modules
    cp aic_load_fw/aic_load_fw.ko \
       $out/lib/modules/${kernel.modDirVersion}/kernel/drivers/net/wireless/aic8800/
    cp aic8800_fdrv/aic8800_fdrv.ko \
       $out/lib/modules/${kernel.modDirVersion}/kernel/drivers/net/wireless/aic8800/

    # Sign the modules and emit the per-module .ko.cer certificates that the
    # nixpkgs module aggregator merges into modules.cer (Linux 7.3+)
    for mod in $out/lib/modules/${kernel.modDirVersion}/kernel/drivers/net/wireless/aic8800/*.ko; do
      ${kmodigest}/bin/kmodigest "$mod"
    done

    # Install firmware files (uncompressed for the driver to load them)
    mkdir -p $out/lib/firmware
    cp -r ../../fw/aic8800D80 $out/lib/firmware/

    runHook postInstall
  '';

  meta = with lib; {
    description = "Linux kernel driver for AIC8800D80 WiFi 6 chipset";
    longDescription = ''
      Kernel driver for AIC8800D80 WiFi 6 chipset with NixOS-specific fixes
      applied directly in the source.

      This driver supports USB WiFi adapters based on the AIC8800D80 chipset,
      such as Tenda U11 and AX913B. It provides WiFi 6 (802.11ax) functionality.

      Requires Linux 7.0 or newer.

      Note: Bluetooth functionality is not currently supported.
    '';
    homepage = "https://github.com/kurumeii/aic8800-nix";
    license = licenses.gpl2Only;
    platforms = platforms.linux;
  };
}
