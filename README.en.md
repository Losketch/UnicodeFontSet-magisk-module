# Noto Sans Super

**An automated build tool for merging multiple Noto fonts into a single superfont (Noto Sans Super).**

## Branch Overview

This branch uses the [Warcraft-Font-Merger](https://github.com/nowar-fonts/Warcraft-Font-Merger) toolchain to download, convert, and merge multiple .ttf fonts defined in `tools/fonts/urls.txt`, ultimately outputting a complete TrueType font `NotoSansSuper.ttf`. The font is packaged as a ZIP artifact in GitHub Actions for easy distribution and download.

## Directory Structure

```
├── .github
│   └── workflows
│       └── build.yml        # GitHub Actions CI configuration
├── tools
│   ├── merge_fonts.sh       # Local/CI merge script
│   ├── otfccdump            # otfccdump executable
│   ├── merge-otd            # merge-otd executable
│   ├── otfccbuild           # otfccbuild executable
│   └── fonts
│       └── urls.txt         # Font URL list to download
├── build/                    # CI build artifacts directory
└── README.md
```

## Prerequisites

1. Linux / macOS environment (Bash)
2. otfcc tools (pre-built binaries included in repository)
3. `wget`, `zip`

If you don't have otfcc tools installed locally, you can use the included binaries `tools/otfccdump`, `tools/merge-otd`, `tools/otfccbuild`, but ensure they have executable permissions:

```bash
chmod +x tools/{otfccdump,merge-otd,otfccbuild,merge_fonts.sh}
```

## Local Build

1. Clone the repository:

   ```bash
   git clone --branch NotoSansSuper --single-branch https://github.com/Losketch/UnicodeFontSet-magisk-module.git
   cd UnicodeFontSet-magisk-module
   ```

2. Make tools executable:

   ```bash
   chmod +x tools/{merge_fonts.sh,otfccdump,merge-otd,otfccbuild}
   ```

3. Edit `tools/fonts/urls.txt`, add font URLs or repository relative paths starting with `//` line by line:

   ```
   # Comment line
   https://example.com/fonts/NotoSans-Regular.ttf
   //github.com/googlefonts/noto-fonts/blob/main/hinted/ttf/NotoSansCJKsc-Regular.otf?raw=true
   ```

4. Run the merge script:

   ```bash
   ./tools/merge_fonts.sh
   ```

5. After build completion, `NotoSansSuper.ttf` will be output to the repository root, or run:

   ```bash
   mv NotoSansSuper.ttf build/
   ```

## GitHub Actions Automation

`.github/workflows/build.yml` defines the following workflow:

1. **Triggers**  
   - Push to `NotoSansSuper` branch  
   - Manual trigger (`workflow_dispatch`)

2. **Steps**  
   - Checkout source code  
   - Create `tools/fonts`, `build` directories  
   - Download fonts from `tools/fonts/urls.txt`  
   - Add executable permissions to scripts and tools  
   - Call `tools/merge_fonts.sh` to merge and generate `NotoSansSuper.ttf`  
   - Package as `NotoSansSuper.zip` and upload as Artifact

> Common CI errors:  
> - **Permission denied (Exit 126)**  
>   Ensure all scripts and binaries have `chmod +x`.  
> - **zip file not found**  
>   Note that each step's default working directory is the repository root, ensure packaging and move paths correspond.

## FAQ & Solutions

1. **`./otfccdump: Permission denied`**  
   Add execute permissions to tools:
   ```bash
   chmod +x tools/otfccdump tools/merge-otd tools/otfccbuild
   ```

2. **`mv "../NotoSansSuper.zip": No such file or directory`**  
   Verify packaging output path. Generate ZIP directly in `build/` directory, or modify mv command to:
   ```yaml
   mv NotoSansSuper.zip build/
   ```

3. **Download failure**  
   Check URL validity in `tools/fonts/urls.txt`, or test manually with `wget`.

## License

This branch's tools use MIT License, see [LICENSE-MIT](LICENSE-MIT).  
Fonts use OFL-1.1 License, see [LICENSE-OFL](LICENSE-OFL).  

## Acknowledgments

- [Mercury13](https://github.com/Mercury13)  
- [Noto Fonts](https://github.com/notofonts)  
- [nowar-fonts/Warcraft-Font-Merger](https://github.com/nowar-fonts/Warcraft-Font-Merger)