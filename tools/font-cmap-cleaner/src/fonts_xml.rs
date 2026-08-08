use std::{
    collections::{HashMap, HashSet},
    fs,
    path::Path,
};

use anyhow::{Context, Result};
use quick_xml::{events::Event, Reader};
use tracing::{debug, trace};

pub type EffectiveFonts = HashMap<String, HashSet<u32>>;

/// 解析单个 fonts.xml，提取“有效”的系统字体及其 face index。
/// 规则：
/// - 只解析 <font>...</font>
/// - 忽略带 fallbackFor 属性的 font
/// - TTC/OTC 的 index 属性按 Android 实际引用保留；未指定 index 时默认为 0
/// - 忽略 <!-- UnicodeFontSetModule Start --> 到 <!-- UnicodeFontSetModule End --> 之间的字体
///   （防止把模块自己注入的字体统计为系统字体）
pub fn parse_fonts_xml(path: &Path) -> Result<EffectiveFonts> {
    let mut result = EffectiveFonts::new();

    if !path.exists() {
        debug!(path = %path.display(), "fonts.xml not found");
        return Ok(result);
    }

    debug!(path = %path.display(), "parsing fonts.xml");

    let xml =
        fs::read_to_string(path).with_context(|| format!("读取 fonts.xml 失败: {:?}", path))?;

    let mut reader = Reader::from_str(&xml);
    reader.config_mut().trim_text(true);

    let mut buf = Vec::new();
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
            Ok(Event::Start(event)) if event.name().as_ref() == b"font" => {
                if in_module_section {
                    continue;
                }

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
            Ok(Event::Text(event)) if in_font && !ignore_font => {
                let text = event.decode()?.trim().to_string();
                if !text.is_empty() && font_text.is_empty() {
                    font_text = text;
                }
            }
            Ok(Event::End(event)) if event.name().as_ref() == b"font" => {
                if in_font && !ignore_font && !in_module_section {
                    if let Some(name) = normalize_font_filename(&font_text) {
                        trace!(font = %name, face_index = font_index, "effective font discovered");
                        result.entry(name).or_default().insert(font_index);
                    }
                }
                in_font = false;
                ignore_font = false;
            }
            Ok(Event::Eof) => break,
            Err(error) => return Err(error.into()),
            _ => {}
        }

        buf.clear();
    }

    debug!(count = result.len(), "fonts.xml parsed");
    Ok(result)
}

pub fn collect_effective_fonts(paths: &[&Path]) -> Result<EffectiveFonts> {
    let mut all = EffectiveFonts::new();

    for path in paths {
        for (font, indices) in parse_fonts_xml(path)? {
            all.entry(font).or_default().extend(indices);
        }
    }

    debug!(count = all.len(), "total effective fonts collected");
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
