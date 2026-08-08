use std::{collections::HashMap, fs, path::Path};

use anyhow::{bail, Context, Result};

use crate::ranges::CodepointSet;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum FontRole {
    SystemOverlay,
    NormalFallback,
    TerminalFallback,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct FontPolicyEntry {
    pub role: FontRole,
    pub filename: String,
    pub protect: CodepointSet,
    pub remove: CodepointSet,
}

#[derive(Clone, Debug, Default)]
pub struct FontPolicy {
    entries: Vec<FontPolicyEntry>,
    by_name: HashMap<String, usize>,
}

impl FontPolicy {
    pub fn load(path: &Path) -> Result<Self> {
        let text = fs::read_to_string(path)
            .with_context(|| format!("读取字体策略配置失败: {}", path.display()))?;
        Self::parse(&text)
    }

    pub fn parse(text: &str) -> Result<Self> {
        let mut entries = Vec::new();
        let mut by_name = HashMap::new();

        for (line_number, raw_line) in text.lines().enumerate() {
            let line = raw_line.trim();
            if line.is_empty() || line.starts_with('#') {
                continue;
            }

            let fields: Vec<&str> = line.split('\t').map(str::trim).collect();
            if fields.len() != 4
                || fields[1].is_empty()
                || fields[2].is_empty()
                || fields[3].is_empty()
            {
                bail!(
                    "font-policy.tsv:{}: 需要 4 列：role<TAB>filename<TAB>protect<TAB>remove",
                    line_number + 1
                );
            }

            let role = match fields[0] {
                "system-overlay" => FontRole::SystemOverlay,
                "normal-fallback" => FontRole::NormalFallback,
                "terminal-fallback" => FontRole::TerminalFallback,
                other => bail!("font-policy.tsv:{}: 未知字体角色 {other}", line_number + 1),
            };
            let filename = fields[1].to_string();
            let protect = CodepointSet::parse(fields[2]).with_context(|| {
                format!(
                    "font-policy.tsv:{}: {filename} 的 protect 范围无效",
                    line_number + 1
                )
            })?;
            let remove = CodepointSet::parse(fields[3]).with_context(|| {
                format!(
                    "font-policy.tsv:{}: {filename} 的 remove 范围无效",
                    line_number + 1
                )
            })?;

            if by_name.insert(filename.clone(), entries.len()).is_some() {
                bail!(
                    "font-policy.tsv:{}: 字体 {filename} 被重复配置",
                    line_number + 1
                );
            }
            entries.push(FontPolicyEntry {
                role,
                filename,
                protect,
                remove,
            });
        }

        if entries.is_empty() {
            bail!("font-policy.tsv 中没有有效字体配置");
        }

        Ok(Self { entries, by_name })
    }

    pub fn entries(&self) -> &[FontPolicyEntry] {
        &self.entries
    }

    pub fn entry(&self, filename: &str) -> Option<&FontPolicyEntry> {
        self.by_name
            .get(filename)
            .and_then(|index| self.entries.get(*index))
    }

    pub fn role(&self, filename: &str) -> Option<FontRole> {
        self.entry(filename).map(|entry| entry.role)
    }

    pub fn entries_for(&self, role: FontRole) -> impl Iterator<Item = &FontPolicyEntry> {
        self.entries.iter().filter(move |entry| entry.role == role)
    }

    pub fn filenames_for(&self, role: FontRole) -> impl Iterator<Item = &str> {
        self.entries_for(role).map(|entry| entry.filename.as_str())
    }
}

#[cfg(test)]
mod tests {
    use super::{FontPolicy, FontRole};

    #[test]
    fn parses_ordered_roles_and_range_policies() {
        let policy = FontPolicy::parse(
            "system-overlay\tOverlay.ttf\t*\t-\nnormal-fallback\tA.ttf\t[ff-4e02,1df02]\t30ede\nnormal-fallback\tB.ttf\t-\t-\nterminal-fallback\tLast.ttf\t*\t-\n",
        )
        .unwrap();
        assert_eq!(policy.role("Overlay.ttf"), Some(FontRole::SystemOverlay));
        assert_eq!(
            policy
                .filenames_for(FontRole::NormalFallback)
                .collect::<Vec<_>>(),
            vec!["A.ttf", "B.ttf"]
        );
        let a = policy.entry("A.ttf").unwrap();
        assert!(a.protect.contains(0xFF));
        assert!(a.protect.contains(0x1DF02));
        assert!(a.remove.contains(0x30EDE));
    }

    #[test]
    fn rejects_old_or_ambiguous_policy_rows() {
        assert!(FontPolicy::parse("normal-fallback\tA.ttf\n").is_err());
        assert!(FontPolicy::parse("normal-fallback\tA.ttf\t-\tD800\n").is_err());
    }
}
