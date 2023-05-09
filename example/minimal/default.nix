{ pkgs ? import <nixpkgs> { } }:

let

  lib = pkgs.lib;

  nmd = import ../.. { inherit pkgs; };

  docs = nmd.buildDocBookDocs {
    pathName = "simple-example";
    documentsDirectory = ./.;
    chunkToc = ''
      <toc>
        <d:tocentry xmlns:d="http://docbook.org/ns/docbook" linkend="book-minimal-example">
          <?dbhtml filename="index.html"?>
        </d:tocentry>
      </toc>
    '';
  };

in {
  inherit (docs) html htmlOpenTool;
}
