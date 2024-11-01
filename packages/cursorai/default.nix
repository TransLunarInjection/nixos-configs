#
{ appimageTools, fetchurl, gsettings-desktop-schemas, gtk3 }:
appimageTools.wrapType2 {
  # or wrapType1
  name = "cursor-ai";
  src = fetchurl {
    url = "https://downloader.cursor.sh/linux/appImage/x64";
    hash = "sha256-GWkilBlpXube//jbxRjmKJjYcmB42nhMY8K0OgkvtwA=";
  };
  profile = ''
    export XDG_DATA_DIRS=${gsettings-desktop-schemas}/share/gsettings-schemas/${gsettings-desktop-schemas.name}:${gtk3}/share/gsettings-schemas/${gtk3.name}:$XDG_DATA_DIRS
  '';
}
