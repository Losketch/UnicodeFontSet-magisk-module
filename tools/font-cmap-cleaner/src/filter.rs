use std::collections::HashSet;

use crate::policy::{FontPolicyEntry, FontRole};

/// 根据前序覆盖范围与 protect/remove 策略计算最终保留映射。
pub fn compute_keep(
    all_chars: &HashSet<u32>,
    baseline: &HashSet<u32>,
    variation_bases: &HashSet<u32>,
    entry: &FontPolicyEntry,
) -> HashSet<u32> {
    all_chars
        .iter()
        .copied()
        .filter(|codepoint| {
            let retained_by_role = match entry.role {
                FontRole::NormalFallback | FontRole::TerminalFallback => {
                    !baseline.contains(codepoint)
                        || variation_bases.contains(codepoint)
                        || entry.protect.contains(*codepoint)
                }
                FontRole::SystemOverlay => true,
            };

            retained_by_role && !entry.remove.contains(*codepoint)
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use std::collections::HashSet;

    use crate::{
        filter::compute_keep,
        policy::{FontPolicyEntry, FontRole},
        ranges::CodepointSet,
    };

    fn set(values: &[u32]) -> HashSet<u32> {
        values.iter().copied().collect()
    }

    #[test]
    fn normal_fallback_protects_selected_duplicates() {
        let entry = FontPolicyEntry {
            role: FontRole::NormalFallback,
            filename: "A.ttf".into(),
            protect: CodepointSet::parse("41,43").unwrap(),
            remove: CodepointSet::None,
        };

        let keep = compute_keep(
            &set(&[0x41, 0x42, 0x43]),
            &set(&[0x41, 0x42]),
            &set(&[]),
            &entry,
        );

        assert_eq!(keep, set(&[0x41, 0x43]));
    }

    #[test]
    fn terminal_fallback_is_deduplicated_against_preceding_coverage() {
        let entry = FontPolicyEntry {
            role: FontRole::TerminalFallback,
            filename: "LastResort.ttf".into(),
            protect: CodepointSet::None,
            remove: CodepointSet::None,
        };

        let keep = compute_keep(
            &set(&[0x41, 0x42, 0x1F600, 0x10FFFF]),
            &set(&[0x41, 0x42, 0x1F600]),
            &set(&[]),
            &entry,
        );

        assert_eq!(keep, set(&[0x10FFFF]));
    }

    #[test]
    fn terminal_fallback_protect_can_override_ordered_dedup() {
        let entry = FontPolicyEntry {
            role: FontRole::TerminalFallback,
            filename: "LastResort.ttf".into(),
            protect: CodepointSet::parse("1F600").unwrap(),
            remove: CodepointSet::None,
        };

        let keep = compute_keep(
            &set(&[0x1F600, 0x10FFFF]),
            &set(&[0x1F600]),
            &set(&[]),
            &entry,
        );

        assert_eq!(keep, set(&[0x1F600, 0x10FFFF]));
    }

    #[test]
    fn remove_wins_over_protect_and_uvs_dependency() {
        let entry = FontPolicyEntry {
            role: FontRole::NormalFallback,
            filename: "A.ttf".into(),
            protect: CodepointSet::All,
            remove: CodepointSet::parse("42-43").unwrap(),
        };

        let keep = compute_keep(
            &set(&[0x41, 0x42, 0x43]),
            &set(&[0x41, 0x42, 0x43]),
            &set(&[0x43]),
            &entry,
        );

        assert_eq!(keep, set(&[0x41]));
    }

    #[test]
    fn system_overlay_preserves_by_default_but_can_be_range_filtered() {
        let entry = FontPolicyEntry {
            role: FontRole::SystemOverlay,
            filename: "Overlay.ttf".into(),
            protect: CodepointSet::All,
            remove: CodepointSet::parse("42").unwrap(),
        };

        let keep = compute_keep(&set(&[0x41, 0x42]), &set(&[0x41]), &set(&[]), &entry);

        assert_eq!(keep, set(&[0x41]));
    }
}
