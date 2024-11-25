{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    a2s = {
      url = "github:yepoleb/python-a2s?rev=c7590ffa9a6d0c6912e17ceeab15b832a1090640";
      flake = false;
    };

    dayzquery = {
      url = "github:aclist/dayzquery?rev=3088bbfb147b77bc7b6a9425581b439889ff3f7f";
      flake = false;
    };

    dzguiSrc = {
      url = "github:aclist/dztui?ref=dzgui";
      flake = false;
    };
    dzguiSrc-testing = {
      url = "github:aclist/dztui?ref=testing";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    a2s,
    dayzquery,
    dzguiSrc,
    dzguiSrc-testing,
    ...
  }: let
    # Patch version of the package
    # When I make an update to the package while the sourced didn't update
    # the updated package won't be build as it's still the same version.
    # Appending this variable to the package version solves this.
    patchVer = "1.0.1";

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
    # dzguiPkg-testing = dzguiPkg.overrideAttrs (old: {
    #   pname = "DZGUI-testing";
    #   src = dzgui-testing + "/";
    #   version = "${dzgui-testing.rev}-${patchVer}";
    #   patches = [
    #     ./patches/testing/disable_self_management.patch
    #     ./patches/testing/disable_branch_switch.patch
    #     ./patches/testing/fix_ping.patch
    #   ];
    # });
  in {
    formatter.x86_64-linux = pkgs.alejandra;

    packages.x86_64-linux = rec {
      dzgui = pkgs.callPackage ./package.nix {
        a2s-src = a2s;
        dayzquery-src = dayzquery;
        dzguiName = "DZGUI";
        dzgui-src = dzguiSrc;
        patchVer = patchVer;
        dzguiBranch = "stable";
        dzguiPostInstall = ''
          substituteInPlace ''$out/opt/helpers/ui.py \
            --replace-fail '("Toggle release branch",),' "" \
        '';
      };
      dzgui-testing = pkgs.callPackage ./package.nix {
        a2s-src = a2s;
        dayzquery-src = dayzquery;
        dzguiName = "DZGUI-testing";
        dzgui-src = dzguiSrc-testing;
        patchVer = patchVer;
        dzguiBranch = "testing";
        dzguiPostInstall = ''
          substituteInPlace ''$out/opt/helpers/ui.py \
            --replace 'RowType.TGL_BRANCH,' ""
        '';
      };

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
