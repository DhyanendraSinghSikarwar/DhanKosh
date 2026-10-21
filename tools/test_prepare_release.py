import unittest

import prepare_release as pr

PUB = "name: hisaab\nversion: 0.1.0+1\nenvironment:\n"
LOG = "# Changelog\n\n## [Unreleased]\n\n### Added\n- Thing one\n- Thing two\n\n## [0.0.1] - 2026-01-01\n- old\n"


class PrepareRelease(unittest.TestCase):
    def test_read_version(self):  # TC-32-01
        self.assertEqual(pr.read_version("version: 3.0.0+34\n"), ("3.0.0", 34))
        with self.assertRaises(ValueError):
            pr.read_version("name: x\n")

    def test_bump_keeps_name_and_grows_build(self):
        text, name, build = pr.bump_pubspec(PUB)
        self.assertEqual((name, build), ("0.1.0", 2))
        self.assertIn("version: 0.1.0+2", text)

    def test_bump_new_version(self):
        text, name, build = pr.bump_pubspec(PUB, "0.2.0")
        self.assertEqual((name, build), ("0.2.0", 2))
        self.assertIn("version: 0.2.0+2", text)
        with self.assertRaises(ValueError):
            pr.bump_pubspec(PUB, "v0.2")

    def test_promote_changelog(self):
        out = pr.promote_changelog(LOG, "0.2.0", "2026-10-21")
        self.assertIn("## [Unreleased]\n\n## [0.2.0] - 2026-10-21\n\n### Added", out)
        with self.assertRaises(ValueError):
            pr.promote_changelog(out, "0.2.0", "2026-10-22")

    def test_notes_format(self):  # TC-32-03, FR-32-09
        out = pr.promote_changelog(LOG, "0.2.0", "2026-10-21")
        sha = "ab" * 32
        notes = pr.make_notes("0.2.0", pr.section_bullets(out, "0.2.0"), sha)
        self.assertEqual(
            notes,
            f"DhanKosh 0.2.0\n\n- Thing one\n- Thing two\n\nsha256: {sha}\n",
        )

    def test_bullets_capped_and_sha_checked(self):
        many = "## [1.0.0] - d\n" + "".join(f"- b{i}\n" for i in range(60))
        self.assertEqual(len(pr.section_bullets(many, "1.0.0")), 40)
        with self.assertRaises(ValueError):
            pr.make_notes("1.0.0", [], "XYZ")


if __name__ == "__main__":
    unittest.main()
