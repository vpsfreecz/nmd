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

            case ''${1:-} in
              -h) echo "$0 [-c]" ;;
              -c) check=""       ;;
            esac

            PATH=${with pkgs; nixpkgs.lib.makeBinPath [ nixfmt yapf ]}

            nixfmt ''${check+-c} **/*.nix
            yapf ''${check--i} ''${check+-d} **/*.py
          '';
        in {
          default = pkgs.mkShell {
            name = "dev-shell";
            nativeBuildInputs =
              [ pFormat (pkgs.python3.withPackages (p: [ p.mistune ])) ];
          };
        });
    };
}
