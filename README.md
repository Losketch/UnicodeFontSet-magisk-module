<div align="center">

<a href="#">
  <img src="https://img.shields.io/badge/语言-中文-blue?style=for-the-badge&logo=googletranslate&logoColor=white" alt="中文版本">
</a>
<a href="README.en.md">
  <img src="https://img.shields.io/badge/Language-English-red?style=for-the-badge&logo=googletranslate&logoColor=white" alt="English Version">
</a>

# Magisk 模块：扩展 Unicode 字体合集（UFS-Magisk）

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

UFS 是一个面向已 Root 设备的字体扩展模块。它整合了多套开源字体并无缝接入 Android 系统的字体回退（fallback）链中，用于补全系统中大量缺失的字符（涵盖冷僻汉字、古文字、符号及最新 Emoji 等）。

模块原生支持 Magisk、KernelSU 及 APatch，并针对其它字体模块共存与系统 OTA 更新做了自动兼容适配。

---

## 安装指引

### 1. 下载模块
前往 [Releases 页面](https://github.com/Losketch/UnicodeFontSet-magisk-module/releases) 下载对应版本的安装包：
- **CBDT 格式**：适用于 Android 8.0+ (API 26+)
- **COLRv1 格式**：适用于 Android 13+ (API 33+)，推荐较新系统使用以获得更好的彩色 Emoji/符号渲染

### 2. 刷入并配置
在模块管理器（Magisk / KernelSU / APatch）中选择安装包进行刷入：
- **音量上键**：跳过 cmap 清理（**推荐普通用户选择**，耗时极短）。
- **音量下键**：执行 cmap 清理（深度去重，降低字符被意外字体截胡的概率）。
- **15 秒无操作**：默认自动跳过清理。

### 3. 重启生效
刷入完成后，重启手机即可生效。

---

## 基础配置

绝大多数用户**开箱即用，无需修改任何配置**。如需微调，可通过以下配置文件实现：

### 1. 特殊分区 XML 模式 (`SPECIAL_PARTITION_XML_MODE`)
配置文件路径：`/data/adb/ufs/config.conf`

在 KernelSU 或 APatch 环境下，系统中的 `/system/product` 或 `/system/system_ext` 可能为符号链接（Symlink）。为避免模块目录遮蔽符号链接导致系统启动异常，模块默认采用安全策略：
- **`safe`（默认）**：检测到目标为符号链接时自动安全降级，跳过在特殊分区挂载 UFS 专有 XML。
- **`force`**：强制使用标准 Magisk 布局挂载特殊分区。**仅在你确认所用的挂载方式/Metamodule 能够安全处理特殊分区时启用，否则可能导致 Bootloop**。

#### 快速切换命令：
```sh
# 切换为强制模式（需 Root 权限）
su -c 'mkdir -p /data/adb/ufs && echo "SPECIAL_PARTITION_XML_MODE=force" > /data/adb/ufs/config.conf'

# 恢复默认安全模式
su -c 'mkdir -p /data/adb/ufs && echo "SPECIAL_PARTITION_XML_MODE=safe" > /data/adb/ufs/config.conf'
```
修改后执行一次模块 **Action** 或**重启设备**即可生效。

---

### 2. 字体策略文件 (`font-policy.tsv`)
文件路径：`模块目录/config/font-policy.tsv`

用于指定具体字体的映射保留与删除规则。每行一个字体，采用 **TAB（制表符）** 分隔：
```text
role<TAB>font filename<TAB>protect<TAB>remove
```

| 字段 | 说明 | 示例 |
|---|---|---|
| `role` | `normal-fallback`（普通补字） / `terminal-fallback`（最终兜底） / `system-overlay`（同名替换原厂字体） | `normal-fallback` |
| `font filename` | 字体文件名 | `PlangothicP2-Regular.otf` |
| `protect` | 保留指定字符映射，不被前序字体去重清除（`-` 为空，`*` 为全选） | `[U+0080-U+009F]` |
| `remove` | 强制删除指定字符的 cmap 映射（与 protect 冲突时 **remove 优先**） | `[e000-f8ff]` |

> 仅高级用户需要调整此文件。修改后建议重新运行 Action 或重新刷入模块。

---

## 兼容性与故障排查

### 模块未生效？
1. **重启设备**一次。
2. 在模块管理器中找到 UFS，点击执行 **Action**（重新整理字体 XML 配置）。
3. 检查排查日志：
   ```text
   /data/adb/modules/unicode_font_set/ufs.log
   ```
4. 如果是 KernelSU / APatch 用户且日志显示“挂载安全降级”，表明已自动保护系统符号链接。

### Magisk DenyList（排除列表）与应用闪退/缺字
若某个被加入 DenyList 的应用开启了「模块挂载隔离（Mount Isolation）」，Magisk 会在该应用的挂载空间内隐藏模块文件。这可能导致该 App 读取到了系统的字体配置文件，却无法访问模块内的字体文件，进而产生**缺字、乱码或启动闪退**。

**排查建议**：
1. 检查异常应用是否加入了 DenyList。
2. 尝试临时调整隔离策略或使用 [FontLoader](https://github.com/JingMatrix/FontLoader) 等辅助方案。

### 其它字体模块冲突
- UFS 会自动检测并与其它字体模块共存。在发生冲突时，UFS 会自动备份冲突文件。
- **请勿直接“禁用”模块**：如果不想继续使用 UFS，请执行**标准卸载**，以便模块卸载脚本恢复此前备份的其它模块文件。

---

## 常见问题 (FAQ)

#### Q: 如何验证模块是否生效？
可以在浏览器或笔记应用中直接查看扩展字符（例如生僻古籍字、Unicode 扩展汉字、特殊表情符号）。如果原先显示的“豆腐块”（`□`）已正确渲染为相应字形，即表示生效。

#### Q: cmap cleaner（清理器）是否有必要运行？
对于大多数用户，直接按音量上键跳过即可。只有当你发现某些特定字符/Emoji 的样式被不喜欢的字体抢先匹配显示时，再在刷入时按音量下键执行深度清理。

#### Q: 卸载后提示有残留锁文件？
正常卸载通常会自动清理。如需手动重置状态，可执行：
```sh
su -c rm -rf /data/adb/ufs_lock /data/adb/ufs
```

---

## 文档与支持

- 📄 [字体来源与许可协议](docs/LICENSES.md)
- 🙏 [致谢与第三方项目](docs/CREDITS.md)
- 🛠️ [开发与编译指南](docs/DEVELOPMENT.md)

> **免责声明**：本模块按“原样”提供。替换系统字体及修改系统配置存在一定风险，刷入前请自行做好系统备份，并自行承担使用风险。
