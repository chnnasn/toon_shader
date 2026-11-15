"""Resolve character bundle dependencies by inspecting UnityFS directory headers."""
import concurrent.futures
import json
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/aether-python'))
import lz4.block
import UnityPy
UnityPy.config.FALLBACK_UNITY_VERSION = '2022.3.62f1'
SOURCE = Path(r'D:\AetherGazerLauncher\AetherGazer\AetherGazer_Data\StreamingAssets\Windows')
entries = [entry.split('|') for entry in json.loads((SOURCE / 'AssetHash_Info.bytes').read_text())['assetHashList']]


def directory(entry):
    name, digest, _ = entry
    path = SOURCE / digest[0] / digest[1] / (digest + '.ys')
    try:
        with path.open('rb') as stream:
            header = stream.read(256)
            start = header.find(b'UnityFS\0', 0, 32)
            if start < 0:
                return []
            position = start + 12
            position = header.index(b'\0', position) + 1
            position = header.index(b'\0', position) + 1
            size, compressed, uncompressed, flags = struct.unpack_from('>QIII', header, position)
            offset = start + ((position + 20 - start + 15) // 16) * 16
            if flags & 128:
                offset = start + size - compressed
            stream.seek(offset)
            info = stream.read(compressed)
            compression = flags & 63
            if compression in (2, 3):
                info = lz4.block.decompress(info, uncompressed_size=uncompressed)
            elif compression != 0:
                return []
            blocks = struct.unpack_from('>I', info, 16)[0]
            position = 20 + blocks * 10
            count = struct.unpack_from('>I', info, position)[0]
            position += 4
            output = []
            for _ in range(count):
                position += 20
                end = info.index(b'\0', position)
                output.append((info[position:end].decode(), entry))
                position = end + 1
            return output
    except (OSError, ValueError, struct.error):
        return []


def extract_character_shared(character, hero, cab_map):
    env = UnityPy.load(str(ROOT / f'.tmp/aether-bundles/comchar/assets/comchar/artresources/char/hero/{hero}.ys'))
    source_file = next(obj.assets_file for obj in env.objects)
    output = ROOT / '.tmp/aether-shared'
    output.mkdir(exist_ok=True)
    manifest = []
    required = set()
    for material in (ROOT / 'Assets/Studies/WuchangStudy/SourceArt' / character / 'Materials').glob('*.json'):
        tree = json.loads(material.read_text(encoding='utf-8-sig'))
        for slot in tree['m_SavedProperties']['m_TexEnvs']:
            pointer = slot['Value']['m_Texture']
            if pointer['m_FileID']:
                required.add((pointer['m_FileID'], pointer['m_PathID']))
    for number, dependency in enumerate(source_file.externals, 1):
        cab = dependency.path.rsplit('/', 1)[-1]
        entry = cab_map.get(cab)
        if not entry:
            raise ValueError(f'Missing dependency {cab}')
        name, digest, _ = entry
        data = (SOURCE / digest[0] / digest[1] / (digest + '.ys')).read_bytes()
        target = ROOT / '.tmp/aether-bundles' / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data[data.index(b'UnityFS\0'):])
        dep_env = UnityPy.load(str(target))
        for obj in dep_env.objects:
            if obj.type.name == 'Texture2D' and (number, obj.path_id) in required:
                texture = obj.read()
                filename = f'{texture.m_Name}_{obj.path_id}.png'
                try:
                    texture.image.save(output / filename)
                except ValueError:
                    filename = f'{texture.m_Name}_{obj.path_id}.bytes'
                    (output / filename).write_bytes(texture.get_image_data())
                manifest.append({'character': character, 'fileId': number, 'pathId': obj.path_id, 'name': texture.m_Name,
                    'file': filename, 'bundle': name, 'width': texture.m_Width, 'height': texture.m_Height,
                    'format': texture.m_TextureFormat, 'mipCount': texture.m_MipCount})
        print(number, name, flush=True)
    return manifest


if __name__ == '__main__':
    cache = ROOT / '.tmp/aether_cab_index.json'
    if cache.exists():
        cab_map = json.loads(cache.read_text())
    else:
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as executor:
            cab_map = dict(pair for result in executor.map(directory, entries) for pair in result)
        cache.write_text(json.dumps(cab_map))
    print('Indexed serialized files', len(cab_map), flush=True)
    manifest = extract_character_shared('105401', '1054', cab_map)
    manifest.extend(extract_character_shared('614801', '6148', cab_map))
    (ROOT / 'Tools/AetherGazer/shared_textures.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    print('Exported shared textures', len(manifest))
