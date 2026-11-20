using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

// All falling drops and their landing rings share one transparent draw.
internal sealed class LinnaeRainField
{
    readonly Mesh mesh;
    readonly Material material;
    readonly GameObject volume;
    readonly MeshRenderer renderer;

    public LinnaeRainField(Shader shader, Transform owner)
    {
        mesh = BuildMesh();
        material = CoreUtils.CreateEngineMaterial(shader);
        volume = new GameObject("Linnae rain") { hideFlags = HideFlags.HideAndDontSave };
        volume.transform.SetParent(owner, false);
        volume.AddComponent<MeshFilter>().sharedMesh = mesh;
        renderer = volume.AddComponent<MeshRenderer>();
        renderer.sharedMaterial = material;
        renderer.shadowCastingMode = ShadowCastingMode.Off;
        renderer.receiveShadows = false;
    }

    public void Apply(Vector3 origin, float amount)
    {
        // Cancel camera rotation so gravity and wind remain in world space.
        volume.transform.SetPositionAndRotation(origin, Quaternion.identity);
        renderer.enabled = amount > .001f;
        material.SetFloat("_RainAmount", amount);
    }

    public void Release()
    {
        CoreUtils.Destroy(volume);
        CoreUtils.Destroy(mesh);
        CoreUtils.Destroy(material);
    }

    static Mesh BuildMesh()
    {
        var positions = new List<Vector3>();
        var uv = new List<Vector2>();
        var seeds = new List<Vector4>();
        var indices = new List<int>();
        var random = new System.Random(3187);
        float Sample() => (float)random.NextDouble();
        var corners = new[] {new Vector2(-1,-1),new Vector2(1,-1),new Vector2(1,1),new Vector2(-1,1)};
        void Quad(Vector3 landing, Vector4 seed)
        {
            int start = positions.Count;
            foreach (var corner in corners) { positions.Add(landing); uv.Add(corner); seeds.Add(seed); }
            indices.Add(start); indices.Add(start+1); indices.Add(start+2);
            indices.Add(start); indices.Add(start+2); indices.Add(start+3);
        }
        for (int i = 0; i < 1100; i++)
        {
            var landing = new Vector3((Sample()-.5f)*6, 0, (Sample()-.5f)*5.2f);
            var seed = new Vector4(Sample(),Sample(),Sample(),0);
            Quad(landing, seed);
            // Only the circular display plinth receives visible impacts.
            if (landing.sqrMagnitude < .74f*.74f) { seed.w = 1; Quad(landing,seed); }
        }
        var result = new Mesh { name="Linnae rain volume", hideFlags=HideFlags.HideAndDontSave };
        result.SetVertices(positions); result.SetUVs(0,uv); result.SetUVs(1,seeds);
        result.SetTriangles(indices,0);
        result.bounds = new Bounds(new Vector3(0,1.9f,0),new Vector3(7,4.2f,6));
        result.UploadMeshData(true);
        return result;
    }
}
