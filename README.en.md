<div align="center">

<a href="README.md">
  <img src="https://img.shields.io/badge/语言-中文-blue?style=for-the-badge&logo=googletranslate&logoColor=white" alt="Chinese Version">
</a>
<a href="#">
  <img src="https://img.shields.io/badge/Language-English-red?style=for-the-badge&logo=googletranslate&logoColor=white" alt="English Version">
</a>

# Magisk Module: Extended Unicode Font Set (UFS-Magisk)

<img src="https://api.visitorbadge.io/api/visitors?path=Losketch.UnicodeFontSet-magisk-module&countColor=%234ecdc4" alt="Github Visitors">
<a href="https://github.com/Losketch/UnicodeFontSet-magisk-module/stargazers"><img src="https://img.shields.io/github/stars/Losketch/UnicodeFontSet-magisk-module?style=for-the-badge&color=yellow" alt="GitHub Stars"></a>
<a href="https://github.com/Losketch/UnicodeFontSet-magisk-module/forks"><img src="https://img.shields.io/github/forks/Losketch/UnicodeFontSet-magisk-module?style=for-the-badge&color=8a2be2" alt="GitHub Forks"></a>
<a href="https://github.com/Losketch/UnicodeFontSet-magisk-module/issues"><img src="https://img.shields.io/github/issues-raw/Losketch/UnicodeFontSet-magisk-module?style=for-the-badge&label=Issues&color=orange" alt="Github Issues"></a>
<br/>
<a href="https://github.com/Losketch/UnicodeFontSet-magisk-module/releases/latest"><img src="https://img.shields.io/github/downloads/Losketch/UnicodeFontSet-magisk-module/total?style=for-the-badge" alt="Github Downloads"></a>
<a href="https://github.com/Losketch/UnicodeFontSet-magisk-module/releases"><img src="https://img.shields.io/github/v/release/Losketch/UnicodeFontSet-magisk-module?style=for-the-badge&color=brightgreen" alt="Version"></a>
<a href="https://github.com/Losketch/UnicodeFontSet-magisk-module/actions"><img src="https://img.shields.io/github/actions/workflow/status/Losketch/UnicodeFontSet-magisk-module/main.yml?style=for-the-badge" alt="Github Action"></a>
<img src="https://img.shields.io/badge/Platform-Android-lightgreen?style=for-the-badge" alt="Platform">

</div>

UFS is a font extension module for rooted Android devices. It combines multiple open-source fonts and integrates them into Android's system font fallback chain, providing glyph coverage for thousands of missing characters—including rare CJK characters, historical scripts, symbols, and the latest emojis.

The module natively supports Magisk, KernelSU, and APatch, with automated reconciliation to coexist alongside other font modules and survive system OTA updates.

---

## Quick Start

### 1. Download the Module
Download the appropriate package from [Releases](https://github.com/Losketch/UnicodeFontSet-magisk-module/releases):
- **CBDT Variant**: Android 8.0+ (API 26+)
- **COLRv1 Variant**: Android 13+ (API 33+), recommended for modern devices requiring high-fidelity color emojis and symbols.

### 2. Flashing & Options
Flash the ZIP in your module manager (Magisk / KernelSU / APatch):
- **Volume Up**: Skip cmap cleanup (**Recommended for most users**; fast installation).
- **Volume Down**: Run cmap cleanup (performs deduplication to prevent character misdirection).
- **No key pressed for 15s**: Automatically skips cleanup.

### 3. Reboot
Once installation is complete, reboot your device.

---

## Configuration

For typical usage, **no manual configuration is needed**. Advanced settings can be adjusted if required:

### 1. Special-Partition XML Mode (`SPECIAL_PARTITION_XML_MODE`)
Configuration path: `/data/adb/ufs/config.conf`

Under KernelSU or APatch, partition paths such as `/system/product` or `/system/system_ext` may be system symlinks. To avoid shadowing critical symlinks and causing boot failure, UFS uses a safety mechanism:
- **`safe` (Default)**: If a target special partition is detected as a symlink, UFS degrades safely and skips mounting its own partition XML.
- **`force`**: Forces writing XML via the standard Magisk layout. **Enable this only if your active mount implementation / metamodule is known to safely handle separate partitions, otherwise bootloops may occur.**

#### Switching Modes via Shell:
```sh
# Switch to force mode (requires root)
su -c 'mkdir -p /data/adb/ufs && echo "SPECIAL_PARTITION_XML_MODE=force" > /data/adb/ufs/config.conf'

# Restore default safe mode
su -c 'mkdir -p /data/adb/ufs && echo "SPECIAL_PARTITION_XML_MODE=safe" > /data/adb/ufs/config.conf'
```
Trigger the module **Action** button or **reboot** to apply changes.

---

### 2. Font Policy File (`font-policy.tsv`)
File path: `module/config/font-policy.tsv`

Controls fallback roles, inclusion order, and code point filtering per font. Each entry is separated by a **TAB**:
```text
role<TAB>font filename<TAB>protect<TAB>remove
```

| Field | Description | Example |
|---|---|---|
| `role` | `normal-fallback` (fallback) / `terminal-fallback` (final catch-all) / `system-overlay` (replaces stock font) | `normal-fallback` |
| `font filename` | Target font file name | `PlangothicP2-Regular.otf` |
| `protect` | Protects mappings from being removed by prior fonts (`-` for none, `*` for all) | `[U+0080-U+009F]` |
| `remove` | Forcefully removes specified Unicode mappings (**takes precedence over protect**) | `[e000-f8ff]` |

> Intended for advanced users only. Re-run Action or reinstall the module after modifying.

---

## Compatibility & Troubleshooting

### Module Not Active?
1. **Reboot** the device once.
2. In your module manager, tap **Action** on UFS to reconcile system font XML.
3. Check the diagnostic log:
   ```text
   /data/adb/modules/unicode_font_set/ufs.log
   ```
4. On KernelSU / APatch, if the log indicates a "mount-safety fallback", the module has safely bypassed partition symlinks to protect your system.

### App Crashes & Magisk DenyList Mount Isolation
If an application configured in Magisk DenyList has module mount isolation enabled, Magisk unmounts module files inside that app's namespace. The app might read the global `fonts.xml` but fail to access the corresponding font files, resulting in **missing glyphs, tofu boxes (`□`), or crashes**.

**Recommendations**:
- Verify whether the affected app is added to the DenyList.
- Adjust mount isolation settings if necessary, or consider using companion tools like [FontLoader](https://github.com/JingMatrix/FontLoader).

### Coexisting with Other Font Modules
- UFS automatically resolves conflicts with other font modules and creates backups where necessary.
- **Do not simply disable UFS**: If you plan to stop using it, perform a clean **Uninstall** so the removal script can properly restore backed-up files from other modules.

---

## Frequently Asked Questions (FAQ)

#### Q: How can I verify that UFS is working?
View any text containing rare Unicode characters (such as CJK Extension characters, archaic glyphs, or specialized symbols). If they render properly instead of showing placeholder squares (`□`), the fallback chain is active.

#### Q: Do I need to run the cmap cleaner?
Not necessarily. Most users can safely skip it by pressing Volume Up. Run it (Volume Down) only if specific emoji or symbol characters are being overridden by an unintended font earlier in the fallback sequence.

#### Q: How to clear leftover locks after uninstallation?
Standard uninstallation cleans up automatically. To manually reset any lingering files:
```sh
su -c rm -rf /data/adb/ufs_lock /data/adb/ufs
```

---

## Documentation & References

- 📄 [Font Sources & Licenses](docs/LICENSES.md)
- 🙏 [Credits & Acknowledgments](docs/CREDITS.md)
- 🛠️ [Development & Build Guide](docs/DEVELOPMENT.md)

> **Disclaimer**: This module is provided "as is". Modifying system fonts and partition setups involves inherent risks. Please maintain reliable backups and proceed at your own risk.
