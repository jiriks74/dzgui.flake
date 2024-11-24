{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    dzgui = {
      url = "github:aclist/dztui?ref=main";
      flake = false;
    };
    dzgui-testing = {
      url = "github:aclist/dztui?ref=testing";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    dzgui,
    dzgui-testing,
    ...
  }: let
    # Patch version of the package
    # When I make an update to the package while the sourced didn't update
    # the updated package won't be build as it's still the same version.
    # Appending this variable to the package version solves this.
    patchVer = "1.0.0";

    pkgs = nixpkgs.legacyPackages.x86_64-linux;

    # Regular dependencies of dzgui
    # NOTE: For extra dependencies needed in nix use dzguiGuiDeps
    dzguiDeps = with pkgs; [
      curl
      gtk3
      inetutils
      jq
      (python311.withPackages (ps: [ps.pygobject3]))
      wmctrl
      xdotool
      zenity
    ];

    # Extra dependencies that need to be installed because we use nix
    dzguiGuiDeps = with pkgs; [
      # GUI
      at-spi2-core.out
      gdk-pixbuf.out
      glib.out
      gobject-introspection
      gobject-introspection-unwrapped
      gsettings-desktop-schemas.out
      gtk3.out
      harfbuzz.out
      pango.out
    ];

    dzguiPkg = pkgs.stdenv.mkDerivation rec {
      pname = "DZGUI";
      # Get src and version from the flake
      # This makes `nix flake update dzgui` work for easier updating
      src = dzgui + "/"; # Flake input is a directory or archive
      version = "${dzgui.rev}-${patchVer}";

      patches = [
        ./patches/main/disable_self_management.patch
        ./patches/main/disable_branch_switch.patch
        ./patches/main/fix_ping.patch
      ];

      nativeBuildInputs = with pkgs; [
        makeWrapper
      ];

      buildInputs = dzguiDeps ++ dzguiGuiDeps;

      installPhase = ''
        runHook preInstall
        mkdir -p $out/bin
        mkdir -p $out/opt

        cp -r {dzgui.sh,helpers,images} $out/opt

        for i in 16 24 48 64 96 128 256; do
          mkdir -p $out/share/icons/hicolor/''${i}x''${i}/apps
          cp images/icons/''${i}.png $out/share/icons/hicolor/''${i}x''${i}/apps/dzgui.png
        done

        mkdir -p $out/share/applications
        cat << EOF >> $out/share/applications/${pname}.desktop
        [Desktop Entry]
        Version=1.0
        Type=Application
        Terminal=false
        Exec=$out/bin/dzgui
        Name=$pname
        Comment=DayZ GUI server browser and frontend for Linux
        Icon=dzgui
        Categories=Game
        EOF

        substituteInPlace $out/opt/dzgui.sh \
          --replace-fail '="/usr/bin/zenity"' =${pkgs.zenity}/bin/zenity \
          --replace-fail '="$HOME/.local/share/$app_name"' =$out/opt \
          --replace-fail '="$share_path/dzgui.sh"' =$out/opt/dzgui.sh \
          --replace-fail '="$share_path/helpers"' =$out/opt/helpers

        substituteInPlace $out/opt/helpers/funcs \
          --replace-fail '="/usr/bin/zenity"' =${pkgs.zenity}/bin/zenity \
          --replace-fail '="$HOME/.local/share/$app_name"' =$out/opt

        substituteInPlace $out/opt/helpers/lan \
          --replace-fail '="$HOME/.local/share/dzgui/helpers/query_v2.py"' =$out/opt/helpers/query_v2.py

        ln -s $out/opt/dzgui.sh $out/bin/dzgui

        # GI_TYPELIB_PATH doesn't get set automatically unless it's a nix-shell or nix develop
        # To get the necessary paths and packages add the dependencies to dzguiDeps,
        # run `nix develop` and `echo $GI_TYPELIB_PATH` to get the paths.
        #
        # Then figure out the packages and paths that are missing.
        # New packages (that get installed as dependencies) go into `dzguiGuiDeps`
        # and the paths go below.
        #
        # WARN: Some packages (like glib and gtk3) will need `.out`, `.lib`
        # depending on what package output is needed.
        # Use https://github.com/nix-community/nix-index-database if you're not sure.
        wrapProgram $out/bin/dzgui \
          --prefix GI_TYPELIB_PATH : "${pkgs.at-spi2-core.out}/lib/girepository-1.0" \
          --prefix GI_TYPELIB_PATH : "${pkgs.gdk-pixbuf.out}/lib/girepository-1.0" \
          --prefix GI_TYPELIB_PATH : "${pkgs.glib.out}/lib/girepository-1.0" \
          --prefix GI_TYPELIB_PATH : "${pkgs.gobject-introspection}/lib/girepository-1.0" \
          --prefix GI_TYPELIB_PATH : "${pkgs.gobject-introspection-unwrapped}/lib/girepository-1.0" \
          --prefix GI_TYPELIB_PATH : "${pkgs.gsettings-desktop-schemas.out}/lib/girepository-1.0" \
          --prefix GI_TYPELIB_PATH : "${pkgs.gtk3.out}/lib/girepository-1.0" \
          --prefix GI_TYPELIB_PATH : "${pkgs.harfbuzz.out}/lib/girepository-1.0" \
          --prefix GI_TYPELIB_PATH : "${pkgs.pango.out}/lib/girepository-1.0" \
          --prefix PATH : "${pkgs.lib.makeBinPath dzguiDeps}"

        runHook postInstall
      '';
    };

    dzguiPkg-testing = dzguiPkg.overrideAttrs (old: {
      pname = "DZGUI-testing";
      src = dzgui-testing + "/";
      version = "${dzgui-testing.rev}-${patchVer}";
      patches = [
        ./patches/testing/disable_self_management.patch
        ./patches/testing/disable_branch_switch.patch
        ./patches/testing/fix_ping.patch
      ];
    });

    dzguiShell = pkgs.mkShell {
      packages = dzguiDeps ++ [dzguiPkg];
    };
  in {
    formatter.x86_64-linux = pkgs.alejandra;

    devShells.x86_64-linux = rec {
      dzgui = dzguiShell;
      default = dzgui;
    };

    packages.x86_64-linux = rec {
      dzgui = dzguiPkg;
      dzgui-testing = dzguiPkg-testing;
      default = dzgui;
    };

    apps.x86_64-linux = {
      dzgui = {
        type = "app";
        program = "${self.packages.x86_64-linux.dzgui}/bin/dzgui";
      };
      dzgui-testing = {
        type = "app";
        program = "${self.packages.x86_64-linux.dzgui-testing}/bin/dzgui";
      };
      default = {
        type = "app";
        program = "${self.packages.x86_64-linux.default}/bin/dzgui";
      };
    };
  };
}
