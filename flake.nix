{
  description = "Catapult - cross-platform launcher for Cataclysm: DDA and BN (prebuilt release)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      inherit (pkgs) lib;

      version = "26.10a";
      version_hash = "sha256-WrZnuGXPq9c4PHk5QOFlIxsiED13f93Ap+JfiPB6eMU=";

      # The upstream release binary (single self-contained executable).
      unwrapped = pkgs.stdenvNoCC.mkDerivation {
        pname = "catapult-unwrapped";
        inherit version;

        src = pkgs.fetchurl {
          url = "https://github.com/qrrk/Catapult/releases/download/${version}/catapult-linux-x64-${version}";
          hash = version_hash;
        };

        dontUnpack = true;
        dontStrip = true;
        dontPatchELF = true;
        dontFixup = true;

        installPhase = ''
          install -Dm755 $src $out/bin/catapult
        '';
      };

      launcher = pkgs.writeShellApplication {
        name = "catapult-launch";
        runtimeInputs = [ pkgs.coreutils pkgs.diffutils ];
        text = ''
          data="''${XDG_DATA_HOME:-$HOME/.local/share}/catapult"
          mkdir -p "$data"
          if ! cmp -s ${unwrapped}/bin/catapult "$data/catapult"; then
            install -m755 ${unwrapped}/bin/catapult "$data/catapult.tmp"
            mv -f "$data/catapult.tmp" "$data/catapult"
          fi
          cd "$data"
          exec ./catapult "$@"
        '';
      };

      catapult = pkgs.buildFHSEnv {
        name = "catapult";
        targetPkgs = p: with p; [
          libGL
          libx11 libxcursor libxinerama libxrandr libxi libxext libxrender libxfixes
          libxkbcommon wayland
          alsa-lib libpulseaudio udev dbus fontconfig
          SDL2 SDL2_image SDL2_ttf SDL2_mixer freetype
          zip unzip zlib ncurses
          stdenv.cc.cc.lib
        ];
        runScript = lib.getExe launcher;
        meta = {
          description = "Cross-platform launcher for Cataclysm: DDA and BN";
          homepage = "https://github.com/qrrk/Catapult";
          license = lib.licenses.mit;
          mainProgram = "catapult";
          platforms = [ system ];
        };
      };

      # ==========================================
      # Menu Integration
      # ==========================================

      # 1. Fetch the official icon from the upstream repository
      iconPng = pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/qrrk/Catapult/master/icons/appicon.png";
        hash = "sha256-gfisg62i7f46y7g53xzgxzn3d2jvkk2jf99w480dhkdz75rzdjy1";
      };

      # 2. Place the icon in the standard Freedesktop icon directory structure
      iconDir = pkgs.runCommand "catapult-icon" {} ''
        mkdir -p $out/share/icons/hicolor/256x256/apps
        cp ${iconPng} $out/share/icons/hicolor/256x256/apps/catapult.png
      '';

      # 3. Create the .desktop file
      desktopItem = pkgs.makeDesktopItem {
        name = "catapult";
        desktopName = "Catapult";
        # Using just "catapult" is the standard NixOS approach. 
        # It resolves correctly via PATH once the package is installed.
        exec = "catapult";
        icon = "catapult";
        categories = ["Game" "RolePlaying" "Launcher"];
        comment = "Cross-platform launcher for Cataclysm: DDA and BN";
      };

      # 4. Combine the FHS environment, desktop item, and icon into a single package
      catapultWithDesktop = pkgs.symlinkJoin {
        name = "catapult";
        paths = [ catapult desktopItem iconDir ];
        meta = catapult.meta;
      };

    in
    {
      packages.${system} = {
        default = catapultWithDesktop;
        inherit catapult unwrapped;
      };

      apps.${system}.default = {
        type = "app";
        program = lib.getExe catapultWithDesktop;
      };
    };
}