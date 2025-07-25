
## V1.5.0

### 📝 字体更新与优化
- **字体精简**：移除 `UnicodiaDaarage.otf` 字体，以优化模块体积和资源占用。
- **UFSAramusic.ttf 新增**：引入 `UFSAramusic.ttf` 字体，此字体内的字形均为开源字体制作而成（拼这些阿拉伯连字累死我了）。

<details>
<summary>点击查看 UFSAramusic 新增的字形</summary>

- **亚美尼亚文 (Armenian)**：新增 3 个字形
  ```
  ՘ (U+0558)  ֋ (U+058B)  ֌ (U+058C)
  ```

- **阿拉伯文扩充乙 (Arabic Extended-B)**：新增 1 个字形
  ```
  ࢏ (U+088F)
  ```

- **阿拉伯文扩充甲 (Arabic Extended-A)**：新增 25 个字形
  ```
  ﯃ (U+FBC3)  ﯄ (U+FBC4)  ﯅ (U+FBC5)  ﯆ (U+FBC6)  ﯇ (U+FBC7)
  ﯈ (U+FBC8)  ﯉ (U+FBC9)  ﯊ (U+FBCA)  ﯋ (U+FBCB)  ﯌ (U+FBCC)
  ﯍ (U+FBCD)  ﯎ (U+FBCE)  ﯏ (U+FBCF)  ﯐ (U+FBD0)  ﯑ (U+FBD1)
  ﯒ (U+FBD2)  ﶐ (U+FD90)  ﶑ (U+FD91)  ﷈ (U+FDC8)  ﷉ (U+FDC9)
  ﷊ (U+FDCA)  ﷋ (U+FDCB)  ﷌ (U+FDCC)  ﷍ (U+FDCD)  ﷎ (U+FDCE)
  ```

- **阿拉伯扩充丙 (Arabic Extended-C)**：新增 13 个字形
  ```
   𐻅 (U+10EC5)  𐻆 (U+10EC6)  𐻐 (U+10ED0)  𐻑 (U+10ED1)  𐻒 (U+10ED2)
   𐻓 (U+10ED3)  𐻔 (U+10ED4)  𐻕 (U+10ED5)  𐻖 (U+10ED6)  𐻗 (U+10ED7)
   𐻘 (U+10ED8)  𐻺 (U+10EFA)  𐻻 (U+10EFB)
  ```

- **乐符 (Musical Symbols)**：新增 23 个字形
  ```
   𝄧 (U+1D127)  𝄨 (U+1D128)  𝇫 (U+1D1EB)  𝇬 (U+1D1EC)  𝇭 (U+1D1ED)
   𝇮 (U+1D1EE)  𝇯 (U+1D1EF)  𝇰 (U+1D1F0)  𝇱 (U+1D1F1)  𝇲 (U+1D1F2)
   𝇳 (U+1D1F3)  𝇴 (U+1D1F4)  𝇵 (U+1D1F5)  𝇶 (U+1D1F6)  𝇷 (U+1D1F7)
   𝇸 (U+1D1F8)  𝇹 (U+1D1F9)  𝇺 (U+1D1FA)  𝇻 (U+1D1FB)  𝇼 (U+1D1FC)
   𝇽 (U+1D1FD)  𝇾 (U+1D1FE)  𝇿 (U+1D1FF)
  ```

- **拉丁扩充庚 (Latin Extended-G)**：新增 22 个字形
  ```
   𝼟 (U+1DF1F)  𝼠 (U+1DF20)  𝼡 (U+1DF21)  𝼢 (U+1DF22)  𝼣 (U+1DF23)
   𝼤 (U+1DF24)  𝼫 (U+1DF2B)  𝼬 (U+1DF2C)  𝼭 (U+1DF2D)  𝼮 (U+1DF2E)
   𝼯 (U+1DF2F)  𝼰 (U+1DF30)  𝼱 (U+1DF31)  𝼲 (U+1DF32)  𝼳 (U+1DF33)
   𝼴 (U+1DF34)  𝼵 (U+1DF35)  𝼶 (U+1DF36)  𝼷 (U+1DF37)  𝼸 (U+1DF38)
   𝼹 (U+1DF39)  𝼺 (U+1DF3A)
  ```

</details>

### 🔤 Unicode 字符支持增强
- **Unicode 17.0 Beta 全字形覆盖**：通过集成 `UFSAramusic.ttf`，本模块现已实现对 Unicode 17.0 Beta 标准的**全**字形显示支持。
- **特定西夏字符集说明**：目前，以下西夏文字符集暂未包含在全字形显示范围内：
    - `西夏 (Tangut)` 区块的 8 个字符（U+187F8 至 U+187FF）
    - `西夏偏旁 (Tangut Components)` 区块的 21 个字符（U+18D09 至 U+18D1E）
    - 整个 `西夏偏旁补充 (Tangut Components Supplement)` 区块的 115 个字符（U+18D80 至 U+18DF2）

---
*本版本主要聚焦于字体集的精简与 Unicode 17.0 Beta 的前瞻性支持，显著提升了字符显示的完整性。*
