# SPDX-License-Identifier: Apache-2.0

"""Check registry naming and architecture selection without a registry or daemon."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
AMD64 = "sha256:" + "a" * 64
ARM64 = "sha256:" + "b" * 64


def manifest(architecture, digest):
    return {"platform": {"os": "linux", "architecture": architecture}, "digest": digest}


class PublicationTests(unittest.TestCase):
    def resolve(self, manifests, platform="linux/amd64"):
        with tempfile.TemporaryDirectory() as directory:
            index = Path(directory) / "index.json"
            index.write_text(json.dumps({"manifests": manifests}))
            return subprocess.run(
                ["bash", str(ROOT / "scripts/image-platform"), str(index), platform],
                capture_output=True, text=True, check=False,
            )

    def test_platforms_resolve_to_distinct_runtime_digests(self):
        manifests = [
            manifest("arm64", ARM64),
            {"platform": {"os": "unknown", "architecture": "unknown"}, "digest": "sha256:" + "c" * 64},
            manifest("amd64", AMD64),
        ]
        for platform, expected in [("linux/amd64", AMD64), ("linux/arm64", ARM64)]:
            with self.subTest(platform=platform):
                result = self.resolve(manifests, platform)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.strip(), expected)

    def test_missing_or_ambiguous_platform_is_rejected(self):
        for manifests in [[], [manifest("arm64", ARM64)], [manifest("amd64", AMD64)] * 2]:
            with self.subTest(manifests=manifests):
                self.assertNotEqual(self.resolve(manifests).returncode, 0)

    def test_invalid_digest_or_platform_is_rejected(self):
        for digest in ["latest", "sha256:abc", "sha256:" + "g" * 64]:
            with self.subTest(digest=digest):
                self.assertNotEqual(self.resolve([manifest("amd64", digest)]).returncode, 0)
        self.assertNotEqual(self.resolve([manifest("amd64", AMD64)], "linux/s390x").returncode, 0)

    def test_catalog_and_local_build_use_directory_names(self):
        result = subprocess.run(
            ["bash", str(ROOT / "scripts/container"), "matrix"],
            capture_output=True, text=True, check=True,
        )
        for image in json.loads(result.stdout)["include"]:
            with self.subTest(image=image["name"]), tempfile.TemporaryDirectory() as directory:
                self.assertEqual(image["file"], f"containers/{image['name']}/Containerfile")
                self.assertEqual(image["platform_list"], image["platforms"].split(","))
                engine = Path(directory) / "engine"
                engine.write_text('#!/bin/sh\nprintf "%s\\n" "$@"\n')
                engine.chmod(0o755)
                env = dict(os.environ, CONTAINER_ENGINE=str(engine), CONTAINER_TAG="test")
                env.pop("CONTAINER_REGISTRY", None)
                built = subprocess.run(
                    ["bash", str(ROOT / "scripts/container"), "build", image["name"]],
                    env=env, capture_output=True, text=True, check=True,
                ).stdout.splitlines()
                self.assertEqual(built[built.index("--tag") + 1], f"ghcr.io/sentenz/{image['name']}:test")


if __name__ == "__main__":
    unittest.main()
