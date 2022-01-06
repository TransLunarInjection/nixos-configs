{ system, pkgs }:
let
  lutris-unwrapped = (pkgs.lutris-unwrapped.override {
    #wine = pkgs.wineWowPackages.staging;
    wine = pkgs.emptyDirectory;
  }).overrideAttrs (old: {
    patches = old.patches ++ [ ];
    propagatedBuildInputs = old.propagatedBuildInputs ++ [ pkgs.wineWowPackages.fonts ];
  });
  xdg-open-with-portal = pkgs.callPackage ./xdg-open-with-portal { };
in
{
  key-mapper = pkgs.callPackage ./key-mapper { };
  powercord = pkgs.callPackage ./powercord {
    plugins = { };
    themes = { };
  };
  kwinft = pkgs.lib.recurseIntoAttrs (pkgs.callPackage ./kwinft { });
  xdg-open-with-portal = xdg-open-with-portal;
  lutris-unwrapped = lutris-unwrapped;
  lutris = pkgs.lutris.override {
    lutris-unwrapped = lutris-unwrapped;
    extraLibraries = pkgs: [ (pkgs.hiPrio xdg-open-with-portal) ];
  };
  spawn = pkgs.callPackage ./spawn { };
  swaysome = pkgs.callPackage ./swaysome { };
  sworkstyle = pkgs.callPackage ./sworkstyle { };
}
