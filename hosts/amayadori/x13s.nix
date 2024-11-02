{ config, options, flakeArgs, lib, pkgs, ... }:
# Hi! This is the Thinkpad X13s specific part of my NixOS config.
# I daily drive it when I'm travelling but it's not without issues.
# See https://github.com/jhovold/linux/wiki/X13s for non distro specific info
let
  useGrub = false;
  inherit (config.lun.x13s) useGpu;
  useGpuFw = config.lun.x13s.useGpu;
  kernelVersion = "6.9.10";
  dtbName = "x13s${kernelVersion}.dtb";
  modDirVersion = "${kernelVersion}";
  kernelSrc = {
    owner = "steev";
    repo = "linux";
    version = kernelVersion;
    rev = "259251ae5050a837ca7be8228f2280d0932bcfba";
    hash = "sha256-wA+7/H6hs2TTUNCRVJGy3F9a6kzuOffzG8x+6qufryQ=";
  };
  # When on use the in-kernel QCOM_PD_MAPPER module instead of
  # userspace. Avoids some workarounds to make sure the userspace one has access to uncompressed firmware
  # Doesn't seem to be working right yet though, need to investigate.
  kernelPdMapper = false;
  kernelOpts = {
    Y = lib.mkForce lib.kernel.yes;
    N = lib.mkForce lib.kernel.no;
    M = lib.mkForce lib.kernel.module;
  };
  remove-dupe-fw = ''
    pushd ${pkgs.linux-firmware}
    shopt -s extglob
    shopt -s globstar
    for file in */**; do
      if [ -f "$file" ] && [ -f "$out/$file" ]; then
        echo "Duplicate file $file"
        rm -fv "$out/$file"
      fi
    done
    popd
  '';
  kp = [
    {
      name = "x13s-cfg";
      patch = null;
      extraStructuredConfig = with kernelOpts; {
        EFI_ARMSTUB_DTB_LOADER = Y;
        OF_OVERLAY = Y;
        BTRFS_FS = Y;
        BTRFS_FS_POSIX_ACL = Y;
        SND_USB = Y;
        SND_USB_AUDIO = M;
        NO_HZ_FULL = Y;
        HZ_100 = Y;
        HZ_250 = N;
        DRM_AMDGPU = N;
        DRM_NOUVEAU = N;
        QCOM_TSENS = Y;
        NVMEM_QCOM_QFPROM = Y;
        ARM_QCOM_CPUFREQ_NVMEM = Y;
        MEDIA_CONTROLLER = Y;
        SND_USB_AUDIO_USE_MEDIA_CONTROLLER = Y;
        # linux> ../drivers/media/i2c/ar1337.c: In function 'ar1337_get_fmt':
        # linux> ../drivers/media/i2c/ar1337.c:349:68: error: passing argument 2 of 'v4l2_subdev_get_pad_format' from incompatible pointer type [-Werror=incompatible-pointer-types]
        # VIDEO_AR1337 = N;
      } // lib.optionalAttrs kernelPdMapper {
        QCOM_PD_MAPPER = M;
        QRTR = M;
      };
    }
    # {
    #   name = "x13s-hotter-revert";
    #   patch = ./x13s-hotter-revert.patch;
    # }
  ];
  linux_x13s_pkg = { buildLinux, ... } @ args:
    buildLinux (args // {
      inherit modDirVersion;
      name = "x13s-linux-${modDirVersion}";
      version = kernelVersion;

      # https://github.com/steev/linux/tree/lenovo-x13s-v6.7.0-rc8
      src = pkgs.fetchFromGitHub ({
        name = "src-x13s-linux";
      } // kernelSrc);
      kernelPatches = (args.kernelPatches or [ ]) ++ kp;

      extraMeta.branch = "6.7";
    } // (args.argsOverride or { }));

  linux_x13s = pkgs.callPackage linux_x13s_pkg {
    defconfig = "johan_defconfig";
  };

  linuxPackages_x13s = pkgs.linuxPackagesFor linux_x13s;
  dtb = "${linuxPackages_x13s.kernel}/dtbs/qcom/sc8280xp-lenovo-thinkpad-x13s.dtb";
  inherit (config.boot.loader) efi;

  # nurl https://git.codelinaro.org/clo/ath-firmware/ath11k-firmware.git
  ath11k_fw_src = pkgs.fetchgit {
    name = "ath11k-firmware-src";
    url = "https://git.codelinaro.org/clo/ath-firmware/ath11k-firmware.git";
    rev = "bb527dcebac835c47ed4f5428a7687769fa9b1b2";
    hash = "sha256-p6ifwtRNUOyQ2FN2VhSXS6dcrvrtiFZawu/iVXQ4uR0=";
  };

  x13s-tplg = pkgs.fetchgit {
    name = "x13s-tplg-audioreach-topology";
    url = "https://git.linaro.org/people/srinivas.kandagatla/audioreach-topology.git";
    rev = "1ade4f466b05a86a7c7bdd51f719c08714580d14";
    hash = "sha256-GFGcm+KicTfNXSY8oMJlqBkrjdyb05C65hqK0vfCQvI=";
  };
  # nurl https://github.com/linux-surface/aarch64-firmware
  aarch64-fw = pkgs.fetchFromGitHub {
    name = "aarch64-fw-src";
    owner = "linux-surface";
    repo = "aarch64-firmware";
    rev = "9f07579ee64aba56419cfd0fbbca9f26741edc90";
    hash = "sha256-Lyav0RtoowocrhC7Q2Y72ogHhgFuFli+c/us/Mu/Ugc=";
  };

  ath11k_fw = pkgs.runCommandNoCC "ath11k_fw" { } ''
    mkdir -p $out/lib/firmware/ath11k/
    cp -r --no-preserve=mode,ownership ${ath11k_fw_src}/* $out/lib/firmware/ath11k/

    ${remove-dupe-fw}
  '';
  cenunix_fw_src = pkgs.fetchzip {
    url = "https://github.com/cenunix/x13s-firmware/releases/download/1.0.0/x13s-firmware.tar.gz";
    sha256 = "sha256-cr0WMKbGeJyQl5S8E7UEB/Fal6FY0tPenEpd88KFm9Q=";
    stripRoot = false;
  };
  x13s_extra_fw = pkgs.runCommandNoCC "x13s_extra_fw" { } ''
    mkdir -p $out/lib/firmware/qcom/sc8280xp/
    # mkdir -p $out/lib/firmware/qca/

    pushd "${cenunix_fw_src}"
    mkdir -p $out/lib/firmware/qcom/sc8280xp/LENOVO/21BX
    mkdir -p $out/lib/firmware/qca
    mkdir -p $out/lib/firmware/ath11k/WCN6855/hw2.0/
    # cp -v my-repo/a690_gmu.bin $out/lib/firmware/qcom
    cp -v my-repo/qcvss8280.mbn $out/lib/firmware/qcom/sc8280xp/LENOVO/21BX
    # cp -v my-repo/SC8280XP-LENOVO-X13S-tplg.bin $out/lib/firmware/qcom/sc8280xp
    cp -v my-repo/hpnv21.8c $out/lib/firmware/qca/hpnv21.b8c
    # cp -v my-repo/board-2.bin $out/lib/firmware/ath11k/WCN6855/hw2.0
    popd

    cp ${x13s-tplg}/prebuilt/qcom/sc8280xp/LENOVO/21BX/audioreach-tplg.bin $out/lib/firmware/qcom/sc8280xp/SC8280XP-LENOVO-X13S-tplg.bin
    cp -r --no-preserve=mode,ownership ${x13s-tplg}/prebuilt/* $out/lib/firmware/
    ${lib.optionalString useGpuFw ''
      # cp -r ${aarch64-fw}/firmware/qca/* $out/lib/firmware/qca/
      cp -r --no-preserve=mode,ownership ${aarch64-fw}/firmware/qcom/* $out/lib/firmware/qcom/
    ''}

    ${remove-dupe-fw}
  '';
  # see https://github.com/szclsya/x13s-alarm
  pd-mapper = (pkgs.callPackage "${flakeArgs.mobile-nixos}/overlay/qrtr/pd-mapper.nix" { inherit qrtr; }).overrideAttrs (_old: {
    # TODO: use newer version and fix patch
    # src = pkgs.fetchFromGitHub {
    #   owner = "andersson";
    #   repo = "pd-mapper";
    #   rev = "107104b20bccc1089ba46893e64b3bdcb98c6830";
    #   hash = "sha256-ypLS/g1FNi2vzIYkIoml2FkMM1Tc8UrRRhWaYbwpwkc=";
    # };
  });
  qrtr = pkgs.callPackage "${flakeArgs.mobile-nixos}/overlay/qrtr/qrtr.nix" { };
  qmic = pkgs.callPackage "${flakeArgs.mobile-nixos}/overlay/qrtr/qmic.nix" { };
  rmtfs = pkgs.callPackage "${flakeArgs.mobile-nixos}/overlay/qrtr/rmtfs.nix" { inherit qmic qrtr; };
  uncompressed-fw = pkgs.callPackage
    ({ runCommand, buildEnv, firmwareFilesList }:
      runCommand "qcom-modem-uncompressed-firmware-share"
        {
          firmwareFiles = buildEnv {
            name = "qcom-modem-uncompressed-firmware";
            paths = firmwareFilesList;
            pathsToLink = [
              "/lib/firmware/rmtfs"
              "/lib/firmware/qcom"
            ];
          };
        } ''
        PS4=" $ "
        (
        set -x
        mkdir -p $out/share/
        ln -s $firmwareFiles/lib/firmware/ $out/share/uncompressed-firmware
        )
      '')
    {
      # We have to borrow the pre `apply`'d list, thus `options...definitions`.
      # This is because the firmware is compressed in `apply` on `hardware.firmware`.
      firmwareFilesList = lib.flatten options.hardware.firmware.definitions;
    };
in
{
  options = {
    lun.x13s = {
      useGpu = lib.mkEnableOption "enable a690 gpu" // { default = true; };
    };
  };

  config = {
    specialisation.no-gpu.configuration = {
      services.displayManager.sddm.wayland.enable = false;
      lun.x13s.useGpu = false;
    };

    hardware.firmware = [
      (lib.hiPrio ath11k_fw)
      (lib.lowPrio (x13s_extra_fw // { compressFirmware = false; }))
    ];

    environment.systemPackages = lib.mkIf (!kernelPdMapper) [ qrtr qmic rmtfs pd-mapper uncompressed-fw ];
    environment.pathsToLink = lib.mkIf (!kernelPdMapper) [ "share/uncompressed-firmware" ];

    hardware.opengl.package = lib.mkIf useGpu
      ((pkgs.mesa.override {
        galliumDrivers = [ "swrast" "freedreno" "zink" ];
        vulkanDrivers = [ "swrast" "freedreno" ];
      }).overrideAttrs (old: {
        mesonFlags = old.mesonFlags ++ [
          "-Dgallium-vdpau=disabled"
          "-Dgallium-va=disabled"
          "-Dandroid-libbacktrace=disabled"
        ];
        postPatch = ''
          ${old.postPatch}

          mkdir -p $spirv2dxil
          touch $spirv2dxil/dummy
        '';
      })).drivers;
    services.logind.extraConfig = ''
      HandlePowerKey=suspend
      HandleLidSwitch=lock
      HandleLidSwitchExternalPower=ignore
      HandleLidSwitchDocked=ignore
      IdleAction=ignore
    '';
    systemd.services = {
      # rmtfs = {
      #   wantedBy = [ "multi-user.target" ];
      #   requires = [ "qrtr-ns.service" ];
      #   after = [ "qrtr-ns.service" ];
      #   serviceConfig = {
      #     # https://github.com/andersson/rmtfs/blob/7a5ae7e0a57be3e09e0256b51b9075ee6b860322/rmtfs.c#L507-L541
      #     ExecStart = "${pkgs.rmtfs}/bin/rmtfs -s -r ${if rmtfsReadsPartition then "-P" else "-o /run/current-system/sw/share/uncompressed-firmware/rmtfs"}";
      #     Restart = "always";
      #     RestartSec = "1";
      #   };
      # };
      qrtr-ns = lib.mkIf (!kernelPdMapper) {
        serviceConfig = {
          ExecStart = "${qrtr}/bin/qrtr-ns -f 1";
          Restart = "always";
        };
      };
      pd-mapper = lib.mkIf (!kernelPdMapper) {
        wantedBy = [ "multi-user.target" ];
        requires = [ "qrtr-ns.service" ];
        after = [ "qrtr-ns.service" ];
        serviceConfig = {
          ExecStart = "${pd-mapper}/bin/pd-mapper";
          Restart = "always";
        };
      };
    };


    # https://dumpstack.io/1675806876_thinkpad_x13s_nixos.html
    boot = {
      loader.efi = {
        canTouchEfiVariables = lib.mkForce false;
        efiSysMountPoint = "/boot";
      };

      supportedFilesystems = lib.mkForce [ "ext4" "btrfs" "cifs" "f2fs" "jfs" "ntfs" "vfat" "xfs" ];
      initrd.supportedFilesystems = lib.mkForce [ "ext4" "btrfs" "vfat" ];
      consoleLogLevel = 9;
      kernelModules = [
        "snd_usb_audio"
        "msm"
      ] ++ lib.optionals kernelPdMapper [
        "qrtr"
        "qcom_pd_mapper"
      ];
      kernelPackages = lib.mkForce linuxPackages_x13s;
      kernelParams = [
        "pcie_aspm.policy=powersupersave"
        # "pcie_aspm=force"
        "boot.shell_on_fail"
        "clk_ignore_unused"
        "pd_ignore_unused"
        "arm64.nopauth"
        "efi=noruntime"
        # "cma=128M"
        "nvme.noacpi=1" # fixes high power after suspend resume
        "iommu.strict=0" # fixes some issues when using USB devices eg slow wifi
        # "iommu.passthrough=0"
      ] ++ lib.optionals (!useGrub) [
        "dtb=${dtbName}"
      ];
      initrd = {
        includeDefaultModules = false;
        kernelModules = [
          "i2c_hid"
          "i2c_hid_of"
          "i2c_qcom_geni"
          "leds_qcom_lpg"
          "pwm_bl"
          "qrtr"
          "pmic_glink_altmode"
          "gpio_sbu_mux"
          "phy_qcom_qmp_combo"
          "panel-edp"
          "phy_qcom_edp"
          "i2c-core"
          "i2c-hid"
          "i2c-hid-of"
          "i2c-qcom-geni"
          "pcie-qcom"
          "phy-qcom-qmp-combo"
          "phy-qcom-qmp-pcie"
          "phy-qcom-qmp-usb"
          "phy-qcom-snps-femto-v2"
          "phy-qcom-usb-hs"
          "nvme"
        ];
      };
    } // (if useGrub then {
      loader.grub.enable = true;
      loader.grub.device = "nodev";
      loader.grub.version = 2;
      loader.grub.efiSupport = true;
      loader.systemd-boot.enable = lib.mkForce false;
    } else {
      loader.systemd-boot.enable = true;
    });

    system.activationScripts.x13s-dtb = ''
      in_package="${dtb}"
      esp_tool_folder="${efi.efiSysMountPoint}/"
      in_esp="''${esp_tool_folder}${dtbName}"
      >&2 echo "Ensuring $in_esp in EFI System Partition"
      if ! ${pkgs.diffutils}/bin/cmp --silent "$in_package" "$in_esp"; then
        ls -l "$in_esp" || true
        >&2 echo "Copying $in_package -> $in_esp"
        mkdir -p "$esp_tool_folder"
        cp "$in_package" "$in_esp"
        sync
      fi
    '';
  };
}
