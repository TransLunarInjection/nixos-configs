{ flakeArgs }:
system:
let
  # Patches applied before importing nixpkgs
  # Only applied to pkgs/nixpkgs input, not stable input
  pkgsPatches = [
    # add .patch to a github PR URL to get a patch quickly
    ./nixpkgs-patches/graphical-session-delay.patch
  ];
  defaultPkgsConfig = {
    config.allowUnfree = true;
    overlays = [
      # (final: prev: {
      #   some-package = ...
      # })
      flakeArgs.self.overlays.default
      flakeArgs.emacs-overlay.overlay
      (import ./overlay-nixpkgs.nix { inherit flakeArgs; })
    ];
  };
  readModules = path: builtins.map (x: path + "/${x}") (builtins.filter (str: (builtins.match "^[^.]*(\.nix)?$" str) != null) (builtins.attrNames (builtins.readDir path)));
  lib = perSystemSelf.nixpkgsLib;
  perSystemSelf = {
    # hack: only patch for x86_64 so nix flake check doesn't fall over for other platforms
    # eventually will get rid of this IFD
    # once there's patches support for flake inputs
    # https://github.com/NixOS/nix/pull/6530
    pkgs = flakeArgs.self.lib.mkPkgs flakeArgs.nixpkgs system pkgsPatches (defaultPkgsConfig // { inherit system; });
    pkgs-stable = flakeArgs.self.lib.mkPkgs flakeArgs.nixpkgs-stable system [ ] (defaultPkgsConfig // { inherit system; });
    nixpkgsLib = flakeArgs.nixpkgs.lib.extend (_final: _prev: {
      nixosSystem = args:
        ((import "${perSystemSelf.pkgs}/nixos/lib/eval-config-minimal.nix" { inherit lib; }).evalModules (args // {
          modules = args.modules
            ++ (import "${perSystemSelf.pkgs}/nixos/modules/module-list.nix")
            # ++ [ (import "${perSystemSelf.pkgs}/nixos/modules/services/x11/desktop-managers/cosmic.nix") ]
            ++ [{
            # Avoid reimporting pkgs (disables config.pkgs.overlays)
            # FIXME: is it possible to have a specific
            # specialisation for a system which still uses
            # overlays when this is on?
            imports = [ (import "${perSystemSelf.pkgs}/nixos/modules/misc/nixpkgs/read-only.nix") ];
            nixpkgs.pkgs = perSystemSelf.pkgs;
            # _module.args.pkgs = lib.mkForce perSystemSelf.pkgs;
            system.nixos.versionSuffix = "";
            system.nixos.revision = "";
          }];
        }));
    });
    makeHost = path: lib.nixosSystem {
      specialArgs =
        {
          inherit flakeArgs;
          inherit (perSystemSelf) pkgs pkgs-stable;
          nixpkgs-modules-path = "perSystemSelf.pkgs";
          nixos-hardware-modules-path = "${flakeArgs.nixos-hardware}";
        };

      modules = [
        #{ nixpkgs.pkgs = perSystemSelf.pkgs; }
        flakeArgs.home-manager.nixosModules.home-manager
        path
        ./users
        ({ config, ... }:
          {
            config = {
              home-manager.extraSpecialArgs = {
                inherit flakeArgs;
                inherit (perSystemSelf) pkgs-stable;
                lun-profiles = config.lun.profiles;
              };
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
            };
          })
      ]
      ++ (builtins.attrValues flakeArgs.self.nixosModules)
      ++ (readModules ./modules);
    };
    nixosIso = hardware: lib.nixosSystem {
      inherit (perSystemSelf.pkgs) system;
      specialArgs = {
        nixpkgs-modules-path = "${perSystemSelf.pkgs}";
      };
      modules = [
        { nixpkgs.pkgs = perSystemSelf.pkgs; }
        hardware
        ./nixos-minimal-installer.nix
      ];
    };
    legacyPackages = flakeArgs.self.localPackagesForPkgs perSystemSelf.pkgs;
    packages = lib.filterAttrs (_k: pkg: lib.isDerivation pkg && !((pkg.meta or { }).broken or false) && (!(pkg ? meta && pkg.meta ? platforms) || builtins.elem system pkg.meta.platforms)) perSystemSelf.legacyPackages;
    devShell = flakeArgs.minimal-shell.lib.minimal-shell {
      inherit (perSystemSelf) pkgs;
      shellHooks = perSystemSelf.checks.pre-commit-check.shellHook;
      shellPackages = [ perSystemSelf.pkgs.nixpkgs-fmt ];
    };
    formatter = perSystemSelf.pkgs.nixpkgs-fmt;

    homeConfigurations =
      let
        makeUser = username:
          import "${flakeArgs.home-manager}/modules" {
            inherit (perSystemSelf) pkgs;
            check = true;
            extraSpecialArgs = {
              inherit flakeArgs;
              inherit (perSystemSelf) pkgs-stable;
              nixosConfig = null;
              lun-profiles = {
                emacs = false;
                graphical = true;
                wine = false;
              };
            };
            configuration = {
              _module.args.pkgs = lib.mkForce perSystemSelf.pkgs;
              _module.args.pkgs_i686 = lib.mkForce { };
              imports = [ "${./users}/${username}" ];
              home.homeDirectory = "/home/${username}";
              home.username = "${username}";
            };
          };
      in
      {
        lun = makeUser "lun";
        mmk = makeUser "mmk";
      };
    slowChecks = rec {
      all-packages = perSystemSelf.pkgs.symlinkJoin {
        name = "lun packages.${system}";
        paths = lib.attrValues perSystemSelf.packages;
      };
      all-systems = perSystemSelf.pkgs.symlinkJoin {
        name = "lun nixosConfigurations for system ${system}";
        paths = lib.filter (x: x.system == system) (map (cfg: flakeArgs.self.nixosConfigurations.${cfg}.config.system.build.toplevel) (builtins.attrNames flakeArgs.self.nixosConfigurations));
      };
      all-users = perSystemSelf.pkgs.symlinkJoin {
        name = "lun homeConfigurations for system ${system}";
        paths = map (x: x.activationPackage) (lib.attrValues perSystemSelf.homeConfigurations);
      };
      all = perSystemSelf.pkgs.symlinkJoin {
        name = "lun all";
        paths = [ all-packages all-systems all-users ];
      };
    };
    checks = {
      pre-commit-check = flakeArgs.pre-commit-hooks.lib.${system}.run {
        src = ./.;
        hooks = {
          # nix
          statix.enable = true;
          deadnix.enable = true;
          nil.enable = true;
          nixpkgs-fmt.enable = true;
          # shell
          shellcheck = {
            enable = true;
            files = "\\.sh$";
            types_or = lib.mkForce [ ];
          };
          bats.enable = true;
          beautysh = {
            enable = true;
            files = "\\.sh$";
            entry = lib.mkForce "${lib.getExe perSystemSelf.pkgs.beautysh} -t";
          };
          # YAML
          yamllint.enable = true;
        };
      };
    } // flakeArgs.deploy-rs.lib.${system}.deployChecks flakeArgs.self.deploy;
  };
in
perSystemSelf
