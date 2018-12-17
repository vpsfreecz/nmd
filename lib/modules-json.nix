{ pkgs, lib, optionsDocs }:

with lib;

let

  jsonData =
    let
      trimAttrs = flip removeAttrs ["name" "visible" "internal"];
      attributify = opt: {
        inherit (opt) name;
        value = trimAttrs opt;
      };
    in
      listToAttrs (map attributify optionsDocs);

  jsonFile =
    pkgs.writeText "options.json"
    (builtins.unsafeDiscardStringContext
    (builtins.toJSON jsonData));

in

jsonFile
