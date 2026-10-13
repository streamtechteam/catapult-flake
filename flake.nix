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
        # Don't touch the ELF: it has an embedded PCK that stripping/patching could corrupt.
        dontStrip = true;
        dontPatchELF = true;
        dontFixup = true;

        installPhase = ''
          install -Dm755 $src $out/bin/catapult
        '';
      };

      # Catapult needs write access to the folder containing its executable,
      # so copy it to a writable data dir and run it from there.
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

      # FHS env: the launcher is a generic Linux binary (expects /lib64/ld-linux),
      # and so are the game builds it downloads (they need SDL2 etc.).
      catapult = pkgs.buildFHSEnv {
        name = "catapult";
        targetPkgs = p: with p; [
          # Godot runtime libs (dlopen'd)
          libGL
          libx11 libxcursor libxinerama libxrandr libxi libxext libxrender libxfixes
          libxkbcommon wayland
          alsa-lib libpulseaudio udev dbus fontconfig
          # Game builds (from the README's dependency list)
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
    in
    {
      packages.${system} = {
        default = catapult;
        inherit catapult unwrapped;
      };

      apps.${system}.default = {
        type = "app";
        program = lib.getExe catapult;
      };
    };
}