{
  a2s-src,
  dayzquery-src,
  dzguiName,
  dzgui-src,
  dzguiBranch,
  patchVer,
  dzguiPostInstall,
  lib,
  stdenv,
  makeWrapper,
  wrapGAppsHook,
  gawk,
  curl,
  gobject-introspection,
  inetutils,
  jq,
  python311,
  sysctl,
  wmctrl,
  xdotool,
  zenity,
}:
stdenv.mkDerivation rec {
  pname = dzguiName;
  # Get src and version from the flake
  # This makes `nix flake update dzgui` work for easier updating
  src = dzgui-src + "/"; # Flake input is a directory or archive
  version = "${dzgui-src.rev}-${patchVer}";

  buildInputs = [
    gawk
    curl
    inetutils
    jq
    sysctl
    wmctrl
    xdotool
    zenity

    # GUI
    (python311.withPackages (ps: [ps.pygobject3]))
  ];

  nativeBuildInputs = [
    makeWrapper
    wrapGAppsHook
    gobject-introspection
  ];

  patches = [
    # ./patches/main/disable_self_management.patch
    # ./patches/main/disable_branch_switch.patch
    # ./patches/main/fix_ping.patch
  ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    mkdir -p $out/share/dzgui

    cp -r {dzgui.sh,helpers,images,CHANGELOG.md} $out/share/dzgui
    cp images/{dzgui,grid.png,hero.png,icon.png,logo.png} $out/share/dzgui
    mkdir -p $out/share/dzgui/helpers/a2s
    cp ${a2s-src}/a2s/* $out/share/dzgui/helpers/a2s
    cp ${dayzquery-src}/dayzquery.py $out/share/dzgui/helpers/a2s

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

    substituteInPlace $out/share/dzgui/dzgui.sh \
      --replace-fail 'for dir in "$state_path" "$cache_path" "$share_path" "$helpers_path" "$freedesktop_path" "$config_path" "$log_path"; do' \
        'for dir in "$state_path" "$cache_path" "$config_path" "$log_path"; do' \
      --replace-fail '[[ ! -f $share_path/icon.png ]] && freedesktop_dirs' "" \
      --replace-fail '[[ ! -f "$freedesktop_path/$app_name.desktop" ]] && freedesktop_dirs' "" \
      --replace-fail "    check_version" "" \
      --replace-fail 'fetch_helpers > >(pdialog "Checking helper files")' "" \
      --replace-fail 'source "$config_file"' "source ''\"\$config_file''\"''\nbranch=${dzguiBranch}" \
      --replace-fail '#CONSTANTS' "#CONSTANTS''\nbranch=${dzguiBranch}" \
      --replace-fail '="/usr/bin/zenity"' =${zenity}/bin/zenity \
      --replace-fail '="$HOME/.local/share/$app_name"' "=$out/share/dzgui" \
      --replace-fail '="$share_path/dzgui.sh"' "=$out/share/dzgui/dzgui.sh" \
      --replace-fail '="$share_path/helpers"' "=$out/share/dzgui/helpers"

    substituteInPlace $out/share/dzgui/helpers/funcs \
      --replace-fail '="/usr/bin/zenity"' =${zenity}/bin/zenity \
      --replace-fail '="$HOME/.local/share/$app_name"' =$out/share/dzgui

    substituteInPlace $out/share/dzgui/helpers/lan \
      --replace-fail '="$HOME/.local/share/dzgui/helpers/query_v2.py"' =$out/share/dzgui/helpers/query_v2.py

    substituteInPlace $out/share/dzgui/helpers/ui.py \
      --replace-fail "= '%s/.local/share/dzgui/helpers' %(user_path)" "= \"$out/share/dzgui/helpers\"" \
      --replace-fail "= '%s/CHANGELOG.md' %(state_path)" "= \"$out/share/dzgui/CHANGELOG.md\""

    ln -s $out/share/dzgui/dzgui.sh $out/bin/dzgui

    runHook postInstall
  '';

  postInstall = dzguiPostInstall;

  preFixup = ''
    gappsWrapperArgs+=(
      --prefix PATH ':' ${lib.makeBinPath buildInputs}
    )
  '';
}
