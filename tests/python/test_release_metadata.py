import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/python"))

import release_metadata as rm


class ReleaseMetadataTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.config = rm.load_config(ROOT / "release.toml")

    def test_variant_api_is_generated_into_module_prop(self):
        cbdt = rm.render_module_prop(self.config, "cbdt", "build")
        colrv1 = rm.render_module_prop(self.config, "colrv1", "build")
        self.assertIn("minApi=26\n", cbdt)
        self.assertIn("minApi=33\n", colrv1)
        self.assertIn("buildState=built\n", cbdt)
        self.assertIn("buildState=built\n", colrv1)

    def test_prerelease_build_has_no_stable_update_channel(self):
        if rm.is_prerelease(self.config["release"]["framework_version"]):
            text = rm.render_module_prop(self.config, "cbdt", "release")
            self.assertIn("updateJson=\n", text)

    def test_repository_module_prop_is_source_placeholder(self):
        prop = {}
        for raw in (ROOT / "module/module.prop").read_text(encoding="utf-8").splitlines():
            if "=" in raw:
                key, value = raw.split("=", 1)
                prop[key] = value

        self.assertEqual(prop["version"], "SOURCE")
        self.assertEqual(prop["versionCode"], "0")
        self.assertEqual(prop["buildState"], "source")
        for generated in ("frameworkVersion", "unicodeVersion", "variant", "minApi"):
            self.assertNotIn(generated, prop)

    def test_matrix_contains_both_variants(self):
        names = {item["name"] for item in rm.matrix_payload(self.config)["variant"]}
        self.assertEqual(names, {"cbdt", "colrv1"})


if __name__ == "__main__":
    unittest.main()
