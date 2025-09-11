
## V1.7.0

### 📝 字体更新与优化
- **字体轮廓更新**：修复 `UFSZeroExt` 字体中「𘴞」(U+18D1E) 的错误部件，且添加了字体源文件。
- **字体更新**：`UFSZeroExt`新增了120个字形，跟进`遍黑体（Plangothic）`、`Last Resort`和`UnicodiaSesh`字体更新

### 🔧 系统优化
- **模块操作功能**：调整构建顺序以尝试修复“顺序颠倒”问题。

### 🔤 Unicode 码点显示情况
- **Unicode 17.0 标准码点全覆盖**：从Unicode草案更新至正式发行版，本模块实现了对 Unicode 17.0 标准码点的完整字形显示支持。

```bash
PS .\UnicodeFontSet-magisk-module\system\fonts> $type = Get-ChildItem *.*tf | ForEach-Object { $_.Name }
PS .\UnicodeFontSet-magisk-modulesystem\fonts> py check_fonts_unicode.py UnicodeData.txt $type
1) 解析 UnicodeData.txt …
   → 总计需覆盖 159866 个码点（已剔除代理/私用区）

   已从 CtrlCtrl.otf 读取 644 个 codepoint
   已从 KreativeSquare.ttf 读取 6244 个 codepoint
   已从 MonuTemp.ttf 读取 2717 个 codepoint
   已从 NewGardiner.ttf 读取 5205 个 codepoint
   已从 NotoColorEmoji.ttf 读取 1492 个 codepoint
   已从 NotoSansSuper.otf 读取 17696 个 codepoint
   已从 NotoUnicode.otf 读取 21755 个 codepoint
   已从 PlangothicP1-Regular.ttf 读取 65446 个 codepoint
   已从 PlangothicP2-Regular.ttf 读取 42546 个 codepoint
   已从 SourceHanSansSC-Regular.otf 读取 44853 个 codepoint
   已从 UFSEmoji-Ext.ttf 读取 12 个 codepoint
   已从 UFSZeroExt.otf 读取 360 个 codepoint
   已从 UnicodiaSesh.ttf 读取 3190 个 codepoint

   字体联合后共支持 164849 个码点

✅ 联合覆盖了全部目标 Unicode 码点！
```

---
***覆盖情况说明**：*
- *Unicode 17.0 标准码点（排除代理区和私用区）：159,866 个 - ✅ 完全覆盖*
- *字体总支持码点：164,849 个（包含部分非标准码点和字体厂商扩展字符）*
