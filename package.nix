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
  curl,
  gtk3,
  gobject-introspection,
  inetutils,
  jq,
  python311,
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
    curl
    inetutils
    jq
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
    mkdir -p $out/opt

    cp -r {dzgui.sh,helpers,images,CHANGELOG.md} $out/opt
    cp images/{dzgui,grid.png,hero.png,icon.png,logo.png} $out/opt
    mkdir -p $out/opt/helpers/a2s
    cp ${a2s-src}/a2s/* $out/opt/helpers/a2s
    cp ${dayzquery-src}/dayzquery.py $out/opt/helpers/a2s

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
      --replace-fail 'ping -c1 -4' 'ping -c1' \
      --replace-fail 'for dir in "$state_path" "$cache_path" "$share_path" "$helpers_path" "$freedesktop_path" "$config_path" "$log_path"; do' \
        'for dir in "$state_path" "$cache_path" "$config_path" "$log_path"; do' \
      --replace-fail '[[ ! -f $share_path/icon.png ]] && freedesktop_dirs' "" \
      --replace-fail '[[ ! -f "$freedesktop_path/$app_name.desktop" ]] && freedesktop_dirs' "" \
      --replace-fail "    check_version" "" \
      --replace-fail 'fetch_helpers > >(pdialog "Checking helper files")' "" \
      --replace-fail 'source "$config_file"' "source ''\"\$config_file''\"''\nbranch=${dzguiBranch}" \
      --replace-fail '#CONSTANTS' "#CONSTANTS''\nbranch=${dzguiBranch}" \
      --replace-fail '="/usr/bin/zenity"' =${zenity}/bin/zenity \
      --replace-fail '="$HOME/.local/share/$app_name"' "=$out/opt" \
      --replace-fail '="$share_path/dzgui.sh"' "=$out/opt/dzgui.sh" \
      --replace-fail '="$share_path/helpers"' "=$out/opt/helpers"

    substituteInPlace $out/opt/helpers/funcs \
      --replace-fail '="/usr/bin/zenity"' =${zenity}/bin/zenity \
      --replace-fail '="$HOME/.local/share/$app_name"' =$out/opt

    substituteInPlace $out/opt/helpers/lan \
      --replace-fail '="$HOME/.local/share/dzgui/helpers/query_v2.py"' =$out/opt/helpers/query_v2.py

    substituteInPlace $out/opt/helpers/ui.py \
      --replace-fail "= '%s/.local/share/dzgui/helpers' %(user_path)" "= \"$out/opt/helpers\"" \
      --replace-fail "= '%s/CHANGELOG.md' %(state_path)" "= \"$out/opt/CHANGELOG.md\""

    ln -s $out/opt/dzgui.sh $out/bin/dzgui

    runHook postInstall
  '';

  postInstall = dzguiPostInstall;

  preFixup = ''
    gappsWrapperArgs+=(
      --prefix PATH ':' ${lib.makeBinPath buildInputs}
    )
  '';
}
