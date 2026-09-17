from fabric.core.service import Service, Signal, Property
from loguru import logger
from user_options import user_options
import services.singletons as singletons

PROFILES = {
    "optimized": {
        "name": "Optimized",
        "desc": "Ultra-low CPU & power saving for older hardware or battery life",
        "sysmon_interval_ms": 5000,
        "brightness_poll_ms": 3500,
    },
    "balanced": {
        "name": "Balanced",
        "desc": "Everyday responsive desktop shell with smooth animations",
        "sysmon_interval_ms": 3000,
        "brightness_poll_ms": 2000,
    },
    "dedicated": {
        "name": "Dedicated",
        "desc": "High-frequency real-time telemetry and maximum visual flair",
        "sysmon_interval_ms": 1000,
        "brightness_poll_ms": 1000,
    },
}

class AgilityProfileService(Service):
    _instance = None

    @Signal
    def profile_changed(self, profile: str) -> None: ...

    @Property(str, "read-write")
    def current_profile(self) -> str:
        return self._current_profile

    @classmethod
    def get_instance(cls) -> "AgilityProfileService":
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self._current_profile = getattr(user_options.settings, "agility_profile", "optimized")
        if self._current_profile not in PROFILES:
            self._current_profile = "optimized"
        self._apply_profile(self._current_profile, initial=True)

    def set_profile(self, profile_name: str) -> bool:
        if profile_name not in PROFILES:
            logger.warning(f"[AgilityProfile] Unknown profile '{profile_name}'. Must be one of {list(PROFILES.keys())}")
            return False

        if profile_name == self._current_profile:
            return True

        self._current_profile = profile_name
        setattr(user_options.settings, "agility_profile", profile_name)
        try:
            user_options.save()
        except Exception as e:
            logger.error(f"[AgilityProfile] Failed to save options: {e}")

        self._apply_profile(profile_name)
        self.profile_changed(profile_name)
        self.notify("current-profile")
        logger.info(f"[AgilityProfile] Active profile switched to '{profile_name}' ({PROFILES[profile_name]['name']})")
        return True

    def _apply_profile(self, profile_name: str, initial: bool = False) -> None:
        cfg = PROFILES.get(profile_name, PROFILES["optimized"])

        # Tune sysmon polling interval
        if hasattr(singletons, "sysmon") and singletons.sysmon:
            singletons.sysmon.set_interval(cfg["sysmon_interval_ms"])

        # Tune brightness polling interval
        if hasattr(singletons, "brightness") and singletons.brightness:
            singletons.brightness.POLL_INTERVAL = cfg["brightness_poll_ms"]
            if hasattr(singletons.brightness, "_poll_timer_id") and singletons.brightness._poll_timer_id:
                singletons.brightness._setup_polling()

        logger.debug(f"[AgilityProfile] Applied settings for '{profile_name}' (initial={initial})")
