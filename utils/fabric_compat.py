"""
Agility Shell - Fabric & PyGObject Compatibility Layer
======================================================
Resolves TypeError exceptions with PyGObject >= 3.52 / 3.56 where introspected
enums without native GType registrations (such as GtkLayerShell.Layer and
GtkLayerShell.KeyboardMode) inherit from Python enum.IntEnum and cannot be directly
registered as typed GObject properties or converted from string representations.
"""

import enum

def apply_fabric_pygobject_patch():
    try:
        import fabric.core.service
    except ImportError:
        return

    prop_cls = getattr(fabric.core.service, "Property", None)
    if not prop_cls or getattr(prop_cls, "_pygobject_patched", False):
        return

    orig_init = prop_cls.__init__

    def patched_init(
        self,
        type=object,
        flags=fabric.core.service.GObject.ParamFlags.READWRITE,
        nickname=None,
        description="",
        default_value=None,
        minimum=None,
        maximum=None,
        getter=None,
        setter=None,
        install=True,
        **kwargs,
    ):
        t = type
        _t = object
        try:
            if hasattr(t, "__gtype__"):
                _t = t
            elif isinstance(t, type):
                if issubclass(t, bool):
                    _t = bool
                elif issubclass(t, int) and not issubclass(t, enum.Enum):
                    _t = int
                elif issubclass(t, float):
                    _t = float
                elif issubclass(t, str) and not issubclass(t, enum.Enum):
                    _t = str
                else:
                    _t = object
            else:
                _t = object
        except (TypeError, Exception):
            _t = object

        if _t is object:
            default_value = None
            minimum = None
            maximum = None

        return orig_init(
            self,
            type=_t,
            flags=flags,
            nickname=nickname,
            description=description,
            default_value=default_value,
            minimum=minimum if _t in (int, float) else None,
            maximum=maximum if _t in (int, float) else None,
            getter=getter,
            setter=setter,
            install=install,
            **kwargs,
        )

    prop_cls.__init__ = patched_init
    prop_cls._pygobject_patched = True

apply_fabric_pygobject_patch()
