import os
import json
from typing import Callable, Any, ParamSpec, Concatenate

from loguru import logger
from gi.repository import Gio, GLib

from fabric.core.service import Signal, Property
from fabric.utils.helpers import idle_add

from ..base.service import WMService
from .keyboard import NiriKeyboardLayouts
from .window import NiriWindow
from .workspace import NiriWorkspace

P = ParamSpec("P")
NIRI_COMMAND_BUFFER_SIZE = 1_048_576


class NiriSocketNotFoundError(Exception): ...


class Niri(WMService):

    @Signal("workspace-added")
    def workspace_added(self, workspace: object): ...

    @Property(bool, "readable", default_value=False)
    def is_available(self) -> bool:
        socket_path = os.getenv("NIRI_SOCKET")
        return bool(socket_path and os.path.exists(socket_path))

    @Property(object, "readable", default_value=None)
    def keyboard_layouts(self) -> NiriKeyboardLayouts:
        return self._keyboard_layouts

    @Property(object, "readable", default_value=None)
    def windows(self) -> list[NiriWindow]:
        return list(self._windows.values())

    @Property(object, "readable", default_value=None)
    def active_window(self) -> NiriWindow:
        return self._active_window

    @Property(object, "readable", default_value=None)
    def workspaces(self) -> list[NiriWorkspace]:
        return list(self._workspaces.values())

    @Property(str, "readable", default_value="")
    def active_output(self) -> str:
        return self._property_helper_active_output or ""

    @Property(bool, "readable", default_value=False)
    def overview_opened(self) -> bool:
        return self._property_helper_overview_opened or False

    def __init__(self, **kwargs):
        self._keyboard_layouts = NiriKeyboardLayouts(self)
        self._windows: dict[int, NiriWindow] = {}
        self._active_window = NiriWindow(self)
        self._workspaces: dict[int, NiriWorkspace] = {}

        self.socket_path = os.getenv("NIRI_SOCKET")
        if not self.socket_path or not os.path.exists(self.socket_path):
            raise NiriSocketNotFoundError("NIRI_SOCKET not found or invalid.")

        super().__init__(**kwargs)

        self.__listen_events_sync(break_on="OverviewOpenedOrClosed")

        GLib.Thread.new("niri-event-thread", self.__event_thread, None)

        self.notify("is-available")
        self.emit("ready")

    def __event_thread(self, _) -> bool:
        try:
            client = Gio.SocketClient()
            address = Gio.UnixSocketAddress.new(self.socket_path)
            conn: Gio.SocketConnection = client.connect(address)
            ostream = conn.get_output_stream()
            istream = Gio.DataInputStream.new(conn.get_input_stream())

            ostream.write(b'"EventStream"\n')
            ostream.flush()

            while not ostream.is_closed():
                raw = istream.read_line_utf8(None)
                if raw is None or raw[0] is None:
                    continue
                try:
                    event_data = json.loads(raw[0])
                    event_type = next(iter(event_data))
                    payload = event_data[event_type]
                    idle_add(self.__on_event, event_type, payload)
                except Exception as e:
                    logger.error(f"[NiriService] Event parse error: {e}")
        except Exception as e:
            logger.error(f"[NiriService] Event thread error: {e}")

        return False

    def __listen_events_sync(self, break_on: str = "") -> None:
        try:
            client = Gio.SocketClient()
            address = Gio.UnixSocketAddress.new(self.socket_path)
            conn: Gio.SocketConnection = client.connect(address)
            ostream = conn.get_output_stream()
            istream = Gio.DataInputStream.new(conn.get_input_stream())

            ostream.write(b'"EventStream"\n')
            ostream.flush()

            while True:
                raw = istream.read_line_utf8(None)
                if raw is None or raw[0] is None:
                    continue
                try:
                    event_data = json.loads(raw[0])
                    event_type = next(iter(event_data))
                    payload = event_data[event_type]
                    self.__on_event(event_type, payload)
                    if break_on and event_type == break_on:
                        return
                except Exception as e:
                    logger.error(f"[NiriService] Init event parse error: {e}")
        except Exception as e:
            logger.error(f"[NiriService] Init event socket error: {e}")

    def __on_event(self, event_type: str, data: dict) -> None:
        match event_type:
            case "KeyboardLayoutSwitched":
                self.__update_current_layout(data)
            case "KeyboardLayoutsChanged":
                self.__update_keyboard_layouts(data)
            case "WindowClosed":
                self.__destroy_window(data)
            case "WindowFocusChanged":
                self.__update_window_focus(data)
            case "WindowOpenedOrChanged":
                self.__update_window(data)
            case "WindowsChanged":
                self.__update_windows(data)
            case "WindowLayoutsChanged":
                self.__update_window_layouts(data)
            case "WorkspaceActivated":
                self.__update_active_workspace(data)
            case "WorkspaceActiveWindowChanged":
                self.__update_workspace_active_window(data)
            case "WorkspacesChanged":
                self.__update_workspaces(data)
            case "OverviewOpenedOrClosed":
                self.__update_overview_opened(data)

    def __update_current_layout(self, data: dict) -> None:
        self._keyboard_layouts.sync({"current_idx": data["idx"]})
        self.notify("keyboard-layouts")

    def __update_keyboard_layouts(self, data: dict) -> None:
        self._keyboard_layouts.sync(data["keyboard_layouts"])
        self.notify("keyboard-layouts")

    def __sort_windows(self) -> None:
        self._windows = dict(
            sorted(self._windows.items(), key=lambda item: item[1].sort_key())
        )

    def __destroy_window(self, data: dict) -> None:
        window = self._windows.pop(data["id"], None)
        if window:
            window.emit("destroyed")
            self.__sort_windows()
            self.notify("windows")

    def __update_window(self, data: dict) -> None:
        window_data = data["window"]
        window = self._windows.get(window_data["id"])
        if window is None:
            window = NiriWindow(self)

        window.sync(window_data)
        self._windows[window_data["id"]] = window

        if window.is_focused:
            self._active_window.sync(window_data)

        self.__sort_windows()
        self.notify("active-window", "windows")

    def __update_window_focus(self, data: dict) -> None:
        focused_id = data["id"]
        for window in self._windows.values():
            window.sync({"is_focused": window.id == focused_id})

        if focused_id and focused_id in self._windows:
            self._active_window.sync(self._windows[focused_id].data)
        else:
            self._active_window.sync(NiriWindow(self).data)

        self.notify("active-window", "windows")

    def __update_niri_obj(self, store: dict, fresh_data: list, obj_type) -> None:
        for item in fresh_data:
            obj = store.get(item["id"])
            if obj is None:
                obj = obj_type(self)
            obj.sync(item)
            store[item["id"]] = obj

    def __cleanup_niri_obj(self, store: dict, fresh_data: list) -> None:
        fresh_ids = {item["id"] for item in fresh_data}
        for id_, item in list(store.items()):
            if id_ not in fresh_ids:
                store.pop(id_)
                item.emit("destroyed")

    def __update_windows(self, data: dict) -> None:
        windows = data["windows"]
        self.__update_niri_obj(self._windows, windows, NiriWindow)

        for window_data in windows:
            if window_data["is_focused"]:
                self._active_window.sync(window_data)

        self.__cleanup_niri_obj(self._windows, windows)
        self.__sort_windows()
        self.notify("active-window", "windows")

    def __update_window_layouts(self, data: dict) -> None:
        active_changed = False
        for id_, layout in data.get("changes", []):
            if id_ in self._windows:
                self._windows[id_].sync({"layout": layout})
            if id_ == self._active_window.id:
                self._active_window.sync({"layout": layout})
                active_changed = True

        old_order = list(self._windows.keys())
        self.__sort_windows()
        new_order = list(self._windows.keys())
        if old_order != new_order:
            self.notify("windows")
        if active_changed:
            self.notify("active-window")

    def __sort_workspaces(self) -> None:
        self._workspaces = dict(
            sorted(self._workspaces.items(), key=lambda w: w[1].idx)
        )

    def __update_workspaces(self, data: dict) -> None:
        workspaces = data["workspaces"]
        self.__update_niri_obj(self._workspaces, workspaces, NiriWorkspace)
        self.__cleanup_niri_obj(self._workspaces, workspaces)
        self.__sort_workspaces()

        focused = [w for w in self._workspaces.values() if w.is_focused]
        if focused:
            self._property_helper_active_output = focused[0].output
            self.notify("active-output")

        self.notify("workspaces")

    def __update_active_workspace(self, data: dict) -> None:
        active_ws_id = data["id"]
        is_focused = data["focused"]
        output = self._workspaces[active_ws_id].output

        for workspace in self._workspaces.values():
            update = {}
            got_activated = workspace.id == active_ws_id
            if workspace.output == output:
                update["is_active"] = got_activated
            if is_focused:
                update["is_focused"] = got_activated
            workspace.sync(update)

        if is_focused:
            self._property_helper_active_output = output

        self.notify("active-output", "workspaces")

    def __update_workspace_active_window(self, data: dict) -> None:
        ws = self._workspaces.get(data["workspace_id"])
        if ws:
            ws.sync({"active_window_id": data["active_window_id"]})

    def __update_overview_opened(self, data: dict) -> None:
        self._property_helper_overview_opened = data["is_open"]
        self.notify("overview-opened")

    def send_command(self, command: str | dict) -> dict:
        payload = json.dumps(command) if isinstance(command, dict) else f'"{command}"'
        try:
            client = Gio.SocketClient()
            address = Gio.UnixSocketAddress.new(os.getenv("NIRI_SOCKET"))
            conn: Gio.SocketConnection = client.connect(address)
            ostream = conn.get_output_stream()
            istream = Gio.DataInputStream.new(conn.get_input_stream())

            ostream.write((payload + "\n").encode())
            ostream.flush()

            raw = istream.read_line_utf8(None)[0]
            return json.loads(raw)
        except Exception as e:
            logger.error(f"[NiriService] Command error: {e}")
            return {}

    def send_command_async(
        self,
        command: str | dict,
        callback: Callable[Concatenate[dict, P], Any],
        *args: P.args,
        **kwargs: P.kwargs,
    ) -> None:
        payload = json.dumps(command) if isinstance(command, dict) else f'"{command}"'
        client = Gio.SocketClient()
        address = Gio.UnixSocketAddress.new(os.getenv("NIRI_SOCKET"))

        def reader_callback(istream, res, conn):
            try:
                raw = istream.read_line_finish_utf8(res)[0]
                data = json.loads(raw)
            except Exception as e:
                logger.error(f"[NiriService] Async read error: {e}")
                data = {}
            callback(data, *args, **kwargs)

        def connect_callback(client, res, _):
            try:
                conn = client.connect_finish(res)
                ostream = conn.get_output_stream()
                istream = Gio.DataInputStream.new(conn.get_input_stream())
                ostream.write_async(
                    (payload + "\n").encode(),
                    NIRI_COMMAND_BUFFER_SIZE, None, None, None, None,
                )
                ostream.flush_async(1, None, None, None)
                istream.read_line_async(1, None, reader_callback, conn)
            except Exception as e:
                logger.error(f"[NiriService] Async connect error: {e}")

        client.connect_async(address, None, connect_callback, None)

    def switch_kb_layout(self) -> None:
        self.send_command({"Action": {"SwitchLayout": {"layout": "Next"}}})

    def switch_to_workspace(self, idx: int) -> None:
        self.send_command({"Action": {"FocusWorkspace": {"reference": {"Index": idx}}}})

    def switch_to_workspace_by_id(self, workspace_id: int) -> None:
        self.send_command({"Action": {"FocusWorkspace": {"reference": {"Id": workspace_id}}}})

    def get_workspace_by_id(self, workspace_id: int) -> NiriWorkspace | None:
        return self._workspaces.get(workspace_id)
