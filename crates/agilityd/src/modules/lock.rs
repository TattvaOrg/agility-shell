//! Subsystem module: lock (Secure Linux PAM Lockscreen Worker)
//! Implements isolated worker thread wrapping Linux PAM (`libpam`),
//! rate limiting with exponential backoff, immediate memory zeroization,
//! and D-Bus interface `org.agility.Daemon.Lock`.

use agility_common::LockStatus;
use std::fmt;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};
use tracing::{debug, info, warn};
use zbus::object_server::SignalEmitter;

/// Maximum backoff duration in seconds.
pub const MAX_BACKOFF_SECS: u64 = 30;

/// Secure memory container that zeroes out its buffer on drop and prevents leaking secrets in logs.
pub struct ZeroizingString {
    bytes: Vec<u8>,
}

impl ZeroizingString {
    /// Constructs a `ZeroizingString` from an owned `String`, immediately wiping
    /// the source `String`'s backing buffer with volatile zero writes.
    pub fn new(mut s: String) -> Self {
        let mut bytes = Vec::with_capacity(s.len());
        bytes.extend_from_slice(s.as_bytes());

        // Volatile wipe of original String buffer
        unsafe {
            for b in s.as_bytes_mut() {
                std::ptr::write_volatile(b, 0);
            }
            std::sync::atomic::compiler_fence(std::sync::atomic::Ordering::SeqCst);
        }

        Self { bytes }
    }

    /// Constructs a `ZeroizingString` from a byte slice.
    pub fn from_slice(slice: &[u8]) -> Self {
        let mut bytes = Vec::with_capacity(slice.len());
        bytes.extend_from_slice(slice);
        Self { bytes }
    }

    /// Returns the underlying byte slice.
    pub fn as_bytes(&self) -> &[u8] {
        &self.bytes
    }

    /// Returns whether the buffer is empty.
    pub fn is_empty(&self) -> bool {
        self.bytes.is_empty()
    }

    /// Length in bytes.
    pub fn len(&self) -> usize {
        self.bytes.len()
    }

    /// Explicitly overwrites all bytes in memory with zeros using volatile writes.
    pub fn zeroize(&mut self) {
        for b in self.bytes.iter_mut() {
            unsafe {
                std::ptr::write_volatile(b, 0);
            }
        }
        std::sync::atomic::compiler_fence(std::sync::atomic::Ordering::SeqCst);
    }
}

impl Drop for ZeroizingString {
    fn drop(&mut self) {
        self.zeroize();
    }
}

impl Clone for ZeroizingString {
    fn clone(&self) -> Self {
        Self::from_slice(&self.bytes)
    }
}

impl fmt::Debug for ZeroizingString {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "[REDACTED]")
    }
}

/// Rate limiter tracking consecutive failed authentication attempts and exponential backoff.
#[derive(Debug, Clone)]
pub struct RateLimiter {
    consecutive_failures: u32,
    lockout_until: Option<Instant>,
    max_delay_secs: u64,
}

impl Default for RateLimiter {
    fn default() -> Self {
        Self::new(MAX_BACKOFF_SECS)
    }
}

impl RateLimiter {
    pub fn new(max_delay_secs: u64) -> Self {
        Self {
            consecutive_failures: 0,
            lockout_until: None,
            max_delay_secs,
        }
    }

    /// Returns whether the system is currently locked out from authentication attempts.
    pub fn is_locked_out(&self) -> bool {
        if let Some(until) = self.lockout_until {
            Instant::now() < until
        } else {
            false
        }
    }

    /// Returns the remaining lockout duration in seconds (0.0 if not locked out).
    pub fn remaining_lockout_secs(&self) -> f64 {
        if let Some(until) = self.lockout_until {
            let now = Instant::now();
            if until > now {
                return (until - now).as_secs_f64();
            }
        }
        0.0
    }

    /// Returns the count of consecutive failed attempts.
    pub fn failed_attempts(&self) -> u32 {
        self.consecutive_failures
    }

    /// Records a successful authentication attempt, resetting failure counters and lockout state.
    pub fn record_success(&mut self) {
        self.consecutive_failures = 0;
        self.lockout_until = None;
    }

    /// Records a failed authentication attempt, computing exponential backoff delay.
    ///
    /// Backoff schedule:
    /// - 0..=2 failures: 0 seconds (grace margin for typos)
    /// - 3 failures: 1 second
    /// - 4 failures: 2 seconds
    /// - 5 failures: 4 seconds
    /// - 6 failures: 8 seconds
    /// - 7 failures: 16 seconds
    /// - 8+ failures: capped at `max_delay_secs` (default 30 seconds)
    pub fn record_failure(&mut self) -> u64 {
        self.consecutive_failures = self.consecutive_failures.saturating_add(1);
        let delay_secs = match self.consecutive_failures {
            0..=2 => 0,
            3 => 1,
            4 => 2,
            5 => 4,
            6 => 8,
            7 => 16,
            _ => self.max_delay_secs,
        };

        if delay_secs > 0 {
            self.lockout_until = Some(Instant::now() + Duration::from_secs(delay_secs));
        } else {
            self.lockout_until = None;
        }

        delay_secs
    }

    /// Manually reset rate limiter state.
    pub fn reset(&mut self) {
        self.consecutive_failures = 0;
        self.lockout_until = None;
    }
}

/// Abstract authentication backend trait allowing mock injection in tests.
pub trait AuthBackend: Send + Sync {
    fn authenticate(&self, user: &str, password: &ZeroizingString) -> bool;
}

/// Linux PAM authentication backend wrapping `pam-sys`.
pub struct PamBackend {
    pub custom_service: Option<String>,
}

impl PamBackend {
    pub fn new(service: Option<String>) -> Self {
        Self {
            custom_service: service,
        }
    }
}

/// Candidate PAM services in preference order when no custom service is provided.
const CANDIDATE_SERVICES: &[&str] = &[
    "agility-lock",
    "hyprlock",
    "login",
    "system-auth",
    "vlock",
    "passwd",
];

#[cfg(feature = "pam")]
struct PamUserData {
    password: ZeroizingString,
    user: String,
    last_error: Option<String>,
}

#[cfg(feature = "pam")]
extern "C" fn pam_conversation_callback(
    num_msg: libc::c_int,
    msg: *mut *mut pam_sys::types::PamMessage,
    resp: *mut *mut pam_sys::types::PamResponse,
    appdata_ptr: *mut libc::c_void,
) -> libc::c_int {
    unsafe {
        if num_msg <= 0 || num_msg > 32 || msg.is_null() || resp.is_null() || appdata_ptr.is_null()
        {
            return pam_sys::types::PamReturnCode::CONV_ERR as libc::c_int;
        }

        let data = &mut *(appdata_ptr as *mut PamUserData);

        // Allocate array of PamResponse structs using libc::calloc (PAM will call libc::free)
        let responses = libc::calloc(
            num_msg as usize,
            std::mem::size_of::<pam_sys::types::PamResponse>(),
        ) as *mut pam_sys::types::PamResponse;

        if responses.is_null() {
            return pam_sys::types::PamReturnCode::BUF_ERR as libc::c_int;
        }

        for i in 0..num_msg as usize {
            let msg_ptr = *msg.add(i);
            if msg_ptr.is_null() {
                for j in 0..i {
                    let r = (*responses.add(j)).resp;
                    if !r.is_null() {
                        libc::free(r as *mut libc::c_void);
                    }
                }
                libc::free(responses as *mut libc::c_void);
                return pam_sys::types::PamReturnCode::CONV_ERR as libc::c_int;
            }

            let style = (*msg_ptr).msg_style;
            let msg_text = if (*msg_ptr).msg.is_null() {
                ""
            } else {
                std::ffi::CStr::from_ptr((*msg_ptr).msg)
                    .to_str()
                    .unwrap_or("")
            };

            match style {
                1 => {
                    // PAM_PROMPT_ECHO_OFF: Password prompt
                    let pw_bytes = data.password.as_bytes();
                    let len = pw_bytes.len();
                    let ptr = libc::malloc(len + 1) as *mut libc::c_char;
                    if ptr.is_null() {
                        for j in 0..i {
                            let r = (*responses.add(j)).resp;
                            if !r.is_null() {
                                libc::free(r as *mut libc::c_void);
                            }
                        }
                        libc::free(responses as *mut libc::c_void);
                        return pam_sys::types::PamReturnCode::BUF_ERR as libc::c_int;
                    }
                    std::ptr::copy_nonoverlapping(
                        pw_bytes.as_ptr() as *const libc::c_char,
                        ptr,
                        len,
                    );
                    *ptr.add(len) = 0;
                    (*responses.add(i)).resp = ptr;
                    (*responses.add(i)).resp_retcode = 0;
                }
                2 => {
                    // PAM_PROMPT_ECHO_ON: User / prompt text
                    let user_bytes = data.user.as_bytes();
                    let len = user_bytes.len();
                    let ptr = libc::malloc(len + 1) as *mut libc::c_char;
                    if ptr.is_null() {
                        for j in 0..i {
                            let r = (*responses.add(j)).resp;
                            if !r.is_null() {
                                libc::free(r as *mut libc::c_void);
                            }
                        }
                        libc::free(responses as *mut libc::c_void);
                        return pam_sys::types::PamReturnCode::BUF_ERR as libc::c_int;
                    }
                    std::ptr::copy_nonoverlapping(
                        user_bytes.as_ptr() as *const libc::c_char,
                        ptr,
                        len,
                    );
                    *ptr.add(len) = 0;
                    (*responses.add(i)).resp = ptr;
                    (*responses.add(i)).resp_retcode = 0;
                }
                3 => {
                    // PAM_ERROR_MSG: Log error message from PAM
                    warn!("PAM error message: {msg_text}");
                    data.last_error = Some(msg_text.to_string());
                    (*responses.add(i)).resp = std::ptr::null_mut();
                    (*responses.add(i)).resp_retcode = 0;
                }
                4 => {
                    // PAM_TEXT_INFO: Informational message
                    info!("PAM text info: {msg_text}");
                    (*responses.add(i)).resp = std::ptr::null_mut();
                    (*responses.add(i)).resp_retcode = 0;
                }
                _ => {
                    (*responses.add(i)).resp = std::ptr::null_mut();
                    (*responses.add(i)).resp_retcode = 0;
                }
            }
        }

        *resp = responses;
        pam_sys::types::PamReturnCode::SUCCESS as libc::c_int
    }
}

#[cfg(feature = "pam")]
fn authenticate_pam_single(
    service: &str,
    user: &str,
    password: &ZeroizingString,
) -> Result<bool, String> {
    let mut data = PamUserData {
        password: ZeroizingString::from_slice(password.as_bytes()),
        user: user.to_string(),
        last_error: None,
    };

    let conv = pam_sys::types::PamConversation {
        conv: Some(pam_conversation_callback),
        data_ptr: (&mut data as *mut PamUserData) as *mut libc::c_void,
    };

    let service_c = std::ffi::CString::new(service).map_err(|e| e.to_string())?;
    let user_c = std::ffi::CString::new(user).map_err(|e| e.to_string())?;
    let mut pamh: *const pam_sys::types::PamHandle = std::ptr::null();

    let start_res =
        unsafe { pam_sys::raw::pam_start(service_c.as_ptr(), user_c.as_ptr(), &conv, &mut pamh) };

    if start_res != pam_sys::types::PamReturnCode::SUCCESS as libc::c_int {
        data.password.zeroize();
        return Err(format!("pam_start failed for service '{service}'"));
    }

    let pamh_mut = pamh as *mut pam_sys::types::PamHandle;
    let auth_res = unsafe { pam_sys::raw::pam_authenticate(pamh_mut, 0) };

    let acct_res = if auth_res == pam_sys::types::PamReturnCode::SUCCESS as libc::c_int {
        unsafe { pam_sys::raw::pam_acct_mgmt(pamh_mut, 0) }
    } else {
        auth_res
    };

    // End PAM transaction
    unsafe {
        pam_sys::raw::pam_end(pamh_mut, auth_res);
    }

    // Zero-out password in memory immediately!
    data.password.zeroize();

    if auth_res == pam_sys::types::PamReturnCode::SUCCESS as libc::c_int
        && (acct_res == pam_sys::types::PamReturnCode::SUCCESS as libc::c_int
            || acct_res == pam_sys::types::PamReturnCode::NEW_AUTHTOK_REQD as libc::c_int)
    {
        Ok(true)
    } else {
        debug!(
            "PAM auth failure on service '{}' (code: {}, acct: {})",
            service, auth_res, acct_res
        );
        Ok(false)
    }
}

impl AuthBackend for PamBackend {
    fn authenticate(&self, user: &str, password: &ZeroizingString) -> bool {
        #[cfg(feature = "pam")]
        {
            let services_to_try: Vec<&str> = if let Some(ref svc) = self.custom_service {
                vec![svc.as_str()]
            } else {
                CANDIDATE_SERVICES.to_vec()
            };

            for svc in services_to_try {
                // If service file doesn't exist in /etc/pam.d/ and is not standard login/system-auth, skip
                if !std::path::Path::new(&format!("/etc/pam.d/{svc}")).exists()
                    && svc != "login"
                    && svc != "system-auth"
                {
                    continue;
                }

                match authenticate_pam_single(svc, user, password) {
                    Ok(true) => return true,
                    Ok(false) => {
                        debug!("PAM rejected authentication for user '{user}' on service '{svc}'");
                    }
                    Err(e) => {
                        debug!("PAM error on service '{svc}': {e}");
                    }
                }
            }
            false
        }
        #[cfg(not(feature = "pam"))]
        {
            let _ = (user, password);
            warn!("PAM feature is not compiled in agilityd");
            false
        }
    }
}

/// Request sent to the isolated worker thread.
struct PamWorkerRequest {
    user: String,
    password: ZeroizingString,
    responder: tokio::sync::oneshot::Sender<bool>,
}

/// Retrieves the current system username.
pub fn get_current_username() -> String {
    if let Ok(user) = std::env::var("USER") {
        if !user.trim().is_empty() {
            return user.trim().to_string();
        }
    }
    if let Ok(user) = std::env::var("LOGNAME") {
        if !user.trim().is_empty() {
            return user.trim().to_string();
        }
    }
    unsafe {
        let uid = libc::getuid();
        let pwd = libc::getpwuid(uid);
        if !pwd.is_null() && !(*pwd).pw_name.is_null() {
            let c_str = std::ffi::CStr::from_ptr((*pwd).pw_name);
            if let Ok(s) = c_str.to_str() {
                if !s.is_empty() {
                    return s.to_string();
                }
            }
        }
    }
    "user".to_string()
}

/// Secure Linux PAM Lockscreen Service managing rate limiting and worker thread dispatch.
pub struct LockService {
    rate_limiter: Arc<Mutex<RateLimiter>>,
    worker_tx: std::sync::mpsc::Sender<PamWorkerRequest>,
    default_user: String,
}

impl LockService {
    /// Constructs a new `LockService` using the production `PamBackend`.
    pub fn new(service_name: Option<String>) -> Self {
        let backend = Arc::new(PamBackend::new(service_name));
        Self::with_backend(backend)
    }

    /// Constructs a `LockService` with a custom authentication backend (used in tests and PAM).
    pub fn with_backend(backend: Arc<dyn AuthBackend>) -> Self {
        let (tx, rx) = std::sync::mpsc::channel::<PamWorkerRequest>();

        // Spawn isolated worker thread wrapping Linux PAM
        let _ = std::thread::Builder::new()
            .name("agilityd-pam-worker".to_string())
            .spawn(move || {
                while let Ok(mut req) = rx.recv() {
                    let result = backend.authenticate(&req.user, &req.password);
                    // Explicit zeroization of password memory in worker thread
                    req.password.zeroize();
                    let _ = req.responder.send(result);
                }
            });

        Self {
            rate_limiter: Arc::new(Mutex::new(RateLimiter::default())),
            worker_tx: tx,
            default_user: get_current_username(),
        }
    }

    /// Authenticates current user with given password string.
    /// Password memory is immediately wrapped in `ZeroizingString` and wiped from original string.
    pub async fn authenticate(&self, password: String) -> bool {
        self.authenticate_for_user(&self.default_user, password)
            .await
    }

    /// Authenticates a specific user with password string.
    pub async fn authenticate_for_user(&self, user: &str, password: String) -> bool {
        // Wrap in ZeroizingString; wipes the input String buffer immediately
        let mut secure_password = ZeroizingString::new(password);

        // Check rate limiting lockout
        {
            let limiter = self.rate_limiter.lock().unwrap();
            if limiter.is_locked_out() {
                let remaining = limiter.remaining_lockout_secs();
                warn!(
                    "Authentication attempt blocked by rate limiter for user '{user}'. Locked out for {remaining:.1}s."
                );
                secure_password.zeroize();
                return false;
            }
        }

        let (resp_tx, resp_rx) = tokio::sync::oneshot::channel();
        let request = PamWorkerRequest {
            user: user.to_string(),
            password: secure_password,
            responder: resp_tx,
        };

        if self.worker_tx.send(request).is_err() {
            warn!("PAM worker channel disconnected");
            return false;
        }

        // Wait for worker with 10-second timeout to avoid indefinite hanging
        match tokio::time::timeout(Duration::from_secs(10), resp_rx).await {
            Ok(Ok(true)) => {
                let mut limiter = self.rate_limiter.lock().unwrap();
                limiter.record_success();
                info!("Authentication successful for user '{user}'");
                true
            }
            Ok(Ok(false)) => {
                let mut limiter = self.rate_limiter.lock().unwrap();
                let delay = limiter.record_failure();
                let failures = limiter.failed_attempts();
                warn!(
                    "Authentication failed for user '{user}'. Failure count: {failures}. Lockout delay: {delay}s."
                );
                false
            }
            Ok(Err(_)) => {
                warn!("PAM worker dropped response channel");
                false
            }
            Err(_) => {
                warn!("PAM worker authentication timed out");
                false
            }
        }
    }

    /// Requests session lock, emitting lock request to Quickshell and systemd logind.
    pub async fn lock_session(&self) {
        info!("Session lock requested via org.agility.Daemon.Lock");

        // Notify systemd-logind via loginctl lock-session as system-level lock trigger
        tokio::spawn(async move {
            let _ = tokio::process::Command::new("loginctl")
                .arg("lock-session")
                .output()
                .await;
        });
    }

    /// Check if authentication is currently locked out.
    pub fn is_locked_out(&self) -> bool {
        self.rate_limiter.lock().unwrap().is_locked_out()
    }

    /// Count of consecutive failed authentication attempts.
    pub fn failed_attempts(&self) -> u32 {
        self.rate_limiter.lock().unwrap().failed_attempts()
    }

    /// Remaining lockout duration in seconds.
    pub fn remaining_lockout_secs(&self) -> f64 {
        self.rate_limiter.lock().unwrap().remaining_lockout_secs()
    }

    /// Retrieves current lock status snapshot.
    pub fn status(&self) -> LockStatus {
        let limiter = self.rate_limiter.lock().unwrap();
        LockStatus {
            is_locked_out: limiter.is_locked_out(),
            failed_attempts: limiter.failed_attempts(),
            remaining_lockout_secs: limiter.remaining_lockout_secs() as u64,
        }
    }

    /// Resets the rate limiter (e.g. for testing).
    pub fn reset_rate_limit(&self) {
        self.rate_limiter.lock().unwrap().reset();
    }
}

/// D-Bus interface wrapper implementing `org.agility.Daemon.Lock`.
pub struct LockInterface {
    service: Arc<LockService>,
}

impl LockInterface {
    pub fn new(service: Arc<LockService>) -> Self {
        Self { service }
    }
}

#[zbus::interface(name = "org.agility.Daemon.Lock")]
impl LockInterface {
    /// Verifies password via isolated Linux PAM worker thread.
    async fn authenticate(
        &self,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
        password: String,
    ) -> bool {
        let success = self.service.authenticate(password).await;
        let _ = Self::auth_result(&emitter, success).await;
        success
    }

    /// Emits lock request to Quickshell WlrSessionLock and logind.
    async fn lock_session(
        &self,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
    ) -> zbus::fdo::Result<()> {
        self.service.lock_session().await;
        let _ = Self::lock_requested(&emitter).await;
        Ok(())
    }

    /// Whether authentication is currently locked out due to rate limiting.
    #[zbus(property)]
    async fn is_locked_out(&self) -> bool {
        self.service.is_locked_out()
    }

    /// Number of consecutive failed authentication attempts.
    #[zbus(property)]
    async fn failed_attempts(&self) -> u32 {
        self.service.failed_attempts()
    }

    /// Remaining lockout duration in seconds.
    #[zbus(property)]
    async fn remaining_lockout_secs(&self) -> f64 {
        self.service.remaining_lockout_secs()
    }

    /// Retrieve full lock status as JSON.
    async fn get_status(&self) -> String {
        serde_json::to_string(&self.service.status()).unwrap_or_default()
    }

    /// Signal emitted when a session lock is requested.
    #[zbus(signal)]
    async fn lock_requested(emitter: &SignalEmitter<'_>) -> zbus::Result<()>;

    /// Signal emitted when an authentication attempt completes.
    #[zbus(signal)]
    async fn auth_result(emitter: &SignalEmitter<'_>, success: bool) -> zbus::Result<()>;
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Mock authentication backend for deterministic unit tests.
    struct MockAuthBackend {
        valid_password: &'static str,
    }

    impl AuthBackend for MockAuthBackend {
        fn authenticate(&self, _user: &str, password: &ZeroizingString) -> bool {
            password.as_bytes() == self.valid_password.as_bytes()
        }
    }

    #[test]
    fn test_zeroizing_string_memory_wiping() {
        let original = "super_secret_password_12345".to_string();
        let mut secure = ZeroizingString::new(original);

        assert_eq!(secure.as_bytes(), b"super_secret_password_12345");
        assert_eq!(format!("{secure:?}"), "[REDACTED]");

        // Explicit zeroize
        secure.zeroize();
        for &byte in secure.as_bytes() {
            assert_eq!(byte, 0, "All bytes must be zeroed out");
        }
    }

    #[test]
    fn test_zeroizing_string_from_slice() {
        let slice = b"my_token";
        let mut secure = ZeroizingString::from_slice(slice);
        assert_eq!(secure.len(), 8);
        assert!(!secure.is_empty());

        secure.zeroize();
        for &b in secure.as_bytes() {
            assert_eq!(b, 0);
        }
    }

    #[test]
    fn test_rate_limiter_backoff_schedule() {
        let mut limiter = RateLimiter::new(30);

        // Failures 1 and 2: grace period (0s delay)
        assert_eq!(limiter.record_failure(), 0);
        assert_eq!(limiter.failed_attempts(), 1);
        assert!(!limiter.is_locked_out());

        assert_eq!(limiter.record_failure(), 0);
        assert_eq!(limiter.failed_attempts(), 2);
        assert!(!limiter.is_locked_out());

        // Failure 3: 1s delay
        assert_eq!(limiter.record_failure(), 1);
        assert_eq!(limiter.failed_attempts(), 3);
        assert!(limiter.is_locked_out());
        assert!(limiter.remaining_lockout_secs() > 0.0);

        // Failure 4: 2s delay
        assert_eq!(limiter.record_failure(), 2);
        assert_eq!(limiter.failed_attempts(), 4);

        // Failure 5: 4s delay
        assert_eq!(limiter.record_failure(), 4);

        // Failure 6: 8s delay
        assert_eq!(limiter.record_failure(), 8);

        // Failure 7: 16s delay
        assert_eq!(limiter.record_failure(), 16);

        // Failure 8+: capped at 30s
        assert_eq!(limiter.record_failure(), 30);
        assert_eq!(limiter.record_failure(), 30);

        // Success resets counter and lockout
        limiter.record_success();
        assert_eq!(limiter.failed_attempts(), 0);
        assert!(!limiter.is_locked_out());
        assert_eq!(limiter.remaining_lockout_secs(), 0.0);
    }

    #[tokio::test]
    async fn test_lock_service_authentication_with_mock() {
        let mock_backend = Arc::new(MockAuthBackend {
            valid_password: "correct_password",
        });
        let service = LockService::with_backend(mock_backend);

        // Test wrong password -> failure
        let res1 = service.authenticate("wrong_password".to_string()).await;
        assert!(!res1);
        assert_eq!(service.failed_attempts(), 1);
        assert!(!service.is_locked_out());

        // Test correct password -> success
        let res2 = service.authenticate("correct_password".to_string()).await;
        assert!(res2);
        assert_eq!(service.failed_attempts(), 0);
        assert!(!service.is_locked_out());
    }

    #[tokio::test]
    async fn test_lock_service_rate_limiting_lockout() {
        let mock_backend = Arc::new(MockAuthBackend {
            valid_password: "unlock_secret",
        });
        let service = LockService::with_backend(mock_backend);

        // Perform 3 failures to trigger lockout
        for _ in 0..3 {
            let res = service.authenticate("bad".to_string()).await;
            assert!(!res);
        }

        assert_eq!(service.failed_attempts(), 3);
        assert!(service.is_locked_out());

        // An attempt while locked out (even with correct password) must be rejected immediately
        let blocked = service.authenticate("unlock_secret".to_string()).await;
        assert!(!blocked, "Locked-out attempts must be blocked");

        // Manually reset rate limit and authenticate again
        service.reset_rate_limit();
        assert!(!service.is_locked_out());

        let res = service.authenticate("unlock_secret".to_string()).await;
        assert!(res);
        assert_eq!(service.failed_attempts(), 0);
    }

    #[test]
    fn test_lock_status_serialization() {
        let status = LockStatus {
            is_locked_out: true,
            failed_attempts: 5,
            remaining_lockout_secs: 4,
        };
        let json = serde_json::to_string(&status).expect("Serialization failed");
        assert!(json.contains("\"is_locked_out\":true"));
        assert!(json.contains("\"failed_attempts\":5"));
        assert!(json.contains("\"remaining_lockout_secs\":4"));
    }
}
