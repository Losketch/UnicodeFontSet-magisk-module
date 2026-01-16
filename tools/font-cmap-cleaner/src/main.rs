use anyhow::{Result, bail, Context};
use clap::{Parser, Subcommand};
use tracing::{info, warn, debug, error, span, Level};
use tracing_subscriber::{fmt, EnvFilter};
use std::{
    collections::HashSet,
    env,
    fs,
    path::{Path, PathBuf},
    panic::{catch_unwind, AssertUnwindSafe},
};

use ttf_parser::Face;
use walkdir::WalkDir;

use font_cmap_tool::fonts_xml::collect_effective_fonts;
use font_cmap_tool::scan::scan_effective_system_unicode;
use font_cmap_tool::rewrite::rewrite_font;

#[derive(Parser, Debug)]
#[command(name = "font-cmap-tool")]
#[command(author, version, about = "字体 cmap 清理工具")]
struct Args {
    /// 系统字体目录
    #[arg(short = 's', long, default_value = "/system/fonts")]
    system_fonts: PathBuf,

    /// 模块字体目录
    #[arg(short = 'm', long, default_value = "./fonts")]
    module_fonts: PathBuf,

    /// 输出目录（不指定则原地修改）
    #[arg(short = 'o', long)]
    output: Option<PathBuf>,

    /// 只显示统计，不实际修改文件
    #[arg(short = 'n', long)]
    dry_run: bool,

    /// 详细输出模式
    #[arg(short = 'v', long)]
    verbose: bool,

    /// 跳过处理的字体文件名（可多次指定）
    #[arg(long = "skip-font")]
    skip_fonts: Vec<String>,

    /// 跳过处理的字体白名单文件（每行一个文件名）
    #[arg(long = "skip-font-file", default_value = "./whitelist.txt")]
    skip_font_file: PathBuf,

    /// 显式指定 fonts.xml（可多次指定，优先级最高）
    #[arg(long = "fonts-xml")]
    fonts_xml: Vec<PathBuf>,

    /// system 字体 cmap 安全阈值（超过则不并入 system_unicode）
    #[arg(long = "system-cmap-threshold", default_value = "1114112")]
    system_cmap_threshold: usize,

    /// 禁用彩色输出
    #[arg(long = "no-color")]
    no_color: bool,

    /// 子命令
    #[command(subcommand)]
    command: Option<Command>,
}

#[derive(Subcommand, Debug)]
enum Command {
    /// 在系统字体中查找包含某个 Unicode 码位的字体
    Find {
        /// Unicode 码位，例如：U+4E00 / 4E00 / 1F600
        codepoint: String,
    },
}

const FONT_XML_FILES: &[&str; 10] = &[
    "fonts.xml",
    "fonts_base.xml",
    "fonts_fallback.xml",
    "font_fallback.xml",
    "fonts_inter.xml",
    "fonts_slate.xml",
    "fonts_ule.xml",
    "fonts_flyme.xml",
    "flyme_fallback.xml",
    "flyme_font_fallback.xml",
];

const FONT_XML_SUBDIRS: &[&str; 5] = &[
    "/system/etc",
    "/system/product/etc",
    "/system/system_ext/etc",
    "/vendor/etc",
    "/product/etc",
];

fn collect_font_xml_paths() -> Vec<PathBuf> {
    use std::collections::BTreeSet;

    let mut set = BTreeSet::new();

    for dir in FONT_XML_SUBDIRS {
        let base = Path::new(dir);
        if !base.exists() {
            continue;
        }

        for file in FONT_XML_FILES {
            let p = base.join(file);
            if p.exists() {
                set.insert(p);
            }
        }
    }

    set.into_iter().collect()
}

fn main() -> Result<()> {
    let args = Args::parse();

    let filter = if args.verbose {
        EnvFilter::new("trace")
    } else {
        EnvFilter::from_default_env()
            .add_directive("font_cmap_tool=info".parse().unwrap())
    };

    let disable_color =
        args.no_color
        || env::var_os("NO_COLOR").is_some()
        || env::var("TERM").map(|v| v == "dumb").unwrap_or(false);

    fmt()
        .with_env_filter(filter)
        .with_target(false)
        .with_line_number(false)
        .with_ansi(!disable_color)
        .compact()
        .init();

    info!(
        os = std::env::consts::OS,
        arch = std::env::consts::ARCH,
         "🖥️ 运行环境"
    );

    let font_xml_paths = if !args.fonts_xml.is_empty() {
        args.fonts_xml.clone()
    } else {
        collect_font_xml_paths()
    };
    if font_xml_paths.is_empty() {
        bail!("❌ 未提供 fonts.xml，无法保证 fallback 安全性");
    }

    info!("📄 发现 {} 个 fonts.xml:", font_xml_paths.len());
    for p in &font_xml_paths {
        debug!(path = %p.display(), "📄 发现 fonts.xml");
    }

    let xml_refs: Vec<&Path> = font_xml_paths.iter().map(PathBuf::as_path).collect();
    let effective_fonts = collect_effective_fonts(&xml_refs)?;

    if effective_fonts.is_empty() {
        bail!("❌ fonts.xml 解析成功但未得到任何有效字体");
    }

    debug!(fonts = effective_fonts.len(), ?effective_fonts, "🧩 有效字体集合");

    if let Some(Command::Find { codepoint }) = &args.command {
        let cp = parse_codepoint(codepoint)?;
        info!("🔍 查找 Unicode U+{:X}", cp);

        let fonts = find_fonts_containing(
            &args.system_fonts,
            cp,
            &effective_fonts,
        )?;

        if fonts.is_empty() {
            println!("❌ 没有任何系统字体包含 U+{:X}", cp);
        } else {
            println!("✅ 以下系统字体包含 U+{:X}:", cp);
            for f in fonts {
                println!("  - {}", f);
            }
        }
        return Ok(());
    }

    let skip_fonts = build_skip_font_set(&args)?;

    info!("系统字体目录: {:?}", args.system_fonts);
    info!("模块字体目录: {:?}", args.module_fonts);

    if args.dry_run {
        info!("🔍 Dry-run 模式：仅统计，不修改文件");
    }

    if let Some(ref out) = args.output {
        info!("输出目录: {:?}", out);
        fs::create_dir_all(out)?;
    }

    info!("扫描有效系统字体 Unicode...");
    let system_unicode =
        scan_effective_system_unicode(
        &args.system_fonts,
        &effective_fonts,
        args.system_cmap_threshold,
    )?;

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

        let file_name = match path.file_name().and_then(|n| n.to_str()) {
            Some(n) => n,
            None => continue,
        };

        let font_span = span!(
            Level::INFO,
            "🔤 处理字体",
            file = %file_name,
            path = %path.display(),
        ).entered();
        let _enter = font_span.enter();

        if skip_fonts.contains(file_name) {
            info!("🛑 跳过白名单字体");

            if let Some(ref out_dir) = args.output {
                let dst = out_dir.join(file_name);
                if dst != path {
                    fs::create_dir_all(dst.parent().unwrap())?;
                    fs::copy(&path, &dst)?;
                }
            }
            continue;
        }

        let ext = path.extension().and_then(|e| e.to_str());
        if !matches!(ext, Some("ttf") | Some("otf")) {
            continue;
        }

        let data = fs::read(&path)?;
        let face = match Face::parse(&data, 0) {
            Ok(f) => f,
            Err(e) => {
                warn!(error = ?e, "⚠️ 字体解析失败");
                continue;
            }
        };

        let mut all_chars = HashSet::new();
        let mut keep = HashSet::new();

        if let Some(cmap) = face.tables().cmap {
            for sub in cmap.subtables {
                sub.codepoints(|cp| {
                    all_chars.insert(cp);
                    if !system_unicode.contains(&cp) {
                        keep.insert(cp);
                    }
                });
            }
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

        let dst_path = if let Some(ref out_dir) = args.output {
            out_dir.join(file_name)
        } else {
            path.clone()
        };

        if keep_count == 0 {
            warn!(
                "🗑️ {}: 无可保留字符，已跳过（不输出空字体）",
                file_name
            );
            continue;
        }

        if keep_count == total_chars {
            if dst_path != path {
                fs::create_dir_all(dst_path.parent().unwrap())?;
                fs::copy(&path, &dst_path)?;
            }
            processed_count += 1;
            continue;
        }

        let mut keep_vec: Vec<u32> = keep.into_iter().collect();
        keep_vec.sort_unstable();

        let result = catch_unwind(AssertUnwindSafe(|| {
            rewrite_font(
                path.to_str().unwrap(),
                dst_path.to_str().unwrap(),
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
            Ok(Err(e)) => warn!(error = %e, "⚠️ 重写失败，已跳过"),
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
        let content = fs::read_to_string(file)
            .with_context(|| format!("读取白名单文件失败: {:?}", file))?;

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
    let ext_ok = name.ends_with(".ttf") || name.ends_with(".otf");

    if !looks_like_emoji || !ext_ok {
        warn!(
            "⚠️ 白名单条目可能不规范（非 emoji 字体？）: {}",
            name
        );
    }
}

fn parse_codepoint(s: &str) -> Result<u32> {
    let hex = s.trim()
        .strip_prefix("U+")
        .or_else(|| s.trim().strip_prefix("u+"))
        .unwrap_or(s);

    let cp = u32::from_str_radix(hex, 16)
        .with_context(|| format!("无效的 Unicode 码位: {}", s))?;

    if cp > 0x10FFFF {
        bail!("Unicode 码位超出范围: U+{:X}", cp);
    }

    Ok(cp)
}

fn find_fonts_containing(
    dir: &PathBuf,
    cp: u32,
    effective_fonts: &HashSet<String>,
) -> Result<Vec<String>> {
    let mut result = Vec::new();

    for entry in WalkDir::new(dir).into_iter().filter_map(|e| e.ok()) {
        let path = entry.path();

        if !matches!(
            path.extension().and_then(|e| e.to_str()),
            Some("ttf") | Some("otf")
        ) {
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
            let mut found = false;
            for sub in cmap.subtables {
                if sub.is_unicode() {
                    sub.codepoints(|p| {
                        if p == cp {
                            found = true;
                        }
                    });
                }
                if found {
                    break;
                }
            }

            if found {
                result.push(file_name.to_string());
            }
        }
    }

    Ok(result)
}
