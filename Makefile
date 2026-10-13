# =============================================================================
#  Agility Shell -- Root Makefile
#  Next-Gen Rust (`agilityd`, `agl`) & Quickshell Architecture
# =============================================================================

PREFIX ?= /usr
DESTDIR ?=
BINDIR = $(PREFIX)/bin
DATADIR = $(PREFIX)/share/agility-shell
SYSTEMDDIR = $(PREFIX)/lib/systemd/user
APPLICATIONSDIR = $(PREFIX)/share/applications

CARGO ?= cargo

.PHONY: all build build-rust check clean install uninstall

all: build

build: build-rust

build-rust:
	@echo "==> Compiling Agility Shell Next-Gen Rust workspace (release)..."
	$(CARGO) build --release

check:
	@echo "==> Checking Agility Shell Rust workspace..."
	$(CARGO) check

clean:
	@echo "==> Cleaning build artifacts..."
	-$(CARGO) clean

install: build
	@echo "==> Installing Agility Shell Next-Gen system-wide (PREFIX=$(PREFIX))..."
	mkdir -p $(DESTDIR)$(BINDIR)
	mkdir -p $(DESTDIR)$(DATADIR)
	mkdir -p $(DESTDIR)$(SYSTEMDDIR)
	mkdir -p $(DESTDIR)$(APPLICATIONSDIR)

	# Install Next-Gen Rust binaries
	install -m 755 target/release/agilityd $(DESTDIR)$(BINDIR)/agilityd
	install -m 755 target/release/agl $(DESTDIR)$(BINDIR)/agl
	install -m 755 agility-shell $(DESTDIR)$(BINDIR)/agility-shell

	# Install systemd user service unit
	install -m 644 systemd/agility-shell.service $(DESTDIR)$(SYSTEMDDIR)/agility-shell.service

	# Install desktop entry
	install -m 644 agility-shell.desktop $(DESTDIR)$(APPLICATIONSDIR)/agility-shell.desktop

	# Install application files and assets
	cp -r config themes wallpapers svgs sounds quickshell scripts $(DESTDIR)$(DATADIR)/

	@echo "==> Installation to $(DESTDIR)$(PREFIX) complete."

uninstall:
	@echo "==> Uninstalling Agility Shell from $(DESTDIR)$(PREFIX)..."
	rm -f $(DESTDIR)$(BINDIR)/agility-shell
	rm -f $(DESTDIR)$(BINDIR)/agilityd
	rm -f $(DESTDIR)$(BINDIR)/agl
	rm -f $(DESTDIR)$(SYSTEMDDIR)/agility-shell.service
	rm -f $(DESTDIR)$(APPLICATIONSDIR)/agility-shell.desktop
	rm -rf $(DESTDIR)$(DATADIR)
	@echo "==> Uninstall complete."
