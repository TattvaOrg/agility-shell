{ lib
, rustPlatform
, makeWrapper
, pkg-config
, wayland
, pam
, libpulseaudio
, playerctl
, brightnessctl
, wf-recorder
, upower
, swayidle
, networkmanager
, bluez
, quickshell
, matugen
, jq
}:

rustPlatform.buildRustPackage {
  pname = "agility-shell";
  version = "2.0.0";

  src = ./.;

  cargoLock = {
    lockFile = ./Cargo.lock;
  };

  nativeBuildInputs = [
    pkg-config
    makeWrapper
  ];

  buildInputs = [
    wayland
    pam
    libpulseaudio
    playerctl
    brightnessctl
    wf-recorder
    upower
    swayidle
    networkmanager
    bluez
  ];

  postInstall = ''
    mkdir -p $out/share/agility-shell
    mkdir -p $out/share/applications
    mkdir -p $out/lib/systemd/user

    install -m 755 agility-shell $out/bin/agility-shell
    install -m 644 systemd/agility-shell.service $out/lib/systemd/user/
    install -m 644 agility-shell.desktop $out/share/applications/

    cp -r config themes wallpapers svgs sounds quickshell scripts $out/share/agility-shell/

    wrapProgram $out/bin/agility-shell \
      --prefix PATH : ${lib.makeBinPath [ quickshell matugen jq playerctl brightnessctl wf-recorder upower ]}
    wrapProgram $out/bin/agl \
      --prefix PATH : ${lib.makeBinPath [ quickshell matugen jq ]}
  '';

  meta = with lib; {
    description = "Next-generation Wayland desktop shell powered by Rust daemon and Quickshell";
    homepage = "https://github.com/TattvaOrg/agility-shell";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
  };
}