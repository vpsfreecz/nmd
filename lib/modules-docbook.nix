{ pkgs, lib

# ID of the `variablelist` DocBook element holding the documented
# options.
, id

# Prefix to add to specific option entries. For an option `foo.bar`
# the XML identifier is `<optionIdPrefix>-foo.bar`.
#
# Example:
#    optionIdPrefix = "myopt";
, optionIdPrefix ? "opt"

  # A function taking the relative module path to an URL where the
  # module can be viewed.
  #
  # Example:
  #     mkModuleUrl = path: "https://myproject.foo/${path}"
, mkModuleUrl

# The "typical" channel name for this module set. This will be used
# to present a friendly path to the module defining an option.
#
# Example:
#     channelName = "myproject"
, channelName

, optionsJson }:

with lib;

let

  optionsDocBook = pkgs.runCommand "options-db.xml" {
    nativeBuildInputs = [ (getBin pkgs.libxslt) ];
  } ''
    export NIX_STORE_DIR=$TMPDIR/store
    export NIX_STATE_DIR=$TMPDIR/state
    ${pkgs.nix}/bin/nix-instantiate \
      --eval --xml --strict \
      --expr '{file}: builtins.fromJSON (builtins.readFile file)' \
      --argstr file ${optionsJson} \
      > options.xml

    mkdir -p $out/nmd-result

    xsltproc \
      --stringparam elementId '${id}' \
      --stringparam optionIdPrefix '${optionIdPrefix}' \
      --nonet \
      -o $out/nmd-result/${id}.xml \
      ${./options-to-docbook.xsl} options.xml
  '';

in optionsDocBook
