{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, flake-utils }: with flake-utils.lib;
  let
    mk010 = system: let
      pkgs = nixpkgs.legacyPackages."${system}";
    in with pkgs; stdenv.mkDerivation rec {
      name = "010editor";
      version = "15.0.1";
      src = fetchurl {
        url = "https://download.sweetscape.com/010EditorLinux64Installer${version}.tar.gz";
        hash = "sha256-MRMAxJ8p9U88hxOJ7CjCAgRhviSy3dSaevGC2MiMTq4=";
      };

      buildInputs = with libsForQt5.qt5; [
        qtbase
        qttools
        qtx11extras
        libsForQt5.quazip
        libgcc
        cups
      ];
      nativeBuildInputs = with libsForQt5.qt5; [
        autoPatchelfHook
        wrapQtAppsHook
        makeWrapper
      ];

      sourceRoot = ".";

      postUnpack = ''
        ls -la $sourceRoot 2> /dev/null
        mv 010editor unpackSrc
        mv unpackSrc/* ./
      '';

      # prePatch = ''
      #   ls -la $sourceRoot 2> /dev/null
      #   ls -la . 2> /dev/null
      #   echo $PWD 2> /dev/null
        
      #   #exit 1
      #   patchelf --replace-needed libquazip.so.1 libquazip1-qt5.so 010editor
      # '';

      installPhase = ''
        mkdir $out && cp -ar * $out

        # Patch executable and libs
        for file in \
          $out/010editor \
          $out/lib/*;
        do
          patchelf --set-rpath "${stdenv.cc.cc.lib}/lib:${stdenv.cc.cc.lib}/lib64" "$file"
        done

        # Don't use wrapped QT plugins since they are already included in the
        # package, else the program crashes because of the conflict.
        wrapProgram $out/010editor --unset QT_PLUGIN_PATH --set QT_QPA_PLATFORM=xcb

        mkdir $out/bin
        ln -s $out/010editor $out/bin/010editor

        # Copy the icon and generated desktop file
        install -D 010_icon_128x128.png -t $out/share/icons/hicolor/128x128/apps/
        install -D $desktopItem/share/applications/* -t $out/share/applications/
      '';

      qtWrapperArgs = [
        # wayland is currently broken, remove when TS3 fixes that
        "--set QT_QPA_PLATFORM xcb"
        "--unset QT_PLUGIN_PATH"
      ];
      
      desktopItem = makeDesktopItem {
        name = "010editor";
        exec = "010editor %f";
        icon = "010_icon_128x128";
        desktopName = "010 Editor";
        genericName = "Text and hex edtior";
        categories = [ "Development" ];
        mimeTypes = [
          "text/html"
          "text/plain"
          "text/x-c++hdr"
          "text/x-c++src"
          "text/xml"
        ];
      };

      dontConfigure = true;
      dontBuild = true;

      outputs = ["out"];

      meta.mainProgram = "010editor";
    };
  in
    eachSystem [ system.x86_64-linux ] (system: {
      packages.default = mk010 system;
    });
}
