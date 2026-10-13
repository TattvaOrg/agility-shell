{
  description = "agility-shell — Next-generation Wayland desktop shell powered by Rust daemon and Quickshell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, utils, ... }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        formatter = pkgs.nixfmt-rfc-style;

        packages.default = pkgs.callPackage ./package.nix {};

        devShells.default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            cargo
            rustc
            pkg-config
            makeWrapper
          ];

          buildInputs = with pkgs; [
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
            matugen
            jq
          ];
        };
      });
}
