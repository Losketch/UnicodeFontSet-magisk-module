use std::{collections::HashSet, fs, path::Path};

use anyhow::Result;
use tracing::{debug, trace, warn};
use ttf_parser::Face;
use walkdir::WalkDir;

use crate::{
    font::{face_indices, is_font_path, unicode_codepoints},
    fonts_xml::EffectiveFonts,
};

pub fn scan_effective_system_unicode(
    dir: &Path,
    effective_fonts: &EffectiveFonts,
    cmap_threshold: usize,
) -> Result<HashSet<u32>> {
    debug!(
        dir = %dir.display(),
        effective_fonts = effective_fonts.len(),
        "scan effective system unicode"
    );

    let mut set = HashSet::new();

    for entry in WalkDir::new(dir).follow_links(true) {
        let entry = match entry {
            Ok(entry) => entry,
            Err(error) => {
                warn!(error = %error, "walk system font directory failed; entry skipped");
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

        let file_name = match path.file_name().and_then(|name| name.to_str()) {
            Some(name) => name,
            None => continue,
        };

        let referenced_indices = if effective_fonts.is_empty() {
            None
        } else {
            match effective_fonts.get(file_name) {
                Some(indices) => Some(indices),
                None => {
                    trace!(font = %file_name, "skip non-effective system font");
                    continue;
                }
            }
        };

        let data = match fs::read(path) {
            Ok(data) => data,
            Err(error) => {
                warn!(path = %path.display(), error = %error, "read system font failed; skipped");
                continue;
            }
        };

        let mut parsed_faces = 0usize;

        for face_index in face_indices(&data) {
            if referenced_indices.is_some_and(|indices| !indices.contains(&face_index)) {
                trace!(font = %file_name, face_index, "skip unreferenced collection face");
                continue;
            }

            let face = match Face::parse(&data, face_index) {
                Ok(face) => face,
                Err(error) => {
                    trace!(
                        font = %file_name,
                        face_index,
                        error = ?error,
                        "font face parse failed; skipped"
                    );
                    continue;
                }
            };

            parsed_faces += 1;
            let local = unicode_codepoints(&face);
            let count = local.len();

            if count > cmap_threshold {
                warn!(
                    font = %file_name,
                    face_index,
                    count,
                    threshold = cmap_threshold,
                    "system font face cmap exceeds threshold, face excluded from system_unicode"
                );
                continue;
            }

            set.extend(local);
        }

        if parsed_faces == 0 {
            warn!(font = %file_name, "no parseable faces found; skipped");
        }
    }

    debug!(total = set.len(), "system unicode collected");
    Ok(set)
}
