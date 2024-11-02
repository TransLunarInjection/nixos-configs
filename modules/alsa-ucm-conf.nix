{ pkgs, config, ... }:
let
  alsa-ucm-conf = pkgs.alsa-ucm-conf.overrideAttrs (old: {
    patches = old.patches ++ [
      ./alsa-ucm-2i2.patch
    ];
  });
  env = {
    ALSA_CONFIG_UCM2 = "${alsa-ucm-conf}/share/alsa/ucm2";
  };
in
{
  environment.systemPackages = [ alsa-ucm-conf ];
  environment.variables = env;
  environment.sessionVariables = env;
  systemd.user.services.pipewire.environment.ALSA_CONFIG_UCM2 = config.environment.variables.ALSA_CONFIG_UCM2;
  systemd.user.services.wireplumber.environment.ALSA_CONFIG_UCM2 = config.environment.variables.ALSA_CONFIG_UCM2;
}
