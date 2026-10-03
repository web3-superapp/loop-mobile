"""Metadata is ignored only when both its name and binary magic agree."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location(
    'check_harness', Path(__file__).parents[1] / 'scripts/check_harness.py')
harness = importlib.util.module_from_spec(spec)
spec.loader.exec_module(harness)


class AppleDoubleSourceReadTest(unittest.TestCase):
    def test_verified_sidecar_is_not_source(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / '._screen.dart'
            path.write_bytes(bytes.fromhex('00051607') + b'\xff\x00')
            self.assertEqual(harness.read_text(path), '')

    def test_real_dot_source_is_still_read(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / '._screen.dart'
            path.write_text('forbiddenRealCode();', encoding='utf-8')
            self.assertEqual(harness.read_text(path), 'forbiddenRealCode();')

    def test_other_binary_source_remains_an_error(self):
        with tempfile.TemporaryDirectory() as directory:
            for name in ['screen.dart', '._screen.dart']:
                path = Path(directory) / name
                path.write_bytes(b'\xff\xfe')
                with self.assertRaises(UnicodeDecodeError):
                    harness.read_text(path)

    def test_record_inventory_ignores_only_verified_metadata(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            decisions = root / 'docs/decisions'
            decisions.mkdir(parents=True)
            sidecar = decisions / '._0111-example.md'
            sidecar.write_bytes(bytes.fromhex('00051607') + b'\xff')
            self.assertEqual(harness.check_records(root), [])
            sidecar.write_text('real malformed record', encoding='utf-8')
            self.assertTrue(harness.check_records(root))
