{ flakeArgs, pkgs, ... }:
{
  imports = [
    flakeArgs.lix-module.nixosModules.default
  ];

  nix.package = pkgs.callPackage (flakeArgs.lix + "/package.nix") { };
}
