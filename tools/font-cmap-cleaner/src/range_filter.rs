use std::collections::HashSet;

use crate::ranges::CodepointSet;

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct RangeFilterPlan {
    pub keep: HashSet<u32>,
    pub removed: usize,
}

pub fn plan_filter(
    all_chars: &HashSet<u32>,
    keep_filter: Option<&CodepointSet>,
    remove_filter: &CodepointSet,
) -> RangeFilterPlan {
    let keep: HashSet<u32> = all_chars
        .iter()
        .copied()
        .filter(|codepoint| {
            let included = keep_filter.is_none_or(|set| set.contains(*codepoint));
            included && !remove_filter.contains(*codepoint)
        })
        .collect();

    RangeFilterPlan {
        removed: all_chars.len().saturating_sub(keep.len()),
        keep,
    }
}

#[cfg(test)]
mod tests {
    use std::collections::HashSet;

    use super::plan_filter;
    use crate::ranges::CodepointSet;

    #[test]
    fn remove_only_removes_requested_codepoints() {
        let all = HashSet::from([0x41, 0x42, 0x43, 0x1F600]);
        let remove = CodepointSet::parse("[41,43,1F600]").unwrap();
        let plan = plan_filter(&all, None, &remove);

        assert_eq!(plan.keep, HashSet::from([0x42]));
        assert_eq!(plan.removed, 3);
    }

    #[test]
    fn keep_only_intersects_with_requested_codepoints() {
        let all = HashSet::from([0x41, 0x42, 0x43, 0x44]);
        let keep = CodepointSet::parse("[41-43]").unwrap();
        let plan = plan_filter(&all, Some(&keep), &CodepointSet::None);

        assert_eq!(plan.keep, HashSet::from([0x41, 0x42, 0x43]));
        assert_eq!(plan.removed, 1);
    }

    #[test]
    fn remove_wins_after_keep_filter() {
        let all = HashSet::from([0x41, 0x42, 0x43, 0x44]);
        let keep = CodepointSet::parse("[41-44]").unwrap();
        let remove = CodepointSet::parse("[42,44]").unwrap();
        let plan = plan_filter(&all, Some(&keep), &remove);

        assert_eq!(plan.keep, HashSet::from([0x41, 0x43]));
        assert_eq!(plan.removed, 2);
    }

    #[test]
    fn keep_range_with_no_matches_produces_empty_result() {
        let all = HashSet::from([0x41, 0x42]);
        let keep = CodepointSet::parse("E000-F8FF").unwrap();
        let plan = plan_filter(&all, Some(&keep), &CodepointSet::None);

        assert!(plan.keep.is_empty());
        assert_eq!(plan.removed, 2);
    }
}
