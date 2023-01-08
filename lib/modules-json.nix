{ pkgs, lib, optionsJson }:

with lib;

let

  jsonFile = { path ? "options.json" }:
    pkgs.runCommand (builtins.baseNameOf path) { } ''
      dest=$out/${lib.escapeShellArg path}
      mkdir -p "$(dirname "$dest")"
      ${pkgs.jq}/bin/jq -c \
        'map({key: .name, value: del(.name, .visible, .internal)}) | from_entries' \
        ${optionsJson} > "$dest"
    '';

in makeOverridable jsonFile { }
