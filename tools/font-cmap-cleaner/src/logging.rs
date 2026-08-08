use std::env;
use tracing_subscriber::{fmt, EnvFilter};

pub fn init_tracing(verbose: bool, no_color: bool) {
    let filter = if verbose {
        EnvFilter::new("trace")
    } else {
        EnvFilter::from_default_env()
            .add_directive("font_cmap_tool=info".parse().expect("valid log directive"))
    };

    let disable_color = no_color
        || env::var_os("NO_COLOR").is_some()
        || env::var("TERM")
            .map(|value| value == "dumb")
            .unwrap_or(false);

    fmt()
        .with_env_filter(filter)
        .with_target(false)
        .with_line_number(false)
        .with_ansi(!disable_color)
        .compact()
        .init();
}
