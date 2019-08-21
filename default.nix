{ pkgs }:

let

  lib = pkgs.lib;

in

{
  buildModulesDocs = import ./lib/modules-doc.nix { inherit lib pkgs; };

  docBook = import ./docbook.nix { inherit lib pkgs; };
}
