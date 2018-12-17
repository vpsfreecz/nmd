{ pkgs
, lib

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

, optionsDocs
}:

with lib;

let

  optionsXml = pkgs.writeText "nmd-options.xml" (builtins.toXML optionsDocs);

  optionsDocBook = pkgs.runCommand "options-db.xml"
    {
      nativeBuildInputs = [ (getBin pkgs.libxslt) ];
    }
    ''
      xsltproc -o $out ${./options-to-docbook.xsl} ${optionsXml}
    '';

  # docbookOptionDocs =
  #   (map expandDeclaration optionsDocs);

in

optionsDocBook
