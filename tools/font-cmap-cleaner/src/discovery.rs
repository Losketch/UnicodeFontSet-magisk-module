use std::{
    collections::BTreeSet,
    path::{Path, PathBuf},
};

const FONT_XML_FILES: &[&str] = &[
    "fonts.xml",
    "fonts_base.xml",
    "fonts_fallback.xml",
    "font_fallback.xml",
    "fonts_inter.xml",
    "fonts_slate.xml",
    "fonts_ule.xml",
    "fonts_flyme.xml",
    "flyme_fallback.xml",
    "flyme_font_fallback.xml",
    "fonts_customization.xml",
];

const FONT_XML_DIRS: &[&str] = &[
    "/system/etc",
    "/system/product/etc",
    "/system/system_ext/etc",
    "/vendor/etc",
    "/product/etc",
];

pub fn collect_font_xml_paths() -> Vec<PathBuf> {
    let mut paths = BTreeSet::new();

    for dir in FONT_XML_DIRS {
        let base = PathBuf::from(dir);
        if !base.exists() {
            continue;
        }

        for file in FONT_XML_FILES {
            let path = base.join(file);
            if path.exists() {
                paths.insert(path);
            }
        }
    }

    paths.into_iter().collect()
}

const ADDITIONAL_SYSTEM_FONT_DIRS: &[&str] = &[
    "/product/fonts",
    "/system/product/fonts",
    "/system_ext/fonts",
    "/system/system_ext/fonts",
    "/vendor/fonts",
];

const UPDATABLE_SYSTEM_FONT_DIR: &str = "/data/fonts/files";

pub fn collect_system_font_dirs(primary: &Path) -> Vec<PathBuf> {
    collect_font_dirs(primary, false)
}

pub fn collect_find_font_dirs(primary: &Path) -> Vec<PathBuf> {
    collect_font_dirs(primary, true)
}

fn collect_font_dirs(primary: &Path, include_updatable: bool) -> Vec<PathBuf> {
    let mut paths = BTreeSet::new();
    paths.insert(primary.to_path_buf());

    if primary == Path::new("/system/fonts") {
        for candidate in ADDITIONAL_SYSTEM_FONT_DIRS {
            let path = PathBuf::from(candidate);
            if path.is_dir() {
                paths.insert(path);
            }
        }

        if include_updatable {
            let path = PathBuf::from(UPDATABLE_SYSTEM_FONT_DIR);
            if path.is_dir() {
                paths.insert(path);
            }
        }
    }

    paths.into_iter().collect()
}
