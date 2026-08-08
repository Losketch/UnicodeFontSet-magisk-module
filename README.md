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

UFS 为已 Root 的 Android 设备补充大量系统缺失字符。模块组合多套字体，并把它们加入 Android 的字体回退链。Unicode 覆盖目标与 UFS 框架版本相互独立；当前目标由 `release.toml` 的 `unicode_version` 定义（当前为 Unicode 18.0.0 Beta，不包括代理区与私用区）。

模块支持 Magisk，并可配合 KernelSU / APatch 使用；也会尽量兼容其它字体模块和系统 OTA 后的字体配置变化。

## 下载与安装

1. 前往 [Releases](https://github.com/Losketch/UnicodeFontSet-magisk-module/releases) 下载模块 ZIP。
2. 在 Magisk / KernelSU / APatch 的模块页面安装。
3. 选择与你系统匹配的 Variant：
   - **CBDT**：API 26+（Android 8.0+）。
   - **COLRv1**：API 33+（Android 13+）。
4. 安装时会询问是否执行 cmap 清理：
   - **音量上键**：跳过清理。
   - **音量下键**：执行清理。
   - 15 秒无操作：自动跳过。
5. 安装完成后重启。

普通使用通常无需修改任何配置。

### KernelSU 用户

KernelSU 需要可挂载 `/system` 的元模块（例如 `meta-overlayfs`），否则 `system/fonts/` 中的字体不会真正生效。详见 [KernelSU Metamodule 文档](https://kernelsu.org/zh_CN/guide/metamodule.html)。

## 配置

UFS 的运行时字体策略集中在：

```text
module/config/
├── font-policy.tsv      # 字体角色、顺序、保护/删除范围
├── fonts_fragment.xml   # 写入 Android fallback 的字体列表和顺序
└── discovery.conf       # 系统字体/XML 的发现范围
```

### `font-policy.tsv`

这是一个 **TAB 分隔**文件，每只字体一行：

```text
role<TAB>font filename<TAB>protect<TAB>remove
```

例如：

```text
normal-fallback	PlangothicP2-Regular.otf	[U+0080-U+009F]	-
```

请使用真正的 TAB，不要用空格代替。

| role | 用途 | 是否需要写进 `fonts_fragment.xml` |
|---|---|---|
| `system-overlay` | 用同名文件替换系统原字体 | 通常不需要 |
| `normal-fallback` | 普通补字字体，按表中顺序处理 | 需要 |
| `terminal-fallback` | 最后的兜底字体 | 需要，并应放在最后 |

`normal-fallback` / `terminal-fallback` 在 `font-policy.tsv` 中的顺序应与 `fonts_fragment.xml` 的 fallback 顺序一致；仓库校验会检查两边是否漂移。

### `protect` 与 `remove`

- `protect`：字体原本存在的这些 cmap 映射不会因与前序字体重复而被清理。
- `remove`：无论前序字体是否包含这些字符，都强制删除这些 nominal Unicode cmap 映射。
- 同一码点同时出现时，**`remove` 优先**。

支持的范围写法：

```text
-                              不指定任何码点
*                              全部码点
80-9f                          一个范围
U+0080-U+009F                  同上
1df02                          单个码点
[ff-4e02,1df02,30ede]          多个范围/码点
[U+00FF-U+4E02,U+1DF02]        也可以带 U+
```

保护示例：

```text
normal-fallback	PlangothicP2-Regular.otf	[80-9f]	-
```

`protect` 只保留字体本来存在的映射，不会凭空增加字形。

删除示例：

```text
normal-fallback	ExampleFont.otf	-	[e000-f8ff]
```

当前 range rewrite 支持普通 TTF/OTF。TTC/OTC 可以被识别和查询，但不会被重写。如果去重/过滤后字体没有任何 Unicode 映射，cleaner 会警告并跳过输出，而不会生成空 cmap 字体。

### `discovery.conf`

`discovery.conf` 定义：

- 哪些 familyset XML 用于默认 fallback 配置；
- 哪些系统字体目录参与 cmap cleaner 的默认/global fallback baseline；
- `find` 命令可搜索哪些更宽的字体目录；
- sibling 字体模块常见的 XML/字体位置；
- Android 动态更新字体目录。

默认情况下，`/product/fonts` 与 `/system/product/fonts` **只参与 `find` 诊断，不进入 cmap cleaner 的全局 baseline**。现代 Android 中 product 字体常用于可选或命名字体，文件存在并不代表其参与默认 fallback。特殊 ROM 若确实把 product 字体加入全局 fallback，可在这里显式调整 baseline 路径。

Shell 在运行时读取该配置；Rust cleaner 在构建时嵌入它，因此修改后需要重新编译模块才能让 Rust 侧生效。

## cmap cleaner

cleaner 用于减少 fallback 字体之间重复的 cmap 映射，降低某些符号、Emoji 或长尾字符被错误字体抢先匹配的概率。

- 不确定是否需要时，可以先跳过 cleaner。
- cleaner 的行为由 `font-policy.tsv` 控制。
- cleaner 会修改模块中的 TTF/OTF；重新安装模块可恢复发布包原字体。
- 清理完成后需要重启设备。

## 与其它字体模块一起使用

UFS 会尝试与其它字体模块共存，并在模块变化或 OTA 后重新整理自己的字体 XML。

如果安装后没有生效：

1. 重启一次。
2. 在模块管理器中执行 UFS 的 **Action**。
3. KernelSU 用户确认已安装并启用可挂载 `/system` 的元模块。
4. 查看日志：

```text
/data/adb/modules/unicode_font_set/ufs.log
```

UFS 为解决同名字体/cmap 冲突会备份并移除其它字体模块中的冲突文件。仅“禁用” UFS 不等价于回滚这些改动；停止使用时请正常**卸载** UFS，让卸载脚本恢复备份。

## 常见问题

### 安装后某些 App 闪退

Android 12+ 的字体加载方式与旧版本不同。若传统字体模块导致应用崩溃，可尝试 [FontLoader](https://github.com/JingMatrix/FontLoader)。

### 怎么确认 UFS 已生效？

可以检查：

```text
/system/fonts/
/system/etc/fonts.xml
/system/product/etc/fonts.xml
```

也可以直接打开包含生僻字、扩展汉字、古文字或符号的测试文本查看显示结果。

### 支持哪些 Android 版本？

以 `release.toml` 为准：

- **CBDT**：API 26+（Android 8.0+）。
- **COLRv1**：API 33+（Android 13+）。

安装器会读取当前构建的 `minApi`；低于门槛时会停止安装。

### 卸载后还有残留怎么办？

通常正常卸载即可。如果需要手动清理锁文件：

```bash
su -c rm -rf /data/adb/ufs_lock
```

## 其它文档

- 📄 [字体来源与许可](docs/LICENSES.md)
- 🙏 [鸣谢](docs/CREDITS.md)
- 🛠️ [构建与测试](docs/DEVELOPMENT.md)

本模块按“原样”提供。修改字体、过滤 cmap 或替换系统字体前请自行备份，并自行承担使用风险。
