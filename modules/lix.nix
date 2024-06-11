{ flakeArgs, ... }:
{
  imports = [
    flakeArgs.lix-module.nixosModules.default
  ];
}
