
## V1.7.5

### 🔤 Unicode 18.0 Alpha Full Support / Unicode 18.0 Alpha 全面支持
- **Jurchen & Seal Complete**: All characters in Unicode 18.0 Alpha are now supported
- **Archaic Cuneiform Numerals**: Added U+12550-U+1268F block support (311/311 coverage)

- **女真文与篆书完整覆盖**：完成 Unicode 18.0 Alpha 标准中定义的所有字符
- **古楔形文字数字区块**：新增 Archaic Cuneiform Numerals (U+12550-U+1268F) 支持，311/311 覆盖

### 📝 Font Updates & Engineering / 字体更新与工程改进
- **UFSZeroExt**: Regenerated sources, updated UFO, added new Unicode glyphs
- **UFSZeroExt**：重新生成 UFO，添加新 Unicode 字形

### 🔧 Platform Detection & ABI / 平台检测与 ABI
- **Arch Detection**: Added `detect_arch()` for robust ABI/architecture detection
- **架构检测**：新增 `detect_arch()` 函数

### 🧹 Uninstall Improvements / 卸载优化
- **Logging**: Refactored log_msg in uninstall.sh
- **Backup Handling**: Enhanced missing backup checks, skip disabled/pending-remove modules

- **日志**：重构 uninstall.sh 的 log_msg
- **备份处理**：增强缺失备份检查

### 🛠️ Code Cleanup / 代码清理
- **fontdiff.py**

---

<details>
<summary><h4>Historical update content</h4></summary>

## V1.7.4

### 🧩 代码架构重构
- **模块化重构**：将 `common_functions.sh` 拆分为结构化的 `lib/` 目录，包括常量、工具、XML 处理、二进制字体处理、监控逻辑和 cmap 逻辑等独立模块
- **字体模块架构优化**：重构字体模块架构和安装程序工作流，优化安装 UI 流程和日志记录
- **Shell 兼容性提升**：移除 bash 专有的 `local -n` 用法，改用基于 name 的 eval；修复 `safe_printf` 调用问题；增强 XML 注释匹配的空白容错能力

### 🔧 功能增强与稳定性改进
- **错误处理增强**：在字体重写逻辑中添加更详细的错误上下文，使用 anyhow::Context；增加 CFF 和 CFF2 表的检查和调试日志
- **Shell 脚本健壮性**：使用 `printf` 替代 `ui_print` 中的 `echo` 以解决可移植性问题；在 utility 函数中添加基本参数验证

### 🌐 国际化与本地化改进
- **统一翻译框架**：引入 `safe_printf` 支持位置格式参数；将硬编码的 UI/log 字符串替换为语言键；对齐英文和中文翻译，提升消息一致性
- **语言检测增强**：优化区域设置检测，解析区域设置组件，健壮地加载语言文件；移除 `device_provisioned` 回退；修复区域设置解析问题

### 📦 构建与发布流程
- **版本管理优化**：重构 GitHub Actions 工作流，使用日期和构建号生成版本和版本号，确保夜间构建和发布构建的版本唯一且一致
- **CI 工作流改进**：更新 `.gitattributes`、工作流和 `.gitignore`；将 UPX 版本升级至 5.1.0
- **许可证管理**：为字体源文件添加 SIL Open Font License；为 font-cmap-cleaner 工具添加 Mozilla Public License 2.0

### 🔤 Unicode 解析与字体分析
- **Unicode 解析优化**：重构 `check_fonts_unicode.py`，按 Unicode 分类（Cs、Co、Cn）排除码点而非硬编码代理/私用区范围
- **字体差异分析工具**：新增 `fontdiff.py`，支持字体文件的视觉 HTML 差异对比，高亮显示新增、移除、变更、重命名和修改的字形
- **字体 cmap 清理器增强**：更新 `font-cmap-cleaner` 支持 `--ignore-xml` 选项，允许忽略XML文件处理所有字体

### 📝 字体与文档更新
- **UFSTempAlpha 字体**：新增 `UFSTempAlpha.otf` 字体文件（font-source/UFSTempAlpha.fcp 和 module/system/fonts/UFSTempAlpha.otf）
- **NotoSansSuper 更新**：更新 `NotoSansSuper.otf` 字体及其 Unicode 覆盖范围 SVG
- **文档样本更新**：更新多个文档/SVG 样本（覆盖计数、高度/viewBox、新增/更新的区块）

---

## V1.7.3

### 🗂️ 仓库与结构调整
- **目录结构优化**：重新整理仓库目录树，提升整体可读性与维护性。
- **模块化改造**：将硬编码的字体 XML 抽离为 `config/fonts_fragment.xml`，降低后续更新成本。
- **卸载支持**：新增 `uninstall.sh`，在模块移除时自动还原被修改的备份文件。

### 🧪 测试与质量保障
- **测试体系引入**：新增 Rust 单元测试与集成测试，覆盖：
  - `fonts.xml` 解析逻辑
  - Unicode 扫描与 cmap 重写
  - CLI 行为验证
- **测试资源完善**：提供最小字体与 `fonts.xml` fixtures，确保测试可复现。

### 🔧 核心功能重构与稳定性提升
- **字体注入流程重构**：使用基于 `awk` 的块插入逻辑，替换脆弱的 `sed` 多行注入方案。
- **模块初始化修复**：
  - 修复脚本真实路径解析问题（symlink 场景）
  - 增强 Magisk 镜像路径校验与回退机制
- **并发与安全性**：
  - 引入全局锁防止并发执行
  - 使用原子写入与安全 SHA1 文件名，避免文件损坏
- **日志系统升级**：
  - 迁移至结构化 tracing 日志
  - 时间戳精度提升至秒级
  - 增加扫描阈值保护，避免 Emoji 字体被误过滤

### 🧹 字体处理与覆盖分析增强
- **Font cmap Cleaner 集成**：
  - 新增 Rust 编写的 `font-cmap-cleaner` 工具
  - 安装阶段可通过音量键交互选择是否执行
  - 支持 ABI 自动匹配、白名单与 dry-run 预览模式
- **系统字体感知**：
  - 解析 Android `fonts.xml`，仅扫描实际生效的系统字体
  - 自动忽略 fallback 字体和模块自身注入字体，提升覆盖分析准确性
  - 支持 `.ttc` 字体集合
- **跳过与白名单机制**：
  - 支持按文件名跳过处理
  - 对非 Emoji 字体加入白名单时给出警告

### 📦 构建与发布流程
- **Android Rust 工具链**：
  - 通过 GitHub Actions 使用 NDK + cargo-ndk 构建 Android 可用的 Rust 工具
  - 对生成的二进制进行 UPX 压缩

### 🌐 国际化与用户体验
- **完整国际化支持**：
  - 引入统一语言加载器 `lang/lang.sh`
  - 提供 `en_US` 与 `zh_CN` 语言包
  - 使用 `safe_text` / `safe_printf` 防止缺失翻译导致崩溃
- **交互体验优化**：
  - 安装阶段禁用 ANSI 颜色输出，避免在严格 shell 环境下出错

### 🧩 字体与文档更新
- **字体替换**：在工作流、配置与文档中统一使用 `UnicodiaDaarage`，移除 `MonuTemp`。
- **文档改进**：
  - README 新增 Android 12+ FontLoader 与 KernelSU Meta Module 说明
  - 新增结构化 GitHub Issue 模板（Bug / Feature Request）

---

## V1.7.2

### 🗂️ 文件结构优化
- **移除冗余字体**：删除CtrlCtrl.otf和UFSEmoji-Ext.ttf
- **XML配置精简**：简化fonts.xml中的字体家族定义

### 📊 性能与兼容性
- **UnicodiaSesh字体**：埃及象形文字区块显示字体更新
- **字体许可证更新**：完善LICENSES.md，明确包含历史使用字体

### 🔄 自动更新系统
- **多版本支持**：为COLRv1和CBDT变体分别配置独立的更新JSON文件
- **夜间构建优化**：生成专门的夜间构建更新配置文件和变更日志
- **版本号改进**：夜间构建版本号使用纯日期格式，移除冗余数字

### 📦 构建流程增强
- **矩阵构建策略**：同时构建COLRv1（Android 12L+）和CBDT（Android 5.0+）两个变体
- **模块属性动态更新**：根据构建类型自动设置正确的updateJson链接
- **多工件管理**：分别为不同变体生成独立的ZIP包和更新文件

### 🌐 国际化改进
- **文档链接优化**：调整README语言切换按钮的链接行为
- **许可证文档调整**：更新字体许可证描述，从CeCILL-C/OFL改为作者声明/OFL

---

## V1.7.1

### 📝 字体更新
- **字体更新**：将遍黑体（Plangothic）替换为 OTF 版本；更新 `NotoColorEmoji` 和 `UnicodiaSesh` 字体。

### 🔧 系统优化
- **模块操作功能**：为每个 font 标签添加 `postScriptName`；调整 `NotoSansSuper` 与 `NotoUnicode` 字体的加载顺序；新增时间输出功能。

---

## V1.7.0

### 📝 字体更新与优化
- **字体轮廓更新**：修复 `UFSZeroExt` 字体中「𘴞」(U+18D1E) 的错误部件，且添加了字体源文件。
- **字体更新**：`UFSZeroExt`新增了120个字形，跟进`遍黑体（Plangothic）`、`Last Resort`和`UnicodiaSesh`字体更新

### 🔧 系统优化
- **模块操作功能**：调整构建顺序以尝试修复“顺序颠倒”问题。

---

## V1.6.1

### 📝 字体更新与优化
- **字体轮廓问题修复**：修复 `UFSZeroExt` 字体由于FontCreator导出优化后字形轮廓出现问题，取消锚点优化。
- **字体更新与删除**：将 `NotoSans*-Regular.otf` 字体统一替换为非地区子集的 `SourceHanSansSC-Regular.otf`。
- **字体更新**：将 `UFS*Ext` 和 `NotoSansSuper.otf` 字体换为三次贝塞尔曲线版本。 
`UFSZeroExt` 和 `UFSEmoji-Ext` 字体更新和制作了新的字形。

---

## V1.6.0

### 📝 字体更新与优化
- **字体重命名并更新**：将 `UFSAramusic.ttf` 字体重命名为 `UFSZeroExt.ttf` 字体，并更新和制作了新的字形。

---

## V1.5.0

### 📝 字体更新与优化
- **字体精简**：移除 `UnicodiaDaarage.otf` 字体，以优化模块体积和资源占用。
- **UFSAramusic.ttf 新增**：引入 `UFSAramusic.ttf` 字体，此字体内的字形均为开源字体制作而成（拼这些阿拉伯连字累死我了）。

---

## V1.4.0

### 🔤 Unicode 字符支持扩展
- **埃及象形文字扩展 A**：新增 UnicodiaSesh.ttf 和 NewGardiner.ttf 字体，实现对埃及象形文字扩展 A 区块的显示
- **Tulu-Tigalari 文字**：集成 UnicodiaDaarage.otf 字体，实现对 Tulu-Tigalari 区块的显示

### 📝 字体更新
- **NotoColorEmoji**：替换为 COLRv1 矢量表情字体标准，提供更清晰的缩放效果
- **NotoSansSuper**：更新至最新版本，扩充字符显示
- **KreativeSquare**：新增全宽等宽字体，支持伪图形、半图形字符和私用区字符

### 🔧 系统优化
- **日志管理改进**：开机自动清理历史日志
- **模块操作功能**：模块管理下点击"操作"按钮可立即执行模块监控

---

## V1.3.0
1. 全面升级字体注入机制，替换 `MonuLast` 字体为 `LastResort`，并新增对 `LastResort` 字体的支持
2. 更新了 `NotoSansSuper` 和 `Plangothic` 字体
3. 优化字体XML配置插入逻辑：动态检测和删除旧配置，确保字体配置唯一性与正确性
4. 增强字体二进制文件的备份与还原策略，支持对重名字体文件的精准管理，提升模块间兼容性
5. 改进系统字体XML文件迁移，自动检测来自系统路径的字体配置，确保系统字体同步无误
6. 增加字体文件和字体二进制文件变化监控，自动检测更新、删除操作，实时同步字体配置
7. 提升脚本稳定性：增强路径映射逻辑，支持多路径环境下的兼容，避免路径冲突问题
8. 细化日志记录，记录每次字体配置注入、备份、还原过程，方便排查与维护
9. 修复若干已知问题，字体管理流程更加可靠

</details>

---

### 🔤 Unicode Codepoint Coverage / Unicode 码点显示情况

- **Unicode 17.0 Full Support**: Complete glyph coverage for all defined characters in Unicode 17.0
- **Unicode 17.0 标准码点全覆盖**：本模块实现了对 Unicode 17.0 标准码点的完整字形显示。

- **Unicode 18.0 Alpha Complete**: All target codepoints are now covered!
- **Unicode 18.0 Alpha 全面支持**：所有目标码点现已完全覆盖！

```bash
PS .\UnicodeFontSet-magisk-module\module\system\fonts> py check_fonts_unicode.py UnicodeData.txt *.*tf
1) Parsing UnicodeData.txt ...
   → Total codepoints to cover: 172914 (excluded Cs/Co/Cn categories)

   Read KreativeSquare.ttf codepoints from 6244
   Read NewGardiner.ttf codepoints from 4639
   Read NotoColorEmoji.ttf codepoints from 1499
   Read NotoEmoji-Regular.ttf codepoints from 1503
   Read NotoSansSuper.otf codepoints from 17693
   Read NotoUnicode.otf codepoints from 21755
   Read PlangothicP1-Regular.otf codepoints from 65435
   Read PlangothicP2-Regular.otf codepoints from 42542
   Read SourceHanSansSC-Regular.otf codepoints from 44853
   Read TempSeal.ttf codepoints from 22554
   Read UFSTempAlpha.otf codepoints from 1720
   Read UFSZeroExt.otf codepoints from 378
   Read UnicodiaDaarage.otf codepoints from 101
   Read UnicodiaSesh.ttf codepoints from 4719

   Union of fonts supports 177436 codepoints

✅ All target Unicode codepoints are covered!
```

---
***Coverage Notes / 覆盖情况说明：***
- *V1.7.5: Full Unicode 18.0 Alpha support — Jurchen (18E00-19191), Seal (3D000-3FC3F), Archaic Cuneiform Numerals (12550-12686)*
- *V1.7.5 已完成 Unicode 18.0 Alpha 全部字符支持，包括女真文(Jurchen 18E00-19191)、篆书(Seal 3D000–3FC3F)和古楔形文字数字(Archaic Cuneiform Numerals 12550-12686)区块*

### 🎨 Emoji Font Variants / Emoji 字体格式变体
- Please refer to [`Variants`](https://github.com/Losketch/UnicodeFontSet-magisk-module/releases/tag/nightly)
- 请参考[`Variants`](https://github.com/Losketch/UnicodeFontSet-magisk-module/releases/tag/nightly).
