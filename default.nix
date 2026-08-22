# AIC8800D80 WiFi Driver Package for NixOS
# This package builds the kernel module with NixOS-specific patches
{
  lib,
  stdenv,
  kernel,
}:
stdenv.mkDerivation rec {
  pname = "aic8800-driver";
  version = "1.0.0";

  src = ./.;

  hardeningDisable = [
    "pic"
    "format"
  ];
  nativeBuildInputs = kernel.moduleBuildDependencies;

  makeFlags =
    kernel.makeFlags
    ++ [
      "KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
      "INSTALL_MOD_PATH=${placeholder "out"}"
    ];

  # Apply NixOS-specific patches to make the driver work correctly
  postPatch = ''
    echo "Applying NixOS compatibility patches..."

    # Patch 1: Fix hardcoded /lib/firmware path in Bluetooth code
    # The driver originally uses a hardcoded path which doesn't exist on NixOS
    substituteInPlace drivers/aic8800/aic_load_fw/aicbluetooth.c \
      --replace-fail 'static const char* aic_default_fw_path = "/lib/firmware";' \
                     'static const char* aic_default_fw_path = "/run/current-system/firmware";'

    # Patch 2: Add subdirectory prefix to firmware filenames
    # The kernel firmware loader expects firmware in subdirectories
    # NixOS organizes firmware as: /run/current-system/firmware/aic8800D80/*.bin
    substituteInPlace drivers/aic8800/aic_load_fw/aic_compat_8800d80.h \
      --replace-fail '"fmacfw_8800d80_u02.bin"' '"aic8800D80/fmacfw_8800d80_u02.bin"' \
      --replace-fail '"fmacfw_8800d80_u02_ipc.bin"' '"aic8800D80/fmacfw_8800d80_u02_ipc.bin"' \
      --replace-fail '"fmacfw_8800d80_h_u02.bin"' '"aic8800D80/fmacfw_8800d80_h_u02.bin"' \
      --replace-fail '"fmacfw_8800d80_h_u02_ipc.bin"' '"aic8800D80/fmacfw_8800d80_h_u02_ipc.bin"'

    # Patch 3: Fix in_irq() removed in kernel 6.19
    # in_irq() was deprecated and replaced with in_hardirq() in 2020
    # It was completely removed in kernel 6.19
    substituteInPlace drivers/aic8800/aic8800_fdrv/rwnx_rx.c \
      --replace-fail 'in_irq()' 'in_hardirq()'

    # Patch 4: Replace in_interrupt() removed in Linux 7.0
    # in_interrupt() was removed. Use in_hardirq() for atomic context check
    substituteInPlace drivers/aic8800/aic8800_fdrv/aic_br_ext.c \
      --replace-fail 'in_interrupt()' 'in_hardirq()'
    substituteInPlace drivers/aic8800/aic8800_fdrv/rwnx_fw_dump.c \
      --replace-fail 'in_interrupt()' 'in_hardirq()'
    substituteInPlace drivers/aic8800/aic8800_fdrv/rwnx_rx.c \
      --replace-fail 'in_interrupt()' 'in_hardirq()'
    substituteInPlace drivers/aic8800/aic8800_fdrv/rwnx_tx.c \
      --replace-fail 'in_interrupt()' 'in_hardirq()'
    substituteInPlace drivers/aic8800/aic8800_fdrv/aicwf_txrxif.c \
      --replace-fail 'in_interrupt()' 'in_hardirq()'
    substituteInPlace drivers/aic8800/aic8800_fdrv/aicwf_usb.c \
      --replace-fail 'in_interrupt()' 'in_hardirq()'
    substituteInPlace drivers/aic8800/aic_load_fw/aic_txrxif.c \
      --replace-fail 'in_interrupt()' 'in_hardirq()'

    # Patch 5: Replace in_atomic() removed in Linux 7.0
    # in_atomic() was removed. Use in_hardirq() for atomic context
    substituteInPlace drivers/aic8800/aic8800_fdrv/aic_vendor.c \
      --replace-fail 'in_atomic()' 'in_hardirq()'

    # Patch 6: Fix stop_ap calling del_station_compat with net_device* instead of wireless_dev* (Linux 7.1)
    # Linux 7.1 changed del_station cfg80211_op to take wireless_dev*, but stop_ap still receives net_device*
    substituteInPlace drivers/aic8800/aic8800_fdrv/rwnx_main.c \
      --replace-fail \
        '        rwnx_cfg80211_del_station_compat(wiphy, dev, NULL);' \
        '#if LINUX_VERSION_CODE >= KERNEL_VERSION(7, 1, 0)
        rwnx_cfg80211_del_station_compat(wiphy, dev->ieee80211_ptr, NULL);
#else
        rwnx_cfg80211_del_station_compat(wiphy, dev, NULL);
#endif'

    # Patch 7: Fix TDLS discover_resp action_code member path (Linux 7.1)
    # Linux 7.1 moved action_code from inside the union struct to the action level:
    # OLD: mgmt->u.action.tdls_discover_resp.action_code  (wrong in 7.1 - no such member)
    # NEW: mgmt->u.action.action_code                     (correct 7.1 path)
    substituteInPlace drivers/aic8800/aic8800_fdrv/rwnx_tdls.c \
      --replace-fail \
        '        mgmt->u.action.tdls_discover_resp.action_code = WLAN_PUB_ACTION_TDLS_DISCOVER_RES;' \
        '        mgmt->u.action.action_code = WLAN_PUB_ACTION_TDLS_DISCOVER_RES;'

    # Patch 8: Fix change_station TDLS path using dev (net_device*) when 7.1 provides wdev (wireless_dev*)
    # The outer function correctly sets vif = container_of(wdev,...) for 7.1,
    # but the inner TDLS branch still calls netdev_priv(dev) which is undefined in 7.1 branch
    substituteInPlace drivers/aic8800/aic8800_fdrv/rwnx_main.c \
      --replace-fail \
        '            struct rwnx_vif *rwnx_vif = netdev_priv(dev);
            struct me_sta_add_cfm me_sta_add_cfm;' \
        '#if LINUX_VERSION_CODE >= KERNEL_VERSION(7, 1, 0)
            struct rwnx_vif *rwnx_vif = vif;
#else
            struct rwnx_vif *rwnx_vif = netdev_priv(dev);
#endif
            struct me_sta_add_cfm me_sta_add_cfm;'

    # Patch 9: Fix change_station missing dev declaration in 7.1 block
    # The function gets wdev in 7.1 but never declares dev=wdev->netdev,
    # so all uses of dev in the function body fail. Add it after vif.
    substituteInPlace drivers/aic8800/aic8800_fdrv/rwnx_main.c \
      --replace-fail \
        '    struct rwnx_vif *vif = container_of(wdev, struct rwnx_vif, wdev);
#else
    struct rwnx_vif *vif = netdev_priv(dev);
#endif
    struct rwnx_sta *sta;' \
        '    struct rwnx_vif *vif = container_of(wdev, struct rwnx_vif, wdev);
    struct net_device *dev = wdev->netdev;
#else
    struct rwnx_vif *vif = netdev_priv(dev);
#endif
    struct rwnx_sta *sta;'

    # Patch 10: strncpy() removed from kernel in 7.2 — compat shim added directly in rwnx_compat.h
    # Patch 11: remain_on_channel gained const u8 *rx_addr param (Linux 7.2)
    substituteInPlace drivers/aic8800/aic8800_fdrv/rwnx_main.c \
      --replace-fail \
        '                                unsigned int duration, u64 *cookie)
{
	return rwnx_cfg80211_remain_on_channel_(wiphy,' \
        '                                unsigned int duration, u64 *cookie
#if LINUX_VERSION_CODE >= KERNEL_VERSION(7, 2, 0)
                                , const u8 *rx_addr
#endif
                                )
{
	return rwnx_cfg80211_remain_on_channel_(wiphy,'

    # Patch 12: Suppress upstream vendor driver warnings
    # -Wmissing-prototypes: vendor code lacks forward declarations throughout
    # -Wimplicit-fallthrough: EXTRA_CFLAGS not picked up in modern kernel build system
    # -Woverflow/-Wunused-*: in BT code (aicbluetooth.c) which is not functional
    echo 'ccflags-y += -Wno-missing-prototypes -Wno-missing-declarations -Wno-implicit-fallthrough -Wno-attribute-warning' \
      >> drivers/aic8800/aic8800_fdrv/Makefile
    echo 'ccflags-y += -Wno-missing-prototypes -Wno-missing-declarations -Wno-overflow -Wno-unused-variable -Wno-unused-function -Wno-implicit-fallthrough' \
      >> drivers/aic8800/aic_load_fw/Makefile

    echo "Patches applied successfully"
  '';

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

    # Install firmware files (uncompressed for the driver to load them)
    mkdir -p $out/lib/firmware
    cp -r ../../fw/aic8800D80 $out/lib/firmware/

    runHook postInstall
  '';

  meta = with lib; {
    description = "Linux kernel driver for AIC8800D80 WiFi 6 chipset";
    longDescription = ''
      Kernel driver for AIC8800D80 WiFi 6 chipset with NixOS-specific patches.

      This driver supports USB WiFi adapters based on the AIC8800D80 chipset,
      such as Tenda U11 and AX913B. It provides WiFi 6 (802.11ax) functionality.

      The package includes patches to work correctly with NixOS's firmware
      management system, fixing hardcoded paths and firmware loading issues.

      Note: Bluetooth functionality is not currently supported.
    '';
    homepage = "https://github.com/kurumeii/aic8800-nix";
    license = licenses.gpl2Only;
    platforms = platforms.linux;
  };
}
