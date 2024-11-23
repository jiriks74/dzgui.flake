{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    dzgui = {
      url = "github:aclist/dztui?ref=testing";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    dzgui,
  }: let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;

    # Get src and version from the flake
    # This makes `nix flake update dzgui` work for easier updating
    dzguiSrc = dzgui + "/"; # Flake input is a directory or archive
    dzguiVersion = "${dzgui.rev}";

    # Regular dependencies of dzgui
    # NOTE: For extra dependencies needed in nix use dzguiGuiDeps
    dzguiDeps = with pkgs; [
      curl
      gtk3
      inetutils
      jq
      (python311.withPackages (ps: [ ps.pygobject3 ]))
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

    dzguiPkg = pkgs.stdenv.mkDerivation {
      pname = "dzgui";
      version = dzguiVersion;
      src = dzguiSrc;

      patches = [
        ./disable_self_management.patch
        # ./fix_ping.patch
        ./disable_ping.patch # The script checks for internet connection using ping
                             # It can be fixed but it's unreliable as it doesn't work
                             # on other branches. Disabling is just easier.
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
      default = dzgui;
    };

    apps.x86_64-linux =  {
      dzgui = {
        type = "app";
        program = "${self.packages.x86_64-linux.dzgui}/bin/dzgui";
      };
      default = {
        type = "app";
        program = "${self.packages.x86_64-linux.default}/bin/dzgui";
      };
    };
  };
}
