{ pkgs, lib, ... }:
let
  useSvp = false; #pkgs.system == "x86_64-linux";
  mpv-unwrapped = pkgs.mpv-unwrapped.override { vapoursynthSupport = true; };
  mpv = pkgs.mpv.override { mpv = mpv-unwrapped; };
in
{
  config = lib.mkMerge [
    {
      home.packages = (with pkgs; [
        vlc
        smplayer
        yt-dlp
      ]) ++ lib.optional (!useSvp) pkgs.mpv;
    }
    (lib.mkIf useSvp {
      home.packages = [ mpv ];
      home.file.".config/mpv/motioninterpolation.py".source = pkgs.substituteAll {
        src = ./motioninterpolation.py;
        mvtoolslib = "${pkgs.vapoursynth-mvtools}/lib/vapoursynth/";
      };

      home.file.".config/mpv/svp.py".source = pkgs.substituteAll {
        src = ./svp.py;
        svpflow = "${pkgs.lun.svpflow}/lib/";
        mvtoolslib = "${pkgs.vapoursynth-mvtools}/lib/vapoursynth/";
      };

      home.file.".config/mpv/mpv.conf".text = ''
        #vf=format=yuv420p,vapoursynth=~~/motioninterpolation.py:4:4
        vf=vapoursynth=~~/svp.py:2:24
      '';
    })
  ];
}
