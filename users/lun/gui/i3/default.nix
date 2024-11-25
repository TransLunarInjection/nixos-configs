{ config, lib, pkgs, flakeArgs, ... }:
# https://github.com/berbiche/dotfiles/blob/df1cf43f9f7b267e7b4bf3a9e6cc8e4b4defb680/profiles/i3/home-manager/i3-config.nix#L4
#
# TODO: eww from https://github.com/FlafyDev/nixos-config/blob/fd7bbff67dfaf056a56d028a9e434722e400fa88/configs/eww/hm-custom-eww.nix
# TODO: screen locking and idle from https://old.reddit.com/r/i3wm/comments/e6jife/locking_screen_on_lid_close/f9r7pc0/
let
  mod = "Mod4";
  drun = "${lib.getExe pkgs.rofi} -show run";
  menu = "${lib.getExe pkgs.rofi} -show combi";
  i3-screenshot = pkgs.writeShellScriptBin "i3-screenshot" ''
    path="$HOME/sync/screenshots/$(hostname)-$(date "+%Y-%m-%d %T").png" && ${lib.getExe pkgs.maim} --hidecursor -s "$path" && ${lib.getExe pkgs.xclip} -selection clipboard -t image/png "$path"
  '';
  fontNames = [
    "Liberation Mono"
    "Font Awesome 6 Free"
    "Font Awesome 6 Brands 8"
  ];
  fonts = {
    names = fontNames;
    size = 8.0;
  };
  i3-wp = pkgs.writeShellScriptBin "i3-wallpaper" ''
    if [ "$XDG_CURRENT_DESKTOP" = "none+i3" ]; then
      if [ -f ~/.fehbg ]; then
        exec ~/.fehbg
      else
        exec ${lib.getExe pkgs.feh} --bg-scale ~/sync/theming/wp/default/
      fi
    fi
  '';
  bgswitcher = flakeArgs.background-switcher.packages.${pkgs.system}.switcher;
  bgswitchermenu = pkgs.writeScriptBin "rofi-background-switcher" ''
    ${pkgs.rofi}/bin/rofi -show background -modes "background:${bgswitcher}/bin/background-switcher"
  '';
in
{
  xdg.configFile."i3wsr/config.toml".text = ''
    [icons]
    firefox = ""
    Emacs = ""
    kitty = ""
    ArmCord = ""
  '';
  xdg.configFile."random-background/config.toml".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/sync/theming/background-switcher.toml";
  home.packages = [
    pkgs.lm_sensors
    pkgs.i3status-rust
    pkgs.i3wsr
    pkgs.feh
    pkgs.kitty # add to path sice we use it as meta-enter
    i3-wp
    i3-screenshot
    bgswitchermenu
  ];
  xsession.windowManager.i3 = {
    enable = true;
    config = {
      inherit fonts;

      modifier = mod;

      keybindings = config.wayland.windowManager.sway.config.keybindings // {
        "Print" = "exec ${lib.getExe i3-screenshot}";
        "${mod}+x" = "exec sh -c '${lib.getExe pkgs.maim} -s | ${lib.getExe pkgs.xclip} -selection clipboard -t image/png'";
        "${mod}+q" = "exec sh -c '${lib.getExe pkgs.i3lock} -c ba9bff & sleep 2 && ${lib.getExe pkgs.xorg.xset} dpms force off'";
        "${mod}+Return" = "exec ${lib.getExe pkgs.kitty}";
        "${mod}+space" = "exec ${drun}";
        "${mod}+d" = "exec ${menu}";
        "${mod}+i" = "bar hidden_state toggle";
        "${mod}+Shift+b" = "exec ${lib.getExe bgswitchermenu}";
        "${mod}+Shift+r" = "restart";

        "XF86KbdBrightnessUp" = "exec ${lib.getExe pkgs.brightnessctl} -d '*kbd*' set +40%";
        "XF86KbdBrightnessDown" = "exec ${lib.getExe pkgs.brightnessctl} -d '*kbd*' set 40%-";
        "XF86MonBrightnessUp" = "exec ${lib.getExe pkgs.brightnessctl} set +5%";
        "XF86MonBrightnessDown" = "exec ${lib.getExe pkgs.brightnessctl} set 5%-";
      };

      startup = [
        {
          command = "${lib.getExe i3-wp}";
          notification = false;
        }
        {
          command = "${lib.getExe pkgs.i3wsr} --icons awesome -r -m";
          notification = false;
        }
      ];

      bars = [
        {
          inherit fonts;
          position = "top";
          #mode = "hide";
          statusCommand = "${pkgs.i3status-rust}/bin/i3status-rs ~/.config/i3status-rust/config-default.toml";
        }
      ];
    };
    # Start menu style drun on release
    extraConfig = ''
      bindcode --release 133 exec --no-startup-id ${drun}
    '';
  };
  # ref https://github.com/workflow/nixos-config/blob/e559dbb5ce560084ce9249dd6febe721cb512d10/home/i3status-rust.nix#L76
  programs.i3status-rust = {
    enable = true;
    bars.default = {
      settings.theme.theme = "solarized-dark";
      settings.icons.icons = "awesome6";
      blocks = [
        {
          block = "custom";
          command = "${
              flakeArgs.i3status-nix-update-widget.packages.${pkgs.system}.default.override {
                flakelock = "${flakeArgs.self}/flake.lock";
              }
            }/bin/i3status-nix-update-widget";
          interval = 3000;
          json = true;
        }
        {
          block = "custom";
          command = "cat /etc/hostname";
          interval = "once";
        }
        { block = "memory"; }
        { block = "cpu"; }
        {
          block = "net";
          interval = 5;
          format = " $icon {$signal_strength $ssid $frequency|} ";
          format_alt = " $icon {$signal_strength $ssid $frequency|Wired connection} via $device ";
        }
        {
          block = "time";
          interval = 10;
          format = " $icon $timestamp.datetime(f:'%F %R') ";
        }
        {
          block = "battery";
          format = " {$icon $percentage|} {$time |}";
        }
        { block = "backlight"; }
        { block = "sound"; }
      ];
    };
  };
}
