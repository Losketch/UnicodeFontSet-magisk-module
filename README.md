# Unicode 字体合集 Magisk 模块

本模块专为已 root 的 Android 设备设计，旨在扩展系统字体库，方便 Magisk 用户安装和使用。
本项目借鉴了 [simonsmh 的 notocjk 模块](https://github.com/simonsmh/notocjk) 和 [lakejason0 的 又又一个遍黑体 Magisk 模块](https://github.com/lakejason0/AAnother-Plangothic-magisk-module) 的实现思路——通过命令和流编辑器动态替换字体配置文件中的标签，简化了用户手动编辑字体配置的复杂操作。

## 模块简介
本 Magisk 模块的核心功能是在系统字体目录（`/system/fonts`）中安装多个字体，同时通过脚本修改系统的 `fonts.xml` 文件，实现手机字库的全面补充。

## 下载方式

请前往 [Releases 页面](https://github.com/Losketch/UnicodeFontSet-magisk-module/releases)

## 使用须知

- 本脚本并非适配所有机型和系统，兼容性参考了 simonsmh 的 notocjk 模块和 lakejason0 的 又又一个遍黑体 Magisk 模块，用户可参考 lxgw 提供的 [CJK 字体 Magisk 模块兼容性调整指南](https://github.com/lxgw/advanced-cjk-font-magisk-module-template#%E5%85%BC%E5%AE%B9%E6%80%A7%E8%B0%83%E6%95%B4-%E4%BB%85%E4%BE%9B%E5%8F%82%E8%80%83) 以及 notocjk 模块的说明。因使用本模块造成的任何设备问题，作者概不负责。
- 请勿将本模块用于商业用途。

## 字体来源

- [Ctrl Ctrl](https://github.com/MY1L/Ctrl/releases/tag/Ctr1)
- [Monu Temp](https://github.com/MY1L/Unicode/releases/tag/Temp)
- [Noto Emoji](https://github.com/googlefonts/noto-emoji)
- [Noto Unicode](https://github.com/MY1L/Unicode/releases/tag/NotoUni7)
- [NotoSansKR & NotoSansSC](https://github.com/notofonts/noto-cjk/raw/refs/heads/main/Sans/SubsetOTF)
- [Plangothic](https://github.com/Fitzgerald-Porthmouth-Koenigsegg/Plangothic)
- NotoSansSuper.ttf：该字体是由 49 个 Noto 家族字体缝合而成的

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
