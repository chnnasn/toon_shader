"""Create the study graph using the installed Shader Graph 17 serialization schema.

The Custom Function node is authored here because UnitySkills exposes a smaller
node subset. The Unity editor then generates and validates the shader normally.
"""
import copy
import json
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / 'Assets/Studies/BrahmaWujianStudy/Shaders'
DEST.mkdir(parents=True, exist_ok=True)

def objects(path):
    text = path.read_text(encoding='utf-8-sig')
    result = []
    while text.strip():
        obj, end = json.JSONDecoder().raw_decode(text.lstrip())
        result.append(obj)
        text = text.lstrip()[end:]
    return result

source = objects(ROOT / 'Assets/Studies/WuchangStudy/Shaders/WuchangSurface.shadergraph')
custom = objects(next((ROOT / 'Library/PackageCache').glob(
    'com.unity.shadergraph@*/ShaderGraphLibrary/Nature/SpeedTree8ColorAlpha.shadersubgraph')))
prototypes = {o['m_Type'].split('.')[-1]: o for o in source + custom}
by_id = {o['m_ObjectId']: o for o in source}
graph = copy.deepcopy(source[0])
graph['m_ObjectId'] = uuid.uuid5(uuid.NAMESPACE_URL, 'BrahmaWujian/Graph').hex
graph['m_Path'] = 'AetherGazer/Brahma Wujian'
graph['m_Properties'] = []
graph['m_Keywords'] = []
graph['m_CategoryData'] = []
graph['m_GroupDatas'] = []
graph['m_StickyNoteDatas'] = []
graph['m_Edges'] = []
blocks = [o for o in source if o['m_Type'].endswith('.BlockNode')]
result = [graph] + copy.deepcopy(blocks)
for block in blocks:
    result += [copy.deepcopy(by_id[s['m_Id']]) for s in block['m_Slots']]
graph['m_Nodes'] = [{'m_Id': o['m_ObjectId']} for o in blocks]
targets = [o for o in source if o['m_Type'].endswith(('UniversalTarget', 'UniversalUnlitSubTarget'))]
universal_target = next(o for o in targets if o['m_Type'].endswith('UniversalTarget'))
graph['m_ActiveTargets'] = [{'m_Id': universal_target['m_ObjectId']}]
for original in targets:
    target = copy.deepcopy(original)
    if target['m_Type'].endswith('UniversalTarget'):
        target['m_CastShadows'] = True
        target['m_SurfaceType'] = 0
        target['m_AllowMaterialOverride'] = True
    else:
        target['m_KeepLightingVariants'] = True
        target['m_DefaultSSAO'] = False
        target['m_DefaultDecalBlending'] = False
    result.append(target)

def uid(name):
    return uuid.uuid5(uuid.NAMESPACE_URL, 'BrahmaWujian/' + name).hex

def existing_meta_guid(path, fallback):
    """Keep Unity's imported GUID stable when regenerating the graph."""
    if path.exists():
        for line in path.read_text(encoding='utf-8-sig').splitlines():
            if line.startswith('guid: '):
                return line.removeprefix('guid: ').strip()
    return fallback

def clone(kind, name):
    obj = copy.deepcopy(prototypes[kind])
    obj['m_ObjectId'] = uid(name)
    result.append(obj)
    return obj

def slot(kind, name, index, output=False):
    obj = clone(kind + 'MaterialSlot', name + '/slot')
    obj.update(m_Id=index, m_DisplayName=name.split('/')[-1], m_ShaderOutputName=name.split('/')[-1],
               m_SlotType=int(output), m_StageCapability=3)
    if 'm_Value' in obj:
        obj['m_Value'] = copy.deepcopy(obj['m_DefaultValue'])
    return obj

def node(kind, name, x, y):
    obj = clone(kind, name)
    obj['m_Group'] = {'m_Id': ''}
    obj['m_DrawState']['m_Position'].update(x=x, y=y, width=220, height=100)
    obj['m_PreviewExpanded'] = False
    obj['m_Precision'] = 1
    graph['m_Nodes'].append({'m_Id': obj['m_ObjectId']})
    return obj

def connect(a, a_slot, b, b_slot):
    graph['m_Edges'].append({'m_OutputSlot': {'m_Node': {'m_Id': a['m_ObjectId']}, 'm_SlotId': a_slot},
                             'm_InputSlot': {'m_Node': {'m_Id': b['m_ObjectId']}, 'm_SlotId': b_slot}})

# Original material names are retained, so the imported bindings remain inspectable.
textures = ['_BaseMap', '_BumpMap', '_RMOTex', '_RampMap', '_RampMask', '_BlendTex',
            '_HairMaskTex', '_StockingBumpMap', '_NoiseMap', '_SparkleMap']
colors = {
    '_BaseColor': [1, 1, 1, 1], '_HairAnisotropyColor': [1, 1, 1, 1],
    '_StockingCenterColor': [1, 1, 1, 1], '_StockingFalloffColor': [.2, .2, .2, 1],
    '_EmissiveColor': [1, 1, 1, 1], '_RimLightTintColor': [1, 1, 1, 1],
    '_StudyShadowTint': [.69, .59, .64, 1], '_OutlineColor': [.3, .3, .3, 1],
}
vectors = {'_RampMaskChannel': [0, 0, 0, 1], '_Tiling': [1, 1, 0, 0],
           '_RoughnessRemap': [0, 1, 1, 0], '_MetallicRemap': [0, 1, 1, 0],
           '_OcclusionRemap': [0, 1, 1, 0], '_HeadForward': [0, 0, -1, 0],
           '_HeadRight': [1, 0, 0, 0]}
floats = {
    '_FaceMode': 0, '_HairMode': 0, '_EyeMode': 0, '_FurMode': 0, '_EffectMode': 0,
    '_NormalScale': 1, '_UseAlphaTest': 0, '_Cutoff': .5, '_CharacterSurface': 0,
    '_Roughness': 1, '_Metallic': 1, '_Occlusion': 1, '_UseRampMap': 1, '_RampCount': 10,
    '_UseRampMaskRGBChannel': 0, '_Anisotropy': 1, '_AnisotropyPow': 72, '_AnisotropyShift': .05,
    '_UseStockingFalloff': 0, '_StockingInt': .55, '_StockingNormalIntensity': .2,
    '_EmissiveIntensity': 0, '_UseRimLight': 1, '_RimLightIntensity': 1,
    '_RimMidPoint': .65, '_RimWidth': .18, '_RimColorMixAlbedo': .5,
    '_StudyRampWeight': .22, '_StudySpecularWeight': .12, '_StudyRimWeight': .045,
    '_StudyLightFloor': .85, '_StudyShadowStrength': .65, '_StudySparkle': 0,
    '_StudyNormalWeight': 1, '_StudyOpacity': 1,
    '_HairShadowX': .0045, '_HairShadowY': .0075, '_HairTranEAlpha': .5,
    '_UseFringeShadowCaster': 0, '_UseFringeShadowReceiver': 0, '_UseHairTranE': 0,
    '_StencilComp': 8, '_StencilOp': 0, '_StencilRefC': 206, '_WriteMask': 255,
    '_StencilRefShadowCaster': 200, '_StencilRefShadowReceiver': 201,
    '_BlendAlphaSrc': 1, '_BlendAlphaDst': 0,
    '_OutlineWidth': 2, '_OutlineIntensity': 1, '_OutlineZBias': .001,
    '_FurExtrudeStrength': .015, '_NoisePower': 1, '_Timing': .6,
}
# Keep every original-facing control on the blackboard, but do not consume
# unused values in the Custom Function.  Shader Graph 17 mis-generates the
# second output when a Custom Function slot index reaches 65.
connected_floats = [name for name in list(floats)[:36]
                    if name not in {'_CharacterSurface', '_UseRampMaskRGBChannel', '_HairShadowX'}]
connected = textures + list(colors)[:7] + list(vectors) + connected_floats
properties = [(n, 'Texture2D', None) for n in textures]
properties += [(n, 'Color', dict(zip('rgba', v))) for n, v in colors.items()]
properties += [(n, 'Vector4', dict(zip('xyzw', v))) for n, v in vectors.items()]
properties += [(n, 'Vector1', v) for n, v in floats.items()]
hlsl_meta = DEST / 'BrahmaLighting.hlsl.meta'
hlsl_guid = existing_meta_guid(hlsl_meta, uid('BrahmaLighting.hlsl'))
function = node('CustomFunctionNode', 'BrahmaSurface', 400, 0)
function.update(m_FunctionName='BrahmaSurface', m_FunctionSource=hlsl_guid,
                m_SourceType=0, m_FunctionBody='', m_FunctionSourceUsePragmas=True, m_Slots=[])
arguments = []
for index, (name, kind) in enumerate([('UV', 'Vector4'), ('PositionWS', 'Vector3'),
                                      ('NormalWS', 'Vector3'), ('TangentWS', 'Vector3')]):
    geometry = node('UVNode' if index == 0 else 'NormalVectorNode', name, -850, index * 150)
    if index == 1:
        geometry['m_Type'] = 'UnityEditor.ShaderGraph.PositionNode'
        geometry['m_PositionSource'] = 0
    if index == 3:
        geometry['m_Type'] = 'UnityEditor.ShaderGraph.TangentVectorNode'
    geometry['m_Space'] = 2
    output = slot(kind, name + '/Out', 0, True)
    geometry['m_Slots'] = [{'m_Id': output['m_ObjectId']}]
    entry = slot(kind, 'function/' + name, index)
    entry['m_StageCapability'] = 2
    function['m_Slots'].append({'m_Id': entry['m_ObjectId']})
    connect(geometry, 0, function, index)
    arguments.append(('float4' if kind == 'Vector4' else 'float3', name))

for i, (name, kind, value) in enumerate(properties):
    prop = clone(kind + 'ShaderProperty', name + '/property')
    prop.update(m_Name=name, m_OverrideReferenceName=name, m_DefaultReferenceName=name,
                m_GeneratePropertyBlock=True, m_Hidden=False,
                m_Guid={'m_GuidSerialized': str(uuid.UUID(uid(name + '/guid')))})
    if value is not None:
        prop['m_Value'] = value
    if kind == 'Texture2D':
        prop['m_DefaultType'] = 1 if name == '_BumpMap' or name == '_StockingBumpMap' else 0
    graph['m_Properties'].append({'m_Id': prop['m_ObjectId']})
    if name not in connected:
        continue
    slot_kind = 'Vector4' if kind == 'Color' else kind
    propnode = node('PropertyNode', name + '/node', -400, i * 110)
    propnode['m_Property'] = {'m_Id': prop['m_ObjectId']}
    output = slot(slot_kind, name + '/Out', 0, True)
    propnode['m_Slots'] = [{'m_Id': output['m_ObjectId']}]
    number = len(arguments)
    entry = slot(slot_kind, 'function/' + name[1:], number)
    entry['m_StageCapability'] = 2
    function['m_Slots'].append({'m_Id': entry['m_ObjectId']})
    connect(propnode, 0, function, number)
    arguments.append(({'Texture2D': 'UnityTexture2D', 'Vector1': 'float', 'Vector4': 'float4'}[slot_kind], name[1:]))

for name, kind, block_name in [('Color', 'Vector3', 'SurfaceDescription.BaseColor'),
                               ('Alpha', 'Vector1', 'SurfaceDescription.Alpha')]:
    index = len(arguments)
    entry = slot(kind, 'function/' + name, index, True)
    entry['m_StageCapability'] = 2
    function['m_Slots'].append({'m_Id': entry['m_ObjectId']})
    block = next(b for b in blocks if b['m_Name'] == block_name)
    connect(function, index, block, 0)
    arguments.append(('out float3' if kind == 'Vector3' else 'out float', name))

(DEST / 'BrahmaSurface.shadergraph').write_text('\n\n'.join(json.dumps(o, indent=4) for o in result), encoding='utf-8')
if not hlsl_meta.exists():
    hlsl_meta.write_text('fileFormatVersion: 2\nguid: ' + hlsl_guid + '\nShaderIncludeImporter:\n  externalObjects: {}\n  userData: \n  assetBundleName: \n  assetBundleVariant: \n', encoding='utf-8')
signature = 'void BrahmaSurface_float(\n    ' + ',\n    '.join(t + ' ' + n for t, n in arguments) + ')\n'
(ROOT / 'Tools/AetherGazerResearch/brahma-function-signature.txt').write_text(signature, encoding='utf-8')
print('Graph nodes', len(graph['m_Nodes']), 'properties', len(properties), 'function arguments', len(arguments))
