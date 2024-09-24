{ fetchFromGitHub
, stdenv
, ncnn
, glslang
, autoAddDriverRunpath
, wayland-protocols
, wayland
, cmake
, pkg-config
, egl-wayland
, libglvnd
, ninja
}:
stdenv.mkDerivation {
  pname = "vkpeak";
  version = "unstable";
  src = fetchFromGitHub {
    owner = "nihui";
    repo = "vkpeak";
    rev = "0c8c1d8eab74cd9405898953de3d61e9156606d0";
    hash = "sha256-3SXSpFgSquoW8/c1snQXkMGFAqgifDpwgrE+h8OeKG8=";
    fetchSubmodules = true;
  };
  # Use TFLOPS / TOPS instead of GFLOPS / GIOPS to match more frequently used terminology
  postPatch = ''
    rm -rf ncnn
    ln -s ${ncnn.src} ncnn
    substituteInPlace CMakeLists.txt --replace 'FATAL_ERROR' WARNN
          substituteInPlace vkpeak.cpp \
          --replace 'GFLOPS' 'TFLOPS' \
          --replace 'GIOPS' 'TOPS' \
          --replace 'return max_gflops;' 'return max_gflops / 1000.0;' \
  '';
  cmakeFlags = [ "-DNCNN_SYSTEM_GLSLANG=1" "-DNCNN_VULKAN=1" "-DNCNN_STDIO=1" "-DCMAKE_BUILD_SHARED_LIBS=1" ];
  installPhase = ''
    mkdir -p $out/bin
    cp ./vkpeak $out/bin/
  '';
  enableParallelBuilding = true;
  nativeBuildInputs = [ cmake pkg-config ninja autoAddDriverRunpath ];
  buildInputs = [ glslang wayland-protocols wayland libglvnd egl-wayland ];
  meta.mainPackage = "vkpeak";
}
