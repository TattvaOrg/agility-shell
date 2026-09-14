# Maintainer: AbsolOrg <https://github.com/AbsolOrg>
pkgname=agility-shell-git
pkgver=1.3.0.r0.g0000000
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
    'matugen-bin'
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
    'python-thefuzz'
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
source=("git+https://github.com/AbsolOrg/agility-shell.git#branch=expansions")
sha256sums=('SKIP')

pkgver() {
    cd "${srcdir}/agility-shell"
    printf "1.3.0.r%s.g%s" "$(git rev-list --count HEAD)" "$(git rev-parse --short HEAD)"
}

build() {
    cd "${srcdir}/agility-shell"
    make
}

package() {
    cd "${srcdir}/agility-shell"
    make DESTDIR="${pkgdir}" PREFIX="/usr" install
    make DESTDIR="${pkgdir}" PREFIX="/usr" install-venv
}
