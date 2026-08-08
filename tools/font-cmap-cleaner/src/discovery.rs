use std::{
    collections::BTreeMap,
    path::{Path, PathBuf},
};

use anyhow::Result;

use crate::config::DiscoveryConfig;

#[derive(Clone, Copy, Debug, Eq, Ord, PartialEq, PartialOrd)]
pub enum FontSourceKind {
    System,
    Product,
    SystemExt,
    Vendor,
    Updatable,
    Custom,
}

impl FontSourceKind {
    pub fn label(self) -> &'static str {
        match self {
            Self::System => "system",
            Self::Product => "product",
            Self::SystemExt => "system_ext",
            Self::Vendor => "vendor",
            Self::Updatable => "android-update",
            Self::Custom => "custom",
        }
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct FontSearchRoot {
    pub path: PathBuf,
    pub source: FontSourceKind,
}

pub fn collect_font_xml_paths() -> Result<Vec<PathBuf>> {
    let config = DiscoveryConfig::embedded()?;
    let mut paths = BTreeMap::<PathBuf, ()>::new();

    for dir in &config.font_xml_baseline_dirs {
        let base = PathBuf::from(dir);
        if !base.exists() {
            continue;
        }

        for file in &config.font_xml_familyset_files {
            let path = base.join(file);
            if path.exists() {
                paths.insert(path, ());
            }
        }
    }

    Ok(paths.into_keys().collect())
}

pub fn collect_system_font_dirs(primary: &Path) -> Result<Vec<PathBuf>> {
    let config = DiscoveryConfig::embedded()?;
    Ok(
        collect_font_roots(primary, &config.system_font_baseline_dirs, false, &config)?
            .into_iter()
            .map(|root| root.path)
            .collect(),
    )
}

pub fn collect_find_font_dirs(primary: &Path) -> Result<Vec<FontSearchRoot>> {
    let config = DiscoveryConfig::embedded()?;
    collect_font_roots(primary, &config.system_font_search_dirs, true, &config)
}

fn collect_font_roots(
    primary: &Path,
    configured_dirs: &[String],
    include_updatable: bool,
    config: &DiscoveryConfig,
) -> Result<Vec<FontSearchRoot>> {
    let mut roots = BTreeMap::<PathBuf, FontSourceKind>::new();

    if primary == Path::new("/system/fonts") {
        for candidate in configured_dirs {
            let path = PathBuf::from(candidate);
            if path.is_dir() {
                roots.entry(path.clone()).or_insert(source_kind(&path));
            }
        }

        if include_updatable {
            let path = PathBuf::from(&config.updatable_system_font_dir);
            if path.is_dir() {
                roots.insert(path, FontSourceKind::Updatable);
            }
        }
    } else {
        roots.insert(primary.to_path_buf(), FontSourceKind::Custom);
    }

    Ok(roots
        .into_iter()
        .map(|(path, source)| FontSearchRoot { path, source })
        .collect())
}

fn source_kind(path: &Path) -> FontSourceKind {
    let text = path.to_string_lossy();
    if text.starts_with("/vendor") {
        FontSourceKind::Vendor
    } else if text.starts_with("/product") || text.starts_with("/system/product") {
        FontSourceKind::Product
    } else if text.starts_with("/system_ext") || text.starts_with("/system/system_ext") {
        FontSourceKind::SystemExt
    } else {
        FontSourceKind::System
    }
}
