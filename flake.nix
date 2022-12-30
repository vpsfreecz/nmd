{
  description = "A documentation framework for projects based on NixOS modules";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
    let
      supportedSystems = nixpkgs.lib.platforms.unix;
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in {
      lib = forAllSystems (system:
        import ./default.nix { pkgs = nixpkgs.legacyPackages.${system}; });

      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          pFormat = pkgs.writeShellScriptBin "p-format" ''
            shopt -s globstar
            set -euo pipefail

            check=""
            case ''${1:-} in
              -h) echo "$0 [-c]"  ;;
              -c) check="-c"      ;;
            esac

            PATH=${with pkgs; nixpkgs.lib.makeBinPath [ nixfmt ]}

            nixfmt $check **/*.nix
          '';
        in {
          default = pkgs.mkShell {
            name = "dev-shell";
            nativeBuildInputs = [ pFormat ];
          };
        });
    };
}
