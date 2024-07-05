{ flakeArgs, pkgs, ... }:
{
  nix.package = pkgs.callPackage (flakeArgs.lix + "/package.nix") { };
}
