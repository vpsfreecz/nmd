{ pkgs }:

let

  lib = pkgs.lib;

in

{
  buildModulesDocs = import ./lib/modules-doc.nix { inherit lib pkgs; };
  buildDocBookDocs = import ./lib/manual-docbook.nix { inherit lib pkgs; };
}
