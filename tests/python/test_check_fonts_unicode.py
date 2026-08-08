import contextlib
import io
import subprocess
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/python"))

import check_fonts_unicode as cfu


class CheckFontsUnicodeTests(unittest.TestCase):
    def test_module_import_does_not_require_fonttools(self):
        tools_dir = ROOT / "tools/python"
        code = (
            "import sys; "
            f"sys.path.insert(0, {str(tools_dir)!r}); "
            "import check_fonts_unicode"
        )
        result = subprocess.run(
            [sys.executable, "-S", "-c", code],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_repository_policy_marks_last_resort_as_terminal_fallback(self):
        terminal = cfu.parse_terminal_fallbacks(ROOT / "module/config/font-policy.tsv")
        self.assertEqual(terminal, {"LastResort-Regular.ttf"})

    def test_terminal_fallback_is_skipped_and_union_is_limited_to_targets(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            unicode_data = tmp_path / "UnicodeData.txt"
            unicode_data.write_text(
                textwrap.dedent(
                    """
                    0041;LATIN CAPITAL LETTER A;Lu;0;L;;;;;N;;;;0061;
                    0042;LATIN CAPITAL LETTER B;Lu;0;L;;;;;N;;;;0062;
                    E000;PRIVATE USE AREA;Co;0;L;;;;;N;;;;;
                    """
                ).strip()
                + "\n",
                encoding="utf-8",
            )
            policy = tmp_path / "font-policy.tsv"
            policy.write_text(
                "normal-fallback\tNormal.ttf\t-\t-\n"
                "terminal-fallback\tLastResort-Regular.ttf\t-\t-\n",
                encoding="utf-8",
            )
            normal = tmp_path / "Normal.ttf"
            last_resort = tmp_path / "LastResort-Regular.ttf"

            def fake_codepoints(path):
                if Path(path).name == "Normal.ttf":
                    return {0x0041, 0xE000, 0x10FFFF}
                self.fail("terminal fallback should be skipped before reading its cmap")

            argv = [
                "check_fonts_unicode.py",
                str(unicode_data),
                str(normal),
                str(last_resort),
                "--font-policy",
                str(policy),
                "--warn-only",
                "--lang",
                "en",
            ]
            output = io.StringIO()
            with mock.patch.object(sys, "argv", argv), mock.patch.object(
                cfu, "get_font_codepoints", side_effect=fake_codepoints
            ), contextlib.redirect_stdout(output):
                with self.assertRaises(SystemExit) as exc:
                    cfu.main()

            self.assertEqual(exc.exception.code, 0)
            text = output.getvalue()
            self.assertIn(f"Skipped terminal fallback: {last_resort}", text)
            self.assertIn(f"Read 1 target codepoints from {normal}", text)
            self.assertIn("Union of fonts covers 1 target codepoints", text)
            self.assertIn("Missing 1 codepoints", text)
            self.assertIn("U+0042", text)
            self.assertNotIn("1114112", text)


if __name__ == "__main__":
    unittest.main()
