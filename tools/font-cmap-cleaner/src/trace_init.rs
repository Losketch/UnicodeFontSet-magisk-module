use tracing_subscriber::{fmt, EnvFilter};

pub fn init_tracing(verbose: bool, json: bool) {
    let filter = if verbose {
        EnvFilter::new("trace")
    } else {
        EnvFilter::from_default_env()
            .add_directive("font_cmap_tool=info".parse().unwrap())
    };

    let builder = fmt()
        .with_env_filter(filter)
        .with_target(true)
        .with_thread_ids(true)
        .with_line_number(true);

    if json {
        builder.json().init();
    } else {
        builder.init();
    }
}
