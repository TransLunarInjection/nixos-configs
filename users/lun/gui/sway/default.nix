{ pkgs, lib, config, ... }:
let
  execSpawn = cmd: "exec ${pkgs.lun.spawn}/bin/spawn ${cmd}";
  bar = "${config.programs.waybar.package}/bin/waybar";
  drun = execSpawn "${pkgs.wofi}/bin/wofi --show drun";
  menu = execSpawn "${pkgs.wofi}/bin/wofi --show dmenu";
  screenshot = execSpawn "${pkgs.sway-contrib.grimshot}/bin/grimshot --notify copy area";
in
{
  imports = [
    ./waybar.nix
    ./swayidle.nix
  ];

  /*
    testing launch for multigpu nvidia&amd - needs more up to date sway/wlroots
    env \
    WLR_RENDERER=vulkan \
    GBM_BACKEND=nvidia-drm \
    __GLX_VENDOR_LIBRARY_NAME=nvidia \
    WLR_NO_HARDWARE_CURSORS=1 \
    WLR_DRM_DEVICES=/dev/dri/card0:/dev/dri/card1 \
    sway --unsupported-gpu 2> ~/dev/swaylog
  */

  # Borrowed significantly from https://github.com/lovesegfault/nix-config
  home.packages = [ pkgs.lun.spawn ];

  services.mako = {
    enable = true;
    sort = "+time";
    maxVisible = 10;
    layer = "overlay";
    borderRadius = 5;
  };

  wayland.windowManager.sway = {
    enable = true;
    # https://github.com/nix-community/home-manager/issues/5311
    # custom wallpaper breaks checkConfig
    checkConfig = false;
    # Use system sway
    package = null;
    config = {
      inherit menu;
      modifier = "Mod4";
      bars = [{ command = bar; }];

      keybindings =
        let
          up = "w";
          left = "a";
          down = "s";
          right = "d";
          inherit (config.wayland.windowManager.sway.config) modifier;
          inherit (config.wayland.windowManager.sway.config) terminal;
          pactl = "${pkgs.pulseaudio}/bin/pactl";
          pamixer = "${pkgs.pamixer}/bin/pamixer";
          alt = "Mod1";
        in
        lib.mkOptionDefault {
          "${modifier}+Return" = execSpawn terminal;
          "${modifier}+space" = drun;
          # "${modifier}+m" = execSpawn "${pkgs.emojimenu-wayland}/bin/emojimenu";
          # "${modifier}+o" = execSpawn "${pkgs.screenocr}/bin/screenocr";
          # "${modifier}+t" = execSpawn "${pkgs.otpmenu-wayland}/bin/otpmenu";
          # "${modifier}+p" = execSpawn "${pkgs.passmenu-wayland}/bin/passmenu";
          "${modifier}+q" = execSpawn "swaylock -f";
          "Print" = screenshot;
          "XF86AudioMute" = execSpawn "${pamixer} -t";
          "XF86AudioLowerVolume" = execSpawn "${pamixer} -d 5";
          "XF86AudioRaiseVolume" = execSpawn "${pamixer} -i 5";
          "Shift+XF86AudioRaiseVolume" = execSpawn "${pamixer} -i 5 --allow-boost";
          "XF86AudioMicMute" = execSpawn "${pactl} set-source-mute @DEFAULT_SOURCE@ toggle";
          # move workspace to output
          "${modifier}+Control+Shift+${left}" = "move workspace to output left";
          "${modifier}+Control+Shift+${right}" = "move workspace to output right";
          "${modifier}+Control+Shift+${up}" = "move workspace to output up";
          "${modifier}+Control+Shift+${down}" = "move workspace to output down";
          # move workspace to output with arrow keys
          "${modifier}+Control+Shift+Left" = "move workspace to output left";
          "${modifier}+Control+Shift+Right" = "move workspace to output right";
          "${modifier}+Control+Shift+Up  " = "move workspace to output up";
          "${modifier}+Control+Shift+Down" = "move workspace to output down";
          "${modifier}+Control+${alt}+Shift+Q" = "exec swaymsg -t get_tree | ${pkgs.jq}/bin/jq 'recurse(.nodes[], .floating_nodes[]) | select(.focused).pid' | xargs -L 1 kill -9";
          # FIXME: pick another editor for these
          # "${modifier}+${alt}+s" = ''
          #   exec emacsclient -c "~/sync/dev/scratch/$(date +%Y-%m)/$(date +%F).txt"'';
          # "${modifier}+${alt}+d" = ''
          #   exec emacsclient -c "~/sync/org/diary/$(date +%Y-%m)/log_$(date +%F).txt"'';
        };


      output = {
        "*" = {
          scale = "1";
          bg = "${config.xdg.dataHome}/wall.png fill #0a0a0a";
        };
      };

      terminal = "${config.programs.foot.package}/bin/foot";

      window.commands = [
        { command = "floating enable"; criteria.app_id = "imv"; }
      ];
    };

    extraConfig = ''
      include /etc/sway/config.d/*

      input type:touchpad {
        tap disabled
        natural_scroll disabled
      }
      input type:pointer {
        accel_profile flat
      }
      exec_always pkill kanshi; exec kanshi &> $XDG_RUNTIME_DIR/kanshi.log
    '';

    # export FREETYPE_PROPERTIES=truetype:interpreter-version=35
    # TODO doesn't do anything when using null/system sway package
    extraSessionCommands = ''
      export ECORE_EVAS_ENGINE=wayland_egl
      export ELM_ENGINE=wayland_egl
      export MOZ_ENABLE_WAYLAND=1
      export GDK_BACKEND=wayland
      export QT_QPA_PLATFORM=xcb
      export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
      export QT_WAYLAND_FORCE_DPI=physical
      export SDL_VIDEODRIVER=wayland
      export XDG_CURRENT_DESKTOP="sway"
      export _JAVA_AWT_WM_NONREPARENTING=1
    '';

    systemd.enable = true;
  };

  # systemd.user.services.sway-inactive-windows-transparency =
  #   let
  #     inherit (pkgs.sway-contrib) inactive-windows-transparency; in
  #   {
  #     Unit = {
  #       Description = "Set opacity of onfocused windows in SwayWM";
  #       PartOf = "graphical-session.target";
  #       StartLimitIntervalSec = "0";
  #     };
  #     Service = {
  #       Type = "simple";
  #       ExecStart = ''
  #         ${inactive-windows-transparency}/bin/inactive-windows-transparency.py -o 0.9
  #       '';
  #       Restart = "on-failure";
  #       RestartSec = "1";
  #     };
  #     Install = { WantedBy = [ "sway-session.target" ]; };
  #   };

  systemd.user.services = {
    mako = {
      Unit = {
        Description = "A lightweight Wayland notification daemon";
        Documentation = "man:mako(1)";
        PartOf = "graphical-session.target";
      };
      Service = {
        Type = "simple";
        Restart = "always";
        ExecStart = "${pkgs.mako}/bin/mako";
      };
      Install = { WantedBy = [ "sway-session.target" ]; };
    };
    polkit-agent = {
      Unit = {
        Description = "polkit-gnome-authentication-agent-1";
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
        Restart = "on-failure";
        RestartSec = 1;
        TimeoutStopSec = 10;
      };
      Install = { WantedBy = [ "sway-session.target" ]; };
    };
  };

  # home.file.".config/sway/config".text = ''
  #   set $mod Mod4
  #   set $menu dmenu_path | wofi --dmenu | xargs swaymsg exec --
  #   bindsym $mod+Space exec $menu
  # '';
}
