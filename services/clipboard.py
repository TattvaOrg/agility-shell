import time
from typing import List, Dict
from fabric.core.service import Service, Property, Signal
from gi.repository import Gtk, Gdk, GLib
from loguru import logger

class ClipboardService(Service):
    @Signal
    def changed(self) -> None: ...

    @Property(list, "readable")
    def history(self) -> List[Dict]:
        return self._history

    def __init__(self, max_items: int = 50, **kwargs):
        super().__init__(**kwargs)
        self._max_items = max_items
        self._history: List[Dict] = []
        self._clipboard = Gtk.Clipboard.get(Gdk.SELECTION_CLIPBOARD)
        self._last_text = ""

        # Event-driven clipboard listening (zero CPU polling)
        try:
            self._clipboard.connect("owner-change", self._on_owner_change)
            self._clipboard.request_text(self._on_text_received)
        except Exception as e:
            logger.warning(f"[ClipboardService] Failed to connect owner-change: {e}")
            GLib.timeout_add(5000, self._check_clipboard)

    def _on_owner_change(self, clipboard, event):
        try:
            clipboard.request_text(self._on_text_received)
        except Exception:
            pass

    def _on_text_received(self, clipboard, text, data=None):
        if text and text.strip() and text != self._last_text:
            self._last_text = text
            self.add_item(text)

    def _check_clipboard(self) -> bool:
        try:
            self._clipboard.request_text(self._on_text_received)
        except Exception as e:
            logger.debug(f"[ClipboardService] Error reading clipboard: {e}")
        return True

    def add_item(self, text: str):
        text = text.strip()
        if not text:
            return

        # Remove duplicate if exists
        self._history = [item for item in self._history if item["text"] != text]

        item = {
            "text": text,
            "preview": text if len(text) <= 120 else text[:117] + "...",
            "timestamp": time.strftime("%H:%M"),
        }
        self._history.insert(0, item)
        if len(self._history) > self._max_items:
            self._history = self._history[:self._max_items]

        self.notify("history")
        self.emit("changed")

    def copy_text(self, text: str):
        self._last_text = text
        self._clipboard.set_text(text, -1)
        self._clipboard.store()

    def clear(self):
        self._history.clear()
        self._last_text = ""
        self.notify("history")
        self.emit("changed")
