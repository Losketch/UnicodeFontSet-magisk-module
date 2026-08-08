use anyhow::{bail, Context, Result};

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct CodepointRange {
    pub start: u32,
    pub end: u32,
}

#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub enum CodepointSet {
    #[default]
    None,
    All,
    Ranges(Vec<CodepointRange>),
}

impl CodepointSet {
    pub fn parse(input: &str) -> Result<Self> {
        let mut text = input.trim();
        if text == "-" || text.is_empty() {
            return Ok(Self::None);
        }
        if text == "*" {
            return Ok(Self::All);
        }
        if text.starts_with('[') || text.ends_with(']') {
            if !(text.starts_with('[') && text.ends_with(']')) {
                bail!("Unicode range 列表方括号不匹配: {input}");
            }
            text = text[1..text.len() - 1].trim();
            if text.is_empty() {
                bail!("Unicode range 列表不能为空: {input}");
            }
        }

        let mut ranges = Vec::new();
        for raw_item in text.split(',') {
            let item = raw_item.trim();
            if item.is_empty() {
                bail!("Unicode range 列表包含空项目: {input}");
            }

            let range = if let Some((start, end)) = item.split_once('-') {
                if end.contains('-') {
                    bail!("Unicode range 格式错误: {item}");
                }
                let start = parse_scalar(start)?;
                let end = parse_scalar(end)?;
                if start > end {
                    bail!("Unicode range 逆序: {item}");
                }
                if intersects_surrogates(start, end) {
                    bail!("Unicode range 与 surrogate 区间 U+D800-U+DFFF 相交: {item}");
                }
                CodepointRange { start, end }
            } else {
                let codepoint = parse_scalar(item)?;
                CodepointRange {
                    start: codepoint,
                    end: codepoint,
                }
            };
            ranges.push(range);
        }

        ranges.sort_unstable_by_key(|range| (range.start, range.end));
        let mut merged: Vec<CodepointRange> = Vec::with_capacity(ranges.len());
        for range in ranges {
            if let Some(last) = merged.last_mut() {
                if range.start <= last.end.saturating_add(1) {
                    last.end = last.end.max(range.end);
                    continue;
                }
            }
            merged.push(range);
        }

        Ok(Self::Ranges(merged))
    }

    pub fn contains(&self, codepoint: u32) -> bool {
        match self {
            Self::None => false,
            Self::All => char::from_u32(codepoint).is_some(),
            Self::Ranges(ranges) => {
                let index = ranges.partition_point(|range| range.end < codepoint);
                ranges
                    .get(index)
                    .is_some_and(|range| range.start <= codepoint && codepoint <= range.end)
            }
        }
    }

    pub fn is_none(&self) -> bool {
        matches!(self, Self::None)
    }
}

fn parse_scalar(input: &str) -> Result<u32> {
    let trimmed = input.trim();
    let hex = trimmed
        .strip_prefix("U+")
        .or_else(|| trimmed.strip_prefix("u+"))
        .unwrap_or(trimmed);
    if hex.is_empty() {
        bail!("空 Unicode 码位");
    }
    let codepoint =
        u32::from_str_radix(hex, 16).with_context(|| format!("无效的 Unicode 码位: {input}"))?;
    if char::from_u32(codepoint).is_none() {
        bail!("不是有效的 Unicode 标量值: U+{codepoint:X}");
    }
    Ok(codepoint)
}

fn intersects_surrogates(start: u32, end: u32) -> bool {
    start <= 0xDFFF && end >= 0xD800
}

#[cfg(test)]
mod tests {
    use super::{CodepointRange, CodepointSet};

    #[test]
    fn parses_bracketed_ranges_and_points() {
        let set = CodepointSet::parse("[ff-4e02,1df02,30ede]").unwrap();
        assert!(set.contains(0xFF));
        assert!(set.contains(0x4E02));
        assert!(set.contains(0x1DF02));
        assert!(set.contains(0x30EDE));
        assert!(!set.contains(0x4E03));
    }

    #[test]
    fn accepts_u_plus_and_merges_overlaps() {
        let set = CodepointSet::parse("U+0041-U+0050,0048-0060,0061").unwrap();
        assert_eq!(
            set,
            CodepointSet::Ranges(vec![CodepointRange {
                start: 0x41,
                end: 0x61,
            }])
        );
    }

    #[test]
    fn supports_all_and_none() {
        assert_eq!(CodepointSet::parse("-").unwrap(), CodepointSet::None);
        assert!(CodepointSet::parse("*").unwrap().contains(0x10FFFF));
    }

    #[test]
    fn rejects_invalid_or_surrogate_ranges() {
        assert!(CodepointSet::parse("4E02-00FF").is_err());
        assert!(CodepointSet::parse("D7FF-E000").is_err());
        assert!(CodepointSet::parse("110000").is_err());
        assert!(CodepointSet::parse("GGGG").is_err());
        assert!(CodepointSet::parse("[]").is_err());
    }
}
