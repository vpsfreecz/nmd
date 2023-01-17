{
  description = "A documentation framework for projects based on NixOS modules";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    scss-reset = {
      url = "github:andreymatin/scss-reset";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, scss-reset }:
    let
      supportedSystems = nixpkgs.lib.platforms.unix;
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in {
      lib = forAllSystems (system:
        import ./default.nix { pkgs = nixpkgs.legacyPackages.${system}; });

      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          lib = pkgs.lib;

          generateCss = pkgs.writeShellScript "generateCss" ''
            set -euo pipefail

            tmpfile=$(mktemp -d)
            trap "rm -r $tmpfile" EXIT

            ln -s "${scss-reset}/build" "$tmpfile/scss-reset"

            PATH=${lib.makeBinPath [ pkgs.coreutils pkgs.rsass ]}

            rsass \
              --load-path="$tmpfile" \
              --style compressed \
              ./static/style.scss \
              > ./static/style.css
            echo "Generated ./static/style.css"
          '';

          # Very basic script to re-start the server and perform Tailwind CSS
          # export on file changes.
          pWatch = pkgs.writeShellScriptBin "p-watch" ''
            set -euo pipefail

            trap "kill 0" EXIT

            watchArgs=""
            while (( $# > 0 )); do
              opt="$1"
              shift
              case $opt in
                --notify)
                  watchArgs="$watchArgs -N"
                  ;;
                *)
                  echo "Unknown argument: $opt" >&2
                  exit 1
                  ;;
              esac
            done

            ${pkgs.watchexec}/bin/watchexec $watchArgs \
              -e scss \
              -- ${generateCss}
          '';

          pBuild = pkgs.writeShellScriptBin "p-build" ''
            exec ${generateCss}
          '';

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
            nativeBuildInputs = [
              pFormat
              pWatch
              pBuild
              pkgs.asciidoc
              (pkgs.python3.withPackages (p: [ p.mistune ]))

              pkgs.rsass
            ];
          };
        });
    };
}
