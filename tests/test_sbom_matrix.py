# SPDX-License-Identifier: Apache-2.0
import importlib.util
from importlib.machinery import SourceFileLoader
import json
import tempfile
import unittest
from pathlib import Path

SCRIPT = str(Path(__file__).parents[1] / "scripts" / "sbom-matrix")
SPEC = importlib.util.spec_from_loader("sbom_matrix", SourceFileLoader("sbom_matrix", SCRIPT))
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class SbomMatrixTests(unittest.TestCase):
    def test_record_resolves_runtime_manifests_and_skips_attestation(self):
        index = {
            "schemaVersion": 2,
            "mediaType": "application/vnd.oci.image.index.v1+json",
            "manifests": [
                {"mediaType": "application/vnd.oci.image.manifest.v1+json", "digest": "sha256:" + "a" * 64, "platform": {"os": "linux", "architecture": "amd64"}},
                {"mediaType": "application/vnd.oci.image.manifest.v1+json", "digest": "sha256:" + "b" * 64, "platform": {"os": "linux", "architecture": "arm64", "variant": "v8"}},
                {"mediaType": "application/vnd.oci.image.manifest.v1+json", "digest": "sha256:" + "c" * 64, "platform": {"os": "unknown", "architecture": "unknown"}, "annotations": {"vnd.docker.reference.type": "attestation-manifest"}},
            ],
        }
        result = MODULE.record(index, "k8s", "ghcr.io/sentenz/container/k8s", "container/k8s", "sha256:" + "d" * 64, ["linux/amd64", "linux/arm64"], "1.0.0")
        self.assertEqual(result["manifests"]["linux/amd64"], "sha256:" + "a" * 64)
        self.assertEqual(result["manifests"]["linux/arm64"], "sha256:" + "b" * 64)

    def test_collect_rejects_missing_platform(self):
        catalog = {"images": [{"name": "k8s", "package": "container/k8s", "platforms": ["linux/amd64", "linux/arm64"]}]}
        record = {"schemaVersion": 1, "name": "k8s", "image": "ghcr.io/sentenz/container/k8s", "version": "1.0.0", "indexDigest": "sha256:" + "d" * 64, "manifests": {"linux/amd64": "sha256:" + "a" * 64}}
        with self.assertRaises(ValueError):
            MODULE.collect(catalog, [record], "sentenz", "1.0.0")


if __name__ == "__main__":
    unittest.main()
