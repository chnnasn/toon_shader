"""Map original material texture PPtrs to extracted files without relying on names alone."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STUDY = 'Assets/Studies/WuchangStudy'
shared = json.loads((ROOT / 'Tools/AetherGazer/shared_textures.json').read_text())
shared_files = {(record['character'], record['fileId'], record['pathId']): record['file'] for record in shared}

bindings = []
for character in ('105401', '614801'):
    hero = character[:4]
    records = json.loads((ROOT / f'Tools/AetherGazer/{hero}_objects.json').read_text(encoding='utf-8'))
    texture_names = {record['id']: record['name'] for record in records if record['type'] == 'Texture2D'}
    for source in sorted((ROOT / STUDY / 'SourceArt' / character / 'Materials').glob('*.json')):
        material = json.loads(source.read_text(encoding='utf-8-sig'))
        properties = material['m_SavedProperties']
        textures = {value['Key']: value['Value']['m_Texture'] for value in properties['m_TexEnvs']}
        floats = {value['Key']: value['Value'] for value in properties['m_Floats']}

        def resolve(pointer):
            if not pointer or not pointer['m_PathID']:
                return ''
            if pointer['m_FileID']:
                name = shared_files.get((character, pointer['m_FileID'], pointer['m_PathID']))
                if name and name.endswith('.png'):
                    return STUDY + '/SourceArt/Shared/' + name
                return ''
            name = texture_names[pointer['m_PathID']]
            path = f'{STUDY}/SourceArt/{character}/{name}.png'
            if not (ROOT / path).exists():
                raise FileNotFoundError(path)
            return path

        base = textures.get('_BaseMap')
        if not base or not base['m_PathID']:
            base = textures.get('_MainTex')
        bindings.append({'character': character, 'name': source.stem,
            'baseTexture': resolve(base), 'rampTexture': resolve(textures.get('_RampMap')),
            'surface': int(floats.get('_CharacterSurface', 0)), 'cull': int(floats.get('_Cull', 2))})
(ROOT / 'Tools/AetherGazer/material_bindings.json').write_text(json.dumps(bindings, indent=2), encoding='utf-8')
print('Mapped materials', len(bindings))

shared_names = sorted({record['file'] for record in shared})
items = [{'sourcePath': str(ROOT / '.tmp/aether-shared' / name),
          'destinationPath': f'{STUDY}/SourceArt/Shared/{name}'} for name in shared_names]
items.extend([
    {'sourcePath': str(ROOT / '.tmp/WuchangLighting.cs'), 'destinationPath': STUDY + '/Scripts/WuchangLighting.cs'},
    {'sourcePath': str(ROOT / '.tmp/WuchangStudyBuilder.cs'), 'destinationPath': STUDY + '/Editor/WuchangStudyBuilder.cs'},
])
(ROOT / '.tmp/wuchang_import_shared.json').write_text(json.dumps({'items': json.dumps(items)}))
