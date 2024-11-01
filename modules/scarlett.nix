{ pkgs
, config
, lib
, ...
}:
with lib; let
  cfg = config.modules.media.audio.interfaces.scarlett2;

  scarlett2 = pkgs.stdenv.mkDerivation {
    name = "scarlett2";

    firmwareSource = pkgs.fetchFromGitHub {
      owner = "geoffreybennett";
      repo = "scarlett2-firmware";
      rev = "a5fefaff35262c6ebe2ca8723ccd8622607baf15"; # tag 2128b
      hash = "sha256-V++JC0odIzSISt8JTAr4vS5/veHvGWs22SVI7XngfPw=";
    };

    src = pkgs.fetchFromGitHub {
      owner = "geoffreybennett";
      repo = "scarlett2";
      rev = "1c262bcac11bceb6da8334b8f5b56d3c9331bfc8";
      hash = "sha256-yhmXVfys300NwZ8UJ7WvOyNkGP3OkIVoRaToF+SenQA=";
    };

    buildInputs = with pkgs; [
      gnumake
      gcc
      alsa-lib
      openssl
      pkg-config
    ];

    buildPhase = ''
      make
    '';

    installPhase = ''
      mkdir -p $out $out/bin $out/bin/firmware
      cp -r scarlett2 $out/bin
      cp -r $firmwareSource/firmware $out/bin
    '';
  };
in
{
  options.modules.media.audio.interfaces.scarlett2.enable = mkEnableOption "Enable scarlett2";
  config = mkIf cfg.enable {
    environment.systemPackages = [ scarlett2 pkgs.alsa-scarlett-gui ];
  };
}
