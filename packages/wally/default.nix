{ stdenv
, lib
, fetchurl
, autoPatchelfHook
, libusb1
, autoAddDriverRunpath
, webkitgtk_4_0
, wrapGAppsHook
, gtk3
, gobject-introspection
}:

stdenv.mkDerivation rec {
  pname = "wally";
  version = "2.1.3";

  src = fetchurl {
    url = "https://github.com/zsa/wally/releases/download/2.1.3-linux/wally";
    sha256 = "sha256-owyXTC/VRJdeSPfyrJmiH5Nvo+CAOv7rEJaCanmv294=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    autoAddDriverRunpath
    wrapGAppsHook
  ];

  buildInputs = [
    libusb1
    webkitgtk_4_0
    gtk3
    gobject-introspection
  ];

  dontUnpack = true;
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    mkdir -p $out/bin
    cp $src $out/bin/wally
    chmod +x $out/bin/wally
  '';

  meta = with lib; {
    description = "A tool to flash firmware to mechanical keyboards";
    homepage = "https://github.com/zsa/wally";
    platforms = [ "x86_64-linux" ];
    license = licenses.mit;
    maintainers = with maintainers; [ spacekookie r-burns ];
  };
}
