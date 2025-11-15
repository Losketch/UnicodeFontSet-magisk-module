<div align="center">

<a href="#">
  <img src="https://img.shields.io/badge/语言-中文-blue?style=for-the-badge&logo=googletranslate&logoColor=white" alt="中文版本">
</a>
<a href="README.en.md">
  <img src="https://img.shields.io/badge/Language-English-red?style=for-the-badge&logo=googletranslate&logoColor=white" alt="English Version">
</a>

# Magisk 模块：扩展 Unicode 字体合集（UFS-Magisk）

<img src="https://api.visitorbadge.io/api/visitors?path=Losketch.UnicodeFontSet-magisk-module&countColor=%234ecdc4" alt="Github Visitors">
<a href="https://github.com/Losketch/UnicodeFontSet-magisk-module/stargazers">
  <img src="https://img.shields.io/github/stars/Losketch/UnicodeFontSet-magisk-module?style=for-the-badge&color=yellow" alt="GitHub Stars">
</a>
<a href="https://github.com/Losketch/UnicodeFontSet-magisk-module/forks">
  <img src="https://img.shields.io/github/forks/Losketch/UnicodeFontSet-magisk-module?style=for-the-badge&color=8a2be2" alt="GitHub Forks">
</a>
<a href="https://github.com/Losketch/UnicodeFontSet-magisk-module/issues">
  <img src="https://img.shields.io/github/issues-raw/Losketch/UnicodeFontSet-magisk-module?style=for-the-badge&label=Issues&color=orange" alt="Github Issues">
</a>
<br/>

<a href="https://github.com/Losketch/UnicodeFontSet-magisk-module/releases/latest">
  <img src="https://img.shields.io/github/downloads/Losketch/UnicodeFontSet-magisk-module/total?style=for-the-badge" alt="Github Downloads">
</a>
<a href="https://github.com/Losketch/UnicodeFontSet-magisk-module/releases">
  <img src="https://img.shields.io/github/v/release/Losketch/UnicodeFontSet-magisk-module?style=for-the-badge&color=brightgreen" alt="Version">
</a>
<a href="https://github.com/Losketch/UnicodeFontSet-magisk-module/actions">
  <img src="https://img.shields.io/github/actions/workflow/status/Losketch/UnicodeFontSet-magisk-module/main.yml?style=for-the-badge" alt="Github Action">
</a>
<img src="https://img.shields.io/badge/Platform-Android-lightgreen?style=for-the-badge" alt="Platform">
<br/>

<a href="https://github.com/Losketch/UnicodeFontSet-magisk-module/commits">
  <img src="https://img.shields.io/github/last-commit/Losketch/UnicodeFontSet-magisk-module?style=for-the-badge" alt="Last Commit">
</a>
<a href="https://github.com/Losketch/UnicodeFontSet-magisk-module/commits">
  <img src="https://img.shields.io/github/commit-activity/m/Losketch/UnicodeFontSet-magisk-module?style=for-the-badge" alt="Commit Activity">
</a>
<img src="https://img.shields.io/badge/language-Bash/sh-89e051?style=for-the-badge">

</div>
<br/>

> **本模块无需依赖系统自带字体，通过联合多个字体，实现了对 Unicode 17.0 标准中所有已定义字符的完整字形覆盖（不包括代理区和私用区）。**  
> **本模块以增量方式安装字体和配置，其他字体模块显示得以保留。**

本模块专为已 Root 的 Android 设备设计，通过 Magisk 框架安装一套完整的 Unicode 字体及其配置文件。

本项目借鉴了 [simonsmh 的 notocjk 模块](https://github.com/simonsmh/notocjk) 和 [lakejason0 的 又又一个遍黑体 Magisk 模块](https://github.com/lakejason0/AAnother-Plangothic-magisk-module) 的实现思路——通过脚本工具动态修改字体配置文件。

## 模块简介
本模块的核心功能是在系统字体目录（`/system/fonts`）中安装多个字体文件，并通过脚本动态的修改系统的 `fonts.xml` 及相关配置文件，为系统字体提供大量补充字符。

## 下载方式

请前往 [Releases 页面](https://github.com/Losketch/UnicodeFontSet-magisk-module/releases) 下载最新版本。

## 使用须知

- **兼容性**: 本模块可能无法兼容所有机型和高定制化系统。更多兼容性信息可参考：
  - [lxgw 的 CJK 字体 Magisk 模块兼容性调整指南](https://github.com/lxgw/advanced-cjk-font-magisk-module-template#兼容性调整-仅供参考)
  - [simonsmh 的 notocjk 模块说明](https://github.com/simonsmh/notocjk)
- 如果系统中已安装其它字体类 Magisk 模块，本模块将以增量方式插入新字体和 XML 配置，不会覆盖原有字体配置，确保已装模块的功能得以保留。
- **安装顺序**:  
  - 推荐先安装其他模块并重启一次，再安装本字体模块并重启，以确保兼容性。  
  - 若后续其他字体模块更新后导致本模块字体未即时生效，可重启 1–2 次（或再次重新激活 Magisk 模块）即可恢复显示。
- **字体特性说明**: 本合集旨在最大化字符覆盖率与显示稳定性，**不包含也无需依赖**任何连字或复杂排版特性。对于彩色字体，请确保您的系统和应用支持 COLRv1 格式（Android 12L+ 及现代浏览器已提供支持）。
- **内核管理器 (KernelSU, APatch)**: 如使用此类管理器，建议关闭其“默认卸载模块”功能以确保字体正常工作。若使用 Shamiko 等隐藏工具，请配置为黑名单模式。
- **免责声明**: 本模块按"原样"提供，仅供个人学习与交流使用。使用者需自行承担风险，作者对因安装此模块而可能导致的任何设备问题不承担责任。

## 字体信息

- 📄 [字体来源与许可](documentation/LICENSES.md)
- 🙏 [鸣谢名单](documentation/CREDITS.md)
