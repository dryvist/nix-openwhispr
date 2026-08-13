{
  description = "Reproducible macOS Nix integration for OpenWhispr";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
    }:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          openwhispr = pkgs.callPackage ./pkgs/openwhispr { };
          models = pkgs.callPackage ./pkgs/openwhispr-models { };
        in
        {
          default = openwhispr;
          openwhispr = openwhispr;
          inherit models;
        }
      );

      apps = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          package = self.packages.${system}.default;
          launcher = pkgs.writeShellApplication {
            name = "openwhispr-launch";
            text = ''
              exec /usr/bin/open -na "${package}/Applications/OpenWhispr.app" --args "$@"
            '';
          };
          verifier = pkgs.writeShellApplication {
            name = "openwhispr-verify-local";
            runtimeInputs = [
              pkgs.bash
              pkgs.coreutils
            ];
            text = builtins.readFile ./scripts/verify-local.sh;
          };
        in
        {
          default = {
            type = "app";
            program = "${launcher}/bin/openwhispr-launch";
          };
          verify-local = {
            type = "app";
            program = "${verifier}/bin/openwhispr-verify-local";
          };
        }
      );

      homeManagerModules.default = import ./modules/home-manager.nix;

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              nixfmt-rfc-style
              statix
              deadnix
              shellcheck
            ];
          };
        }
      );

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          publication = pkgs.runCommand "openwhispr-publication-check" { } ''
            ${./scripts/check-publication.sh}
            touch $out
          '';
          module =
            (home-manager.lib.homeManagerConfiguration {
              inherit pkgs;
              modules = [
                ./modules/home-manager.nix
                {
                  home.username = "ci";
                  home.homeDirectory = "/Users/ci";
                  home.stateVersion = "26.05";
                  programs.openwhispr.enable = true;
                }
              ];
            }).activationPackage;
        }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
    };
}
