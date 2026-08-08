use std::{
    collections::{BTreeSet, HashSet},
    fs,
    panic::{catch_unwind, AssertUnwindSafe},
    path::{Path, PathBuf},
};

use anyhow::{bail, Context, Result};
use clap::Parser;
use font_cmap_tool::{
    cli::{Args, Command},
    discovery::{collect_find_font_dirs, collect_font_xml_paths, collect_system_font_dirs},
    find::find_fonts_containing,
    font::{is_rewritable_font_path, unicode_codepoints, variation_sequence_base_codepoints},
    fonts_xml::{collect_effective_fonts, EffectiveFonts},
    logging::init_tracing,
    rewrite::rewrite_font,
    scan::scan_effective_system_unicode,
};
use tracing::{debug, error, info, span, warn, Level};
use ttf_parser::Face;

fn main() -> Result<()> {
    let args = Args::parse();
    init_tracing(args.verbose, args.no_color);

    info!(
        os = std::env::consts::OS,
        arch = std::env::consts::ARCH,
        "🖥️ 运行环境"
    );

    if let Some(Command::Find { codepoint }) = &args.command {
        let cp = parse_codepoint(codepoint)?;
        info!("🔍 查找 Unicode U+{:X}", cp);

        let system_font_dirs = collect_find_font_dirs(&args.system_fonts);
        let mut fonts = BTreeSet::new();
        for directory in &system_font_dirs {
            fonts.extend(find_fonts_containing(directory, cp)?);
        }

        if fonts.is_empty() {
            println!("❌ 没有任何系统字体包含 U+{:X}", cp);
        } else {
            println!("✅ 以下系统字体包含 U+{:X}:", cp);
            for font in fonts {
                println!("  - {}", font.display());
            }
        }
        return Ok(());
    }

    let font_xml_paths = if args.ignore_xml {
        Vec::new()
    } else if !args.fonts_xml.is_empty() {
        args.fonts_xml.clone()
    } else {
        collect_font_xml_paths()
    };

    let effective_fonts: EffectiveFonts = if args.ignore_xml {
        info!("🔓 忽略 fonts.xml 限制，将处理所有系统字体");
        EffectiveFonts::new()
    } else if font_xml_paths.is_empty() {
        bail!("❌ 未提供 fonts.xml，无法保证 fallback 安全性");
    } else {
        info!("📄 发现 {} 个 fonts.xml:", font_xml_paths.len());
        for path in &font_xml_paths {
            debug!(path = %path.display(), "📄 发现 fonts.xml");
        }

        let xml_refs: Vec<&Path> = font_xml_paths.iter().map(PathBuf::as_path).collect();
        let fonts = collect_effective_fonts(&xml_refs)?;

        if fonts.is_empty() {
            bail!("❌ fonts.xml 解析成功但未得到任何有效字体");
        }

        debug!(fonts = fonts.len(), ?fonts, "🧩 有效字体集合");
        fonts
    };

    let skip_fonts = build_skip_font_set(&args)?;

    let system_font_dirs = collect_system_font_dirs(&args.system_fonts);
    info!("系统字体目录: {:?}", system_font_dirs);
    info!("模块字体目录: {:?}", args.module_fonts);

    if args.dry_run {
        info!("🔍 Dry-run 模式：仅统计，不修改文件");
    }

    if let Some(ref output) = args.output {
        info!("输出目录: {:?}", output);
        fs::create_dir_all(output)?;
    }

    info!("扫描有效系统字体 Unicode...");
    let mut system_unicode = HashSet::new();
    for directory in &system_font_dirs {
        system_unicode.extend(scan_effective_system_unicode(
            directory,
            &effective_fonts,
            args.system_cmap_threshold,
        )?);
    }

    info!(count = system_unicode.len(), "🔍 系统 Unicode 扫描完成");
    info!("处理模块字体...");

    let mut total_kept = 0usize;
    let mut total_removed = 0usize;
    let mut processed_count = 0usize;

    for entry in fs::read_dir(&args.module_fonts)? {
        let entry = entry?;
        let path = entry.path();
        if !path.is_file() {
            continue;
        }

        let file_name = match path.file_name().and_then(|name| name.to_str()) {
            Some(name) => name,
            None => continue,
        };

        let font_span = span!(
            Level::INFO,
            "🔤 处理字体",
            file = %file_name,
            path = %path.display(),
        );
        let _enter = font_span.enter();

        if skip_fonts.contains(file_name) {
            info!("🛑 跳过白名单字体");

            if let Some(ref output_dir) = args.output {
                let destination = output_dir.join(file_name);
                if destination != path {
                    if let Some(parent) = destination.parent() {
                        fs::create_dir_all(parent)?;
                    }
                    fs::copy(&path, &destination)?;
                }
            }
            continue;
        }

        if !is_rewritable_font_path(&path) {
            if path
                .extension()
                .and_then(|extension| extension.to_str())
                .is_some_and(|extension| {
                    extension.eq_ignore_ascii_case("ttc") || extension.eq_ignore_ascii_case("otc")
                })
            {
                warn!("⚠️ 模块字体为 TTC/OTC collection，当前仅扫描/查找支持 collection；为避免错误重写已跳过");
            }
            continue;
        }

        let data = fs::read(&path)?;
        let face = match Face::parse(&data, 0) {
            Ok(face) => face,
            Err(error) => {
                warn!(error = ?error, "⚠️ 字体解析失败");
                continue;
            }
        };

        let all_chars = unicode_codepoints(&face);
        let variation_bases = variation_sequence_base_codepoints(&data);
        let keep: HashSet<u32> = all_chars
            .iter()
            .copied()
            .filter(|codepoint| {
                !system_unicode.contains(codepoint) || variation_bases.contains(codepoint)
            })
            .collect();

        if !variation_bases.is_empty() {
            debug!(
                variation_bases = variation_bases.len(),
                "保留 format 14 UVS/IVS 所引用的基础码位"
            );
        }

        let total_chars = all_chars.len();
        let keep_count = keep.len();
        let removed = total_chars.saturating_sub(keep_count);

        info!(
            total_chars,
            keep_count,
            removed,
            removed_ratio = if total_chars > 0 {
                removed as f64 / total_chars as f64
            } else {
                0.0
            },
            "📝 cmap 统计"
        );

        if args.dry_run {
            continue;
        }

        let destination = if let Some(ref output_dir) = args.output {
            output_dir.join(file_name)
        } else {
            path.clone()
        };

        if keep_count == 0 {
            warn!(
                "🗑️ {}: 无可保留字符，为避免生成空 cmap 字体将保持原文件不变",
                file_name
            );
            if destination != path {
                if let Some(parent) = destination.parent() {
                    fs::create_dir_all(parent)?;
                }
                fs::copy(&path, &destination)?;
            }
            continue;
        }

        if keep_count == total_chars {
            if destination != path {
                if let Some(parent) = destination.parent() {
                    fs::create_dir_all(parent)?;
                }
                fs::copy(&path, &destination)?;
            }
            processed_count += 1;
            continue;
        }

        let mut keep_vec: Vec<u32> = keep.into_iter().collect();
        keep_vec.sort_unstable();

        let result = catch_unwind(AssertUnwindSafe(|| {
            rewrite_font(
                path.to_str().expect("font path must be valid UTF-8"),
                destination
                    .to_str()
                    .expect("destination path must be valid UTF-8"),
                &keep_vec,
            )
        }));

        match result {
            Ok(Ok(())) => {
                processed_count += 1;
                total_kept += keep_count;
                total_removed += removed;
                debug!("✅ 重写成功");
            }
            Ok(Err(error)) => warn!(error = %error, "⚠️ 重写失败，已跳过"),
            Err(_) => error!("💥 rewrite_font panic"),
        }
    }

    info!("");
    info!("📊 统计汇总:");
    info!("  保留字符总数: {}", total_kept);
    info!("  删除字符总数: {}", total_removed);
    info!("  已处理字体数: {}", processed_count);
    info!("✅ 完成");

    Ok(())
}

fn build_skip_font_set(args: &Args) -> Result<HashSet<String>> {
    let mut set = HashSet::new();

    for name in &args.skip_fonts {
        warn_if_non_emoji(name);
        set.insert(name.to_string());
    }

    let file = &args.skip_font_file;
    if file.exists() {
        let content =
            fs::read_to_string(file).with_context(|| format!("读取白名单文件失败: {:?}", file))?;

        for line in content.lines() {
            let line = line.trim();
            if line.is_empty() || line.starts_with('#') {
                continue;
            }

            warn_if_non_emoji(line);
            set.insert(line.to_string());
        }
    } else {
        info!("ℹ️ 白名单文件不存在，已忽略: {:?}", file);
    }

    Ok(set)
}

fn warn_if_non_emoji(name: &str) {
    let lower = name.to_lowercase();
    let looks_like_emoji = lower.contains("emoji");
    let extension_ok = name.ends_with(".ttf") || name.ends_with(".otf");

    if !looks_like_emoji || !extension_ok {
        warn!("⚠️ 白名单条目可能不规范（非 emoji 字体？）: {}", name);
    }
}

fn parse_codepoint(input: &str) -> Result<u32> {
    let trimmed = input.trim();
    let hex = trimmed
        .strip_prefix("U+")
        .or_else(|| trimmed.strip_prefix("u+"))
        .unwrap_or(trimmed);

    let codepoint =
        u32::from_str_radix(hex, 16).with_context(|| format!("无效的 Unicode 码位: {}", input))?;

    if char::from_u32(codepoint).is_none() {
        bail!("不是有效的 Unicode 标量值: U+{:X}", codepoint);
    }

    Ok(codepoint)
}
