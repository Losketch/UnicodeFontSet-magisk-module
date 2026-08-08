use std::{
    collections::{BTreeMap, HashSet},
    fs,
    path::{Path, PathBuf},
};

use anyhow::{Context, Result};
use quick_xml::{events::Event, Reader};
use tracing::{debug, warn};
use ttf_parser::Face;
use walkdir::WalkDir;

use crate::font::{face_indices, is_font_path, postscript_name, unicode_codepoints};

#[derive(Clone, Debug, Default, Eq, PartialEq)]
pub struct UpdatableFontConfig {
    /// Randomized directories listed by PersistentSystemFontConfig as currently active.
    pub active_dirs: HashSet<String>,
    /// PostScript names referenced by persistent named-family definitions. Named families are
    /// diagnostic/configuration data; they do not by themselves enter the global fallback baseline.
    pub family_postscript_names: HashSet<String>,
}

#[derive(Clone, Debug)]
pub struct UpdatedFontFace {
    pub path: PathBuf,
    pub face_index: u32,
    pub postscript_name: String,
    pub unicode: HashSet<u32>,
}

pub fn parse_updatable_config(path: &Path) -> Result<UpdatableFontConfig> {
    if !path.is_file() {
        return Ok(UpdatableFontConfig::default());
    }

    let text = fs::read_to_string(path)
        .with_context(|| format!("读取 updatable font config 失败: {}", path.display()))?;
    let mut reader = Reader::from_str(&text);
    reader.config_mut().trim_text(true);
    let mut buf = Vec::new();
    let mut config = UpdatableFontConfig::default();
    let mut family_depth = 0usize;

    loop {
        match reader.read_event_into(&mut buf) {
            Ok(Event::Start(event)) => {
                let tag = String::from_utf8_lossy(event.name().as_ref()).to_ascii_lowercase();
                let attrs = attributes(&event);

                if tag == "updatedfontdir" {
                    if let Some(value) = attrs.get("value") {
                        if is_safe_randomized_dir(value) {
                            config.active_dirs.insert(value.clone());
                        }
                    }
                } else if tag == "family" {
                    family_depth += 1;
                } else if tag == "font" && family_depth > 0 {
                    // AOSP FontUpdateRequest.Font serializes the PostScript name in `name`.
                    // `postscriptname` is accepted as a narrow OEM compatibility alias.
                    if let Some(name) = attrs.get("name").or_else(|| attrs.get("postscriptname")) {
                        if !name.is_empty() {
                            config.family_postscript_names.insert(name.clone());
                        }
                    }
                }
            }
            Ok(Event::Empty(event)) => {
                let tag = String::from_utf8_lossy(event.name().as_ref()).to_ascii_lowercase();
                let attrs = attributes(&event);
                if tag == "updatedfontdir" {
                    if let Some(value) = attrs.get("value") {
                        if is_safe_randomized_dir(value) {
                            config.active_dirs.insert(value.clone());
                        }
                    }
                } else if tag == "font" && family_depth > 0 {
                    if let Some(name) = attrs.get("name").or_else(|| attrs.get("postscriptname")) {
                        if !name.is_empty() {
                            config.family_postscript_names.insert(name.clone());
                        }
                    }
                }
            }
            Ok(Event::End(event)) => {
                if event.name().as_ref().eq_ignore_ascii_case(b"family") && family_depth > 0 {
                    family_depth -= 1;
                }
            }
            Ok(Event::Eof) => break,
            Err(error) => return Err(error.into()),
            _ => {}
        }
        buf.clear();
    }

    Ok(config)
}

fn attributes(event: &quick_xml::events::BytesStart<'_>) -> BTreeMap<String, String> {
    let mut attrs = BTreeMap::new();
    for attribute in event.attributes().flatten() {
        let key = String::from_utf8_lossy(attribute.key.as_ref()).to_ascii_lowercase();
        let value = String::from_utf8_lossy(attribute.value.as_ref())
            .trim()
            .to_string();
        attrs.insert(key, value);
    }
    attrs
}

fn is_safe_randomized_dir(value: &str) -> bool {
    value.starts_with("~~")
        && value.len() > 2
        && value != "."
        && value != ".."
        && !value.contains('/')
        && !value.contains('\\')
}

pub fn collect_active_updated_faces(
    files_root: &Path,
    config: &UpdatableFontConfig,
) -> Result<BTreeMap<String, UpdatedFontFace>> {
    let mut result = BTreeMap::new();
    if config.active_dirs.is_empty() || !files_root.is_dir() {
        return Ok(result);
    }

    for dir_name in &config.active_dirs {
        if !is_safe_randomized_dir(dir_name) {
            warn!(dir = %dir_name, "invalid updated font directory name; skipped");
            continue;
        }
        let directory = files_root.join(dir_name);
        if !directory.is_dir() {
            warn!(dir = %directory.display(), "active updated font directory is missing");
            continue;
        }

        for entry in WalkDir::new(&directory).max_depth(2).follow_links(false) {
            let entry = match entry {
                Ok(entry) => entry,
                Err(error) => {
                    warn!(
                        error = %error,
                        dir = %directory.display(),
                        "walk updated font dir failed"
                    );
                    continue;
                }
            };
            let path = entry.path();
            if !entry.file_type().is_file() || !is_font_path(path) {
                continue;
            }
            let data = match fs::read(path) {
                Ok(data) => data,
                Err(error) => {
                    warn!(path = %path.display(), error = %error, "read updated font failed");
                    continue;
                }
            };
            for face_index in face_indices(&data) {
                let face = match Face::parse(&data, face_index) {
                    Ok(face) => face,
                    Err(error) => {
                        warn!(
                            path = %path.display(),
                            face_index,
                            error = ?error,
                            "parse updated font face failed"
                        );
                        continue;
                    }
                };
                let Some(ps_name) = postscript_name(&face) else {
                    warn!(
                        path = %path.display(),
                        face_index,
                        "updated font has no Unicode PostScript name; skipped"
                    );
                    continue;
                };
                result.insert(
                    ps_name.clone(),
                    UpdatedFontFace {
                        path: path.to_path_buf(),
                        face_index,
                        postscript_name: ps_name,
                        unicode: unicode_codepoints(&face),
                    },
                );
            }
        }
    }

    debug!(count = result.len(), "active updated font faces collected");
    Ok(result)
}
