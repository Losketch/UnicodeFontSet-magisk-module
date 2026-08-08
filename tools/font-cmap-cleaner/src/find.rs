use std::{
    collections::BTreeMap,
    fs,
    path::{Path, PathBuf},
};

use anyhow::{bail, Result};
use tracing::{debug, warn};
use ttf_parser::Face;
use walkdir::WalkDir;

use crate::font::{face_indices, is_font_path, unicode_glyph_index};

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct FindMatch {
    pub path: PathBuf,
    pub face_indices: Vec<u32>,
}

pub fn find_fonts_containing(directory: &Path, codepoint: u32) -> Result<Vec<FindMatch>> {
    if !directory.is_dir() {
        bail!("字体目录不存在或不是目录: {}", directory.display());
    }

    let mut result = BTreeMap::<PathBuf, Vec<u32>>::new();

    for entry in WalkDir::new(directory).follow_links(true) {
        let entry = match entry {
            Ok(entry) => entry,
            Err(error) => {
                warn!(error = %error, "遍历字体目录失败，已跳过该项");
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

        let mut matched_faces = Vec::new();
        for face_index in face_indices(&data) {
            let face = match Face::parse(&data, face_index) {
                Ok(face) => face,
                Err(error) => {
                    debug!(path = %path.display(), face_index, error = ?error, "字体 face 解析失败，已跳过");
                    continue;
                }
            };
            if unicode_glyph_index(&face, codepoint).is_some() {
                matched_faces.push(face_index);
            }
        }

        if !matched_faces.is_empty() {
            result.insert(path.to_path_buf(), matched_faces);
        }
    }

    Ok(result
        .into_iter()
        .map(|(path, face_indices)| FindMatch { path, face_indices })
        .collect())
}
