# Maintainer: AbsolOrg <https://github.com/AbsolOrg>
pkgname=agility-shell-git
pkgver=2.0.0.r0.g0000000
pkgrel=1
pkgdesc="Next-generation Wayland desktop shell powered by Rust daemon and Quickshell"
arch=('x86_64' 'aarch64')
url="https://github.com/TattvaOrg/agility-shell"
license=('GPL-3.0-or-later')
depends=(
    'wayland'
    'niri'
    'quickshell'
    'pam'
    'libpulse'
    'playerctl'
    'brightnessctl'
    'wf-recorder'
    'upower'
    'swayidle'
    'networkmanager'
    'bluez'
    'matugen'
    'jq'
)
makedepends=('git' 'gcc' 'make' 'pkgconf' 'cargo')
optdepends=(
    'pipewire: for audio playback support'
    'wireplumber: for audio device and volume management'
    'grim: for screenshot region capture'
    'slurp: for interactive screen area selection'
)
provides=('agility-shell' 'agilityd' 'agl')
conflicts=('agility-shell')

if [[ -f "${startdir}/Cargo.toml" && -f "${startdir}/Makefile" ]]; then
    _intree=true
    source=()
    sha256sums=()
else
    _intree=false
    source=("${pkgname}::git+https://github.com/TattvaOrg/agility-shell.git#branch=main")
    sha256sums=('SKIP')
fi

pkgver() {
    if [[ "${_intree}" == "true" ]]; then
        cd "${startdir}"
    else
        cd "${srcdir}/${pkgname}"
    fi
    if git rev-parse --git-dir &>/dev/null; then
        printf "2.0.0.r%s.g%s" "$(git rev-list --count HEAD)" "$(git rev-parse --short HEAD)"
    else
        echo "2.0.0"
    fi
}

build() {
    if [[ "${_intree}" == "true" ]]; then
        cd "${startdir}"
    else
        cd "${srcdir}/${pkgname}"
    fi
    make build
}

package() {
    if [[ "${_intree}" == "true" ]]; then
        cd "${startdir}"
    else
        cd "${srcdir}/${pkgname}"
    fi
    make DESTDIR="${pkgdir}" PREFIX="/usr" install
}
