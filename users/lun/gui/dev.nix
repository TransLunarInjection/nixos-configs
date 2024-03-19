{ pkgs, flakeArgs, ... }:
{
  config = {
    home.packages = with pkgs; [
      nix-output-monitor
      glxinfo
      vulkan-tools
      # nixd # FIXME: relies on "nix-2.17.1" which is marked insecure
      rehex
      imhex
      meld # graphical diff, lets you paste in pretty easily
      nurl # nix-prefetch-url but better
      flakeArgs.deploy-rs.packages.${pkgs.system}.default
      # waylandn't
      pkgs.lun.compositor-killer
    ] ++ lib.optionals (pkgs.system == "x86_64-linux") [
      jetbrains.idea-ultimate
      jetbrains.rust-rover
    ];

    programs.vscode = {
      enable = true;
      package = pkgs.vscode.fhs;
      extensions = with pkgs.vscode-extensions; [
        flakeArgs.alicorn-vscode-extension.packages.${pkgs.system}.alicorn-vscode-extension
      ];
    };
  };
}
