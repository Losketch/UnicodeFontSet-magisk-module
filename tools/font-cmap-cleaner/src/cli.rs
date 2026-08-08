use clap::{Parser, Subcommand};
use std::path::PathBuf;

#[derive(Parser, Debug)]
#[command(name = "font-cmap-tool")]
#[command(author, version, about = "字体 cmap 清理工具")]
pub struct Args {
    /// 系统字体目录
    #[arg(short = 's', long, default_value = "/system/fonts")]
    pub system_fonts: PathBuf,

    /// 模块字体目录
    #[arg(short = 'm', long, default_value = "./fonts")]
    pub module_fonts: PathBuf,

    /// 输出目录（不指定则原地修改）
    #[arg(short = 'o', long)]
    pub output: Option<PathBuf>,

    /// 只显示统计，不实际修改文件
    #[arg(short = 'n', long)]
    pub dry_run: bool,

    /// 详细输出模式
    #[arg(short = 'v', long)]
    pub verbose: bool,

    /// 跳过处理的字体文件名（可多次指定）
    #[arg(long = "skip-font")]
    pub skip_fonts: Vec<String>,

    /// 跳过处理的字体白名单文件（每行一个文件名）
    #[arg(long = "skip-font-file", default_value = "./whitelist.txt")]
    pub skip_font_file: PathBuf,

    /// 显式指定 fonts.xml（可多次指定，优先级最高）
    #[arg(long = "fonts-xml")]
    pub fonts_xml: Vec<PathBuf>,

    /// 忽略 fonts.xml 限制，处理所有字体
    #[arg(long = "ignore-xml")]
    pub ignore_xml: bool,

    /// system 字体 cmap 安全阈值（超过则不并入 system_unicode）
    #[arg(long = "system-cmap-threshold", default_value = "1114112")]
    pub system_cmap_threshold: usize,

    /// 禁用彩色输出
    #[arg(long = "no-color")]
    pub no_color: bool,

    /// 子命令
    #[command(subcommand)]
    pub command: Option<Command>,
}

#[derive(Subcommand, Debug)]
pub enum Command {
    /// 在系统字体中查找包含某个 Unicode 码位的字体
    Find {
        /// Unicode 码位，例如：U+4E00 / 4E00 / 1F600
        codepoint: String,
    },
}
