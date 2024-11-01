{ pkgs, lib, flakeArgs, lun-profiles, ... }:
{
  imports = [
    ./i3
    ./cad
    ./sway
    # ./conky.nix # TODO: perf issues
    ./dev.nix
    ./file-management.nix
    ./xdg-mime-apps.nix
  ] ++ lib.optionals (lun-profiles.personal or false) [
    ./music.nix
    ./syncthing.nix
    ./discord.nix
    ./media
  ] ++ lib.optionals (lun-profiles.gaming or false) [
    ./gaming.nix
    ./vr-gaming.nix
  ];

  config = {
    home.sessionVariables = {
      GTK_DEBUG = "portals";
      GTK_USE_PORTAL = "1";
    };

    programs.firefox = {
      enable = true;
      package = pkgs.firefox-bin;
    };

    # workaround https://github.com/nix-community/home-manager/issues/2064#issuecomment-887300055
    systemd.user.targets.tray = {
      Unit = {
        Description = "Home Manager System Tray";
        Requires = [ "graphical-session-pre.target" ];
      };
    };

    home.packages = lib.optionals (lun-profiles.personal or false) (with pkgs; [
      pinta # paint.net alternative
      flakeArgs.nixpkgs-stable.legacyPackages.${pkgs.system}.calibre
      (flakeArgs.plover-flake.packages.${pkgs.system}.plover.with-plugins
        (ps: with ps; [
          plover-console-ui
        ])
      )
      ark
    ] ++ lib.optionals (pkgs.system == "x86_64-linux") [
      lun.wally
      microsoft-edge
    ]);
  };
}
