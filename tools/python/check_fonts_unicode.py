#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import os
import glob
import argparse
from fontTools.ttLib import TTFont

EXCLUDED_CATEGORIES = {'Cs', 'Co', 'Cn'}

LANG = 'en'

MESSAGES = {
    'en': {
        'parsing_unicodedata': '1) Parsing UnicodeData.txt ...',
        'total_codepoints': '   → Total codepoints to cover: {} (excluded Cs/Co/Cn categories)',
        'reading_font': '   Read {} codepoints from {}',
        'font_read_failed': '   ⚠️ Failed to read font {}: {}',
        'union_codepoints': '   Union of fonts supports {} codepoints',
        'full_coverage': '✅ All target Unicode codepoints are covered!',
        'missing_codepoints': '❌ Missing {} codepoints:',
        'no_fonts': '⚠️ No font files found',
        'arg_unicodedata': 'Path to UnicodeData.txt',
        'arg_fonts': 'TTF/OTF font files to check',
        'arg_lang': 'Language for output (en/zh), default follows LANG env',
        'desc': 'Check Unicode coverage of multiple fonts (skip surrogate/private-use)',
    },
    'zh': {
        'parsing_unicodedata': '1) 解析 UnicodeData.txt ...',
        'total_codepoints': '   → 需覆盖码点总计：{} 个（已剔除 Cs/Co/Cn 分类）',
        'reading_font': '   已从 {} 读取 {} 个码点',
        'font_read_failed': '   ⚠️ 读取字体 {} 失败：{}',
        'union_codepoints': '   字体联合后共支持 {} 个码点',
        'full_coverage': '✅ 联合覆盖了全部目标 Unicode 码点！',
        'missing_codepoints': '❌ 缺少 {} 个码点：',
        'no_fonts': '⚠️ 未找到任何字体文件',
        'arg_unicodedata': 'UnicodeData.txt 的路径',
        'arg_fonts': '要联合检查的 TTF/OTF 字体文件',
        'arg_lang': '输出语言 (en/zh)，默认跟随 LANG 环境变量',
        'desc': '检查多个字体联合后的 Unicode 覆盖率（跳过代理/私用区）',
    }
}

def t(key, *args):
    msg = MESSAGES.get(LANG, MESSAGES['en']).get(key, MESSAGES['en'].get(key, key))
    if args:
        return msg.format(*args)
    return msg

def detect_language():
    lang_env = os.environ.get('LANG', '').lower()
    if lang_env.startswith('zh') or lang_env.startswith('chinese'):
        return 'zh'
    return 'en'

def parse_unicode_data(ud_path):
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
    tt = TTFont(font_path, recalcBBoxes=False, recalcTimestamp=False)
    cps = set()
    for table in tt['cmap'].tables:
        cps.update(table.cmap.keys())
    return cps

def summarize_ranges(sorted_cps):
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

def preparse_lang():
    lang = detect_language()
    i = 1
    while i < len(sys.argv):
        if sys.argv[i] == '--lang' and i + 1 < len(sys.argv):
            lang = sys.argv[i + 1]
            break
        elif sys.argv[i].startswith('--lang='):
            lang = sys.argv[i].split('=', 1)[1]
            break
        i += 1
    return lang

def create_parser():
    p = argparse.ArgumentParser(description=t('desc'))
    p.add_argument('unicodedata', help=t('arg_unicodedata'))
    p.add_argument('fonts', nargs='+', help=t('arg_fonts'))
    p.add_argument('--lang', choices=['en', 'zh'], default=LANG,
                   help=t('arg_lang'))
    return p

def main():
    global LANG

    LANG = preparse_lang()

    p = create_parser()
    args = p.parse_args()

    LANG = args.lang

    font_files = []
    for pat in args.fonts:
        matches = glob.glob(pat)
        if matches:
            font_files.extend(matches)
        else:
            font_files.append(pat)

    if not font_files:
        print(t('no_fonts'))
        sys.exit(1)

    print(t('parsing_unicodedata'))
    full_set, cp_to_name = parse_unicode_data(args.unicodedata)
    print(t('total_codepoints', len(full_set)))
    print()

    union_cps = set()
    for fp in font_files:
        try:
            cps = get_font_codepoints(fp)
            union_cps |= cps
            if LANG == 'zh':
                print(t('reading_font', len(cps), fp))
            else:
                print(t('reading_font', fp, len(cps)))
        except Exception as e:
            print(t('font_read_failed', fp, e))
    print()
    print(t('union_codepoints', len(union_cps)))
    print()

    missing = sorted(full_set - union_cps)
    if not missing:
        print(t('full_coverage'))
        sys.exit(0)

    print(t('missing_codepoints', len(missing)))
    for start, end in summarize_ranges(missing):
        if start == end:
            name = cp_to_name.get(start, '')
            print(f"  U+{start:04X}    {name}")
        else:
            print(f"  U+{start:04X}--U+{end:04X}")
    sys.exit(1)

if __name__ == '__main__':
    main()
