{ stdenv
, lib
, fetchFromGitHub
, pkg-config
, curl
, gtkmm3
, yajl
}:
stdenv.mkDerivation rec {
  pname = "SamRewritten";
  version = "unstable-2023-05-23";
  src = fetchFromGitHub {
    owner = "PaulCombal";
    repo = pname;
    rev = "39d524a72678a226bf9140db6b97641f554563c3";
    sha256 = "sha256-sS/lVY5EWXdTOg7cDWPbi/n5TNt+pRAF1x7ZEaYG4wM=";
  };
  nativeBuildInputs = [
    pkg-config
  ];
  buildInputs = [
    curl
    gtkmm3
    yajl
  ];
  makeFlags = [
    "DESTDIR=$(out)"
  ];
  postInstall = ''
    rm -f $out/usr/bin/samrewritten
    mv $out/usr/* $out/
    rmdir $out/usr
    ln -s $out/lib/SamRewritten/bin/launch.sh $out/bin/samrewritten
  '';
  meta = with lib; {
    mainProgram = "samrewritten";
    description = "Steam Achievement Manager For Linux. Rewritten in C++.";
    homepage = "https://github.com/PaulCombal/SamRewritten";
    license = licenses.gpl3;
    platforms = [ "x86_64-linux" ];
    maintainers = with maintainers; [ arobyn ];
  };
}
