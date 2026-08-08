use std::{
    collections::{BTreeMap, BTreeSet, HashSet},
    fs,
    path::{Path, PathBuf},
};

use anyhow::{bail, Context, Result};
use clap::Parser;
use font_cmap_tool::{
    cli::{Args, Command, RangeFilterArgs},
    config::DiscoveryConfig,
    discovery::{
        collect_find_font_dirs, collect_font_xml_paths, collect_system_font_dirs, FontSourceKind,
    },
    filter::compute_keep,
    find::find_fonts_containing,
    font::{
        is_font_path, is_rewritable_font_path, postscript_name, unicode_codepoints,
        variation_sequence_base_codepoints,
    },
    fonts_xml::{collect_effective_fonts, EffectiveFonts},
    logging::init_tracing,
    policy::{FontPolicy, FontRole},
    range_filter::plan_filter,
    ranges::CodepointSet,
    safe_rewrite::{rewrite_font_safely, RewriteFailure},
    scan::scan_effective_system_view,
    updatable::{collect_active_updated_faces, parse_updatable_config},
};
use tracing::{debug, info, warn};
use ttf_parser::Face;

#[derive(Copy, Clone, Debug, Eq, PartialEq)]
enum MaterializeOutcome {
    Materialized,
    PreservedSource,
    Omitted,
}

fn main() -> Result<()> {
    let args = Args::parse();
    init_tracing(args.verbose, args.no_color);

    debug!(
        os = std::env::consts::OS,
        arch = std::env::consts::ARCH,
        "运行环境"
    );

    match &args.command {
        Some(Command::Find { codepoint }) => run_find(&args, codepoint),
        Some(Command::Filter(command)) => run_range_filter(command),
        None => run_cleaner(&args),
    }
}

fn run_find(args: &Args, codepoint: &str) -> Result<()> {
    let cp = parse_codepoint(codepoint)?;
    info!("🔍 查找 Unicode U+{:X}", cp);

    let roots = collect_find_font_dirs(&args.system_fonts)?;
    let mut matches = BTreeMap::<PathBuf, (FontSourceKind, BTreeSet<u32>)>::new();
    for root in roots {
        for found in find_fonts_containing(&root.path, cp)? {
            let entry = matches
                .entry(found.path)
                .or_insert_with(|| (root.source, BTreeSet::new()));
            entry.1.extend(found.face_indices);
        }
    }

    if matches.is_empty() {
        println!("❌ 没有发现包含 U+{:X} 的字体文件", cp);
    } else {
        println!("✅ 找到包含 U+{:X} 的字体:", cp);
        for (path, (source, faces)) in matches {
            let face_text = if faces.len() == 1 && faces.contains(&0) {
                String::new()
            } else {
                format!(
                    "#face={}",
                    faces
                        .iter()
                        .map(u32::to_string)
                        .collect::<Vec<_>>()
                        .join(",")
                )
            };
            println!("  - [{}] {}{}", source.label(), path.display(), face_text);
        }
    }
    Ok(())
}

fn run_range_filter(command: &RangeFilterArgs) -> Result<()> {
    let source = &command.font;
    if !source.is_file() {
        bail!("找不到字体文件: {}", source.display());
    }
    if !is_rewritable_font_path(source) {
        bail!("filter 目前只修改单个 TTF/OTF 文件；TTC/OTC 字体集合会保持原样");
    }

    let keep_filter = command
        .keep
        .as_deref()
        .map(CodepointSet::parse)
        .transpose()
        .with_context(|| {
            format!(
                "无法解析 --keep Unicode 范围: {}",
                command.keep.as_deref().unwrap_or_default()
            )
        })?;
    let remove_filter = command
        .remove
        .as_deref()
        .map(CodepointSet::parse)
        .transpose()
        .with_context(|| {
            format!(
                "无法解析 --remove Unicode 范围: {}",
                command.remove.as_deref().unwrap_or_default()
            )
        })?
        .unwrap_or_default();
    let data = fs::read(source).with_context(|| format!("读取字体失败: {}", source.display()))?;
    let face = Face::parse(&data, 0)
        .with_context(|| format!("无法读取字体 cmap: {}", source.display()))?;
    let all_chars = unicode_codepoints(&face);
    if all_chars.is_empty() {
        bail!("该字体没有可处理的 Unicode cmap 映射");
    }

    let plan = plan_filter(&all_chars, keep_filter.as_ref(), &remove_filter);
    let destination = command.output.as_deref().unwrap_or(source);

    println!("字体: {}", source.display());
    println!("Unicode 映射: {}", all_chars.len());
    println!("将删除: {}", plan.removed);
    println!("将保留: {}", plan.keep.len());

    if command.dry_run {
        println!("预览完成，未修改文件。");
        return Ok(());
    }

    if plan.removed == 0 {
        copy_if_needed(source, destination)?;
        println!("指定范围未命中任何映射，字体保持不变。");
        return Ok(());
    }

    if plan.keep.is_empty() {
        omit_output(source, destination)?;
        println!("过滤后没有可保留的 Unicode 映射，因此没有输出字体。");
        return Ok(());
    }

    let mut keep: Vec<u32> = plan.keep.iter().copied().collect();
    keep.sort_unstable();

    let source_text = source.to_str().context("字体路径不是有效的 UTF-8")?;
    let destination_text = destination.to_str().context("输出路径不是有效的 UTF-8")?;

    match rewrite_font_safely(source_text, destination_text, &keep) {
        Ok(()) => {
            println!("完成: {}", destination.display());
            Ok(())
        }
        Err(RewriteFailure::Error(error)) => {
            copy_if_needed(source, destination)?;
            debug!(error = %error, "字体重写失败详情");
            bail!("无法安全修改该字体，已保留原文件");
        }
        Err(RewriteFailure::Panicked) => {
            copy_if_needed(source, destination)?;
            bail!("该字体格式目前无法安全修改，已保留原文件");
        }
    }
}

fn run_cleaner(args: &Args) -> Result<()> {
    let discovery = DiscoveryConfig::embedded()?;
    let policy = FontPolicy::load(&args.font_policy)?;
    let font_xml_paths = resolve_font_xml_paths(args)?;
    let effective_fonts = resolve_effective_fonts(args, &font_xml_paths)?;

    let system_font_dirs = collect_system_font_dirs(&args.system_fonts)?;
    debug!("用于系统覆盖判断的字体目录: {:?}", system_font_dirs);
    debug!("UFS 字体目录: {:?}", args.module_fonts);

    if args.dry_run {
        info!("🔍 预览模式：只显示结果，不修改字体");
    }
    if let Some(ref output) = args.output {
        debug!("输出目录: {:?}", output);
        fs::create_dir_all(output)?;
    }

    let module_fonts = collect_module_font_paths(&args.module_fonts)?;
    preserve_unclassified_fonts(args, &module_fonts, &policy)?;

    let explicit_updatable = args.updatable_font_dir.is_some() || args.updatable_config.is_some();
    let use_default_updatable = args.system_fonts == Path::new("/system/fonts");
    let updated_faces = if explicit_updatable || use_default_updatable {
        let config_path = args
            .updatable_config
            .as_deref()
            .unwrap_or_else(|| Path::new(&discovery.updatable_config_xml));
        let files_root = args
            .updatable_font_dir
            .as_deref()
            .unwrap_or_else(|| Path::new(&discovery.updatable_system_font_dir));
        let updatable_config = parse_updatable_config(config_path)?;
        collect_active_updated_faces(files_root, &updatable_config)?
    } else {
        BTreeMap::new()
    };
    let updated_ps_names: HashSet<String> = updated_faces.keys().cloned().collect();

    let configured_overlay_names: HashSet<String> = policy
        .filenames_for(FontRole::SystemOverlay)
        .filter(|name| args.ignore_xml || effective_fonts.contains_key(*name))
        .map(str::to_string)
        .collect();
    let mut effective_overlay_names = HashSet::new();
    let mut overlay_unicode = HashSet::new();
    let mut overlay_ps_names = HashSet::new();
    let mut overlay_kept = 0usize;
    let mut overlay_removed = 0usize;
    for entry in policy.entries_for(FontRole::SystemOverlay) {
        let name = entry.filename.as_str();
        let Some(path) = module_fonts.get(name) else {
            warn!("⚠️ 配置中的系统替换字体不存在: {name}");
            continue;
        };
        let (unicode, ps_names) = scan_overlay_font(path)?;
        overlay_ps_names.extend(ps_names.iter().cloned());

        let (actual_unicode, outcome) = if is_rewritable_font_path(path) {
            let variation_bases = variation_sequence_base_codepoints(&fs::read(path)?);
            let keep = compute_keep(&unicode, &HashSet::new(), &variation_bases, entry);
            let outcome = materialize_font(
                args,
                path,
                name,
                &unicode,
                &keep,
                &mut overlay_kept,
                &mut overlay_removed,
            )?;
            let actual_unicode = match outcome {
                MaterializeOutcome::Materialized => keep,
                MaterializeOutcome::PreservedSource => unicode.clone(),
                MaterializeOutcome::Omitted => HashSet::new(),
            };
            (actual_unicode, outcome)
        } else {
            if !entry.remove.is_none() {
                warn!("⚠️ {name} 是 TTC/OTC 字体集合，不会修改；remove 范围不会生效");
            }
            copy_if_output(args, path, name)?;
            (unicode, MaterializeOutcome::Materialized)
        };

        if !configured_overlay_names.contains(name) {
            debug!(font = %name, "系统替换字体未被当前字体配置引用，不参与系统覆盖判断");
            continue;
        }

        if outcome == MaterializeOutcome::Omitted {
            debug!(font = %name, "系统替换字体被过滤为空，恢复使用系统原字体");
        } else {
            effective_overlay_names.insert(name.to_string());
        }

        let shadowed_by_update = ps_names
            .iter()
            .any(|ps_name| updated_ps_names.contains(ps_name));
        if shadowed_by_update {
            debug!(font = %name, "系统替换字体被 Android 动态字体覆盖");
        } else {
            overlay_unicode.extend(actual_unicode);
        }
    }

    info!("🔎 正在读取系统已覆盖的 Unicode 字符...");
    let mut system_unicode = HashSet::new();
    let mut referenced_stock_ps_names = HashSet::new();
    for directory in &system_font_dirs {
        let scan = scan_effective_system_view(
            directory,
            &effective_fonts,
            args.system_cmap_threshold,
            &effective_overlay_names,
            &updated_ps_names,
        )?;
        system_unicode.extend(scan.unicode);
        referenced_stock_ps_names.extend(scan.referenced_postscript_names);
    }
    system_unicode.extend(overlay_unicode);

    let mut active_updated_count = 0usize;
    for (ps_name, updated) in &updated_faces {
        if referenced_stock_ps_names.contains(ps_name) || overlay_ps_names.contains(ps_name) {
            system_unicode.extend(updated.unicode.iter().copied());
            active_updated_count += 1;
            debug!(
                postscript_name = %updated.postscript_name,
                path = %updated.path.display(),
                face_index = updated.face_index,
                "Android 动态字体参与系统覆盖判断"
            );
        }
    }

    info!(
        count = system_unicode.len(),
        updated_faces = active_updated_count,
        "✅ 系统字体字符统计完成"
    );
    process_ordered_module_fonts(args, &policy, &module_fonts, system_unicode)
}

fn resolve_font_xml_paths(args: &Args) -> Result<Vec<PathBuf>> {
    if args.ignore_xml {
        Ok(Vec::new())
    } else if !args.fonts_xml.is_empty() {
        Ok(args.fonts_xml.clone())
    } else {
        collect_font_xml_paths()
    }
}

fn resolve_effective_fonts(args: &Args, font_xml_paths: &[PathBuf]) -> Result<EffectiveFonts> {
    if args.ignore_xml {
        info!("ℹ️ 已忽略系统字体 XML 限制，找到的系统字体都会参与判断");
        return Ok(EffectiveFonts::new());
    }
    if font_xml_paths.is_empty() {
        bail!("找不到系统字体配置 XML，无法安全判断哪些字符已经由系统提供");
    }

    debug!("发现 {} 个系统字体配置 XML", font_xml_paths.len());
    for path in font_xml_paths {
        debug!(path = %path.display(), "字体配置 XML");
    }
    let xml_refs: Vec<&Path> = font_xml_paths.iter().map(PathBuf::as_path).collect();
    let fonts = collect_effective_fonts(&xml_refs)?;
    if fonts.is_empty() {
        bail!("系统字体配置中没有找到可用字体");
    }
    debug!(fonts = fonts.len(), ?fonts, "系统实际使用的字体");
    Ok(fonts)
}

fn collect_module_font_paths(dir: &Path) -> Result<BTreeMap<String, PathBuf>> {
    let mut result = BTreeMap::new();
    for entry in
        fs::read_dir(dir).with_context(|| format!("读取模块字体目录失败: {}", dir.display()))?
    {
        let entry = entry?;
        let path = entry.path();
        if !path.is_file() || !is_font_path(&path) {
            continue;
        }
        if let Some(name) = path.file_name().and_then(|name| name.to_str()) {
            result.insert(name.to_string(), path);
        }
    }
    Ok(result)
}

fn preserve_unclassified_fonts(
    args: &Args,
    module_fonts: &BTreeMap<String, PathBuf>,
    policy: &FontPolicy,
) -> Result<()> {
    for (name, path) in module_fonts {
        if policy.role(name).is_none() {
            warn!("⚠️ 字体未在 font-policy.tsv 中配置，已保持原样: {name}");
            copy_if_output(args, path, name)?;
        }
    }
    Ok(())
}

fn process_ordered_module_fonts(
    args: &Args,
    policy: &FontPolicy,
    module_fonts: &BTreeMap<String, PathBuf>,
    mut baseline: HashSet<u32>,
) -> Result<()> {
    let mut total_kept = 0usize;
    let mut total_removed = 0usize;
    let mut processed_fallback_count = 0usize;

    for role in [FontRole::NormalFallback, FontRole::TerminalFallback] {
        for entry in policy.entries_for(role) {
            let name = entry.filename.as_str();
            let Some(path) = module_fonts.get(name) else {
                warn!("⚠️ 配置中的字体不存在: {name}");
                continue;
            };
            info!("🔤 正在处理字体: {name}");
            debug!(?role, path = %path.display(), "字体处理详情");

            if !is_rewritable_font_path(path) {
                warn!("⚠️ {name} 是 TTC/OTC 字体集合，已保持原文件");
                if !entry.remove.is_none() {
                    warn!("⚠️ {name} 的 remove 范围不会生效");
                }
                copy_if_output(args, path, name)?;
                baseline.extend(read_all_unicode(path)?);
                continue;
            }

            let data = fs::read(path)?;
            let face = match Face::parse(&data, 0) {
                Ok(face) => face,
                Err(error) => {
                    warn!("⚠️ 无法读取 {name}，已保持原字体");
                    debug!(error = ?error, "字体解析失败详情");
                    copy_if_output(args, path, name)?;
                    continue;
                }
            };
            let all_chars = unicode_codepoints(&face);
            let variation_bases = variation_sequence_base_codepoints(&data);
            let keep = compute_keep(&all_chars, &baseline, &variation_bases, entry);
            let total_chars = all_chars.len();
            let keep_count = keep.len();
            let removed = total_chars.saturating_sub(keep_count);
            info!(total_chars, keep_count, removed, "字符映射统计");

            let outcome = materialize_font(
                args,
                path,
                name,
                &all_chars,
                &keep,
                &mut total_kept,
                &mut total_removed,
            )?;
            match outcome {
                MaterializeOutcome::Materialized => {
                    baseline.extend(keep);
                    if !args.dry_run {
                        processed_fallback_count += 1;
                    }
                }
                MaterializeOutcome::PreservedSource => baseline.extend(all_chars),
                MaterializeOutcome::Omitted => {
                    debug!(font = %name, "字体无可保留映射，不参与后续覆盖判断");
                }
            }
        }
    }
    info!("");
    info!("📊 统计汇总:");
    info!("  保留映射: {}", total_kept);
    info!("  删除映射: {}", total_removed);
    info!("  已处理字体: {}", processed_fallback_count);
    info!("✅ 完成");
    Ok(())
}

fn materialize_font(
    args: &Args,
    path: &Path,
    name: &str,
    all_chars: &HashSet<u32>,
    keep: &HashSet<u32>,
    total_kept: &mut usize,
    total_removed: &mut usize,
) -> Result<MaterializeOutcome> {
    let total_chars = all_chars.len();
    let keep_count = keep.len();
    let removed = total_chars.saturating_sub(keep_count);
    let destination = destination_for(args, path, name);

    if keep_count == 0 {
        warn!(
            font = %name,
            total_chars,
            "⚠️ 清理后没有可保留的 Unicode 映射，已跳过该字体"
        );
        if !args.dry_run {
            omit_output(path, &destination)?;
            *total_removed += removed;
        }
        return Ok(MaterializeOutcome::Omitted);
    }

    if args.dry_run {
        return Ok(MaterializeOutcome::Materialized);
    }

    if keep_count == total_chars {
        copy_if_needed(path, &destination)?;
        *total_kept += keep_count;
        return Ok(MaterializeOutcome::Materialized);
    }

    let mut keep_vec: Vec<u32> = keep.iter().copied().collect();
    keep_vec.sort_unstable();

    let source_text = path.to_str().context("字体路径不是有效的 UTF-8")?;
    let destination_text = destination.to_str().context("输出路径不是有效的 UTF-8")?;

    match rewrite_font_safely(source_text, destination_text, &keep_vec) {
        Ok(()) => {
            *total_kept += keep_count;
            *total_removed += removed;
            debug!(keep_count, removed, "字体 cmap 已更新");
            Ok(MaterializeOutcome::Materialized)
        }
        Err(RewriteFailure::Error(error)) => {
            warn!("⚠️ 无法安全修改 {name}，已保留原字体");
            debug!(error = %error, "字体重写失败详情");
            copy_if_needed(path, &destination)?;
            Ok(MaterializeOutcome::PreservedSource)
        }
        Err(RewriteFailure::Panicked) => {
            warn!("⚠️ {name} 的字体格式暂不支持安全修改，已保留原字体");
            copy_if_needed(path, &destination)?;
            Ok(MaterializeOutcome::PreservedSource)
        }
    }
}

fn omit_output(source: &Path, destination: &Path) -> Result<()> {
    let target = if source == destination {
        source
    } else {
        destination
    };

    match fs::remove_file(target) {
        Ok(()) => {
            debug!(path = %target.display(), "已省略无可保留映射的字体");
            Ok(())
        }
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => Ok(()),
        Err(error) => {
            Err(error).with_context(|| format!("删除无可保留映射的字体失败: {}", target.display()))
        }
    }
}

fn read_all_unicode(path: &Path) -> Result<HashSet<u32>> {
    let data = fs::read(path)?;
    let mut result = HashSet::new();
    for face_index in font_cmap_tool::font::face_indices(&data) {
        if let Ok(face) = Face::parse(&data, face_index) {
            result.extend(unicode_codepoints(&face));
        }
    }
    Ok(result)
}

fn scan_overlay_font(path: &Path) -> Result<(HashSet<u32>, HashSet<String>)> {
    let data = fs::read(path)?;
    let mut unicode = HashSet::new();
    let mut ps_names = HashSet::new();
    for face_index in font_cmap_tool::font::face_indices(&data) {
        if let Ok(face) = Face::parse(&data, face_index) {
            unicode.extend(unicode_codepoints(&face));
            if let Some(name) = postscript_name(&face) {
                ps_names.insert(name);
            }
        }
    }
    Ok((unicode, ps_names))
}

fn destination_for(args: &Args, source: &Path, name: &str) -> PathBuf {
    args.output
        .as_ref()
        .map(|output| output.join(name))
        .unwrap_or_else(|| source.to_path_buf())
}

fn copy_if_output(args: &Args, source: &Path, name: &str) -> Result<()> {
    if let Some(output) = &args.output {
        copy_if_needed(source, &output.join(name))?;
    }
    Ok(())
}

fn copy_if_needed(source: &Path, destination: &Path) -> Result<()> {
    if source == destination {
        return Ok(());
    }
    if let Some(parent) = destination.parent() {
        fs::create_dir_all(parent)?;
    }
    fs::copy(source, destination)?;
    Ok(())
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
