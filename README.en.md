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

UFS adds glyph coverage for many characters missing from stock Android fonts on rooted devices. It combines multiple fonts and inserts them into Android's fallback chain. The Unicode coverage target is independent from the UFS framework version; the current target is defined by `release.toml` (`unicode_version`, currently Unicode 18.0.0 Beta, excluding surrogate and private-use code points).

The module supports Magisk and can also be used with KernelSU / APatch. It attempts to coexist with other font modules and to reconcile font configuration after OTA changes.

## Download and install

1. Download a module ZIP from [Releases](https://github.com/Losketch/UnicodeFontSet-magisk-module/releases).
2. Install it from Magisk / KernelSU / APatch.
3. Choose the variant appropriate for your system:
   - **CBDT**: API 26+ (Android 8.0+).
   - **COLRv1**: API 33+ (Android 13+).
4. During installation, choose whether to run cmap cleanup:
   - **Volume Up**: skip cleanup.
   - **Volume Down**: run cleanup.
   - No input for 15 seconds: skip automatically.
5. Reboot after installation.

Normal use does not require configuration changes.

### KernelSU users

KernelSU needs a metamodule capable of mounting `/system` (for example `meta-overlayfs`); otherwise fonts under `system/fonts/` will not take effect. See the [KernelSU Metamodule documentation](https://kernelsu.org/guide/metamodule.html).

## Configuration

Runtime font policy is concentrated in:

```text
module/config/
├── font-policy.tsv      # font roles, order, protected/removed ranges
├── fonts_fragment.xml   # fonts inserted into Android fallback and their order
└── discovery.conf       # system font/XML discovery scope
```

### `font-policy.tsv`

This is a **TAB-separated** file with one font per row:

```text
role<TAB>font filename<TAB>protect<TAB>remove
```

For example:

```text
normal-fallback	PlangothicP2-Regular.otf	[U+0080-U+009F]	-
```

Use literal TAB characters, not spaces.

| role | Purpose | Required in `fonts_fragment.xml` |
|---|---|---|
| `system-overlay` | Replace a stock font with the same filename | Usually no |
| `normal-fallback` | Normal fallback font, processed in table order | Yes |
| `terminal-fallback` | Final fallback font | Yes, and it should remain last |

The `normal-fallback` / `terminal-fallback` order in `font-policy.tsv` must match the fallback order in `fonts_fragment.xml`; repository validation checks for drift.

### `protect` and `remove`

- `protect`: keep cmap mappings that already exist in this font even if earlier fonts cover the same code points.
- `remove`: force-remove these nominal Unicode cmap mappings regardless of earlier coverage.
- If the same code point appears in both columns, **`remove` wins**.

Accepted range syntax:

```text
-                              no code points
*                              all code points
80-9f                          one range
U+0080-U+009F                  same range
1df02                          one code point
[ff-4e02,1df02,30ede]          multiple ranges/code points
[U+00FF-U+4E02,U+1DF02]        U+ prefixes are also accepted
```

Protect example:

```text
normal-fallback	PlangothicP2-Regular.otf	[80-9f]	-
```

`protect` only preserves mappings already present in the font; it does not create missing glyphs.

Remove example:

```text
normal-fallback	ExampleFont.otf	-	[e000-f8ff]
```

Range rewriting currently supports ordinary TTF/OTF fonts. TTC/OTC collections can be discovered and queried but are not rewritten. If deduplication/filtering would leave no Unicode mappings, the cleaner warns and skips the output instead of producing an empty-cmap font.

### `discovery.conf`

`discovery.conf` defines:

- which familyset XML files are used for the default fallback configuration;
- which system font directories contribute to the cmap cleaner's default/global fallback baseline;
- wider directories searched by the `find` command;
- common XML/font locations in sibling font modules;
- Android's updatable-font directory.

By default, `/product/fonts` and `/system/product/fonts` are **searchable by `find` but excluded from the cleaner's global baseline**. On modern Android, product fonts are commonly optional or named families; their presence does not imply participation in the default fallback chain. A ROM that genuinely uses product fonts in global fallback can opt those paths into the baseline here.

Shell reads this configuration at runtime. The Rust cleaner embeds it at build time, so Rust-side changes require rebuilding the module.

## cmap cleaner

The cleaner reduces duplicate cmap mappings across fallback fonts, lowering the chance that symbols, Emoji, or long-tail characters are matched by an unintended font first.

- If you are unsure whether you need it, you can skip the cleaner.
- Cleaner behavior is controlled by `font-policy.tsv`.
- The cleaner modifies TTF/OTF files inside the module; reinstalling the module restores the packaged originals.
- Reboot after cleanup.

## Using UFS with other font modules

UFS attempts to coexist with other font modules and reconciles its font XML after module changes or OTAs.

If UFS appears inactive:

1. Reboot once.
2. Run UFS **Action** from the module manager.
3. KernelSU users should verify that a `/system`-mounting metamodule is enabled.
4. Check the log:

```text
/data/adb/modules/unicode_font_set/ufs.log
```

To resolve same-name font/cmap conflicts, UFS may back up and remove conflicting files from other font modules. Merely disabling UFS does not roll those changes back; **uninstall** UFS normally so its uninstall script can restore backups.

## FAQ

### Some apps crash after installation

Android 12+ changed font loading behavior. If a traditional font module causes app crashes, try [FontLoader](https://github.com/JingMatrix/FontLoader).

### How can I check whether UFS is active?

Inspect:

```text
/system/fonts/
/system/etc/fonts.xml
/system/product/etc/fonts.xml
```

You can also open test text containing rare characters, CJK extensions, historic scripts, or symbols and check whether they render.

### Supported Android versions

`release.toml` is authoritative:

- **CBDT**: API 26+ (Android 8.0+).
- **COLRv1**: API 33+ (Android 13+).

The installer reads the built variant's `minApi` and aborts below that threshold.

### Leftover lock after uninstall

A normal uninstall should be sufficient. If the lock directory must be removed manually:

```bash
su -c rm -rf /data/adb/ufs_lock
```

## Other documentation

- 📄 [Font sources and licenses](docs/LICENSES.md)
- 🙏 [Credits](docs/CREDITS.md)
- 🛠️ [Build and test](docs/DEVELOPMENT.md)

This module is provided as-is. Back up important data before modifying fonts, filtering cmap mappings, or replacing system fonts, and use it at your own risk.
