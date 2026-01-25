import os
import base64
import hashlib
import argparse
from fontTools.ttLib import TTFont
from fontTools.pens.recordingPen import RecordingPen


def normalize_pen_value(pen_value, precision=2):
    normalized = []
    for cmd, points in pen_value:
        if points:
            new_points = []
            for pt in points:
                new_points.append(
                    tuple(
                        round(v, precision) if isinstance(v, float) else v
                        for v in pt
                    )
                )
            normalized.append((cmd, tuple(new_points)))
        else:
            normalized.append((cmd, points))
    return tuple(normalized)


def glyph_hash(font, glyph_name):
    glyph_set = font.getGlyphSet()
    pen = RecordingPen()
    glyph_set[glyph_name].draw(pen)

    data = repr(normalize_pen_value(pen.value, 2)).encode()
    width = font["hmtx"][glyph_name][0]

    m = hashlib.sha256()
    m.update(data)
    m.update(str(width).encode())
    return m.hexdigest()


def diff_fonts(font_a_path, font_b_path):
    fa = TTFont(font_a_path)
    fb = TTFont(font_b_path)

    glyphs_a = set(fa.getGlyphOrder())
    glyphs_b = set(fb.getGlyphOrder())
    hashes_a = {g: glyph_hash(fa, g) for g in glyphs_a}
    hashes_b = {g: glyph_hash(fb, g) for g in glyphs_b}

    cmap_a = fa["cmap"].getBestCmap()
    cmap_b = fb["cmap"].getBestCmap()

    processed_a = set()
    processed_b = set()

    changed = []       # Name相同，形状不同 (常规修改)
    modified = []      # Name不同，Unicode相同，形状不同 (改名+修改)
    renamed = []       # Name不同，形状相同 (纯改名)

    # --- 1. 基于 Unicode 的核心比对 ---
    # 找出两个字体共同包含的 Unicode 字符
    common_unis = set(cmap_a.keys()) & set(cmap_b.keys())

    for uni in sorted(common_unis):
        g_name_a = cmap_a[uni]
        g_name_b = cmap_b[uni]
        
        h_a = hashes_a.get(g_name_a)
        h_b = hashes_b.get(g_name_b)

        processed_a.add(g_name_a)
        processed_b.add(g_name_b)

        # 名字相同
        if g_name_a == g_name_b:
            if h_a != h_b:
                changed.append(g_name_a)

        # 名字不同 (重命名)
        else:
            if h_a != h_b:
                # 形状也变了 -> 归类为 Modified (改名并修改)
                modified.append((g_name_a, g_name_b))
            else:
                # 形状没变 -> 归类为 Renamed (仅改名)
                renamed.append((g_name_a, g_name_b))

    # --- 2. 处理剩余字形 ---
    # 找出不在上述 Unicode 匹配中出现的字形 (包括 .notdef 或未映射字符)
    remaining_a = glyphs_a - processed_a
    remaining_b = glyphs_b - processed_b

    # 在剩余字形中，寻找形状相同的（可能是没映射 Unicode 的纯改名，或者备用字形）
    used_b_in_rename = set()
    for g_a in remaining_a:
        h_a = hashes_a[g_a]
        # 在 B 的剩余字形中寻找相同 Hash
        match_found = None
        for g_b in remaining_b:
            if g_b in used_b_in_rename: continue
            if hashes_b[g_b] == h_a:
                match_found = g_b
                break
        
        if match_found:
            renamed.append((g_a, match_found))
            used_b_in_rename.add(match_found)
        else:
            # 找不到匹配形状的 -> 列为 Removed
            pass 

    # 最终计算 Added / Removed
    # Renamed 中用过的 B 字形不应出现在 Added 中
    renamed_b_names = {pair[1] for pair in renamed} | {pair[1] for pair in modified}
    renamed_a_names = {pair[0] for pair in renamed} | {pair[0] for pair in modified}

    actual_removed = sorted(list(remaining_a - renamed_a_names))
    actual_added   = sorted(list(remaining_b - renamed_b_names))

    return fa, fb, {
        "added": actual_added,
        "removed": actual_removed,
        "changed": changed,
        "renamed": renamed,
        "modified": modified,
    }


def font_to_base64(path):
    with open(path, "rb") as f:
        return base64.b64encode(f.read()).decode("ascii")


def glyph_to_char(font, glyph_name):
    cmap = font["cmap"].getBestCmap()
    for code, g in cmap.items():
        if g == glyph_name:
            return chr(code)
    return None


def generate_html(font_a_path, font_b_path, fa, fb, diff, out="diff.html"):
    b64_a = font_to_base64(font_a_path)
    b64_b = font_to_base64(font_b_path)

    mime = "font/otf" if font_a_path.lower().endswith(".otf") else "font/ttf"

    html = [
        "<!doctype html>",
        "<html><head><meta charset='utf-8'>",
        "<style>",
        f"""
@font-face {{ font-family: "FontA"; src: url(data:{mime};base64,{b64_a}); }}
@font-face {{ font-family: "FontB"; src: url(data:{mime};base64,{b64_b}); }}

body {{ font-family: sans-serif; padding: 20px; }}
h2 {{ margin-top: 32px; border-bottom: 2px solid #eee; padding-bottom: 8px; clear: both; }}

.section {{
  margin: 12px 0 24px;
  padding: 12px;
  border: 1px solid #ddd;
  border-radius: 6px;
  background: #fcfcfc;
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
}}

.section.modified {{ border-color: #ffcc80; background: #fff8f0; }} /* 橙色 */
.section.renamed {{ border-color: #e6ccff; background: #fdfaff; }}
.section.changed {{ border-color: #f2bcbc; background: #fff0f0; }}
.section.added   {{ border-color: #bde5bd; }}
.section.removed {{ border-color: #ddd; }}

.row {{
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
  margin: 4px;
  width: 110px;
  padding: 8px;
  border-radius: 4px;
}}
.row:hover {{ background: rgba(0,0,0,0.04); }}

.meta {{
  font-size: 10px;
  font-family: monospace;
  color: #555;
  line-height: 1.2;
  text-align: center;
  word-break: break-all;
}}

.glyph {{
  font-size: 80px;
  position: relative;
  line-height: 1;
  height: 80px;
  width: 100%;
  text-align: center;
}}

.old {{ color: rgba(255, 0, 0, 0.6); font-family: "FontA"; position: absolute; left: 0; top: 0; width: 100%; }}
.new {{ color: rgba(0, 0, 255, 0.6); font-family: "FontB"; position: absolute; left: 0; top: 0; width: 100%; }}

.modified .old {{ color: rgba(255, 69, 0, 0.6); }}
.modified .new {{ color: rgba(30, 144, 255, 0.8); z-index: 2; }}

.added {{ color: green; font-family: "FontB"; }}
.removed {{ color: #999; font-family: "FontA"; }}
.renamed-char {{ color: purple; font-family: "FontA"; }}

.tag {{
  display: inline-block;
  font-size: 9px;
  padding: 2px 4px;
  border-radius: 3px;
  font-weight: bold;
  margin-bottom: 4px;
}}
.tag.modified {{ background: #ffe0b2; color: #e65100; }}
.tag.renamed {{ background: #e6ccff; color: #8a2be2; }}
.tag.added   {{ background: #e6ffe6; color: #0a0; }}
.tag.removed {{ background: #f2f2f2; color: #666; }}
.tag.changed {{ background: #ffcdd2; color: #c00; }}
"""
        ,
        "</style></head><body>",
        "<h1>Font Diff</h1>",
        f"<p>Old: {os.path.basename(font_a_path)}<br>"
        f"New: {os.path.basename(font_b_path)}</p>",
    ]

    def render_row(tag, tag_class, glyph_name, char, content_html, sub_info=""):
        name_display = f"<strong>{glyph_name}</strong>"
        if sub_info:
            name_display += f"<br>&#8594;<br><strong>{sub_info}</strong>"
        
        uni_info = f"U+{format(ord(char), '04X')}" if char else ""

        html.append("<div class='row'>")
        html.append(
            "<div class='meta'>"
            f"<span class='tag {tag_class}'>{tag}</span><br>"
            f"{name_display}<br>"
            f"{uni_info}"
            "</div>"
        )
        html.append(content_html)
        html.append("</div>")

    # 1. Modified (Renamed + Changed)
    if diff["modified"]:
        html.append("<h2>Modified (Renamed & Changed)</h2>")
        html.append("<div class='section modified'>")
        for name_a, name_b in diff["modified"]:
            # 这种情况 Unicode 肯定相同，随便取一个
            char = glyph_to_char(fa, name_a)
            if char:
                content = (
                    "<div class='glyph'>"
                    f"<span class='old'>{char}</span>"
                    f"<span class='new'>{char}</span>"
                    "</div>"
                )
                render_row("MODIFIED", "modified", name_a, char, content, sub_info=name_b)
        html.append("</div>")

    # 2. Changed (Name Same, Shape Diff)
    if diff["changed"]:
        html.append("<h2>Changed</h2>")
        html.append("<div class='section changed'>")
        for g in diff["changed"]:
            char = glyph_to_char(fa, g)
            if not char: char = glyph_to_char(fb, g)
            if char:
                content = (
                    "<div class='glyph'>"
                    f"<span class='old'>{char}</span>"
                    f"<span class='new'>{char}</span>"
                    "</div>"
                )
                render_row("CHANGED", "changed", g, char, content)
        html.append("</div>")

    # 3. Renamed (Name Diff, Shape Same)
    if diff["renamed"]:
        html.append("<h2>Renamed (Only)</h2>")
        html.append("<div class='section renamed'>")
        for name_a, name_b in diff["renamed"]:
            char = glyph_to_char(fa, name_a)
            if not char: char = glyph_to_char(fb, name_b)
            if char:
                content = (
                    "<div class='glyph'>"
                    f"<span class='renamed-char'>{char}</span>"
                    "</div>"
                )
                render_row("RENAMED", "renamed", name_a, char, content, sub_info=name_b)
        html.append("</div>")

    # 4. Added
    if diff["added"]:
        html.append("<h2>Added</h2>")
        html.append("<div class='section added'>")
        for g in diff["added"]:
            char = glyph_to_char(fb, g)
            if char:
                content = f"<div class='glyph'><span class='added'>{char}</span></div>"
                render_row("ADDED", "added", g, char, content)
        html.append("</div>")

    # 5. Removed
    if diff["removed"]:
        html.append("<h2>Removed</h2>")
        html.append("<div class='section removed'>")
        for g in diff["removed"]:
            char = glyph_to_char(fa, g)
            if char:
                content = f"<div class='glyph'><span class='removed'>{char}</span></div>"
                render_row("REMOVED", "removed", g, char, content)
        html.append("</div>")

    html.append("</body></html>")

    with open(out, "w", encoding="utf-8") as f:
        f.write("\n".join(html))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Diff two font files and generate an HTML visual report."
    )
    parser.add_argument(
        "old", 
        type=str, 
        help="Path to the old font file (baseline)"
    )
    parser.add_argument(
        "new", 
        type=str, 
        help="Path to the new font file (target)"
    )
    parser.add_argument(
        "-o", "--output", 
        type=str, 
        default="diff.html", 
        help="Output HTML filename (default: diff.html)"
    )

    args = parser.parse_args()

    old_font = args.old
    new_font = args.new

    if not os.path.exists(old_font):
        print(f"Error: Old font file not found: {old_font}")
        exit(1)
    if not os.path.exists(new_font):
        print(f"Error: New font file not found: {new_font}")
        exit(1)

    fa, fb, diff = diff_fonts(old_font, new_font)
    generate_html(old_font, new_font, fa, fb, diff, out=args.output)

    print("Summary:")
    print(f"  Modified (Renamed + Changed): {len(diff['modified'])}")
    print(f"  Changed (Same Name): {len(diff['changed'])}")
    print(f"  Renamed (Same Shape): {len(diff['renamed'])}")
    print(f"  Added: {len(diff['added'])}")
    print(f"  Removed: {len(diff['removed'])}")
    print(f"Output: {args.output}")
