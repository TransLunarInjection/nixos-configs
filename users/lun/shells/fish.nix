{ pkgs, ... }:
{
  # this must also be done in system
  programs.fish.enable = true;

  home.file = {
    ".config/fish/functions/fish_greeting.fish".text = ''
      function fish_greeting;end
    '';
    ".config/fish/functions/up-or-search.fish".source = ./functions/up-or-search.fish;
    ".config/fish/functions/fish_prompt.fish".source = ./fish_prompt.fish;
    ".config/fish/functions/fish_right_prompt.fish".text = ''
      function fish_right_prompt
          set -l st $status
          set -l nsi (${pkgs.any-nix-shell}/bin/nix-shell-info)

          if [ $nsi ]
            echo $nsi
          end

          if [ $st != 0 ]
            echo (set_color $theme_color_error) ↵ $st(set_color $theme_color_normal)
          end
      end
    '';

    ".config/fish/conf.d/ssh-agent.fish".source = ./ssh_agent.fish;

    ".config/fish/conf.d/direnv.fish".text = ''
      eval (pushd /; ${pkgs.direnv}/bin/direnv hook fish; popd;)
    '';

    ".config/fish/conf.d/any-nix-shell.fish".text = ''
      ${pkgs.any-nix-shell}/bin/any-nix-shell fish | source
    '';

    # global fish config
    ".config/fish/conf.d/lun.fish".text = ''
      set -gx EDITOR vim
      history --save
      history --merge
      function history_exit_handler --on-event fish_exit
        history --save
        history --merge
      end
    '';

    ".config/fish/conf.d/colors.fish".text = ''
      switch $TERM
        case '*xte*'
          set -gx TERM xterm-256color
        case '*scree*'
          set -gx TERM screen-256color
        case '*rxvt*'
          set -gx TERM rxvt-unicode-256color
      end
    '';

    ".config/fish/conf.d/gpg.fish".text = ''
      # Set GPG TTY
      set -x GPG_TTY (tty)
    '';
  };

  home.packages = [ pkgs.fishPlugins.foreign-env ];

  programs.fish.shellAliases = {
    tm = "tmux new-session -A -s main";
  };
}
