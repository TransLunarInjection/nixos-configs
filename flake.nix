{
  description = "lun's system config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.11";
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
    pre-commit-hooks.inputs.nixpkgs.follows = "nixpkgs";
    systems.url = "github:nix-systems/default-linux";
    flake-utils.url = "github:numtide/flake-utils";
    flake-utils.inputs.systems.follows = "systems";
    nix-gaming.url = "github:fufexan/nix-gaming";
    nix-gaming.inputs.nixpkgs.follows = "nixpkgs";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    erosanix.url = "github:emmanuelrosa/erosanix";
    erosanix.inputs.nixpkgs.follows = "nixpkgs";
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
    thoth-reminder-bot.url = "github:mmk150/reminder_bot";
    thoth-reminder-bot.inputs.nixpkgs.follows = "nixpkgs";
    thoth-reminder-bot.inputs.flake-utils.follows = "flake-utils";
    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";
    openxr-nix-flake.url = "github:LunNova/openxr-nix-flake";
    openxr-nix-flake.inputs.nixpkgs.follows = "nixpkgs";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    crane.url = "github:ipetkov/crane";
    advisory-db = {
      url = "github:rustsec/advisory-db";
      flake = false;
    };
    background-switcher = {
      url = "github:bootstrap-prime/background-switcher";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
      inputs.rust-overlay.follows = "rust-overlay";
      inputs.crane.follows = "crane";
      inputs.advisory-db.follows = "advisory-db";
    };
    i3status-nix-update-widget = {
      url = "github:bootstrap-prime/i3status-nix-update-widget";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
      inputs.rust-overlay.follows = "rust-overlay";
      inputs.crane.follows = "crane";
      inputs.advisory-db.follows = "advisory-db";
    };
    mobile-nixos = {
      url = "github:NixOS/mobile-nixos";
      flake = false;
    };
    plover-flake = {
      url = "github:dnaq/plover-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
    nixos-cosmic = {
      url = "github:lilyinstarlight/nixos-cosmic";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    alicorn-vscode-extension = {
      url = "github:Fundament-Software/alicorn-vscode-extension";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };

    minimal-shell.url = "github:LunNova/nix-minimal-shell";
  };

  # SCHEMA:
  # lib                       = nix library functions, work on any system
  # nixosConfigurations       = attrset with nixosConfigurations by hostname, each host is for one specific system
  # overlay                   = function that can be used as a nixpkgs overlay, hopefully works on any system
  # perSystem                 = function which takes system as input and generates system specific outputs for that system
  #                             (system: { packages, legacyPackages, homeConfigurations, checks, slowChecks })
  # packages.system           = attrset with packages marked as able to eval/build, generated by perSystem
  # legacyPackages.system     = attrset with packages including unsupported/marked broken, generated by perSystem
  # homeConfigurations.system = attrset with homeConfigurations by username, generated by perSystem
  # checks.system             = attrset with checks, generated by perSystem
  # slowChecks.system         = attrset with checks that are too slow for nix flake check but are used in CI, generated by perSystem
  outputs = flakeArgs:
    let
      lib = import ./lib { bootstrapLib = flakeArgs.nixpkgs.lib; };
      perSystem = import ./per-system.nix { inherit flakeArgs; };
      allSystemsUnmerged = flakeArgs.flake-utils.lib.eachDefaultSystem perSystem;
      allSystems = allSystemsUnmerged // { homeConfigurations = lib.flatten allSystemsUnmerged.homeConfigurations; };
      serviceTest = import ./service-test.nix { };
      inherit (flakeArgs) self;
    in
    {
      inherit flakeArgs perSystem lib;
      assets = import ./assets;
      overlays.default = import ./overlay.nix { inherit flakeArgs; };
      localPackagesForPkgs = pkgs: import ./packages { inherit pkgs flakeArgs; };
      nixosModules = self.lib.readExportedModules ./modules/exported;

      nixosConfigurations = {
        test-vm = allSystems.makeHost.x86_64-linux ./hosts/test-vm;
        router-nixos = allSystems.makeHost.x86_64-linux ./hosts/router;
        tsukiakari-nixos = allSystems.makeHost.x86_64-linux ./hosts/tsukiakari;
        tsukikage-nixos = allSystems.makeHost.x86_64-linux ./hosts/tsukikage;
        hoshitsuki-nixos = allSystems.makeHost.x86_64-linux ./hosts/hoshitsuki;
        lun-kosame-nixos = allSystems.makeHost.x86_64-linux ./hosts/kosame;
        lun-hisame-nixos = allSystems.makeHost.x86_64-linux ./hosts/hisame;
        lun-shigure = allSystems.makeHost.x86_64-linux ./hosts/shigure;
        lun-amayadori-nixos = allSystems.makeHost.aarch64-linux ./hosts/amayadori;
        builder-nixos = allSystems.makeHost.x86_64-linux ./hosts/builder;
      };

      deploy =
        let
          mkNode = { name, hostname ? "${name}-nixos", fast ? false, cfg ? self.nixosConfigurations.${name + "-nixos"} }: {
            inherit hostname;
            # interactiveSudo = true;
            profiles.system = {
              sshUser = "deployer";
              user = "root";
              path = flakeArgs.deploy-rs.lib.x86_64-linux.activate.nixos cfg;
            };
            remoteBuild = fast;
          };
        in
        {
          nodes.router = mkNode { name = "router"; hostname = "10.5.5.1"; };
          nodes.tsukiakari = mkNode { name = "tsukiakari"; fast = true; };
          nodes.tsukikage = mkNode { name = "tsukikage"; fast = true; };
          nodes.shigure = mkNode { name = "shigure"; fast = true; };
          nodes.hoshitsuki = mkNode { name = "hoshitsuki"; fast = true; };
          nodes.testSingleServiceDeployAsLunOnLocalhost = {
            hostname = "localhost";
            profiles.serviceTest = serviceTest.hmProfile {
              inherit (flakeArgs) deploy-rs;
              inherit (flakeArgs.nixpkgs) lib;
              inherit (flakeArgs.self.homeConfigurations.x86_64-linux.lun) pkgs;
              user = "lun";
              profileName = "lunHello";
              modules = [
                serviceTest.helloWorldModule
              ];
              hm = import "${flakeArgs.home-manager}/modules";
              postActivate = ''
                systemctl --user reload-or-restart hello
                systemctl --user status hello --lines=1 || true
              '';
            };
          };
        };
    } // allSystems;
}
