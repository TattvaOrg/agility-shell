use futures_util::StreamExt;

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use tracing::{info, warn};

#[zbus::proxy(
    default_service = "org.freedesktop.login1",
    default_path = "/org/freedesktop/login1/session/auto",
    interface = "org.freedesktop.login1.Session"
)]
trait Login1Session {
    #[zbus(signal)]
    fn lock(&self) -> zbus::Result<()>;

    #[zbus(signal)]
    fn unlock(&self) -> zbus::Result<()>;
}

pub struct LockListener {
    is_locked: Arc<AtomicBool>,
}

impl LockListener {
    pub fn new() -> (Self, Arc<AtomicBool>) {
        let is_locked = Arc::new(AtomicBool::new(false));
        (
            Self {
                is_locked: Arc::clone(&is_locked),
            },
            is_locked,
        )
    }

    pub fn start(&self) {
        let is_locked = Arc::clone(&self.is_locked);

        tokio::spawn(async move {
            info!("Initializing systemd-logind session lock listener...");

            let connection = match zbus::connection::Connection::system().await {
                Ok(conn) => conn,
                Err(e) => {
                    warn!("System D-Bus unavailable for lock monitoring ({e:#}). Session lock listener disabled.");
                    return;
                }
            };

            let proxy = match Login1SessionProxy::new(&connection).await {
                Ok(p) => p,
                Err(e) => {
                    warn!("Failed to create Login1SessionProxy ({e:#}). Session lock listener disabled.");
                    return;
                }
            };

            let mut lock_stream = match proxy.receive_lock().await {
                Ok(s) => s,
                Err(e) => {
                    warn!("Failed to listen for Lock signal ({e:#})");
                    return;
                }
            };

            let mut unlock_stream = match proxy.receive_unlock().await {
                Ok(s) => s,
                Err(e) => {
                    warn!("Failed to listen for Unlock signal ({e:#})");
                    return;
                }
            };

            loop {
                tokio::select! {
                    Some(_) = lock_stream.next() => {
                        info!("Session lock signal received: entering ethereal lock glow mode.");
                        is_locked.store(true, Ordering::SeqCst);
                    }
                    Some(_) = unlock_stream.next() => {
                        info!("Session unlock signal received: restoring normal desktop playback glow.");
                        is_locked.store(false, Ordering::SeqCst);
                    }
                    else => break,
                }
            }
        });
    }
}
