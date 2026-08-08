# 字体许可证

UFS 不根据字体名、来源仓库或同仓库其它文件猜测许可证。每只字体的来源与人工确认后的许可文本 URL 统一维护在：

```text
font-source/font-sources.toml
```

## 本仓库自有字体源码

`font-source/LICENSE-OFL-1.1` 是本仓库自有 OFL-1.1 字体源码/资产的随附许可证，例如 UFSZero Ext。最终模块中的字体许可证由 `font-sources.toml` 的 `license` URL 获取并生成。

## 配置方式

`license` 直接填写可下载到**原始许可证/授权文本**的 HTTPS URL，优先使用字体上游仓库中的 raw 文件：

```toml
[[fonts]]
file = "SourceHanSansSC-Regular.otf"
acquisition = "direct"
source_location = "https://example.com/SourceHanSansSC-Regular.otf"
license = "https://example.com/raw/LICENSE.txt"
```

构建时会下载该文本并按字体文件名保存到：

```text
module/META-INF/licenses/LICENSE-SourceHanSansSC-Regular
```

许可证文件不带 `.txt`。同一个许可证 URL 被多只字体使用时，构建器会复用本次下载结果，但仍为每只字体生成独立的 `LICENSE-<font stem>`，使最终模块中的归属关系保持显式。

如果许可证尚未确认，省略 `license`。CI 会产生 `Font licensing` warning，构建 manifest 会记录 `REVIEW_REQUIRED`；公开 Release 会拒绝未完成审核的字体。

## URL 选择原则

优先级从高到低：

1. 字体**原始上游仓库**中与该字体直接对应的许可证/授权文本；
2. 当前分发仓库中与该字体直接对应的许可证文本；
3. 对于项目自有字体且上游没有独立许可文件，使用可信的标准许可证原文 URL。

不要把仓库主页、GitHub `blob` HTML 页面、README 摘要或 SPDX 标识本身写进 `license`。这里需要的是构建时可以直接保存进模块的许可文本 URL。

对于混合来源字体，应优先指向上游已经整理好的**该字体专用许可文件**，因为这种文件可能包含多个来源、额外授权条件或版权信息；不要用通用许可证文本覆盖这些信息。

## 人工审核要点

每只公开分发字体至少确认：

1. 许可证允许 UFS 的实际分发方式，以及项目会执行的字体/cmap 修改。
2. `license` URL 确实对应当前字体，并包含需要保留的版权、Reserved Font Name、重命名等信息。
3. 混合来源或特殊授权字体已经确认其专用许可文本覆盖当前分发内容和用途。

## 构建结果

每次构建会为有 `license` URL 的字体生成：

```text
module/META-INF/licenses/LICENSE-<font stem>
```

随后生成：

```text
module/META-INF/licenses/font-manifest.tsv
```

manifest 记录本次构建实际使用的字体来源、解析后的下载地址、SHA-256、文件大小、许可证 URL 与审核状态。它是构建记录，不是字体 lockfile。
