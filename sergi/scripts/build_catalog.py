#!/usr/bin/env python3
"""Build an offline visual catalog. Python 3.9+, standard library only."""
import argparse
from collections import Counter, defaultdict
from datetime import date
import hashlib
import html
import json
from pathlib import Path
import re
import shutil
import tempfile
from urllib.parse import quote, urlsplit


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda: f.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def text(value, field, required=False):
    if not isinstance(value, str) or (required and not value.strip()):
        raise ValueError(f'{field}: nonempty string required' if required else f'{field}: string required')
    return value.strip()


def build(manifest, out):
    manifest = Path(manifest).resolve()
    out = Path(out).absolute()
    if out.exists():
        raise ValueError(f'Output already exists; choose a new folder: {out}')
    data = json.loads(manifest.read_text(encoding='utf-8'))
    if not isinstance(data, dict):
        raise ValueError('Manifest must be an object')
    title = text(data.get('title'), 'title', True)
    language = data.get('language', 'tr')
    if language not in ('tr', 'en'):
        raise ValueError('language must be tr or en')
    records = data.get('items')
    if not isinstance(records, list) or not records:
        raise ValueError('items must be a nonempty array')
    normalized, ids, sources = [], set(), []
    for record in records:
        if not isinstance(record, dict):
            raise ValueError('Each item must be an object')
        item = {k: text(record.get(k), k, True) for k in ('id', 'title', 'category', 'kind', 'note')}
        if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_-]{0,79}', item['id']) or item['id'] in ids:
            raise ValueError(f'Invalid or duplicate id: {item["id"]}')
        ids.add(item['id'])
        for key in ('source_url', 'date', 'license', 'language'):
            item[key] = text(record.get(key, ''), key)
        if item['date']:
            if not re.fullmatch(r'\d{4}-\d{2}-\d{2}', item['date']):
                raise ValueError('date must use YYYY-MM-DD')
            date.fromisoformat(item['date'])
        url = item['source_url']
        if url:
            parsed = urlsplit(url)
            if parsed.scheme not in ('http', 'https') or not parsed.hostname or parsed.username or parsed.password or any(c.isspace() or ord(c) < 32 for c in url):
                raise ValueError(f'Invalid HTTP(S) source URL for {item["id"]}')
        tags = record.get('tags', [])
        if not isinstance(tags, list):
            raise ValueError('tags must be an array')
        item['tags'] = [text(v, 'tag', True) for v in tags]
        paths = {}
        for key in ('file', 'preview'):
            value = text(record.get(key, ''), key)
            if value:
                path = (manifest.parent / value).resolve()
                # Kapsam kapısı: dosya manifestin klasöründen dışarı kaçamaz (../../etc/... kopyalanmasın).
                if not path.is_relative_to(manifest.parent):
                    raise ValueError(f'{key} must stay inside the manifest folder: {value}')
                if not path.is_file():
                    raise ValueError(f'Missing {key}: {path}')
                if key == 'preview' and path.suffix.lower() not in ('.png', '.jpg', '.jpeg', '.webp', '.gif'):
                    raise ValueError('Preview must be PNG/JPEG/WebP/GIF')
                paths[key] = path
        if 'file' not in paths and not url:
            raise ValueError(f'{item["id"]}: file or source_url required')
        normalized.append(item)
        sources.append(paths)
    payload = dict(title=title, subtitle=text(data.get('subtitle', ''), 'subtitle'),
                   collected_at=text(data.get('collected_at', ''), 'collected_at'), language=language, items=normalized)
    out.parent.mkdir(parents=True, exist_ok=True)
    stage = Path(tempfile.mkdtemp(prefix='.catalog-build-', dir=out.parent))
    try:
        hashes, urls = defaultdict(list), defaultdict(list)
        for item, paths in zip(normalized, sources):
            folder = stage / 'items' / item['id']
            folder.mkdir(parents=True)
            item['file'] = item['preview'] = ''
            for key, src in paths.items():
                extension = src.suffix.lower()
                if not re.fullmatch(r'\.[a-z0-9]{1,12}', extension):
                    extension = '.bin'
                dest = folder / (('original' if key == 'file' else 'preview') + extension)
                shutil.copy2(src, dest)
                source_hash = digest(src)
                if source_hash != digest(dest):
                    raise ValueError(f'Copy verification failed: {src.name}')
                item[key] = dest.relative_to(stage).as_posix()
                if key == 'file':
                    item['original_name'] = src.name
                    item['sha256'] = source_hash
                    item['bytes'] = dest.stat().st_size
                    hashes[source_hash].append(item['id'])
            if item['source_url']:
                urls[item['source_url']].append(item['id'])
            (folder / 'source.txt').write_text('\n'.join(f'{k}: {item.get(k, "")}' for k in
                ('id', 'title', 'category', 'kind', 'note', 'source_url', 'date', 'license', 'original_name', 'sha256')), encoding='utf-8')
        report = dict(records=len(normalized), local_files=sum(bool(x['file']) for x in normalized),
                      unique_local_files=len(hashes), previews=sum(bool(x['preview']) for x in normalized),
                      categories=dict(Counter(x['category'] for x in normalized)),
                      duplicate_files=[v for v in hashes.values() if len(v) > 1],
                      duplicate_source_urls=[v for v in urls.values() if len(v) > 1],
                      copy_hashes_verified=True,
                      not_checked=['document readability', 'visual quality', 'external URL status', 'license validity'])
        (stage / 'catalog.json').write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding='utf-8')
        (stage / 'validation.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
        template = (Path(__file__).resolve().parent.parent / 'assets' / 'catalog.html').read_text(encoding='utf-8')
        embedded = json.dumps(payload, ensure_ascii=False).replace('&', '\\u0026').replace('<', '\\u003c').replace('>', '\\u003e').replace('\u2028', '\\u2028').replace('\u2029', '\\u2029')
        fallback = '<ul>' + ''.join('<li>' + html.escape(x['title']) + ' — <a href="' + html.escape(quote(x['file'], safe='/') if x['file'] else x['source_url'], quote=True) + '">Open / Aç</a></li>' for x in normalized) + '</ul>'
        # Single substitution pass: user content containing a marker remains literal.
        replacements = {'@@TITLE@@': html.escape(title), '@@DATA@@': embedded, '@@FALLBACK@@': fallback, '@@LANG@@': language}
        page = re.sub(r'@@(?:TITLE|DATA|FALLBACK|LANG)@@', lambda m: replacements[m.group()], template)
        (stage / 'index.html').write_text(page, encoding='utf-8')
        (stage / 'KULLANIM.txt').write_text('index.html dosyasını modern bir tarayıcıda açın. / Open index.html in a modern browser.\nKlasörü tüm alt dosyalarıyla birlikte taşıyın. / Move the whole folder together.\nKatalog çevrimdışıdır; kaynak bağlantıları internet gerektirir. / Source links require internet.\nArama ve filtreler JavaScript gerektirir. / Search and filters require JavaScript.\nvalidation.json teknik kontrol ve tekrar raporudur; içerik kalitesi ayrıca incelenmelidir.\n', encoding='utf-8')
        # mkdtemp 0700 verir, copy2 kaynağın 0600 iznini taşır; teslim edilen klasör paylaşılabilir olmalı.
        for node in [stage, *stage.rglob('*')]:
            node.chmod(0o755 if node.is_dir() else 0o644)
        stage.rename(out)
        return report
    except Exception:
        shutil.rmtree(stage, ignore_errors=True)
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('manifest', type=Path)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    try:
        report = build(args.manifest, args.out)
    except (ValueError, OSError) as error:
        parser.exit(1, f'Error: {error}\n')
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
