
## V1.6.1

### 📝 字体更新与优化
- **字体轮廓问题修复**：修复 `UFSZeroExt` 字体由于FontCreator导出优化后字形轮廓出现问题，取消锚点优化。
- **字体更新与删除**：将 `NotoSans*-Regular.otf` 字体统一替换为非地区子集的 `SourceHanSansSC-Regular.otf`。
- **字体更新**：将 `UFS*Ext` 和 `NotoSansSuper.otf` 字体换为三次贝塞尔曲线版本。 
`UFSZeroExt` 和 `UFSEmoji-Ext` 字体更新和制作了新的字形。

<details>
<summary>点击查看新增的字形</summary>

- **阿拉伯扩充乙 (Arabic Extended-B)**：新增 1 个字形
  ```
ࢗ (U+0897)
  ```

- **西夏 (Tangut)**：新增 4 个字形
  ```
𗄡 (U+17121)  𗱑 (U+17C51)  𗴋 (U+17D0B)  𘃟 (U+180DF)
  ```

- 新增了 8 个彩色emoji
  ```
🛘 (U+1F6D8)	LANDSLIDE
🪊 (U+1FA8A)	TROMBONE
🪎 (U+1FA8E)	TREASURE CHEST
🫈 (U+1FAC8)	HAIRY CREATURE
🫍 (U+1FACD)	ORCA
🫝 (U+1FADD)	APPLE CORE
🫪 (U+1FAEA)	DISTORTED FACE
🫯 (U+1FAEF)	FIGHT CLOUD
  ```
另外还增加了一个连字: `🧑‍🩰 (\u1f9d1\u200d\u1fa70)`

</details>

### 🔤 Unicode 字符支持增强
- **Unicode 17.0 Beta 全字形覆盖**：至此，本模块**真的**实现了对 Unicode 17.0 Beta 标准的**全**字形显示支持。

---
*本版本主要聚焦于字体集的更新与 Unicode 17.0 Beta 的前瞻性支持，显著提升了字符显示的完整性。*
