{
  description = "A flake providing `dzgui` - a better way of launching DayZ on Linux.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    # helpers for dzgui
    a2sSrc = {
      url = "github:yepoleb/python-a2s?rev=c7590ffa9a6d0c6912e17ceeab15b832a1090640";
      flake = false;
    };
    dayzquerySrc = {
      url = "github:yepoleb/dayzquery";
      flake = false;
    };
    # ^ helpers for dzgui

    # dzgui
    dzguiSrc = {
      url = "git+https://codeberg.org/aclist/dztui?ref=dzgui";
      flake = false;
    };
    dzguiSrc-testing = {
      url = "git+https://codeberg.org/aclist/dztui?ref=testing";
      flake = false;
    };
    # ^ dzgui
  };

  outputs = {
    self,
    nixpkgs,
    a2sSrc,
    dayzquerySrc,
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
  in {
    formatter.x86_64-linux = pkgs.alejandra;

    packages.x86_64-linux = rec {
      # Some extra things are needed to make the package work
      # It's a bit unconventional but some things are not bundled
      # with dzgui and I find managing these things with flake inputs easier
      dzgui = pkgs.callPackage ./package.nix {
        a2s-src = a2sSrc;
        dayzquery-src = dayzquerySrc;
        dzguiName = "DZGUI"; # Package name (also used in the desktop file)
        dzgui-src = dzguiSrc;
        patchVer = patchVer;
        dzguiBranch = "stable"; # DZGUI stores it's branch in the config file. It switches
        # to this branch automatically as dzgui manages itself.
        # As it can't manage itself anymore we need to set
        # the branch manually after loading the config file.

        # As of 25. 11. 2024 the ui.py file has major differences
        # and needs to be patched differently in between branches
        # This disables the switch branch option as it's not working (it's a nix package now)
        dzguiPostInstall = ''
          substituteInPlace ''$out/share/dzgui/helpers/ui.py \
            --replace-fail '("Toggle release branch",),' ""
        '';
      };
      dzgui-testing = pkgs.callPackage ./package.nix {
        a2s-src = a2sSrc;
        dayzquery-src = dayzquerySrc;
        dzguiName = "DZGUI-testing";
        dzgui-src = dzguiSrc-testing;
        patchVer = patchVer;
        dzguiBranch = "testing";
        # As of 25. 11. 2024 the ui.py file has major differences
        # and needs to be patched differently in between branches
        # This disables the switch branch option as it's not working (it's a nix package now)
        dzguiPostInstall = ''
          substituteInPlace ''$out/share/dzgui/helpers/ui.py \
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
