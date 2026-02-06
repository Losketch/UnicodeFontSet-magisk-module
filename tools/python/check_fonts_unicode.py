#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
检查多个字体是否覆盖了 UnicodeData.txt 中的所有 Unicode 码位，
如有缺失则打印缺失码位（单个或区间）及其名称（如有）。
python check_fonts_unicode.py UnicodeData.txt font1.ttf font2.otf
"""

import sys
import glob
import argparse
from fontTools.ttLib import TTFont

EXCLUDED_CATEGORIES = {'Cs', 'Co', 'Cn'}

def parse_unicode_data(ud_path):
    """
    解析 UnicodeData.txt，返回：
     - full_cp_set: 展开并剔除 Cs/Co/Cn 分类后的 Unicode 码点 set(int)
     - cp_to_name: 所有非区间单点码位的名称 dict(int->str)
    """
    full = set()
    names = {}
    range_start = None

    with open(ud_path, encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            parts = line.split(';')
            cp = int(parts[0], 16)
            name = parts[1]
            category = parts[2]

            if category in EXCLUDED_CATEGORIES:
                continue

            if name.endswith('First>'):
                range_start = cp
            elif name.endswith('Last>') and range_start is not None:
                for c in range(range_start, cp + 1):
                    if c not in EXCLUDED_CATEGORIES:
                        full.add(c)
                range_start = None
            else:
                full.add(cp)
                names[cp] = name

    return full, names

def get_font_codepoints(font_path):
    """
    读取一个字体的 cmap，返回该字体支持的 Unicode 码点 set(int)。
    """
    tt = TTFont(font_path, recalcBBoxes=False, recalcTimestamp=False)
    cps = set()
    for table in tt['cmap'].tables:
        cps.update(table.cmap.keys())
    return cps

def summarize_ranges(sorted_cps):
    """
    将已排序的码点列表压缩为区间列表 [(start,end),...]
    """
    if not sorted_cps:
        return []
    ranges = []
    start = prev = sorted_cps[0]
    for c in sorted_cps[1:]:
        if c == prev + 1:
            prev = c
        else:
            ranges.append((start, prev))
            start = prev = c
    ranges.append((start, prev))
    return ranges

def main():
    p = argparse.ArgumentParser(
        description="检查多个字体联合后的 Unicode 覆盖率（跳过代理/私用区）"
    )
    p.add_argument('unicodedata', help='UnicodeData.txt 的路径')
    p.add_argument('fonts', nargs='+', help='要联合检查的 TTF/OTF 字体文件')
    args = p.parse_args()

    font_files = []
    for pat in args.fonts:
        matches = glob.glob(pat)
        if matches:
            font_files.extend(matches)
        else:
            font_files.append(pat)

    if not font_files:
        print("⚠️ 未找到任何字体文件")
        sys.exit(1)

    print("1) 解析 UnicodeData.txt …")
    full_set, cp_to_name = parse_unicode_data(args.unicodedata)
    print(f"   → 总计需覆盖 {len(full_set)} 个码点（已剔除 Cs/Co/Cn 分类）\n")

    # 2) 联合读取所有字体的 codepoints
    union_cps = set()
    for fp in font_files:
        try:
            cps = get_font_codepoints(fp)
            union_cps |= cps
            print(f"   已从 {fp} 读取 {len(cps)} 个 codepoint")
        except Exception as e:
            print(f"   ⚠️ 读取字体 {fp} 失败：{e}")
    print(f"\n   字体联合后共支持 {len(union_cps)} 个码点\n")

    # 3) 计算缺失
    missing = sorted(full_set - union_cps)
    if not missing:
        print("✅ 联合覆盖了全部目标 Unicode 码点！")
        sys.exit(0)

    print(f"❌ 缺少 {len(missing)} 个码点：")
    for start, end in summarize_ranges(missing):
        if start == end:
            name = cp_to_name.get(start, '')
            print(f"  U+{start:04X}    {name}")
        else:
            print(f"  U+{start:04X}--U+{end:04X}")
    sys.exit(1)

if __name__ == '__main__':
    main()