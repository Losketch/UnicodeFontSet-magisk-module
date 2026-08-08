use std::{
    panic::{self, AssertUnwindSafe},
    sync::{Mutex, OnceLock},
};

use anyhow::Error;

use crate::rewrite::rewrite_font;

#[derive(Debug)]
pub enum RewriteFailure {
    Error(Error),
    Panicked,
}

pub fn rewrite_font_safely(
    source: &str,
    destination: &str,
    keep: &[u32],
) -> Result<(), RewriteFailure> {
    static PANIC_HOOK_LOCK: OnceLock<Mutex<()>> = OnceLock::new();

    let lock = PANIC_HOOK_LOCK.get_or_init(|| Mutex::new(()));
    let _guard = lock.lock().unwrap_or_else(|poisoned| poisoned.into_inner());

    let original_hook = panic::take_hook();
    panic::set_hook(Box::new(|_| {}));
    let result = panic::catch_unwind(AssertUnwindSafe(|| rewrite_font(source, destination, keep)));
    panic::set_hook(original_hook);

    match result {
        Ok(Ok(())) => Ok(()),
        Ok(Err(error)) => Err(RewriteFailure::Error(error)),
        Err(_) => Err(RewriteFailure::Panicked),
    }
}
