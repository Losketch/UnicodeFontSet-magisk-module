use anyhow::Result;
use std::{collections::HashSet, fs, path::Path};
use ttf_parser::Face;
use walkdir::WalkDir;

pub fn scan_effective_system_unicode(
    dir: &Path,
    effective_fonts: &HashSet<String>,
) -> Result<HashSet<u32>> {
    let mut set = HashSet::new();

    for entry in WalkDir::new(dir).into_iter().filter_map(|e| e.ok()) {
        let path = entry.path();

        if !is_font(path) {
            continue;
        }

        let file_name = match path.file_name().and_then(|n| n.to_str()) {
            Some(n) => n,
            None => continue,
        };

        if !effective_fonts.contains(file_name) {
            continue;
        }

        let data = match fs::read(path) {
            Ok(d) => d,
            Err(_) => continue,
        };

        let face = match Face::parse(&data, 0) {
            Ok(f) => f,
            Err(_) => continue,
        };

        if let Some(cmap) = face.tables().cmap {
            for sub in cmap.subtables {
                sub.codepoints(|cp| {
                    set.insert(cp);
                });
            }
        }
    }

    Ok(set)
}

fn is_font(p: &Path) -> bool {
    matches!(
        p.extension().and_then(|e| e.to_str()),
        Some("ttf") | Some("otf") | Some("ttc")
    )
}
