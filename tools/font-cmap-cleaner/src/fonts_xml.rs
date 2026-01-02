use anyhow::{Context, Result};
use quick_xml::events::Event;
use quick_xml::Reader;
use std::{collections::HashSet, fs, path::Path};
use tracing::{debug, trace};

/// 解析单个 fonts.xml，提取“有效”的系统字体文件名
/// 规则：
/// - 只解析 <font>...</font>
/// - 忽略带 fallbackFor 属性的 font
pub fn parse_fonts_xml(path: &Path) -> Result<HashSet<String>> {
    let mut result = HashSet::new();

    if !path.exists() {
        debug!(path = %path.display(), "fonts.xml not found");
        return Ok(result);
    }

    debug!(path = %path.display(), "parsing fonts.xml");

    let xml = fs::read_to_string(path)
        .with_context(|| format!("读取 fonts.xml 失败: {:?}", path))?;

    let mut reader = Reader::from_str(&xml);
    reader.config_mut().trim_text(true);

    let mut buf = Vec::new();

    let mut in_font = false;
    let mut ignore_font = false;
    let mut font_text = String::new();

    loop {
        match reader.read_event_into(&mut buf) {
            Ok(Event::Start(e)) if e.name().as_ref() == b"font" => {
                in_font = true;
                ignore_font = false;
                font_text.clear();

                for attr in e.attributes().flatten() {
                    if attr.key.as_ref() == b"fallbackFor" {
                        ignore_font = true;
                        trace!("ignore <font> due to fallbackFor");
                        break;
                    }
                }
            }

            Ok(Event::Text(e)) if in_font && !ignore_font => {
                let t = e.decode()?.trim().to_string();
                if !t.is_empty() && font_text.is_empty() {
                    font_text = t;
                }
            }

            Ok(Event::End(e)) if e.name().as_ref() == b"font" => {
                if in_font && !ignore_font {
                    if let Some(name) = normalize_font_filename(&font_text) {
                        trace!(font = %name, "effective font discovered");
                        result.insert(name);
                    }
                }
                in_font = false;
                ignore_font = false;
            }

            Ok(Event::Eof) => break,
            Err(e) => return Err(e.into()),
            _ => {}
        }

        buf.clear();
    }

    debug!(count = result.len(), "fonts.xml parsed");
    Ok(result)
}

pub fn collect_effective_fonts(paths: &[&Path]) -> Result<HashSet<String>> {
    let mut all = HashSet::new();

    for path in paths {
        let set = parse_fonts_xml(path)?;
        all.extend(set);
    }

    debug!(count = all.len(), "total effective fonts collected");
    Ok(all)
}

fn normalize_font_filename(s: &str) -> Option<String> {
    let s = s.trim();
    if s.ends_with(".ttf") || s.ends_with(".otf") || s.ends_with(".ttc") {
        Some(s.to_string())
    } else {
        None
    }
}
