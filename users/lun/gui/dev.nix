{ pkgs, lib, flakeArgs, lun-profiles, ... }:
let
  sshAddDefault = pkgs.writeShellApplication {
    name = "sshAddDefault";
    text = ''
      [[ -d ~/.ssh ]] || exit 0
      if [[ -z "''${SSH_AUTH_SOCK:-}" ]]; then
        export SSH_AUTH_SOCK=$XDG_RUNTIME_DIR/ssh-agent
      fi
      cd ~/.ssh
      for file in id_*; do
        if ! [[ $file =~ .*\.pub$ ]]; then
          ssh-add "$file"
        fi
      done
    '';
  };
in
{
  config = {
    home.packages = with pkgs; [
      nix-output-monitor
      glxinfo
      vulkan-tools
      nixd
      #rehex
      imhex
      meld # graphical diff, lets you paste in pretty easily
      nurl # nix-prefetch-url but better
    ] ++ lib.optionals lun-profiles.personal [
      flakeArgs.deploy-rs.packages.${pkgs.system}.default
      # waylandn't
      # pkgs.lun.compositor-killer # FIXME: wayland-scanner not found
      lun.cursorai
    ] ++ lib.optionals (pkgs.system == "x86_64-linux") [
      # FIXME: these don't work well non-fsh
      # jetbrains.idea-ultimate
      # jetbrains.rust-rover
    ];

    programs.vscode = {
      enable = true;
      package = pkgs.vscode.fhs;
      extensions = with pkgs.vscode-extensions; [
        flakeArgs.alicorn-vscode-extension.packages.${pkgs.system}.alicorn-vscode-extension
      ];
    };

    services.ssh-agent.enable = true;

    systemd.user.services.ssh-agent-add-keys = {
      Install.WantedBy = [ "graphical-session.target" ];
      Unit.Wants = [ "ssh-agent.service" ];
      Service.ExecStart = "${lib.getExe sshAddDefault}";
    };
  };
}
