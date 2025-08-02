#! /bin/bash
set -euo pipefail

cd "$(dirname "$0")"

if [[ ! -d "fonts" ]]; then
  echo "❌ 错误: fonts/ 目录未找到。"
  exit 1
fi

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

echo "🔄 转换字体文件 → .otd..."
for font in fonts/*.{ttf,otf}; do
  [[ -e "$font" ]] || continue
  base=$(basename "$font" | sed 's/\.$ttf\|otf$$//')
  out="$workdir/${base}.otd"
  echo "  ➡️ $font → $out"
  if ! ./otfccdump --ignore-hints "$font" -o "$out"; then
    echo "⚠️ 警告: otfccdump 处理 $font 失败，已跳过。" >&2
    continue
  fi
done

echo "🔍 收集 .otd 文件并按大小排序（从大到小）..."
mapfile -t otd_files < <(ls -1S "$workdir"/*.otd)

if [[ ${#otd_files[@]} -eq 0 ]]; then
  echo "😔 未找到 .otd 文件。退出"
  exit 1
fi

echo "🔗 合并 .otd 文件到 notosanssuper.otd..."
./merge-otd \
  -o notosanssuper.otd \
  -n "Noto Sans Super;400;5;Normal" \
  "${otd_files[@]}"

echo "🔨 构建最终的 OpenType 字体 NotoSansSuper.otf..."
./otfccbuild notosanssuper.otd -O1 -o NotoSansSuper.otf

echo "🧹 正在清理中间的 .otd 文件..."
rm -f notosanssuper.otd

echo "🎉 完成。输出: NotoSansSuper.otf"
