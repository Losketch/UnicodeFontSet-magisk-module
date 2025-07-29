# Noto Sans Super

**将多款 Noto 字体合并为一款超字体（Noto Sans Super）的自动化构建工具。**

## 本分支简介

本分支通过 [Warcraft-Font-Merger](https://github.com/nowar-fonts/Warcraft-Font-Merger) 系列工具，将 `tools/fonts/urls.txt` 中定义的若干 .ttf 字体下载、转换、合并，最终输出一份完整的 TrueType 字体 `NotoSansSuper.ttf`，并在 GitHub Actions 中打包为 ZIP 制品，方便分发和下载。

## 目录结构

```
├── .github
│   └── workflows
│       └── build.yml        # GitHub Actions CI 配置
├── tools
│   ├── merge_fonts.sh       # 本地/CI 合并脚本
│   ├── otfccdump            # otfccdump 可执行文件
│   ├── merge-otd            # merge-otd 可执行文件
│   ├── otfccbuild           # otfccbuild 可执行文件
│   └── fonts
│       └── urls.txt         # 待下载字体 URL 列表
├── build/                    # CI 构建产物目录
└── README.md
```

## 前置依赖

1. Linux / macOS 环境（Bash）
2. otfcc 工具（仓库中已内置二进制，可直接使用）
3. `wget`、`zip`

如果本地没有安装 otfcc 系列工具，也可以使用本分支内 `tools/otfccdump`、`tools/merge-otd`、`tools/otfccbuild`，但需确保它们具有可执行权限：

```bash
chmod +x tools/{otfccdump,merge-otd,otfccbuild,merge_fonts.sh}
```

## 本地构建

1. 克隆仓库：

   ```bash
   git clone --branch NotoSansSuper --single-branch https://github.com/Losketch/UnicodeFontSet-magisk-module.git
   cd UnicodeFontSet-magisk-module
   ```

2. 确保工具可执行：

   ```bash
   chmod +x tools/{merge_fonts.sh,otfccdump,merge-otd,otfccbuild}
   ```

3. 编辑 `tools/fonts/urls.txt`，按行添加你需要合并的字体 URL 或以 `//` 开头的仓库相对路径，例如：

   ```
   # 注释行
   https://example.com/fonts/NotoSans-Regular.ttf
   //github.com/googlefonts/noto-fonts/blob/main/hinted/ttf/NotoSansCJKsc-Regular.otf?raw=true
   ```

4. 运行合并脚本：

   ```bash
   ./tools/merge_fonts.sh
   ```

5. 构建完成后，`NotoSansSuper.ttf` 会输出到仓库根目录，或运行：

   ```bash
   mv NotoSansSuper.ttf build/
   ```

## GitHub Actions 自动化

`.github/workflows/build.yml` 定义了如下流程：

1. **触发条件**  
   - Push 到 `NotoSansSuper` 分支  
   - 手动触发（`workflow_dispatch`）

2. **步骤**  
   - Checkout 源码  
   - 创建 `tools/fonts`、`build` 目录  
   - 从 `tools/fonts/urls.txt` 下载字体  
   - 给脚本和工具添加可执行权限  
   - 调用 `tools/merge_fonts.sh` 合并并生成 `NotoSansSuper.ttf`  
   - 打包为 `NotoSansSuper.zip` 并上传为 Artifact

> 常见 CI 错误：  
> - **Permission denied (Exit 126)**  
>   请确认所有脚本和二进制都已 `chmod +x`。  
> - **zip 文件找不到**  
>   注意每个 step 默认工作目录是 repository 根目录，打包路径和移动路径要对应。

## 常见问题 & 解决方案

1. **`./otfccdump: Permission denied`**  
   给工具添加执行权限：
   ```bash
   chmod +x tools/otfccdump tools/merge-otd tools/otfccbuild
   ```

2. **`mv "../NotoSansSuper.zip": No such file or directory`**  
   确认打包输出路径。可直接在 `build/` 目录下生成 ZIP，或修改 mv 命令为：
   ```yaml
   mv NotoSansSuper.zip build/
   ```

3. **下载失败**  
   检查 `tools/fonts/urls.txt` 中 URL 的有效性，或手动 `wget` 测试。

## 许可证

本分支工具使用 MIT License，详见 [LICENSE-MIT](LICENSE-MIT)。  
字体使用 OFL-1.1 License，详见 [LICENSE-OFL](LICENSE-OFL)。  

## 致谢

- [Mercury13](https://github.com/Mercury13)  
- [Noto Fonts](https://github.com/notofonts)  
- [nowar-fonts/Warcraft-Font-Merger](https://github.com/nowar-fonts/Warcraft-Font-Merger)  