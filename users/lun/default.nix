{ lib, pkgs, lun-profiles, ... }:
{
  imports = [
    ./modern-unix.nix
    ./shells
    ./on-nixos
  ] ++ lib.optionals lun-profiles.graphical [
    ./gui
  ];

  manual.manpages.enable = false;
  programs.man.enable = false;
  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = "lun";
  home.homeDirectory = "/home/lun";

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "21.11";

  home.packages = with pkgs; [
    # Nice to have these on path especially since
    # can't nix run pkgs#usbutils and get lsusb!
    usbutils
    pciutils
    nixpkgs-fmt
    nixpkgs-review
    nixpkgs-hammering
    unar
    unzip
    p7zip
    git-filter-repo
  ];

  programs.git = {
    enable = true;
    lfs = {
      enable = true;
    };
    userName = "Luna Nova";
    userEmail = "git@lunnova.dev";
    extraConfig = {
      checkout.defaultRemote = "origin";
      core.eol = "lf";
      gpg.format = "ssh";
      commit.gpgsign = true;
      user.signingkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJZjpZ0wdmXwnVycJw8abOpspCbfWwDDm9WA8L/k9AID lun_signing_2021-12-21";
      diff.colorMoved = "zebra";
      fetch.prune = true;
      init.defaultBranch = "main";
      rebase.autostash = true;
      rebase.autoSquash = true;
      pull.rebase = true;
      push.autoSetupRemote = true;
      merge.tool = "vscode";
      merge.conflictStyle = "diff3";
      diff.tool = "vscode";
      mergeTool = {
        keepBackup = false;
        vscode.cmd = "code --wait --new-window $MERGED";
      };
      difftool.vscode.cmd = "code --wait --new-window --diff $LOCAL $REMOTE";
      include.path = "./local";
    };
  };

  programs.nix-index.enable = true;

  # FIXME: makes firefox open blank window?
  # systemd.user.startServices = "sd-switch";
}
