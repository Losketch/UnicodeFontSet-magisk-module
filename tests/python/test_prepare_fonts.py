import sys
import tempfile
import textwrap
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/python"))

from prepare_fonts import license_filename, read_sources, select_sources, write_license


class PrepareFontsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sources = read_sources(ROOT / "font-source/font-sources.toml")

    def test_each_variant_has_one_source_per_packaged_filename(self):
        for variant in ("cbdt", "colrv1"):
            selected = select_sources(self.sources, variant)
            names = [row.file for row in selected]
            self.assertEqual(len(names), len(set(names)))
            self.assertIn("NotoColorEmoji.ttf", names)

    def test_emoji_source_changes_by_variant(self):
        cbdt = {row.file: row for row in select_sources(self.sources, "cbdt")}
        colrv1 = {row.file: row for row in select_sources(self.sources, "colrv1")}
        self.assertNotEqual(
            cbdt["NotoColorEmoji.ttf"].source_location,
            colrv1["NotoColorEmoji.ttf"].source_location,
        )

    def test_toml_defaults_variant_and_optional_license_fields(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "sources.toml"
            path.write_text(
                textwrap.dedent(
                    """
                    schema = 1

                    [[fonts]]
                    file = "Example.ttf"
                    acquisition = "direct"
                    source_location = "https://example.invalid/Example.ttf"
                    """
                ).strip()
                + "\n",
                encoding="utf-8",
            )
            [row] = read_sources(path)
            self.assertEqual(row.variant, "all")
            self.assertIsNone(row.license)

    def test_license_filename_is_derived_from_font_name_without_extension(self):
        self.assertEqual(
            license_filename("SourceHanSansSC-Regular.otf"),
            "LICENSE-SourceHanSansSC-Regular",
        )

    def test_toml_rejects_non_https_license_url(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "sources.toml"
            path.write_text(
                textwrap.dedent(
                    """
                    schema = 1

                    [[fonts]]
                    file = "Example.ttf"
                    acquisition = "direct"
                    source_location = "https://example.invalid/Example.ttf"
                    license = "http://example.invalid/LICENSE"
                    """
                ).strip()
                + "\n",
                encoding="utf-8",
            )
            with self.assertRaises(SystemExit):
                read_sources(path)

    def test_write_license_uses_url_cache_and_per_font_names(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp)
            cache: dict[str, bytes] = {}
            url = "https://example.invalid/LICENSE"
            with mock.patch("prepare_fonts.fetch", return_value=b"license text") as fetch_mock:
                write_license("One.ttf", url, target, cache)
                write_license("Two.otf", url, target, cache)
            fetch_mock.assert_called_once_with(url)
            self.assertEqual((target / "LICENSE-One").read_bytes(), b"license text")
            self.assertEqual((target / "LICENSE-Two").read_bytes(), b"license text")

    def test_write_license_creates_missing_output_directory(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "missing" / "licenses"
            with mock.patch("prepare_fonts.fetch", return_value=b"license text"):
                write_license("Example.ttf", "https://example.invalid/LICENSE", target, {})
            self.assertEqual((target / "LICENSE-Example").read_bytes(), b"license text")

    def test_toml_rejects_unknown_keys(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "sources.toml"
            path.write_text(
                textwrap.dedent(
                    """
                    schema = 1

                    [[fonts]]
                    file = "Example.ttf"
                    acquisition = "direct"
                    source_location = "https://example.invalid/Example.ttf"
                    source = "redundant field"
                    """
                ).strip()
                + "\n",
                encoding="utf-8",
            )
            with self.assertRaises(SystemExit):
                read_sources(path)


if __name__ == "__main__":
    unittest.main()
