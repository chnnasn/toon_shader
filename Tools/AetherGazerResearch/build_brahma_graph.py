"""Build the readable Brahma teaching Shader Graph.

The runtime reconstruction remains the handwritten multipass shader because
Shader Graph cannot author the recovered stencil/fixed-function pass contract.
This graph is intentionally a visible, node-by-node study of the material
evaluation. It contains no Custom Function node and no duplicate pass graphs.
"""
import copy
import json
import sys
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "Assets/Studies/WuchangStudy/Shaders/WuchangSurface.shadergraph"
DEST = ROOT / "Assets/Studies/BrahmaWujianStudy/Shaders/BrahmaSurface.shadergraph"

# The graph is now meant to be hand-arranged for learning. Regeneration must be
# an explicit decision so a later tool run cannot erase the user's layout.
if DEST.exists() and "--overwrite" not in sys.argv:
    print("BrahmaSurface already exists; preserving manual node layout. "
          "Pass --overwrite only when a full regeneration is intended.")
    raise SystemExit(0)


def objects(path):
    text = path.read_text(encoding="utf-8-sig")
    result = []
    while text.strip():
        value, end = json.JSONDecoder().raw_decode(text.lstrip())
        result.append(value)
        text = text.lstrip()[end:]
    return result


def uid(name):
    return uuid.uuid5(uuid.NAMESPACE_URL, "BrahmaWujian/ReadableGraph/" + name).hex


def replace_strings(value, replacements):
    if isinstance(value, str):
        for old, new in replacements.items():
            value = value.replace(old, new)
        return value
    if isinstance(value, list):
        return [replace_strings(item, replacements) for item in value]
    if isinstance(value, dict):
        return {key: replace_strings(item, replacements) for key, item in value.items()}
    return value


items = copy.deepcopy(objects(SOURCE))
replacements = {
    "AetherGazer/Wuchang Study": "AetherGazer/Brahma Wujian/Teaching Surface",
    "_RMKMap": "_RMOTex",
    "RMK (R metallic, G emissive, B AO, A roughness)": "RMO (R metallic, G emissive, B AO, A roughness)",
    "_RMKOcclusionStrength": "_Occlusion",
    "RMK AO": "Occlusion strength",
    "_HairMaskMap": "_HairMaskTex",
    "_HairMaskStrength": "_Anisotropy",
    "_StockingNormalMap": "_StockingBumpMap",
    "_StockingPatternStrength": "_StockingNormalIntensity",
    "_StockingStrength": "_UseStockingFalloff",
    "_StockingTiling": "_Tiling",
    "_FaceSDFMap": "_BlendTex",
    "_FaceSDFStrength": "_FaceMode",
    "_FaceShadowTint": "_StudyFaceShadowTint",
    "_ShadowColor": "_StudyShadowTint",
    "_RampStrength": "_StudyRampWeight",
    "_SpecStrength": "_StudySpecularWeight",
    "_RimStrength": "_StudyRimWeight",
    "_Opacity": "_StudyOpacity",
    "_AlphaClip": "_UseAlphaTest",
}
items = replace_strings(items, replacements)
graph = items[0]
by_id = {item["m_ObjectId"]: item for item in items if "m_ObjectId" in item}
graph["m_Path"] = "AetherGazer/Brahma Wujian/Teaching Surface"

category_rules = [
    ("01 Base & Masks", {"_BaseMap", "_BaseColor", "_RMOTex", "_Occlusion"}),
    ("02 Toon Lighting", {"_RampMap", "_StudyShadowTint", "_ShadowRange", "_StudyRampWeight", "_RampRow"}),
    ("03 Specular & Rim", {"_StudySpecularWeight", "_StudyRimWeight"}),
    ("04 Hair", {"_HairMaskTex", "_Anisotropy"}),
    ("05 Face SDF", {"_BlendTex", "_FaceMode", "_StudyFaceShadowTint"}),
    ("06 Stocking", {"_StockingBumpMap", "_StockingCenterColor", "_StockingFalloffColor",
                      "_UseStockingFalloff", "_StockingNormalIntensity", "_Tiling"}),
    ("07 Surface", {"_StudyOpacity", "_UseAlphaTest"}),
]
properties = []
for ref in graph["m_Properties"]:
    prop = by_id[ref["m_Id"]]
    reference = prop.get("m_OverrideReferenceName") or prop.get("m_DefaultReferenceName")
    properties.append((reference, prop["m_ObjectId"]))

graph["m_CategoryData"] = []
for title, members in category_rules:
    child_ids = [object_id for reference, object_id in properties if reference in members]
    if not child_ids:
        continue
    category_id = uid("Category/" + title)
    graph["m_CategoryData"].append({"m_Id": category_id})
    items.append({
        "m_SGVersion": 0,
        "m_Type": "UnityEditor.ShaderGraph.CategoryData",
        "m_ObjectId": category_id,
        "m_Name": title,
        "m_ChildObjectList": [{"m_Id": object_id} for object_id in child_ids],
    })

bands = [
    ("01 Base Texture & Alpha", -10000, -200),
    ("02 Toon Diffuse & Ramp", -200, 700),
    ("03 Rim / View Edge", 700, 1100),
    ("04 Specular & RMO", 1100, 1450),
    ("05 Hair Anisotropy", 1450, 1850),
    ("06 Stocking Layer", 1850, 2250),
    ("07 Face SDF & Final Combine", 2250, 10000),
]
graph["m_GroupDatas"] = []
groups = {}
group_objects = {}
for title, low, _ in bands:
    group_id = uid("Group/" + title)
    groups[title] = group_id
    graph["m_GroupDatas"].append({"m_Id": group_id})
    group_object = {
        "m_SGVersion": 0,
        "m_Type": "UnityEditor.ShaderGraph.GroupData",
        "m_ObjectId": group_id,
        "m_Title": title,
        "m_Position": {"x": 0.0, "y": 0.0},
    }
    group_objects[title] = group_object
    items.append(group_object)

for node_ref in graph["m_Nodes"]:
    node = by_id.get(node_ref["m_Id"])
    if not node or node.get("m_Type", "").endswith("BlockNode"):
        continue
    position = node.get("m_DrawState", {}).get("m_Position", {})
    y = float(position.get("y", 0.0))
    for title, low, high in bands:
        if low <= y < high:
            node["m_Group"] = {"m_Id": groups[title]}
            break

# Put chapters on a stable two-column page. Nodes keep their authored order
# inside each chapter, but no group is allowed to overlap another group.
layout_targets = {
    "01 Base Texture & Alpha": (-3000.0, 0.0),
    "02 Toon Diffuse & Ramp": (-3000.0, 900.0),
    "03 Rim / View Edge": (-3000.0, 1800.0),
    "04 Specular & RMO": (-3000.0, 2700.0),
    "05 Hair Anisotropy": (200.0, 0.0),
    "06 Stocking Layer": (200.0, 1100.0),
    "07 Face SDF & Final Combine": (200.0, 2200.0),
}
for title, target in layout_targets.items():
    group_id = groups[title]
    members = []
    for node_ref in graph["m_Nodes"]:
        node = by_id.get(node_ref["m_Id"])
        if node and node.get("m_Group", {}).get("m_Id") == group_id:
            members.append(node)
    if not members:
        continue
    min_x = min(float(node["m_DrawState"]["m_Position"].get("x", 0.0)) for node in members)
    min_y = min(float(node["m_DrawState"]["m_Position"].get("y", 0.0)) for node in members)
    delta_x = target[0] - min_x
    delta_y = target[1] - min_y
    for node in members:
        position = node["m_DrawState"]["m_Position"]
        position["x"] = float(position.get("x", 0.0)) + delta_x
        position["y"] = float(position.get("y", 0.0)) + delta_y
    group_objects[title]["m_Position"] = {"x": target[0] - 80.0, "y": target[1] - 170.0}

chapter_notes = {
    "01 Base Texture & Alpha": "BaseMap × BaseColor. Alpha is kept separate for clip/opacity.",
    "02 Toon Diffuse & Ramp": "N·L remap → band/ramp lookup → shadow tint blend.",
    "03 Rim / View Edge": "View direction and normal build a controllable silhouette response.",
    "04 Specular & RMO": "RMO channels drive occlusion/specular response before final lighting.",
    "05 Hair Anisotropy": "Hair mask modulates the strand highlight before it joins the surface.",
    "06 Stocking Layer": "Tiled normal and view falloff tint the base surface as a separate layer.",
    "07 Face SDF & Final Combine": "Face SDF selects lit/shadow color, then all modules are combined.",
}
graph["m_StickyNoteDatas"] = []
for title, content in chapter_notes.items():
    note_id = uid("Sticky/" + title)
    x, y = layout_targets[title]
    graph["m_StickyNoteDatas"].append({"m_Id": note_id})
    items.append({
        "m_SGVersion": 0,
        "m_Type": "UnityEditor.ShaderGraph.StickyNoteData",
        "m_ObjectId": note_id,
        "m_Title": title,
        "m_Content": content,
        "m_TextSize": 0,
        "m_Theme": 0,
        "m_Position": {"serializedVersion": "2", "x": x, "y": y - 140.0,
                       "width": 560.0, "height": 100.0},
        "m_Group": {"m_Id": groups[title]},
    })

note_id = uid("Sticky/ReadMe")
graph["m_StickyNoteDatas"].append({"m_Id": note_id})
items.append({
    "m_SGVersion": 0,
    "m_Type": "UnityEditor.ShaderGraph.StickyNoteData",
    "m_ObjectId": note_id,
    "m_Title": "How to read this graph",
    "m_Content": (
        "Follow groups 01→07. This graph teaches the visible surface data flow: "
        "texture/masks, toon ramp, rim, specular, hair, stocking and face SDF. "
        "Stencil, Outline, Reflection and PreDepth are fixed-function multipass "
        "work and therefore live in BrahmaCharacter.shader + Renderer Feature."
    ),
    "m_TextSize": 0,
    "m_Theme": 1,
    "m_Position": {"serializedVersion": "2", "x": -3000.0, "y": -420.0,
                   "width": 1000.0, "height": 150.0},
    "m_Group": {"m_Id": ""},
})

DEST.write_text("\n\n".join(json.dumps(item, indent=4) for item in items), encoding="utf-8")
print("Readable Brahma graph:", len(graph["m_Nodes"]), "nodes,",
      len(graph["m_Edges"]), "edges,", len(graph["m_Properties"]),
      "properties, 0 Custom Functions,", len(bands), "groups")
