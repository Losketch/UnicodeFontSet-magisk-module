use std::collections::HashMap;

use anyhow::{bail, Context, Result};

const DISCOVERY_CONFIG_TEXT: &str = include_str!("../../../module/config/discovery.conf");

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct DiscoveryConfig {
    pub font_xml_familyset_files: Vec<String>,
    pub font_xml_module_subdirs: Vec<String>,
    pub font_binary_module_subdirs: Vec<String>,
    pub font_xml_baseline_dirs: Vec<String>,
    pub system_font_baseline_dirs: Vec<String>,
    pub system_font_search_dirs: Vec<String>,
    pub updatable_system_font_dir: String,
    pub updatable_config_xml: String,
}

impl DiscoveryConfig {
    pub fn embedded() -> Result<Self> {
        Self::parse(DISCOVERY_CONFIG_TEXT)
    }

    pub fn parse(input: &str) -> Result<Self> {
        let values = parse_assignments(input)?;
        Ok(Self {
            font_xml_familyset_files: words(required(&values, "FONT_XML_FAMILYSET_FILES")?),
            font_xml_module_subdirs: words(required(&values, "FONT_XML_MODULE_SUBDIRS")?),
            font_binary_module_subdirs: words(required(&values, "FONT_BINARY_MODULE_SUBDIRS")?),
            font_xml_baseline_dirs: words(required(&values, "FONT_XML_BASELINE_DIRS")?),
            system_font_baseline_dirs: words(required(&values, "SYSTEM_FONT_BASELINE_DIRS")?),
            system_font_search_dirs: words(required(&values, "SYSTEM_FONT_SEARCH_DIRS")?),
            updatable_system_font_dir: required(&values, "UPDATABLE_SYSTEM_FONT_DIR")?.to_string(),
            updatable_config_xml: required(&values, "UPDATABLE_CONFIG_XML")?.to_string(),
        })
    }
}

fn parse_assignments(input: &str) -> Result<HashMap<String, String>> {
    let mut result = HashMap::new();
    for (line_number, raw_line) in input.lines().enumerate() {
        let line = raw_line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        let Some((key, raw_value)) = line.split_once('=') else {
            bail!("discovery.conf:{}: expected KEY=VALUE", line_number + 1);
        };
        let key = key.trim();
        if key.is_empty() {
            bail!("discovery.conf:{}: empty key", line_number + 1);
        }
        let mut value = raw_value.trim();
        if value.len() >= 2
            && ((value.starts_with('"') && value.ends_with('"'))
                || (value.starts_with('\'') && value.ends_with('\'')))
        {
            value = &value[1..value.len() - 1];
        }
        result.insert(key.to_string(), value.to_string());
    }
    Ok(result)
}

fn required<'a>(values: &'a HashMap<String, String>, key: &str) -> Result<&'a str> {
    values
        .get(key)
        .map(String::as_str)
        .filter(|value| !value.trim().is_empty())
        .with_context(|| format!("missing required discovery config key: {key}"))
}

fn words(value: &str) -> Vec<String> {
    value.split_whitespace().map(str::to_string).collect()
}

#[cfg(test)]
mod tests {
    use super::DiscoveryConfig;

    #[test]
    fn embedded_config_separates_baseline_from_diagnostic_search() {
        let config = DiscoveryConfig::embedded().unwrap();
        assert!(config
            .font_xml_familyset_files
            .iter()
            .any(|f| f == "fonts.xml"));
        assert!(!config
            .font_xml_familyset_files
            .iter()
            .any(|f| f == "fonts_customization.xml"));

        assert!(config
            .system_font_baseline_dirs
            .iter()
            .any(|d| d == "/vendor/fonts"));
        assert!(!config
            .system_font_baseline_dirs
            .iter()
            .any(|d| d == "/product/fonts" || d == "/system/product/fonts"));
        assert!(config
            .system_font_search_dirs
            .iter()
            .any(|d| d == "/product/fonts"));
    }
}
