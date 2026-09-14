# Maintainer: AbsolOrg <https://github.com/AbsolOrg>
pkgname=agility-shell-git
pkgver=1.3.0.r366.ge270d87
pkgrel=1
pkgdesc="Next-generation Wayland desktop shell powered by Fabric and GTK3"
arch=('x86_64' 'aarch64')
url="https://github.com/AbsolOrg/agility-shell"
license=('GPL-3.0-or-later')
depends=(
    'gtk3'
    'cairo'
    'libgirepository'
    'gobject-introspection-runtime'
    'gtk-layer-shell'
    'libdbusmenu-gtk3'
    'gtk-session-lock'
    'cinnamon-desktop'
    'gnome-bluetooth-3.0'
    'matugen'
    'playerctl'
    'brightnessctl'
    'wf-recorder'
    'upower'
    'swayidle'
    'networkmanager'
    'bluez'
    'python'
    'python-pip'
    'python-gobject'
    'python-cairo'
    'python-pillow'
    'python-psutil'
    'python-cffi'
    'python-click'
    'python-loguru'
    'python-setproctitle'
    'python-rapidfuzz'
    'awww'
    'niri'
)
makedepends=('git' 'gcc' 'make' 'pkgconf')
optdepends=(
    'quickshell: for advanced desktop applets and awe widgets'
    'pipewire: for audio playback support'
    'wireplumber: for audio device and volume management'
)
provides=('agility-shell')
conflicts=('agility-shell')
if [[ -f "${startdir}/main.py" && -f "${startdir}/Makefile" ]]; then
    _intree=true
    source=()
    sha256sums=()
else
    _intree=false
    source=("${pkgname}::git+https://github.com/TattvaOrg/agility-shell.git#branch=expansions")
    sha256sums=('SKIP')
fi

pkgver() {
    if [[ "${_intree}" == "true" ]]; then
        cd "${startdir}"
    else
        cd "${srcdir}/${pkgname}"
    fi
    if git rev-parse --git-dir &>/dev/null; then
        printf "1.3.0.r%s.g%s" "$(git rev-list --count HEAD)" "$(git rev-parse --short HEAD)"
    else
        echo "1.3.0"
    fi
}

build() {
    if [[ "${_intree}" == "true" ]]; then
        cd "${startdir}"
    else
        cd "${srcdir}/${pkgname}"
    fi
    make
}

package() {
    if [[ "${_intree}" == "true" ]]; then
        cd "${startdir}"
    else
        cd "${srcdir}/${pkgname}"
    fi
    make DESTDIR="${pkgdir}" PREFIX="/usr" install
    make DESTDIR="${pkgdir}" PREFIX="/usr" install-venv
}

