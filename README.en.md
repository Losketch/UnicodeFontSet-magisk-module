<div align="center">

<a href="README.md">
  <img src="https://img.shields.io/badge/语言-中文-blue?style=for-the-badge&logo=googletranslate&logoColor=white" alt="中文版本">
</a>
<a href="#">
  <img src="https://img.shields.io/badge/Language-English-red?style=for-the-badge&logo=googletranslate&logoColor=white" alt="English Version">
</a>

# Magisk Module: Extended Unicode Font Set (UFS-Magisk)

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

> **This module does not depend on system fonts. By combining multiple fonts, it provides complete glyph coverage for all characters currently defined in the Unicode 17.0 standard (excluding surrogate areas and the Private Use Areas).**  
> **The module installs fonts and configuration incrementally so existing font modules remain intact.**

This module is designed for rooted Android devices and installs a comprehensive Unicode font set and configuration files via the Magisk framework.

This project takes inspiration from [simonsmh’s notocjk module](https://github.com/simonsmh/notocjk) and [lakejason0’s AAnother-Plangothic-magisk-module](https://github.com/lakejason0/AAnother-Plangothic-magisk-module) — using scripts to dynamically modify font configuration files.

## Overview
The core function of this module is to install multiple font files into the system font directory (/system/fonts) and dynamically update system fonts.xml and related configuration files so the system gains broad additional complete glyph coverage.

## Download

Please visit the [Releases page](https://github.com/Losketch/UnicodeFontSet-magisk-module/releases) to download the latest version.

## Notes and Usage

- **Compatibility**: This module may not be compatible with every device or highly customized ROM. For more compatibility information, refer to:
  - [lxgw’s CJK font Magisk module compatibility notes](https://github.com/lxgw/advanced-cjk-font-magisk-module-template#兼容性调整-仅供参考)
  - [simonsmh’s notocjk module](https://github.com/simonsmh/notocjk)
  - **App crashes**: Android 12 and later introduced significant changes to font loading. Fonts are no longer preloaded during zygote initialization and are instead loaded on demand, which may cause compatibility issues with traditional Magisk font modules. If you encounter app crashes, please install the [FontLoader](https://github.com/RikkaW/FontLoader) module.
- If you already have other font Magisk modules installed, this module inserts its fonts and XML entries incrementally rather than overwriting existing font configurations, ensuring that the behavior of previously installed modules is preserved.
- **Installation order**:  
  - It is recommended to install other font modules first and reboot once, then install this font module and reboot again to ensure compatibility.  
  - If updates to other font modules later cause this module’s fonts not to take effect immediately, rebooting 1–2 times (or re‑enabling the Magisk module) should restore proper font rendering.
- **Font features**: This collection aims to maximize character coverage and rendering stability. It does **not** include or rely on ligatures or advanced shaping features. For color emoji fonts, please ensure that your system and applications support the COLRv1 format (Android 12L+ and modern browsers provide support).
- **Kernel managers (KernelSU, APatch)**:
  - **KernelSU users**:
    - ⚠️ A **meta module (e.g. `meta-overlayfs`) must be installed first**; otherwise, font files under `system/fonts/` will not be mounted correctly
    - For more information, see the [KernelSU Metamodule documentation](https://kernelsu.org/guide/metamodule.html)
    - It is recommended to disable KernelSU’s “auto uninstall modules” (or similar) feature to ensure fonts work properly
  - **Hiding solutions**: If you use tools such as Shamiko, configure them in blacklist / denylist mode
- **Disclaimer**: This module is provided “as-is” for personal learning and educational purposes only. Users assume all risks. The author accepts no responsibility for any device issues that may arise from installing this module.

## Font Information

- 📄 [Font Sources and Licenses](documentation/LICENSES.md)
- 🙏 [Acknowledgements](documentation/CREDITS.md)
