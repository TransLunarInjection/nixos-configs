{ appimageTools, fetchurl, gsettings-desktop-schemas, gtk3 }:
appimageTools.wrapType2 {
  # or wrapType1
  pname = "wowup";
  version = "v2.10.0";
  src = fetchurl {
    url = "https://github.com/WowUp/WowUp.CF/releases/download/v2.10.0/WowUp-CF-2.10.0.AppImage";
    hash = "sha256-u8rziod2RVSCaqSBgShqFeVrRo9MvHr7cCujSAYpULM=";
  };
  profile = ''
    export XDG_DATA_DIRS=${gsettings-desktop-schemas}/share/gsettings-schemas/${gsettings-desktop-schemas.name}:${gtk3}/share/gsettings-schemas/${gtk3.name}:$XDG_DATA_DIRS
  '';
}
