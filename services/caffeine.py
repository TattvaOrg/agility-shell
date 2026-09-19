import subprocess
from typing import Optional
from fabric.core.service import Service, Property
from loguru import logger

class CaffeineService(Service):
    @Property(bool, "read-write", default_value=False)
    def enabled(self) -> bool:
        return self._enabled

    @enabled.setter
    def enabled(self, value: bool):
        if value == self._enabled:
            return
        self._enabled = value
        self.notify("enabled")
        if value:
            self._start_inhibit()
        else:
            self._stop_inhibit()

    def __init__(self, **kwargs):
        self._enabled = False
        self._process: Optional[subprocess.Popen] = None
        super().__init__(**kwargs)

    def toggle(self):
        self.enabled = not self._enabled

    def _start_inhibit(self):
        try:
            from services.singletons import idle
            if idle:
                idle.stop()
        except Exception as e:
            logger.debug(f"[CaffeineService] Error stopping idle service: {e}")

        try:
            subprocess.run(["pkill", "-x", "swayidle"], check=False, capture_output=True)
        except Exception:
            pass

        try:
            from services.idle import _get_screen_commands
            _, screen_on = _get_screen_commands()
            if screen_on:
                subprocess.Popen(screen_on, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception:
            pass

        try:
            self._process = subprocess.Popen(
                ["systemd-inhibit", "--what=idle:sleep:handle-lid-switch", "--why=Caffeine keep-awake", "--mode=block", "sleep", "infinity"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            logger.info(f"[CaffeineService] Inhibitor started (pid {self._process.pid})")
        except Exception as e:
            logger.warning(f"[CaffeineService] Failed to start inhibitor: {e}")

    def _stop_inhibit(self):
        if self._process is not None:
            try:
                self._process.terminate()
                self._process.wait(timeout=1)
            except Exception:
                try:
                    self._process.kill()
                except Exception:
                    pass
            finally:
                self._process = None
                logger.info("[CaffeineService] Inhibitor stopped")

        try:
            from services.singletons import idle
            if idle:
                idle.start()
        except Exception as e:
            logger.debug(f"[CaffeineService] Error starting idle service: {e}")
