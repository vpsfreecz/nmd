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
      supportedSystems = [
        "aarch64-darwin"
        "aarch64-linux"
        "i686-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];

      lib = nixpkgs.lib;

      forAllSystems = lib.genAttrs supportedSystems;

      flakePkgs = pkgs:
        let
          fpkgs = {
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

            # Very basic script to re-start the server and run rsass on file
            # changes.
            p-watch = pkgs.writeShellScriptBin "p-watch" ''
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
                -- ${fpkgs.generateCss}
            '';

            p-build = pkgs.writeShellScriptBin "p-build" ''
              exec ${fpkgs.generateCss}
            '';

            p-format = pkgs.writeShellScriptBin "p-format" ''
              shopt -s globstar
              set -euo pipefail

              case ''${1:-} in
                -h) echo "$0 [-c]" ;;
                -c) check=""       ;;
              esac

              PATH=${with pkgs; lib.makeBinPath [ nixfmt yapf ]}

              nixfmt ''${check+-c} **/*.nix
              yapf ''${check--i} ''${check+-d} **/*.py
            '';
          };
        in fpkgs;
    in {
      lib = forAllSystems (system:
        import ./default.nix { pkgs = nixpkgs.legacyPackages.${system}; });

      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          fpkgs = flakePkgs pkgs;
        in { inherit (fpkgs) p-format; });

      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          fpkgs = flakePkgs pkgs;
        in {
          default = pkgs.mkShell {
            name = "dev-shell";
            nativeBuildInputs = [
              fpkgs.p-format
              fpkgs.p-watch
              fpkgs.p-build

              pkgs.asciidoc
              (pkgs.python3.withPackages (p: [ p.mistune ]))

              pkgs.rsass
            ];
          };
        });
    };
}
