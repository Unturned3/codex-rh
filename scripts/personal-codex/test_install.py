"""Installer contract tests; network downloads use a local release fixture."""

import hashlib
import os
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile
import unittest


INSTALLER = Path(__file__).with_name("install.sh")
ARCHIVE = "codex-personal-x86_64-unknown-linux-musl.tar.gz"
REPO = "https://github.com/Unturned3/codex-rh"


class InstallTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="pcodex test ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.package = self.root / "package"
        (self.package / "bin").mkdir(parents=True)
        (self.package / "codex-resources").mkdir()
        (self.package / "codex-resources" / "helper").write_text("keep me")
        (self.package / "codex-package.json").write_text("{}")
        executable = self.package / "bin" / "codex"
        executable.write_text("#!/bin/sh\nprintf 'fixture codex 0.0.0\\n'\n")
        executable.chmod(0o755)
        self.assets = self.root / "assets"
        self.assets.mkdir()
        with tarfile.open(self.assets / ARCHIVE, "w:gz") as archive:
            for child in self.package.iterdir():
                archive.add(child, arcname=child.name)
        digest = hashlib.sha256((self.assets / ARCHIVE).read_bytes()).hexdigest()
        # A v1 checksum file includes the old installer; only the archive is needed.
        (self.assets / "SHA256SUMS").write_text(
            f"{digest}  {ARCHIVE}\n{'0' * 64}  install.sh\n"
        )
        self.bin_dir = self.root / "user bin"
        self.launcher = self.bin_dir / "pcodex"
        self.install_root = self.root / "data" / "codex-personal"
        mock_bin = self.root / "mock bin"
        mock_bin.mkdir()
        curl = mock_bin / "curl"
        curl.write_text(
            f"#!{sys.executable}\n"
            """import os, pathlib, shutil, sys
args = sys.argv[1:]
url = next(arg for arg in args if arg.startswith("https://"))
with open(os.environ["CURL_LOG"], "a") as log:
    log.write(url + "\\n")
if url.endswith("/releases/latest"):
    print(os.environ.get("LATEST_URL",
          "https://github.com/Unturned3/codex-rh/releases/tag/personal-v7"), end="")
else:
    asset = url.rsplit("/", 1)[-1]
    if asset == os.environ.get("FAIL_ASSET"):
        sys.exit(22)
    shutil.copyfile(pathlib.Path(os.environ["FIXTURE_ASSETS"]) / asset,
                    args[args.index("-o") + 1])
"""
        )
        curl.chmod(0o755)
        self.env = {
            **os.environ,
            "PATH": f"{mock_bin}:{os.environ['PATH']}",
            "XDG_DATA_HOME": str(self.root / "data"),
            "PCODEX_BIN_DIR": str(self.bin_dir),
            "FIXTURE_ASSETS": str(self.assets),
            "CURL_LOG": str(self.root / "curl.log"),
        }
        self.env.pop("PCODEX_VERSION", None)

    def run_installer(self, *args, success=True):
        # Match curl | bash: no script filename, and EOF on stdin after the script.
        result = subprocess.run(
            ["bash", "-s", "--", *args],
            input=INSTALLER.read_text(),
            text=True,
            capture_output=True,
            env=self.env,
        )
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def test_latest_download_is_pinned_and_preserves_helpers(self):
        self.run_installer()
        self.assertEqual(
            (self.root / "curl.log").read_text().splitlines(),
            [
                f"{REPO}/releases/latest",
                f"{REPO}/releases/download/personal-v7/SHA256SUMS",
                f"{REPO}/releases/download/personal-v7/{ARCHIVE}",
            ],
        )
        self.assertTrue(self.launcher.is_symlink())
        installed = self.launcher.resolve().parent.parent
        self.assertEqual((installed / "codex-resources/helper").read_text(), "keep me")
        self.assertEqual(list(self.bin_dir.glob(".pcodex.*")), [])

    def test_upgrade_retains_previous_install_and_migrates_owned_launcher(self):
        self.run_installer(str(self.package))
        previous = self.launcher.resolve()
        legacy = self.bin_dir / "codex-personal"
        self.launcher.rename(legacy)
        self.run_installer(str(self.package))
        self.assertTrue(previous.exists())
        self.assertNotEqual(previous, self.launcher.resolve())
        self.assertFalse(legacy.is_symlink())

    def test_unrelated_legacy_launcher_is_preserved(self):
        self.bin_dir.mkdir()
        legacy = self.bin_dir / "codex-personal"
        legacy.symlink_to(self.package / "bin/codex")
        self.run_installer(str(self.package))
        self.assertEqual(legacy.resolve(), self.package / "bin/codex")

    def test_pinned_release_skips_latest_lookup(self):
        self.env["PCODEX_VERSION"] = "personal-v1"
        self.run_installer()
        urls = (self.root / "curl.log").read_text().splitlines()
        self.assertEqual(len(urls), 2)
        self.assertTrue(all("/releases/download/personal-v1/" in url for url in urls))

    def test_bad_checksum_preserves_working_install(self):
        self.run_installer(str(self.package))
        previous = self.launcher.resolve()
        (self.assets / "SHA256SUMS").write_text(f"{'0' * 64}  {ARCHIVE}\n")
        self.run_installer(success=False)
        self.assertEqual(self.launcher.resolve(), previous)
        self.assertEqual(len(list(self.install_root.iterdir())), 1)

    def test_download_failure_preserves_working_install(self):
        self.run_installer(str(self.package))
        previous = self.launcher.resolve()
        self.env["FAIL_ASSET"] = ARCHIVE
        self.run_installer(success=False)
        self.assertEqual(self.launcher.resolve(), previous)

    def test_failed_binary_cleans_new_install_and_preserves_launcher(self):
        self.run_installer(str(self.package))
        previous = self.launcher.resolve()
        (self.package / "bin/codex").write_text("#!/bin/sh\nexit 1\n")
        self.run_installer(str(self.package), success=False)
        self.assertEqual(self.launcher.resolve(), previous)
        self.assertEqual(len(list(self.install_root.iterdir())), 1)

    def test_existing_file_is_not_overwritten(self):
        self.bin_dir.mkdir()
        self.launcher.write_text("user file")
        self.run_installer(success=False)
        self.assertEqual(self.launcher.read_text(), "user file")
        self.assertFalse((self.root / "curl.log").exists())

    def test_invalid_or_foreign_release_is_rejected(self):
        for version in ("rust-v1.0.0", "personal-v1/../../other"):
            with self.subTest(version=version):
                self.env["PCODEX_VERSION"] = version
                self.run_installer(success=False)
        self.env.pop("PCODEX_VERSION")
        self.env["LATEST_URL"] = "https://github.com/openai/codex/releases/tag/personal-v7"
        self.run_installer(success=False)
        self.assertFalse(self.launcher.exists())

    def test_unsupported_platform_exits_before_downloading(self):
        uname = Path(self.env["PATH"].split(":")[0]) / "uname"
        uname.write_text("#!/bin/sh\nprintf 'Darwin\\n'\n")
        uname.chmod(0o755)
        result = self.run_installer(success=False)
        self.assertIn("Linux x86_64 only", result.stderr)
        self.assertFalse((self.root / "curl.log").exists())


if __name__ == "__main__":
    unittest.main()
