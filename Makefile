# =============================================================================
#  Agility Shell -- Root Makefile
# =============================================================================

PREFIX ?= /usr
DESTDIR ?=
BINDIR = $(PREFIX)/bin
DATADIR = $(PREFIX)/share/agility-shell
LIBDIR = $(PREFIX)/lib/agility-shell
SYSTEMDDIR = $(PREFIX)/lib/systemd/user
APPLICATIONSDIR = $(PREFIX)/share/applications
PYTHON ?= python3

.PHONY: all clean install install-venv uninstall

all:
	@echo "==> Compiling native snippet libraries..."
	$(MAKE) -C snippets/blur/lib
	$(MAKE) -C snippets/hacktk/lib
	@echo "==> Build complete."

clean:
	@echo "==> Cleaning snippet build artifacts..."
	-$(MAKE) -C snippets/blur/lib clean
	-$(MAKE) -C snippets/hacktk/lib clean
	rm -rf __pycache__ */__pycache__ */*/__pycache__

install: all
	@echo "==> Installing Agility Shell system-wide (PREFIX=$(PREFIX))..."
	mkdir -p $(DESTDIR)$(BINDIR)
	mkdir -p $(DESTDIR)$(DATADIR)
	mkdir -p $(DESTDIR)$(LIBDIR)
	mkdir -p $(DESTDIR)$(SYSTEMDDIR)
	mkdir -p $(DESTDIR)$(APPLICATIONSDIR)

	# Install CLI and launcher binaries
	install -m 755 agility-shell $(DESTDIR)$(BINDIR)/agility-shell
	install -m 755 bin/agl $(DESTDIR)$(BINDIR)/agl

	# Install compiled shared native libraries
	install -m 755 snippets/blur/lib/libblur.so $(DESTDIR)$(LIBDIR)/libblur.so
	install -m 755 snippets/hacktk/lib/libhacktk.so $(DESTDIR)$(LIBDIR)/libhacktk.so

	# Install systemd user service unit
	install -m 644 systemd/agility-shell.service $(DESTDIR)$(SYSTEMDDIR)/agility-shell.service

	# Install desktop entry
	install -m 644 agility-shell.desktop $(DESTDIR)$(APPLICATIONSDIR)/agility-shell.desktop

	# Install application files and assets
	cp -r main.py bar.py lockscreen.py plugin_loader.py user_options.py requirements.txt $(DESTDIR)$(DATADIR)/
	cp -r bar_widgets desktop_applets windows services utils style themes config wallpapers icons svgs sounds snippets quickshell scripts $(DESTDIR)$(DATADIR)/

	# Clean potential build leftovers in target directory
	find $(DESTDIR)$(DATADIR) -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
	find $(DESTDIR)$(DATADIR) -name "*.pyc" -delete 2>/dev/null || true

	@echo "==> Installation to $(DESTDIR)$(PREFIX) complete."

install-venv:
	@echo "==> Provisioning dedicated runtime virtualenv in $(DESTDIR)$(LIBDIR)/venv..."
	mkdir -p $(DESTDIR)$(LIBDIR)
	$(PYTHON) -m venv --system-site-packages $(DESTDIR)$(LIBDIR)/venv
	$(DESTDIR)$(LIBDIR)/venv/bin/pip install --upgrade pip -q
	$(DESTDIR)$(LIBDIR)/venv/bin/pip install -r requirements.txt -q
	@echo "==> Virtual environment provisioned successfully."

uninstall:
	@echo "==> Uninstalling Agility Shell from $(DESTDIR)$(PREFIX)..."
	rm -f $(DESTDIR)$(BINDIR)/agility-shell
	rm -f $(DESTDIR)$(BINDIR)/agl
	rm -f $(DESTDIR)$(SYSTEMDDIR)/agility-shell.service
	rm -f $(DESTDIR)$(APPLICATIONSDIR)/agility-shell.desktop
	rm -rf $(DESTDIR)$(DATADIR)
	rm -rf $(DESTDIR)$(LIBDIR)
	@echo "==> Uninstall complete."
