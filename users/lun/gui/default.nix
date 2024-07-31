{ pkgs, lib, flakeArgs, lun-profiles, ... }:
{
  imports = [
    ./i3
    ./media
    ./cad
    ./sway
    # ./conky.nix # TODO: perf issues
    ./dev.nix
    ./discord.nix
    ./file-management.nix
    ./music.nix
    ./syncthing.nix
    ./vr-gaming.nix
    ./xdg-mime-apps.nix
  ] ++ lib.optionals (lun-profiles.gaming or false) [
    ./gaming.nix
  ];

  config = {
    home.sessionVariables = {
      GTK_DEBUG = "portals";
      GTK_USE_PORTAL = "1";
    };

    programs.firefox = {
      enable = true;
      package = pkgs.firefox.overrideAttrs (old: {
        postFixup = ''
          ${old.postFixup or ""}
          wrapProgram "$out/bin/firefox" --set GTK_USE_PORTAL 1 --set GTK_DEBUG portals --set MOZ_ENABLE_WAYLAND 1
        '';
      });
    };

    # workaround https://github.com/nix-community/home-manager/issues/2064#issuecomment-887300055
    systemd.user.targets.tray = {
      Unit = {
        Description = "Home Manager System Tray";
        Requires = [ "graphical-session-pre.target" ];
      };
    };

    home.packages = with pkgs; [
      pinta # paint.net alternative
      calibre
      (flakeArgs.plover-flake.packages.${pkgs.system}.plover.with-plugins
        (ps: with ps; [
          plover-console-ui
        ])
      )
      ark
    ] ++ lib.optionals (pkgs.system == "x86_64-linux") [
      lun.wally
      microsoft-edge
    ];
  };
}
