{ pkgs, flakeArgs }:
let
  inherit (pkgs) lib;
  resholvCfg = {
    inputs = with pkgs; [
      coreutils
      bash
      borgbackup
      findutils
      optipng
      vulkan-tools
      gnugrep
      curl
      jq
    ] ++ (lib.optionals pkgs.stdenv.isLinux (with pkgs; [
      bubblewrap
      slirp4netns
    ]));
    interpreter = "${pkgs.bash}/bin/bash";
    execer = [
      # See https://github.com/abathur/resholve/issues/77
      "cannot:${pkgs.borgbackup}/bin/borg"
    ] ++ (lib.optionals pkgs.stdenv.isLinux [
      # These are sometimes a lie because there's no support for can: + how to interpret the args
      "cannot:${pkgs.bubblewrap}/bin/bwrap" # can:
      "cannot:${pkgs.slirp4netns}/bin/slirp4netns" # can:
    ]);
    fake = {
      external = [
        "sudo"
        "idea-ultimate"
        "wine"
        "nix"
        "systemctl"
      ];
    };
  };
  wrapScripts = path:
    let
      scripts = map (lib.removeSuffix ".sh") (builtins.attrNames (builtins.readDir path));
    in
    builtins.listToAttrs (map (x: lib.nameValuePair x (pkgs.resholve.writeScriptBin x resholvCfg (builtins.readFile "${path}/${x}.sh"))) scripts);

  lun-scripts-path = pkgs.symlinkJoin { name = "lun-scripts"; paths = lib.attrValues self.lun-scripts; };
  # https://gitlab.freedesktop.org/mesa/mesa/-/merge_requests/19101.patch
  mesaOverride =
    mesaPkg: (mesaPkg.overrideAttrs (_old: { }));
  self = {
    lun-scripts = wrapScripts ./lun-scripts;
    xdg-open-with-portal = pkgs.callPackage ./xdg-open-with-portal { };
    vkpeak = pkgs.callPackage ./vkpeak { };
    compositor-killer = pkgs.callPackage ./compositor-killer { };
    samrewritten = pkgs.callPackage ./samrewritten { };
    sillytavern = pkgs.callPackage ./sillytavern { };
    spawn = pkgs.callPackage ./spawn { };
    swaysome = pkgs.callPackage ./swaysome { };
    sworkstyle = pkgs.callPackage ./sworkstyle { };
    lun = pkgs.writeShellScriptBin "lun" ''
      exec "${lun-scripts-path}/bin/$1" "''${@:2}"
    '';
    rogdrv = pkgs.callPackage ./rogdrv { };
    svpflow = pkgs.callPackage ./svpflow { };
    # inherit (flakeArgs.nixpkgs-mesa-pr.legacyPackages.${pkgs.system}) mesa;
    mesa = mesaOverride pkgs.mesa;
    xorgserver = pkgs.xorg.xorgserver.overrideAttrs (old: {
      configureFlags = old.configureFlags ++ [
        "--enable-config-udev"
        "--enable-config-udev-kms"
        "--disable-config-hal"
      ];
      patches = old.patches ++ [
        # Adds KMS_DEVICE env var to restrict which card xorg will use
        ./xorg/limit-kms-devices.patch
        ./xorg/prefer-highest-refresh-mode.patch
      ];
    });
    vial = pkgs.libsForQt5.callPackage ./vial { };
    wally = pkgs.callPackage ./wally { };
  } //
  # These packages are x86_64-linux
  # This is mostly due to depending on pkgs.pkgsi686Linux to evaluate
  (lib.optionalAttrs (pkgs.system == "x86_64-linux") {
    # FIXME: this is upstreamed?
    tabby = pkgs.callPackage ./tabby { };
    cursorai = pkgs.callPackage ./cursorai { };
    wowup = pkgs.callPackage ./wowup { };
    lutris = pkgs.lutris.override {
      extraLibraries = pkgs: with pkgs; [
        jansson
        gnutls
        openldap
        libgpg-error
        libpulseaudio
        sqlite
        libusb
      ];
    };
    mesa-i686 = mesaOverride pkgs.pkgsi686Linux.mesa;
    wine = (flakeArgs.nix-gaming.packages.${pkgs.system}.wine-ge.overrideAttrs (old: {
      dontStrip = true;
      debug = true;
      patches = old.patches ++ [
        ./wine/fix-NtQueryInformationProcess-ProcessDebugPort-size.patch
        ./wine/log-NtWriteVirtualMemory.patch
        ./wine/log-NtProtectVirtualMemory.patch
      ];
    })).override {
      supportFlags = {
        gettextSupport = true;
        fontconfigSupport = true;
        alsaSupport = true;
        openglSupport = true;
        vulkanSupport = true;
        tlsSupport = true;
        cupsSupport = true;
        dbusSupport = true;
        cairoSupport = true;
        cursesSupport = true;
        saneSupport = true;
        pulseaudioSupport = true;
        udevSupport = true;
        xineramaSupport = true;
        sdlSupport = true;
        mingwSupport = true;
        gtkSupport = false;
        gstreamerSupport = false;
        openalSupport = false;
        openclSupport = false;
        odbcSupport = false;
        netapiSupport = false;
        vaSupport = false;
        pcapSupport = false;
        v4lSupport = false;
        gphoto2Support = false;
        krb5Support = false;
        ldapSupport = false;
        vkd3dSupport = false;
        embedInstallers = false;
        waylandSupport = true;
        usbSupport = true;
        x11Support = true;
      };
    };
  });
in
self
