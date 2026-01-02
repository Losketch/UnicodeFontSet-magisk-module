use anyhow::Result;
use std::{collections::HashSet, fs, path::Path};
use ttf_parser::Face;
use walkdir::WalkDir;
use tracing::{debug, trace};

pub fn scan_effective_system_unicode(
    dir: &Path,
    effective_fonts: &HashSet<String>,
    cmap_threshold: usize,
) -> Result<HashSet<u32>> {
    debug!(
        dir = %dir.display(),
        effective_fonts = effective_fonts.len(),
        "scan effective system unicode"
    );

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
            trace!(font = %file_name, "skip non-effective system font");
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
            let mut local = HashSet::new();

            for sub in cmap.subtables {
                sub.codepoints(|cp| {
                    local.insert(cp);
                });
            }

            let count = local.len();

            if count > cmap_threshold {
                tracing::warn!(
                    font = %file_name,
                    count,
                    threshold = cmap_threshold,
                    "system font cmap exceeds threshold, excluded from system_unicode"
                );
                continue;
            }

            set.extend(local);
        }
    }

    debug!(total = set.len(), "system unicode collected");
    Ok(set)
}

fn is_font(p: &Path) -> bool {
    matches!(
        p.extension().and_then(|e| e.to_str()),
        Some("ttf") | Some("otf") | Some("ttc")
    )
}
