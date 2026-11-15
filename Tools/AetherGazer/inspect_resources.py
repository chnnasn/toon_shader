"""Inspect the installed asset index and restore selected character bundles."""
import json
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/aether-python'))
import UnityPy
UnityPy.config.FALLBACK_UNITY_VERSION = '2022.3.62f1'

SOURCE = Path(r'D:\AetherGazerLauncher\AetherGazer\AetherGazer_Data\StreamingAssets\Windows')
OUTPUT = ROOT / '.tmp/aether-bundles'
OUTPUT.mkdir(parents=True, exist_ok=True)
index = json.loads((SOURCE / 'AssetHash_Info.bytes').read_text())
selected = []
for entry in index['assetHashList']:
    name, digest, size = entry.split('|')
    is_hero = name in (
        'comchar/assets/comchar/artresources/char/hero/1054.ys',
        'comchar/assets/comchar/artresources/char/hero/6148.ys',
    )
    is_prefab = name.startswith('comchar/char/') and any(
        key in name for key in ('105401', '614801')
    ) and 'tpose' in name
    is_icon = name == 'textureconfig/character/icon/105401.ys'
    if not (is_hero or is_prefab or is_icon):
        continue
    source = SOURCE / digest[0] / digest[1] / (digest + '.ys')
    if not source.exists():
        print('MISSING', name)
        continue
    data = source.read_bytes()
    offset = data.find(b'UnityFS\0', 0, 32)
    if offset < 0:
        raise ValueError(f'Unexpected bundle header: {name}')
    target = OUTPUT / name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data[offset:])
    env = UnityPy.load(str(target))
    print(name, Counter(obj.type.name for obj in env.objects))
    records = []
    for obj in env.objects:
        if obj.type.name in ('Mesh', 'Texture2D', 'Material', 'GameObject', 'Animator'):
            tree = obj.read_typetree()
            records.append({'id': obj.path_id, 'type': obj.type.name,
                            'name': tree.get('m_Name', ''),
                            'tree': tree if obj.type.name == 'Material' else {}})
    report = ROOT / 'Tools/AetherGazer' / (target.stem + '_objects.json')
    report.write_text(json.dumps(records, ensure_ascii=False, indent=2, default=str), encoding='utf-8')
    selected.append({'path': name, 'hash': digest, 'size': int(size), 'padding': offset})
    print('Objects', [(r['type'], r['name']) for r in records if r['type'] != 'GameObject'][:100])
(ROOT / 'Tools/AetherGazer/source_manifest.json').write_text(
    json.dumps({'version': index['versionName'], 'bundles': selected}, indent=2), encoding='utf-8')
