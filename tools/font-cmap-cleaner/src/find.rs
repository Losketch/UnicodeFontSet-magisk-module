use std::{
    collections::BTreeSet,
    fs,
    path::{Path, PathBuf},
};

use anyhow::{bail, Result};
use tracing::{debug, warn};
use ttf_parser::Face;
use walkdir::WalkDir;

use crate::font::{face_indices, is_font_path, unicode_glyph_index};

pub fn find_fonts_containing(directory: &Path, codepoint: u32) -> Result<Vec<PathBuf>> {
    if !directory.is_dir() {
        bail!("系统字体目录不存在或不是目录: {}", directory.display());
    }

    let mut result = BTreeSet::new();

    for entry in WalkDir::new(directory).follow_links(true) {
        let entry = match entry {
            Ok(entry) => entry,
            Err(error) => {
                warn!(error = %error, "遍历系统字体目录失败，已跳过该项");
                continue;
            }
        };

        let path = entry.path();
        if !entry.file_type().is_file() && !entry.file_type().is_symlink() {
            continue;
        }
        if !is_font_path(path) {
            continue;
        }

        let data = match fs::read(path) {
            Ok(data) => data,
            Err(error) => {
                warn!(path = %path.display(), error = %error, "读取字体失败，已跳过");
                continue;
            }
        };

        let mut found = false;
        for face_index in face_indices(&data) {
            let face = match Face::parse(&data, face_index) {
                Ok(face) => face,
                Err(error) => {
                    debug!(
                        path = %path.display(),
                        face_index,
                        error = ?error,
                        "字体 face 解析失败，已跳过"
                    );
                    continue;
                }
            };

            if unicode_glyph_index(&face, codepoint).is_some() {
                found = true;
                break;
            }
        }

        if found {
            result.insert(path.to_path_buf());
        }
    }

    Ok(result.into_iter().collect())
}
