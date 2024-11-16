{ pkgs, ... }:
let
  nopasswd = cmd:
    {
      command = cmd;
      options = [ "NOPASSWD" ];
    };
in
{
  users.users."lun".openssh.authorizedKeys.keyFiles = [
    ./keys.pub
  ];
  users.users."deployer".openssh.authorizedKeys.keyFiles = [
    ./keys.pub
  ];

  users.users.lun = {
    uid = 1000;
  };
  users.users.deployer = {
    uid = 1002;
    isNormalUser = true;
    shell = pkgs.fish;
    extraGroups = [ "wheel" ];
  };
  security.sudo.extraRules = [
    {
      users = [ "deployer" ];
      # FIXME: can we restrict more?
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
    {
      commands = [
        (nopasswd "/run/current-system/sw/bin/poweroff")
        (nopasswd "/run/current-system/sw/bin/reboot")
        (nopasswd "/run/current-system/sw/bin/systemctl reboot *")
        (nopasswd "/run/current-system/sw/bin/systemctl restart *")
        (nopasswd "/run/current-system/sw/bin/systemctl start *")
        (nopasswd "/run/current-system/sw/bin/systemctl stop *")
      ];
    }
  ];
}
