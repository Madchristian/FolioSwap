"""Local packaging regression tests; uses only the Python standard library."""
import io
import subprocess
import sys
import tempfile
import unittest
import warnings
import zipfile
from pathlib import Path

sys.dont_write_bytecode = True
import package_release as package

ROOT = Path(__file__).resolve().parents[1]


class PackageTests(unittest.TestCase):
    def test_deterministic_release(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "candidate.zip"
            command = [sys.executable, str(ROOT / "scripts/package_release.py"),
                       "2026.9.30", "--output", str(output)]
            first = subprocess.run(command, capture_output=True, text=True)
            self.assertEqual(first.returncode, 0, first.stderr)
            original = output.read_bytes()
            second = subprocess.run(command, capture_output=True, text=True)
            self.assertEqual(second.returncode, 0, second.stderr)
            self.assertEqual(original, output.read_bytes())
            with zipfile.ZipFile(output) as archive:
                self.assertIsNone(archive.testzip())
                self.assertEqual(len(archive.namelist()), 19)
                self.assertIn(b"## Version: 2026.9.30", archive.read("FolioSwap/FolioSwap.toc"))
                self.assertEqual(archive.read("FolioSwap/LICENSE"), (ROOT / "LICENSE").read_bytes())

    def test_rejects_invalid_or_unrecorded_versions(self):
        for version in ("v2026.9.30", "2026.09.30", "2026.2.30", "2099.1.1", "../../bad"):
            with self.subTest(version=version), self.assertRaises(ValueError):
                package.source_payload(version)

    def test_rejects_extra_traversal_and_duplicate_members(self):
        payload = package.source_payload("2026.9.29")
        for name in ("FolioSwap/artwork/logo.png", "FolioSwap/../escape", "FolioSwap/LICENSE"):
            data = io.BytesIO(package.build(payload))
            with warnings.catch_warnings():
                warnings.simplefilter("ignore", UserWarning)
                with zipfile.ZipFile(data, "a") as archive:
                    archive.writestr(name, b"unexpected")
            with self.subTest(name=name), self.assertRaises(ValueError):
                package.verify(data.getvalue(), payload)

    def test_rejects_changed_source_bytes(self):
        payload = package.source_payload("2026.9.29")
        changed = dict(payload)
        changed["UI/Skin.lua"] += b"\n-- changed\n"
        with self.assertRaisesRegex(ValueError, "bytes differ"):
            package.verify(package.build(changed), payload)

    def test_rejects_truncated_archive(self):
        payload = package.source_payload("2026.9.29")
        with self.assertRaises(zipfile.BadZipFile):
            package.verify(package.build(payload)[:-24], payload)


if __name__ == "__main__":
    unittest.main()
