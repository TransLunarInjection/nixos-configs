# Based off setup from github:buckley310/nixos-config although has diverged now
{ config, lib, utils, ... }:
let
  cfg = config.lun.persistence;
  inherit (config.lun.persistence) persistPath;
  addCheckDesc = desc: elemType: check: lib.types.addCheck elemType check
    // { description = "${elemType.description} (with check: ${desc})"; };
  isNonEmpty = s: (builtins.match "[ \t\n]*" s) == null;
  absolutePathWithoutTrailingSlash = addCheckDesc "absolute path without trailing slash" lib.types.str
    (s: isNonEmpty s && (builtins.match "/.+/" s) == null);
  directories = config.lun.persistence.dirs;
  persistentStoragePaths = lib.unique directories;
  all = config.fileSystems; # // config.virtualisation.fileSystems;
  getDevice = fs: if fs.device != null then fs.device else "/dev/disk/by-label/${fs.label}";
  matchFileSystems = fs: lib.attrValues (lib.filterAttrs (_: v: v.mountPoint or null == fs) all);
  fileSystems = lib.concatMap matchFileSystems persistentStoragePaths;
  deviceUnits = lib.unique
    (map
      (fs:
        if fs.fsType == "zfs" then
          "zfs-import.target"
        else
          "${(utils.escapeSystemdPath (getDevice fs))}.device")
      (lib.filter (fs: fs.neededForBoot && !(builtins.elem "bind" fs.options)) (builtins.attrValues config.fileSystems)));

  createNeededForBootDirs = ''
    for bdir in ${builtins.concatStringsSep " " cfg.dirs}; do
      if [ -d /sysroot/persist ]; then
        echo mkdir -p "/sysroot/persist$bdir"
        mkdir -p "/sysroot/persist$bdir"
      else
        echo "Can't create /sysroot/persist$bdir because sysroot not mounted!!!"
      fi
    done
  '';
in
{
  options.lun.persistence = {
    enable = lib.mkEnableOption "Enable persistence module for tmpfs on root";

    persistPath = lib.mkOption {
      type = absolutePathWithoutTrailingSlash;
      default = "/persist";
    };

    files = lib.mkOption {
      type = with lib.types; listOf absolutePathWithoutTrailingSlash;
      default = [ ];
    };

    dirs = lib.mkOption {
      type = with lib.types; listOf absolutePathWithoutTrailingSlash;
      default = [ ];
    };

    # Intended for use with
    # nix eval --raw .#nixosConfigurations.(hostname).config.lun.persistence.dirs_for_shell_script
    # to iterate over dirs that need created in /persist
    dirs_for_shell_script = lib.mkOption {
      type = with lib.types; str;
      default = "";
    };
  };

  config = lib.mkIf cfg.enable {
    lun.persistence.dirs_for_shell_script = builtins.concatStringsSep "\n" cfg.dirs;

    # Don't bother with the lecture or the need to keep state about who's been lectured
    security.sudo.extraConfig = "Defaults lecture=\"never\"";

    lun.persistence.dirs = [
      "/var/log"
      "/var/tmp"
      "/root" # https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=962987 >:(
      "/home"
      "/etc/NetworkManager"
    ];

    lun.persistence.files = [
      "/etc/adjtime"
    ];

    systemd.tmpfiles.rules =
      let escapedFiles = builtins.map (lib.escape [ "\"" "\\" ]) cfg.files;
      in
      builtins.map (path: "L+ \"${path}\" - - - - ${persistPath}${path}") escapedFiles;
    # services.journald.extraConfig = ''
    #     ForwardToConsole=yes
    #     MaxLevelConsole=debug
    #   '';
    boot.initrd = lib.mkIf config.boot.initrd.systemd.enable {
      #systemd.enable = true;
      systemd.managerEnvironment = { SYSTEMD_LOG_LEVEL = "info"; };
      systemd.contents."/etc/systemd/journald.conf".text = ''
        [Journal]
        ForwardToConsole=yes
        MaxLevelConsole=info
      '';
      systemd.extraConfig = ''
        StatusUnitFormat=combined
        LogLevel=info
        DefaultTimeoutStartSec=30
      '';
      systemd.services = {
        create-persist-dirs = {
          wantedBy = [ "initrd-root-device.target" ];
          # requires = deviceUnits;
          # after = deviceUnits;
          requires = [ "sysroot-persist.mount" ] ++ deviceUnits;
          after = [ "sysroot-persist.mount" ] ++ deviceUnits;
          serviceConfig.Type = "oneshot";
          unitConfig.DefaultDependencies = false;
          script = createNeededForBootDirs;
        };
      };
      # postDeviceCommands = lib.mkIf (!config.boot.initrd.systemd.enable)
      #   (lib.mkAfter createNeededForBootDirs);
    };

    fileSystems =
      let
        pathToFilesystem = name: {
          inherit name;
          value = {
            device = "${persistPath}${name}";
            # fsType = "none";
            noCheck = true;
            neededForBoot = true;
            # depends = [ "${persistPath}" ];
            options = [
              "bind"
              # "x-systemd.requires-mounts-for=${persistPath}"
              #"x-systemd.requires=create-persist-dirs"
              # "x-systemd.requires-mounts-for=/sysroot${persistPath}"
              # "x-systemd.requires=/sysroot${persistPath}"
              # "x-systemd.automount"
              # "X-fstrim.notrim"
              # "x-gvfs-hide"
              #"nofail"
              #  "x-systemd.device-timeout=5s"
              #  "x-systemd.mount-timeout=5s"
            ];
          };
        };
      in
      builtins.listToAttrs (builtins.map pathToFilesystem cfg.dirs);
  };
}
