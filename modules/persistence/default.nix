# Based off setup from github:buckley310/nixos-config although has diverged now
{ config, lib, ... }:
let
  cfg = config.lun.persistence;
  inherit (config.lun.persistence) persistPath;
  addCheckDesc = desc: elemType: check: lib.types.addCheck elemType check
    // { description = "${elemType.description} (with check: ${desc})"; };
  isNonEmpty = s: (builtins.match "[ \t\n]*" s) == null;
  absolutePathWithoutTrailingSlash = addCheckDesc "absolute path without trailing slash" lib.types.str
    (s: isNonEmpty s && (builtins.match "/.+/" s) == null);
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

    fileSystems =
      let pathToFilesystem = name: { inherit name; value = { device = "${persistPath}${name}"; noCheck = true; neededForBoot = true; options = [ "bind" ]; }; };
      in builtins.listToAttrs (builtins.map pathToFilesystem cfg.dirs);
  };
}
