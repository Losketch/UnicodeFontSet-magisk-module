use clap::{ArgGroup, Args as ClapArgs, Parser, Subcommand};
use std::path::PathBuf;

#[derive(Parser, Debug)]
#[command(name = "font-cmap-tool")]
#[command(author, version, about = "UFS 字体 cmap 工具")]
pub struct Args {
    /// 系统字体目录
    #[arg(short = 's', long, default_value = "/system/fonts")]
    pub system_fonts: PathBuf,

    /// UFS 模块字体目录
    #[arg(short = 'm', long, default_value = "./fonts")]
    pub module_fonts: PathBuf,

    /// cleaner 输出目录；不指定时原地处理模块字体
    #[arg(short = 'o', long)]
    pub output: Option<PathBuf>,

    /// 只预览 cleaner 结果，不修改文件
    #[arg(short = 'n', long)]
    pub dry_run: bool,

    /// 显示详细日志
    #[arg(short = 'v', long, global = true)]
    pub verbose: bool,

    /// UFS 字体角色、顺序和 Unicode 范围策略
    #[arg(long = "font-policy", default_value = "./font-policy.tsv")]
    pub font_policy: PathBuf,

    /// 手动指定系统字体 XML；可重复使用
    #[arg(long = "fonts-xml")]
    pub fonts_xml: Vec<PathBuf>,

    /// 不根据系统字体 XML 限制 baseline
    #[arg(long = "ignore-xml")]
    pub ignore_xml: bool,

    /// 单个系统字体允许参与 baseline 的最大 cmap 映射数
    #[arg(long = "system-cmap-threshold", default_value = "1114112")]
    pub system_cmap_threshold: usize,

    /// Android 动态字体目录；通常无需手动指定
    #[arg(long = "updatable-font-dir")]
    pub updatable_font_dir: Option<PathBuf>,

    /// Android 动态字体配置；通常无需手动指定
    #[arg(long = "updatable-config")]
    pub updatable_config: Option<PathBuf>,

    /// 禁用彩色输出
    #[arg(long = "no-color", global = true)]
    pub no_color: bool,

    #[command(subcommand)]
    pub command: Option<Command>,
}

#[derive(Subcommand, Debug)]
pub enum Command {
    /// 查找包含指定 Unicode 码位的字体
    Find {
        /// Unicode 码位，例如 U+4E00、4E00、1F600
        codepoint: String,
    },

    /// 按 Unicode 范围保留或删除单个 TTF/OTF 的 cmap 映射
    Filter(RangeFilterArgs),
}

#[derive(ClapArgs, Debug)]
#[command(group(
    ArgGroup::new("ranges")
        .required(true)
        .multiple(true)
        .args(["keep", "remove"])
))]
pub struct RangeFilterArgs {
    /// 要处理的 TTF/OTF 字体
    pub font: PathBuf,

    /// 只保留这些 Unicode 范围，例如 [4E00-9FFF,20000-2FFFF]
    #[arg(long, value_name = "RANGES")]
    pub keep: Option<String>,

    /// 从保留结果中删除这些 Unicode 范围，例如 [E000-F8FF,1F600]
    #[arg(long, value_name = "RANGES")]
    pub remove: Option<String>,

    /// 输出字体文件；不指定时原地修改
    #[arg(short = 'o', long, value_name = "FILE")]
    pub output: Option<PathBuf>,

    /// 只预览过滤结果，不修改文件
    #[arg(short = 'n', long)]
    pub dry_run: bool,
}
