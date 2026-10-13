//! PAM Authentication Tool (Replaces quickshell/agility/Scripts/system/auth.py)

use std::ffi::CString;
use std::io::{self, BufRead};

struct PamData {
    password: String,
    user: String,
}

extern "C" fn pam_conversation(
    num_msg: libc::c_int,
    msg: *mut *mut pam_sys::types::PamMessage,
    resp: *mut *mut pam_sys::types::PamResponse,
    appdata_ptr: *mut libc::c_void,
) -> libc::c_int {
    unsafe {
        if num_msg <= 0 || msg.is_null() || resp.is_null() || appdata_ptr.is_null() {
            return pam_sys::types::PamReturnCode::CONV_ERR as libc::c_int;
        }

        let data = &*(appdata_ptr as *const PamData);
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
            if style == 1 || style == 2 {
                let bytes = if style == 1 {
                    data.password.as_bytes()
                } else {
                    data.user.as_bytes()
                };
                let len = bytes.len();
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
                std::ptr::copy_nonoverlapping(bytes.as_ptr() as *const libc::c_char, ptr, len);
                *ptr.add(len) = 0;
                (*responses.add(i)).resp = ptr;
                (*responses.add(i)).resp_retcode = 0;
            } else {
                (*responses.add(i)).resp = std::ptr::null_mut();
                (*responses.add(i)).resp_retcode = 0;
            }
        }

        *resp = responses;
        pam_sys::types::PamReturnCode::SUCCESS as libc::c_int
    }
}

pub fn authenticate(password: &str) -> bool {
    let username = std::env::var("USER")
        .or_else(|_| std::env::var("LOGNAME"))
        .unwrap_or_else(|_| "cachy".to_string());

    let candidates = ["agility-lock", "hyprlock", "system-auth", "login", "passwd"];

    for s in candidates {
        let service = match CString::new(s) {
            Ok(c) => c,
            Err(_) => continue,
        };
        let user_c = match CString::new(username.clone()) {
            Ok(c) => c,
            Err(_) => continue,
        };
        let mut pam_data = PamData {
            password: password.to_string(),
            user: username.clone(),
        };

        let conv = pam_sys::types::PamConversation {
            conv: Some(pam_conversation),
            data_ptr: (&mut pam_data as *mut PamData) as *mut libc::c_void,
        };

        unsafe {
            let mut pamh: *const pam_sys::types::PamHandle = std::ptr::null();
            let ret = pam_sys::raw::pam_start(
                service.as_ptr(),
                user_c.as_ptr(),
                &conv,
                &mut pamh,
            );

            if ret != pam_sys::types::PamReturnCode::SUCCESS as libc::c_int || pamh.is_null() {
                continue;
            }

            let pamh_mut = pamh as *mut pam_sys::types::PamHandle;
            let auth_ret = pam_sys::raw::pam_authenticate(pamh_mut, 0);
            let acct_ret = pam_sys::raw::pam_acct_mgmt(pamh_mut, 0);
            pam_sys::raw::pam_end(pamh_mut, auth_ret);

            if auth_ret == pam_sys::types::PamReturnCode::SUCCESS as libc::c_int
                && acct_ret == pam_sys::types::PamReturnCode::SUCCESS as libc::c_int
            {
                return true;
            }
        }
    }

    false
}

pub fn run(args: &[String]) -> i32 {
    let password = if !args.is_empty() {
        args[0].clone()
    } else {
        let stdin = io::stdin();
        let mut line = String::new();
        let _ = stdin.lock().read_line(&mut line);
        line.trim_end_matches(['\r', '\n']).to_string()
    };

    if authenticate(&password) {
        0
    } else {
        1
    }
}
