{ stdenv
, pkg-config
, ncurses5
, fetchFromGitHub
}:
stdenv.mkDerivation {
  pname = "switchtec-user";
  version = "4.2";
  src = fetchFromGitHub {
    owner = "Microsemi";
    repo = "switchtec-user";
    rev = "1c0ced0af7b35df185d0ef2c61f3671d0b6cf16b";
    hash = "sha256-AVAx2Nsg3AR4mDM7pZTXMfjkZoqCqYrf33PWn2TNxog=";
  };
  nativeBuildInputs = [
    pkg-config
  ];
  buildInputs = [
    ncurses5
  ];
  makeFlags = [
    "LDCONFIG=echo"
    "OBJDIR=build"
    "DESTDIR=$(out)"
    "PREFIX="
  ];
  postPatch = ''
    patchShebangs ./VERSION-GEN
  '';
  postConfigure = ''
    ./VERSION-GEN -include $(OBJDIR)/version.mk
  '';
  meta.mainProgram = "switchtec";
}
