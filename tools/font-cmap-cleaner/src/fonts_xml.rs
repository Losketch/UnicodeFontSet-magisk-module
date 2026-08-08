use std::{
    collections::{HashMap, HashSet},
    fs,
    path::Path,
};

use anyhow::{Context, Result};
use quick_xml::{events::Event, Reader};
use tracing::{debug, trace};

pub type EffectiveFonts = HashMap<String, HashSet<u32>>;

/// Parse a familyset-style Android font XML and collect only fonts that participate in the
/// default/global fallback path.
///
/// This mirrors the important parts of Android FontListParser semantics:
/// - an unnamed top-level <family> participates in fallback;
/// - the first top-level <family> / <family-list> also participates, even when named;
/// - later named families are selectable Typefaces, not default fallback providers;
/// - fallbackFor mappings are specific to another named fallback and are excluded here;
/// - TTC/OTC `index` is preserved, defaulting to face 0;
/// - UFS-injected families between the marker comments are ignored.
pub fn parse_fonts_xml(path: &Path) -> Result<EffectiveFonts> {
    let mut result = EffectiveFonts::new();

    if !path.exists() {
        debug!(path = %path.display(), "fonts.xml not found");
        return Ok(result);
    }

    debug!(path = %path.display(), "parsing default fallback font XML");

    let xml =
        fs::read_to_string(path).with_context(|| format!("读取 fonts.xml 失败: {:?}", path))?;

    let mut reader = Reader::from_str(&xml);
    reader.config_mut().trim_text(true);

    let mut buf = Vec::new();
    let mut depth = 0usize;
    let mut top_level_family_seen = false;
    let mut included_container_depth: Option<usize> = None;
    let mut in_module_section = false;
    let mut in_font = false;
    let mut ignore_font = false;
    let mut font_text = String::new();
    let mut font_index = 0u32;

    loop {
        match reader.read_event_into(&mut buf) {
            Ok(Event::Comment(event)) => {
                let comment = event.decode()?.trim().to_string();
                if comment.contains("UnicodeFontSetModule Start") {
                    in_module_section = true;
                    trace!("entering UnicodeFontSetModule section, will skip fonts");
                } else if comment.contains("UnicodeFontSetModule End") {
                    in_module_section = false;
                    trace!("exiting UnicodeFontSetModule section");
                }
            }
            Ok(Event::Start(event)) => {
                depth += 1;
                let tag = event.name();
                let tag = tag.as_ref();

                if depth == 2 && (tag == b"family" || tag == b"family-list") {
                    if in_module_section {
                        included_container_depth = None;
                    } else {
                        let is_first = !top_level_family_seen;
                        let has_name = event.attributes().flatten().any(|attribute| {
                            attribute.key.as_ref() == b"name" && !attribute.value.is_empty()
                        });
                        let participates_in_default_fallback =
                            is_first || (tag == b"family" && !has_name);

                        if participates_in_default_fallback {
                            included_container_depth = Some(depth);
                        } else {
                            included_container_depth = None;
                            trace!("skip later named family from global fallback baseline");
                        }
                        top_level_family_seen = true;
                    }
                }

                if tag == b"font" && included_container_depth.is_some() && !in_module_section {
                    in_font = true;
                    ignore_font = false;
                    font_text.clear();
                    font_index = 0;

                    for attribute in event.attributes() {
                        let attribute = attribute.context("解析 <font> 属性失败")?;
                        match attribute.key.as_ref() {
                            b"fallbackFor" => {
                                ignore_font = true;
                                trace!("ignore <font> due to fallbackFor");
                                break;
                            }
                            b"index" => {
                                let raw = std::str::from_utf8(attribute.value.as_ref())?.trim();
                                font_index = raw
                                    .parse::<u32>()
                                    .with_context(|| format!("无效的 font index: {raw}"))?;
                            }
                            _ => {}
                        }
                    }
                }
            }
            Ok(Event::Text(event)) if in_font && !ignore_font => {
                let text = event.decode()?.trim().to_string();
                if !text.is_empty() && font_text.is_empty() {
                    font_text = text;
                }
            }
            Ok(Event::End(event)) => {
                let tag = event.name();
                let tag = tag.as_ref();

                if tag == b"font" {
                    if in_font && !ignore_font && !in_module_section {
                        if let Some(name) = normalize_font_filename(&font_text) {
                            trace!(font = %name, face_index = font_index, "effective fallback font discovered");
                            result.entry(name).or_default().insert(font_index);
                        }
                    }
                    in_font = false;
                    ignore_font = false;
                }

                if included_container_depth == Some(depth)
                    && (tag == b"family" || tag == b"family-list")
                {
                    included_container_depth = None;
                }

                depth = depth.saturating_sub(1);
            }
            Ok(Event::Empty(event)) => {
                // Empty top-level family/family-list still consumes the "first family" position,
                // matching Android's document-order semantics.
                let next_depth = depth + 1;
                let tag = event.name();
                let tag = tag.as_ref();
                if next_depth == 2
                    && !in_module_section
                    && (tag == b"family" || tag == b"family-list")
                {
                    top_level_family_seen = true;
                }
            }
            Ok(Event::Eof) => break,
            Err(error) => return Err(error.into()),
            _ => {}
        }

        buf.clear();
    }

    debug!(count = result.len(), "default fallback XML parsed");
    Ok(result)
}

pub fn collect_effective_fonts(paths: &[&Path]) -> Result<EffectiveFonts> {
    let mut all = EffectiveFonts::new();

    for path in paths {
        for (font, indices) in parse_fonts_xml(path)? {
            all.entry(font).or_default().extend(indices);
        }
    }

    debug!(count = all.len(), "total default fallback fonts collected");
    Ok(all)
}

fn normalize_font_filename(input: &str) -> Option<String> {
    let input = input.trim();
    let path = Path::new(input);
    let extension = path.extension()?.to_str()?;
    if !extension.eq_ignore_ascii_case("ttf")
        && !extension.eq_ignore_ascii_case("otf")
        && !extension.eq_ignore_ascii_case("ttc")
        && !extension.eq_ignore_ascii_case("otc")
    {
        return None;
    }

    path.file_name()?.to_str().map(str::to_string)
}
