#!/usr/bin/env python3
"""Behavioral checks for the portable catalog generator; no external dependencies."""
import json
from pathlib import Path
import tempfile
import unittest
from build_catalog import build, digest


class CatalogTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'özgün dosya.txt').write_text('Özgün içerik\n', encoding='utf-8')
        self.record = dict(id='one', title='İlk kayıt', category='Arşiv', kind='Not', note='İçerik açıklaması', file='özgün dosya.txt')

    def run_build(self, items, name='out'):
        path = self.root / 'manifest.json'
        path.write_text(json.dumps(dict(title='Kütüphane', items=items), ensure_ascii=False), encoding='utf-8')
        return build(path, self.root / name)

    def test_original_copy_and_portable_paths(self):
        result = self.run_build([self.record])
        original = self.root / 'özgün dosya.txt'
        copy = self.root / 'out/items/one/original.txt'
        self.assertEqual(digest(original), digest(copy))
        payload = json.loads((self.root / 'out/catalog.json').read_text())
        self.assertEqual(payload['items'][0]['file'], 'items/one/original.txt')
        self.assertNotIn(str(self.root), (self.root / 'out/index.html').read_text())
        self.assertEqual(result['unique_local_files'], 1)

    def test_duplicates_are_reported_without_deleting(self):
        result = self.run_build([self.record, dict(self.record, id='two')])
        self.assertEqual(result['duplicate_files'], [['one', 'two']])
        self.assertEqual(result['unique_local_files'], 1)
        self.assertTrue((self.root / 'out/items/two/original.txt').exists())

    def test_missing_input_no_partial_output(self):
        with self.assertRaises(ValueError):
            self.run_build([dict(self.record, file='missing.pdf')])
        self.assertFalse((self.root / 'out').exists())

    def test_reject_unsafe_url_and_duplicate_id(self):
        with self.assertRaises(ValueError):
            self.run_build([dict(self.record, source_url='javascript:alert(1)')])
        with self.assertRaises(ValueError):
            self.run_build([self.record, self.record])
        with self.assertRaises(ValueError):
            self.run_build([dict(self.record, id='../outside')])

    def test_file_cannot_escape_manifest_folder(self):
        # Kapsam kapısı: manifest klasörünün dışındaki dosya kopyalanmaz, yarım çıktı kalmaz.
        outside = Path(self.temp.name).parent / 'katalog-disari-kacis.txt'
        outside.write_text('gizli\n', encoding='utf-8')
        self.addCleanup(outside.unlink)
        with self.assertRaises(ValueError):
            self.run_build([dict(self.record, file='../katalog-disari-kacis.txt')])
        self.assertFalse((self.root / 'out').exists())

    def test_output_folder_is_shareable(self):
        (self.root / 'özgün dosya.txt').chmod(0o600)  # kaynak yalnız-sahip olsa bile
        self.run_build([self.record])
        self.assertEqual((self.root / 'out').stat().st_mode & 0o777, 0o755)
        self.assertEqual((self.root / 'out/items/one/original.txt').stat().st_mode & 0o777, 0o644)

    def test_existing_output_is_preserved(self):
        self.run_build([self.record])
        before = (self.root / 'out/index.html').read_bytes()
        with self.assertRaises(ValueError):
            self.run_build([dict(self.record, title='Changed')])
        self.assertEqual(before, (self.root / 'out/index.html').read_bytes())

    def test_untrusted_text_and_link_only_record(self):
        payload = '</script><script>alert(1)</script> @@DATA@@ & <tag>'
        item = dict(self.record, title=payload, source_url='https://example.com/resource')
        item.pop('file')
        result = self.run_build([item])
        page = (self.root / 'out/index.html').read_text()
        self.assertNotIn('</script><script>alert(1)', page)
        data = page.split('<script type="application/json" id="catalog-data">')[1].split('</script>')[0]
        self.assertEqual(json.loads(data)['items'][0]['title'], payload)
        self.assertEqual(result['local_files'], 0)


if __name__ == '__main__':
    unittest.main()
