# -*- coding: utf-8 -*-

import os
import re
import argparse
from fontTools.ttLib import TTFont
import xml.etree.ElementTree as ET
from xml.dom import minidom

def parse_blocks_file(blocks_file_path):
    """解析Unicode Blocks.txt文件"""
    blocks = []
    with open(blocks_file_path, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#'):
                match = re.match(r'([0-9A-F]+)\.\.([0-9A-F]+);\s*(.*)', line)
                if match:
                    start_hex, end_hex, name = match.groups()
                    start = int(start_hex, 16)
                    end = int(end_hex, 16)
                    blocks.append((start, end, name))
    return blocks

def parse_unicode_data_file(unicode_data_path):
    """解析UnicodeData.txt文件，处理 First/Last 范围，并忽略<control>字符"""
    defined_chars = set()
    control_chars = set()
    lines = []
    with open(unicode_data_path, 'r', encoding='utf-8') as f:
        lines = [l.strip() for l in f if l.strip()]
    i = 0
    while i < len(lines):
        parts = lines[i].split(';')
        code_point = int(parts[0], 16)
        name = parts[1]
        # 处理扩展区块的 First/Last 范围
        if name.endswith(', First>'):
            prefix = name[1:-1].rsplit(', First', 1)[0]
            # 查找下一个 Last
            if i + 1 < len(lines):
                next_parts = lines[i+1].split(';')
                next_name = next_parts[1]
                if next_name.endswith(', Last>') and prefix in next_name:
                    end_cp = int(next_parts[0], 16)
                    # 将整个范围加入
                    for cp in range(code_point, end_cp + 1):
                        defined_chars.add(cp)
                    i += 2
                    continue
        # 常规单字符处理
        if name.startswith('<control>'):
            control_chars.add(code_point)
        defined_chars.add(code_point)
        i += 1
    return defined_chars, control_chars

def get_font_supported_chars(font_path):
    """获取字体支持的字符码位"""
    font = TTFont(font_path)
    cmap = font.getBestCmap()
    return set(cmap.keys())

def create_block_stats(blocks, supported_chars, defined_chars, control_chars):
    """为每个Unicode区块创建统计信息"""
    block_stats = []
    for start, end, name in blocks:
        defined_non_control = sum(1 for cp in range(start, end + 1)
                                   if cp in defined_chars and cp not in control_chars)
        supported_non_control = sum(1 for cp in range(start, end + 1)
                                     if cp in supported_chars and cp not in control_chars)
        undefined_supported = sum(1 for cp in range(start, end + 1)
                                   if cp in supported_chars and cp not in defined_chars)
        if supported_non_control > 0:
            block_stats.append({
                'start': start,
                'end': end,
                'name': name,
                'defined_non_control': defined_non_control,
                'supported_non_control': supported_non_control,
                'undefined_supported': undefined_supported
            })
    return block_stats

def get_gradient_colors(coverage):
    """根据覆盖率获取渐变色和对应文字色"""
    if coverage >= 0.9:
        return ('var(--md-sys-color-primary)',
                'var(--md-sys-color-primary-container)',
                'var(--md-sys-color-on-primary)')
    elif coverage >= 0.5:
        return ('var(--md-sys-color-secondary)',
                'var(--md-sys-color-secondary-container)',
                'var(--md-sys-color-on-secondary)')
    else:
        return ('var(--md-sys-color-tertiary)',
                'var(--md-sys-color-tertiary-container)',
                'var(--md-sys-color-on-tertiary-container)')

def create_svg(block_stats, font_name, output_path):
    """创建Material Dark模式风格的SVG表格，使用foreignObject和HTML表格"""
    svg_width = 650
    row_height = 25
    header_height = 110
    title_height = 0
    footer_padding = 51
    total_rows = len(block_stats)
    svg_height = title_height + header_height + total_rows * row_height + footer_padding

    svg = ET.Element('svg', {
        'width': str(svg_width),
        'height': str(svg_height),
        'xmlns': 'http://www.w3.org/2000/svg',
        'viewBox': f'0 0 {svg_width} {svg_height}',
        'overflow': 'visible'
    })

    style = ET.SubElement(svg, 'style')
    style.text = """
    :root {
        --md-sys-color-primary: #D0BCFF;
        --md-sys-color-on-primary: #371E73;
        --md-sys-color-primary-container: #4F378B;
        --md-sys-color-secondary: #CCC2DC;
        --md-sys-color-on-secondary: #332D41;
        --md-sys-color-secondary-container: #4A4458;
        --md-sys-color-tertiary: #EFB8C8;
        --md-sys-color-tertiary-container: #633B48;
        --md-sys-color-on-tertiary-container: #FFD8E4;
        --md-sys-color-background: #121212;
        --md-sys-color-surface: #1E1E1E;
        --md-sys-color-on-surface: #E0E0E0;
        --md-sys-color-surface-variant: #2C2C2C;
        --md-sys-color-on-surface-variant: #CAC4D0;
        --md-sys-color-outline: #49454E;
        background: var(--md-sys-color-background);
    }
    body {
        font-family: 'Roboto', 'Google Sans', sans-serif;
        color: var(--md-sys-color-on-surface);
        background-color: var(--md-sys-color-background);
        margin: 0;
        padding: 0;
        font-size: 14px;
    }
    .header {
        padding: 18px;
        background-color: var(--md-sys-color-surface);
        border-radius: 16px 16px 0 0;
        box-shadow: 0 1px 2px rgba(0,0,0,0.5);
        margin-bottom: 4px;
    }
    h2 {
        margin: 0;
        font-size: 22px;
        font-weight: 400;
        color: var(--md-sys-color-on-surface);
    }
    .subtitle {
        margin: 4px 0 0;
        font-size: 14px;
        color: var(--md-sys-color-on-surface-variant);
    }
    table {
        width: 100%;
        border-collapse: collapse;
        border-radius: 0 0 16px 16px;
        overflow: hidden;
    }
    th {
        padding: 10px 16px;
        font-weight: 900;
        text-align: left;
        background-color: var(--md-sys-color-primary);
        color: var(--md-sys-color-on-primary);
        border-bottom: 1px solid var(--md-sys-color-outline);
    }
    td {
        padding: 2px 16px;
        font-family: 'Roboto Mono', monospace;
    }
    tr:nth-child(even) {
        background-color: var(--md-sys-color-surface-variant);
    }
    tr:hover {
        background-color: rgba(255,255,255,0.05);
    }
    .coverage-cell {
        position: relative;
        font-weight: 500;
        border-top: 1px solid var(--md-sys-color-outline);
        text-align: center;
    }
    """

    foreign = ET.SubElement(svg, 'foreignObject', {
        'width': str(svg_width),
        'height': str(svg_height),
        'x': '0',
        'y': '0',
        'style': 'overflow: visible;'
    })

    body = ET.SubElement(foreign, 'body', {
        'xmlns': 'http://www.w3.org/1999/xhtml'
    })

    header_div = ET.SubElement(body, 'div', {'class': 'header'})
    title = ET.SubElement(header_div, 'h2')
    title.text = f'Unicode Block Coverage: {font_name}'
    subtitle = ET.SubElement(header_div, 'p', {'class': 'subtitle'})
    total_supported = sum(b['supported_non_control'] for b in block_stats)
    subtitle.text = f'Total supported glyphs: {total_supported}'

    table = ET.SubElement(body, 'table')
    thead = ET.SubElement(table, 'thead')
    header_row = ET.SubElement(thead, 'tr')
    for txt in ['Block Range', 'Block Name', 'Coverage']:
        th = ET.SubElement(header_row, 'th')
        th.text = txt

    tbody = ET.SubElement(table, 'tbody')
    block_stats.sort(key=lambda x: x['start'])

    for block in block_stats:
        tr = ET.SubElement(tbody, 'tr')
        ET.SubElement(tr, 'td').text = f'{block["start"]:04X}..{block["end"]:04X}'
        ET.SubElement(tr, 'td').text = block["name"]

        defined_cnt = block["defined_non_control"]
        supported_cnt = block["supported_non_control"]
        undef_cnt = block["undefined_supported"]
        actual_defined_supported = supported_cnt - undef_cnt
        pct = (supported_cnt / defined_cnt * 100) if defined_cnt else 0.0

        c1, c2, text_color = get_gradient_colors(pct / 100)
        coverage_td = ET.SubElement(tr, 'td', {
            'class': 'coverage-cell',
            'style': (
                f"background: linear-gradient(to right, {c1} {pct:.1f}%, {c2} {pct:.1f}%);"
                f"color: {text_color};"
            )
        })

        if undef_cnt > 0:
            # 例如 "135(+9!)/135"
            coverage_td.text = f'{actual_defined_supported}(+{undef_cnt}!)/{defined_cnt}'
        else:
            coverage_td.text = f'{supported_cnt}/{defined_cnt}'

    # 输出
    rough = ET.tostring(svg, 'utf-8')
    pretty = minidom.parseString(rough).toprettyxml(indent="  ")
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(pretty)

    print(f"SVG生成成功：{output_path}，共 {total_rows} 行，高度 {svg_height}")

def main():
    parser = argparse.ArgumentParser(description='生成字体Unicode支持情况的SVG图表')
    parser.add_argument('font_paths', nargs='+', help='字体文件路径（支持多个）')
    parser.add_argument('--blocks', required=True, help='Unicode Blocks.txt 文件')
    parser.add_argument('--unicode-data', required=True, help='UnicodeData.txt 文件')
    parser.add_argument('--output-dir', default='.', help='输出目录')
    args = parser.parse_args()

    blocks = parse_blocks_file(args.blocks)
    defined_chars, control_chars = parse_unicode_data_file(args.unicode_data)

    os.makedirs(args.output_dir, exist_ok=True)
    for fp in args.font_paths:
        try:
            font_name = os.path.basename(fp)
            supported = get_font_supported_chars(fp)
            stats = create_block_stats(blocks, supported, defined_chars, control_chars)
            out_svg = os.path.join(args.output_dir,
                                   f"{os.path.splitext(font_name)[0]}_unicode_coverage.svg")
            create_svg(stats, font_name, out_svg)
        except Exception as e:
            print(f"处理字体 {fp} 时出错: {e}")

if __name__ == '__main__':
    main()