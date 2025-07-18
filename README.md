<div align="center">

# Unicode 字体合集 Magisk 模块

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

> **本模块无需依赖系统自带字体，即可实现 Unicode 全字符覆盖。**  
> **本模块以增量方式插入新字体和配置，其他字体模块显示得以保留。**

本模块专为已 root 的 Android 设备设计，旨在通过 Magisk 提供一套完整的 Unicode 字体和配置文件，实现所有 Unicode 字符的显示，方便 Magisk 用户安装和使用。

本项目借鉴了 [simonsmh 的 notocjk 模块](https://github.com/simonsmh/notocjk) 和 [lakejason0 的 又又一个遍黑体 Magisk 模块](https://github.com/lakejason0/AAnother-Plangothic-magisk-module) 的实现思路——通过命令和流编辑器动态替换字体配置文件中的标签，简化了用户手动编辑字体配置的复杂操作。

## 模块简介
本 Magisk 模块的核心功能是在系统字体目录（`/system/fonts`）中安装多个字体，同时通过脚本修改系统的 `fonts.xml` 文件，实现手机字库的全面补充。

## 下载方式

请前往 [Releases 页面](https://github.com/Losketch/UnicodeFontSet-magisk-module/releases)

## 使用须知

- 本脚本并非适配所有机型和系统，可能因厂商定制系统而出现兼容性问题。更多兼容性参考：
  - [lxgw 的 CJK 字体 Magisk 模块兼容性调整指南](https://github.com/lxgw/advanced-cjk-font-magisk-module-template#兼容性调整-仅供参考)
  - [simonsmh 制作的 notocjk 模块说明](https://github.com/simonsmh/notocjk)
- 如果系统中已安装其它字体类 Magisk 模块，本模块将以增量方式插入新字体和 XML 配置，不会覆盖原有字体配置，确保已装模块的功能得以保留。
- 本模块仅供个人学习交流，请勿用于商业用途。因使用本模块造成的任何设备问题，作者概不负责。

## 字体来源

- [Ctrl Ctrl](https://github.com/MY1L/Ctrl/releases/tag/Ctr1)
- [Last Resort](https://github.com/unicode-org/last-resort-font)
- [Monu Temp](https://github.com/MY1L/Unicode/releases/tag/Temp)
- [Noto Emoji](https://github.com/googlefonts/noto-emoji)
- [Noto Unicode](https://github.com/MY1L/Unicode/releases/tag/NotoUni7)
- [NotoSansKR & NotoSansSC](https://github.com/notofonts/noto-cjk/raw/refs/heads/main/Sans/SubsetOTF)
- [Plangothic](https://github.com/Fitzgerald-Porthmouth-Koenigsegg/Plangothic)
- [NotoSansSuper.ttf](https://github.com/Losketch/UnicodeFontSet-magisk-module/tree/NotoSansSuper)：该字体是由 n 个 Noto 家族字体加其他 OFL-1.1 许可的字体缝合而成的

<details>
<summary><b>点击查看字体 Unicode 区块覆盖范围</b></summary>

<div align="center">
<img alt="CtrlCtrl" src="./documentation/samples/CtrlCtrl_unicode_coverage.svg">
<img alt="MonuTemp" src="./documentation/samples/MonuTemp_unicode_coverage.svg">
<img alt="NotoColorEmoji" src="./documentation/samples/NotoColorEmoji_unicode_coverage.svg">
<img alt="NotoSansKR-Regular" src="./documentation/samples/NotoSansKR-Regular_unicode_coverage.svg">
<img alt="NotoSansSC-Regular" src="./documentation/samples/NotoSansSC-Regular_unicode_coverage.svg">
<img alt="NotoSansSuper" src="./documentation/samples/NotoSansSuper_unicode_coverage.svg">
<img alt="NotoUnicode" src="./documentation/samples/NotoUnicode_unicode_coverage.svg">
<img alt="PlangothicP1-Regular" src="./documentation/samples/PlangothicP1-Regular_unicode_coverage.svg">
<img alt="PlangothicP2-Regular" src="./documentation/samples/PlangothicP2-Regular_unicode_coverage.svg">
<img alt="Unicode" src="./documentation/samples/Unicode_unicode_coverage.svg">

<img alt="LastResort-Regular" src="./documentation/samples/LastResort-Regular_unicode_coverage.svg">
</div>
</details>

## 鸣谢

- [Fitzgerald Yu](https://github.com/Fitzgerald-Porthmouth-Koenigsegg)
- [GoogleFonts](https://github.com/googlefonts)
- [lakejason0](https://github.com/lakejason0)
- [lxgw](https://github.com/lxgw)
- [MY1L](https://github.com/MY1L)
- [NotoFonts](https://github.com/notofonts)
- [simonsmh](https://github.com/simonsmh)
- [The Unicode Consortium](https://github.com/unicode-org)
