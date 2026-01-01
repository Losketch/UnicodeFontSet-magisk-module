use anyhow::{Result, bail, Context};
use clap::{Parser, Subcommand};
use env_logger::Env;
use log::{info, warn};
use std::{
    collections::HashSet,
    fs,
    path::PathBuf,
    panic::{catch_unwind, AssertUnwindSafe},
};

use ttf_parser::Face;
use walkdir::WalkDir;

mod scan;
mod rewrite;

use scan::scan_fonts_unicode;
use rewrite::rewrite_font;

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
    #[arg(long = "skip-font-file")]
    skip_font_file: Option<PathBuf>,

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

fn main() -> Result<()> {
    let args = Args::parse();

    let log_level = if args.verbose { "debug" } else { "info" };
    env_logger::Builder::from_env(Env::default().default_filter_or(log_level)).init();

    if let Some(Command::Find { codepoint }) = &args.command {
        let cp = parse_codepoint(codepoint)?;
        info!("🔍 查找 Unicode U+{:X}", cp);

        let fonts = find_fonts_containing(&args.system_fonts, cp)?;

        if fonts.is_empty() {
            println!("❌ 没有任何系统字体包含 U+{:X}", cp);
        } else {
            println!("✅ 以下字体包含 U+{:X}:", cp);
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

    info!("扫描系统字体...");
    let system_unicode = scan_fonts_unicode(&args.system_fonts)?;
    info!("系统字体共包含 {} 个字符", system_unicode.len());

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

        if skip_fonts.contains(file_name) {
            info!("🛑 跳过白名单字体: {}", file_name);

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
                warn!("跳过 {}: 解析失败 ({:?})", file_name, e);
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

        total_kept += keep_count;
        total_removed += removed;

        info!(
            "📝 {}: 总字符 {}, 保留 {}, 删除 {} ({:.1}%)",
            file_name,
            total_chars,
            keep_count,
            removed,
            if total_chars > 0 {
                (removed as f64 / total_chars as f64) * 100.0
            } else {
                0.0
            }
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
            Ok(Ok(())) => processed_count += 1,
            Ok(Err(e)) => warn!("⚠️ 跳过 {}: {}", file_name, e),
            Err(_) => warn!("💥 跳过 {}: write-fonts panic", file_name),
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

    if let Some(ref file) = args.skip_font_file {
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

fn find_fonts_containing(dir: &PathBuf, cp: u32) -> Result<Vec<String>> {
    let mut result = Vec::new();

    for entry in WalkDir::new(dir).into_iter().filter_map(|e| e.ok()) {
        let path = entry.path();

        if !matches!(
            path.extension().and_then(|e| e.to_str()),
            Some("ttf") | Some("otf")
        ) {
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
                if let Some(name) = path.file_name().and_then(|n| n.to_str()) {
                    result.push(name.to_string());
                }
            }
        }
    }

    Ok(result)
}
