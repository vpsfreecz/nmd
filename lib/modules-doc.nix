{ pkgs, lib }:

{
# Modules to include in documentation.
modules

# File paths to module roots.
, moduleRootPaths

# A function taking the relative module path to an URL where the
# module can be viewed.
#
# Example:
#     mkModuleUrl = path: "https://myproject.foo/${path}"
, mkModuleUrl

  # A function taking the relative module path and returns path to the
  # module in a channel
, mkChannelPath

# Options specific for DocBook output. If DocBook output is desired
# then this should contain the fields
#
# - id (string): Identifier of the module output. This value will be
#     used as the `xml:id` for the generated DocBook file. It will
#     also be used as the file name for the generated file, in
#     particular the path `nmd-result/<id>.xml`.
#
# Example:
#   docBook = { id = "myproject-options"; optionIdPrefix = "mp-opt"; }
, docBook }:

with lib;

let

  evaluatedModules = evalModules { inherit modules; };

  # Option documentation with non-DocBook markup allowed.
  rawOptionsDocs = (map cleanUpOption (sort moduleDocCompare
    (filter (opt: opt.visible && !opt.internal)
      (optionAttrSetToDocList evaluatedModules.options))));

  rawOptionsJson =
    builtins.toFile "raw-options.json" (builtins.toJSON rawOptionsDocs);

  optionsJson = pkgs.runCommand "options.json" {
    nativeBuildInputs =
      [ pkgs.asciidoc (pkgs.python3.withPackages (p: [ p.mistune ])) ];
    rawOptionsJson = builtins.toJSON rawOptionsDocs;
    rawOverridesJson = "{}";
    passAsFile = [ "rawOptionsJson" "rawOverridesJson" ];
  } ''
    python ${./docbookify-options-json.py} \
           ${rawOptionsJson} \
           $rawOverridesJsonPath \
           > $out
  '';

  # The option documentation with only DocBook markup.
  optionsDocs = builtins.fromJSON (builtins.readFile optionsJson);

  moduleDocCompare = a: b:
    let
      isEnable = lib.hasPrefix "enable";
      isPackage = lib.hasPrefix "package";
      compareWithPrio = pred: cmp: splitByAndCompare pred compare cmp;
      moduleCmp = compareWithPrio isEnable (compareWithPrio isPackage compare);
    in compareLists moduleCmp a.loc b.loc < 0;

  cleanUpOption = opt:
    let
      applyOnAttr = n: f: optionalAttrs (hasAttr n opt) { ${n} = f opt.${n}; };
    in opt // applyOnAttr "declarations" (map mkDeclaration)
    // applyOnAttr "example" substFunction
    // applyOnAttr "default" substFunction // applyOnAttr "type" substFunction
    // applyOnAttr "relatedPackages" mkRelatedPackages;

  mkDeclaration = decl: rec {
    path = stripModulePathPrefixes decl;
    url = mkModuleUrl path;
    channelPath = mkChannelPath path;
  };

  # We need to strip references to /nix/store/* from the options or
  # else the build will fail.
  stripModulePathPrefixes =
    let prefixes = map (p: "${toString p}/") moduleRootPaths;
    in modulePath: fold removePrefix modulePath prefixes;

  # Replace functions by the string <function>
  substFunction = x:
    if builtins.isAttrs x then
      mapAttrs (name: substFunction) x
    else if builtins.isList x then
      map substFunction x
    else if isFunction x then
      "<function>"
    else
      x;

  # Generate some meta data for a list of packages. This is what
  # `relatedPackages` option of `mkOption` lib/options.nix influences.
  #
  # Each element of `relatedPackages` can be either
  # - a string:   that will be interpreted as an attribute name from `pkgs`,
  # - a list:     that will be interpreted as an attribute path from `pkgs`,
  # - an attrset: that can specify `name`, `path`, `package`, `comment`
  #   (either of `name`, `path` is required, the rest are optional).
  mkRelatedPackages = let
    unpack = p:
      if isString p then {
        name = p;
      } else if isList p then {
        path = p;
      } else
        p;

    repack = args:
      let
        name = args.name or (concatStringsSep "." args.path);
        path = args.path or [ args.name ];
        pkg = args.package or (let
          bail = throw "Invalid package attribute path '${toString path}'";
        in attrByPath path bail pkgs);
      in {
        attrName = name;
        packageName = pkg.meta.name;
        available = pkg.meta.available;
      } // optionalAttrs (pkg.meta ? description) {
        inherit (pkg.meta) description;
      } // optionalAttrs (pkg.meta ? longDescription) {
        inherit (pkg.meta) longDescription;
      } // optionalAttrs (args ? comment) { inherit (args) comment; };
  in map (p: repack (unpack p));

in {
  # Raw Nix expression containing the module documentation.
  inherit optionsDocs;

  # Slightly cleaned up JSON representation of the module
  # documentation.
  json = import ./modules-json.nix { inherit pkgs lib optionsJson; };

  # DocBook representation of the module documentation, suitable for
  # inclusion into a DocBook document.
  docBook = import ./modules-docbook.nix
    ({ inherit pkgs lib optionsJson mkModuleUrl channelName; } // docBook);
}
