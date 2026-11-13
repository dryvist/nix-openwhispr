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
      darwinSystems = [
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      allSystems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      forDarwinSystems = nixpkgs.lib.genAttrs darwinSystems;
      forAllSystems = nixpkgs.lib.genAttrs allSystems;
    in
    {
      packages = forDarwinSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          openwhispr = pkgs.callPackage ./pkgs/openwhispr { };
          models = pkgs.callPackage ./pkgs/openwhispr-models { };
        in
        {
          default = openwhispr;
          inherit models openwhispr;
        }
      );

      apps = forDarwinSystems (
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
      homeModules.default = self.homeManagerModules.default;

      overlays.default = final: _prev: {
        openwhispr = self.packages.${final.stdenv.hostPlatform.system}.openwhispr;
        openwhispr-models = self.packages.${final.stdenv.hostPlatform.system}.models;
      };

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              nixfmt
              statix
              deadnix
              shellcheck
              ripgrep
            ];
          };
        }
      );

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          appData = import ./modules/app-data.nix {
            inherit (nixpkgs) lib;
            inherit pkgs;
          };
        in
        {
          app-data-seed = import ./tests/app-data-seed.nix {
            inherit pkgs appData;
          };
          publication =
            pkgs.runCommand "openwhispr-publication-check"
              {
                nativeBuildInputs = [ pkgs.ripgrep ];
              }
              ''
                bash ${self}/scripts/check-publication.sh
                touch $out
              '';
        }
        // nixpkgs.lib.optionalAttrs (nixpkgs.lib.elem system darwinSystems) {
          module =
            (home-manager.lib.homeManagerConfiguration {
              inherit pkgs;
              modules = [
                ./modules/home-manager.nix
                {
                  home = {
                    username = "ci";
                    homeDirectory = "/Users/ci";
                    stateVersion = "26.05";
                  };
                  programs.openwhispr.enable = true;
                }
              ];
            }).activationPackage;
          module-full =
            (home-manager.lib.homeManagerConfiguration {
              inherit pkgs;
              modules = [
                ./modules/home-manager.nix
                {
                  home = {
                    username = "ci";
                    homeDirectory = "/Users/ci";
                    stateVersion = "26.05";
                  };
                  programs.openwhispr = {
                    enable = true;
                    notesDirectory = "/tmp/openwhispr";
                    openaiBaseUrl = "http://localhost:8000/v1";
                    environment = {
                      FOO = "bar";
                    };
                    launchdLabel = "custom.label";
                    folders = [
                      "Meetings"
                      "clients/acme"
                    ];
                    dictionary = [ "Acme Corp" ];
                    dictionaryFile = "/Users/ci/openwhispr/dictionary.txt";
                    actions = {
                      "Summarize meeting" = {
                        icon = "notes";
                        prompt = "Summarize the meeting in three bullets.";
                      };
                      "Review draft" = {
                        kind = "template";
                        promptFile = "/Users/ci/openwhispr/review-prompt.txt";
                      };
                    };
                  };
                }
              ];
            }).activationPackage;
        }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
    };
}
