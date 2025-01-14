#
{ appimageTools, fetchurl, gsettings-desktop-schemas, gtk3 }:
appimageTools.wrapType2 {
  # or wrapType1
  pname = "cursor-ai";
  version = "20241116203009";
  src = fetchurl {
    # url = "https://downloader.cursor.sh/linux/appImage/x64";
    url = "https://web.archive.org/web/20241116203009/https://downloader.cursor.sh/linux/appImage/x64";
    hash = "sha256-fr2P4Na6Jvmhh7FA5JILxrmm8wfI7Ad2+IFeJrxCtmI=";
  };
  profile = ''
    export XDG_DATA_DIRS=${gsettings-desktop-schemas}/share/gsettings-schemas/${gsettings-desktop-schemas.name}:${gtk3}/share/gsettings-schemas/${gtk3.name}:$XDG_DATA_DIRS
  '';
}
