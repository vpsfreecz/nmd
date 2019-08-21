{ pkgs, lib }:

{
  # The name identifying the manual on disk. The output packages will,
  # e.g., install documentation to `share/doc/<name>`.
  pathName

  # List of modules documentation as produced by `buildModulesDocs`.
, modulesDocs ? [ ]

  # Directory of DocBook documents. This directory is expected to
  # contain the files
  #
  # - `manual.xml` containing a `book` element, and
  #
  # - `man-pages.xml` containing a `reference` element.
, documentsDirectory
}:

with lib;

let

  inherit (pkgs) docbook5 docbook5_xsl;

  combinedDirectory = pkgs.buildEnv {
    name = "nmd-documents";
    paths = [ documentsDirectory ] ++ map (v: v.docBook) modulesDocs;
  };

  manualXml = "${combinedDirectory}/manual.xml";
  manPagesXml = "${combinedDirectory}/man-pages.xml";

  runXmlCommand = name: attrs: command:
    pkgs.runCommand
      name
      (attrs // {
        nativeBuildInputs = [
          (getBin pkgs.libxml2)
          (getBin pkgs.libxslt)
        ];
      })
      command;

  manualCombined =
    runXmlCommand
      "manual-combined"
      { }
      ''
        mkdir $out

        xmllint --xinclude \
          --output $out/manual-combined.xml ${manualXml}
        xmllint --xinclude --noxincludenode \
          --output $out/man-pages-combined.xml ${manPagesXml}

        # outputs the context of an xmllint error output
        # LEN lines around the failing line are printed
        function context {
          # length of context
          local LEN=6
          # lines to print before error line
          local BEFORE=4

          # xmllint output lines are:
          # file.xml:1234: there was an error on line 1234
          while IFS=':' read -r file line rest; do
            echo
            if [[ -n "$rest" ]]; then
              echo "$file:$line:$rest"
              local FROM=$(($line>$BEFORE ? $line - $BEFORE : 1))
              # number lines & filter context
              nl --body-numbering=a "$file" | sed -n "$FROM,+$LEN p"
            else
              if [[ -n "$line" ]]; then
                echo "$file:$line"
              else
                echo "$file"
              fi
            fi
          done
        }

        function lintrng {
          xmllint --debug --noout --nonet \
            --relaxng ${docbook5}/xml/rng/docbook/docbook.rng \
            "$1" \
            2>&1 | context 1>&2
            # ^ redirect assumes xmllint doesn’t print to stdout
        }

        lintrng $out/manual-combined.xml
        lintrng $out/man-pages-combined.xml
      '';

  # TODO
  toc = builtins.toFile "toc.xml"
    ''
      <toc role="chunk-toc">
        <d:tocentry xmlns:d="http://docbook.org/ns/docbook" linkend="book-home-manager-manual"><?dbhtml filename="index.html"?>
          <d:tocentry linkend="ch-options"><?dbhtml filename="options.html"?></d:tocentry>
          <d:tocentry linkend="ch-tools"><?dbhtml filename="tools.html"?></d:tocentry>
          <d:tocentry linkend="ch-release-notes"><?dbhtml filename="release-notes.html"?></d:tocentry>
        </d:tocentry>
      </toc>
    '';

  manualXsltprocOptions = toString [
    "--param section.autolabel 1"
    "--param section.label.includes.component.label 1"
    "--stringparam html.stylesheet 'style.css overrides.css highlightjs/mono-blue.css'"
    "--stringparam html.script './highlightjs/highlight.pack.js ./highlightjs/loader.js'"
    "--param xref.with.number.and.title 1"
    "--param toc.section.depth 3"
    "--stringparam admon.style ''"
    "--stringparam callout.graphics.extension .svg"
    "--stringparam current.docid manual"
    "--param chunk.section.depth 0"
    "--param chunk.first.sections 1"
    "--param use.id.as.filename 1"
    "--stringparam generate.toc 'book toc appendix toc'"
    "--stringparam chunk.toc ${toc}"
  ];

  olinkDb =
    runXmlCommand
      "manual-olinkdb"
      { }
      ''
        mkdir $out

        xsltproc \
          ${manualXsltprocOptions} \
          --stringparam collect.xref.targets only \
          --stringparam targets.filename "$out/manual.db" \
          --nonet \
          ${docbook5_xsl}/xml/xsl/docbook/xhtml/chunktoc.xsl \
          ${manualCombined}/manual-combined.xml

        cat > "$out/olinkdb.xml" <<EOF
        <?xml version="1.0" encoding="utf-8"?>
        <!DOCTYPE targetset SYSTEM
          "file://${docbook5_xsl}/xml/xsl/docbook/common/targetdatabase.dtd" [
          <!ENTITY manualtargets SYSTEM "file://$out/manual.db">
        ]>
        <targetset>
          <targetsetinfo>
            Allows for cross-referencing olinks between the man pages
            and manual.
          </targetsetinfo>

          <document targetdoc="manual">&manualtargets;</document>
        </targetset>
        EOF
      '';

  html =
    runXmlCommand
      "html-manual"
      { allowedReferences = ["out"]; }
      ''
        # Generate the HTML manual.
        dst=$out/share/doc/${pathName}
        mkdir -p $dst
        xsltproc \
          ${manualXsltprocOptions} \
          --stringparam target.database.document "${olinkDb}/olinkdb.xml" \
          --nonet --output $dst/ \
          ${docbook5_xsl}/xml/xsl/docbook/xhtml/chunktoc.xsl \
          ${manualCombined}/manual-combined.xml

        mkdir -p $dst/images/callouts
        cp ${docbook5_xsl}/xml/xsl/docbook/images/callouts/*.svg $dst/images/callouts/

        cp ${./style.css} $dst/style.css
        cp ${./overrides.css} $dst/overrides.css
        cp -r ${pkgs.documentation-highlighter} $dst/highlightjs
      '';

  manPages =
    runXmlCommand
      "man-pages"
      { allowedReferences = ["out"]; }
      ''
        # Generate manpages.
        mkdir -p $out/share/man
        xsltproc --nonet \
          --param man.output.in.separate.dir 1 \
          --param man.output.base.dir "'$out/share/man/'" \
          --param man.endnotes.are.numbered 0 \
          --param man.break.after.slash 1 \
          --stringparam target.database.document "${olinkDb}/olinkdb.xml" \
          ${docbook5_xsl}/xml/xsl/docbook/manpages/docbook.xsl \
          ${manualCombined}/man-pages-combined.xml
      '';

in

{
  inherit manualCombined olinkDb;
  inherit html manPages;
}
