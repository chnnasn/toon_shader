using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace BrahmaWujianStudy.Editor
{
    public static class BrahmaReferenceCalibration
    {
        const string Root = "Assets/Studies/BrahmaWujianStudy";

        [MenuItem("Tools/Studies/Brahma Wujian/Apply Screenshot Calibration")]
        public static void Apply()
        {
            ApplyToScene();
            foreach (string id in new[] { "102003", "605603" })
            {
                GameObject form = GameObject.Find("Brahma_Wujian_" + id);
                PrefabUtility.SaveAsPrefabAsset(form, Root + "/Prefabs/" + form.name + ".prefab");
            }
            AssetDatabase.SaveAssets();
            EditorSceneManager.SaveScene(UnityEngine.SceneManagement.SceneManager.GetActiveScene());
            Debug.Log("Brahma screenshot calibration saved.");
        }

        internal static void ApplyToScene()
        {
            foreach (string id in new[] { "102003", "605603" })
            {
                GameObject form = GameObject.Find("Brahma_Wujian_" + id);
                Vector3 position = form.transform.position;
                position.x = id == "102003" ? -.66f : .66f;
                form.transform.position = position;
                foreach (ParticleSystem particles in form.GetComponentsInChildren<ParticleSystem>())
                    particles.Simulate(2, true, true, true);
                foreach (string guid in AssetDatabase.FindAssets("t:Material", new[] { Root + "/Materials/" + id }))
                {
                    string path = AssetDatabase.GUIDToAssetPath(guid);
                    Material material = AssetDatabase.LoadAssetAtPath<Material>(path);
                    string name = Path.GetFileNameWithoutExtension(path);
                    BrahmaWujianStudyBuilder.ConfigureMaterial(material, name, id);
                    if (name.StartsWith("fx_", StringComparison.Ordinal))
                    {
                        Texture mask = material.GetTexture("_Tex_Mask");
                        material.SetTexture("_EffectMask", mask ? mask : Texture2D.whiteTexture);
                        Vector2 scale = material.GetTextureScale("_Tex_Mask");
                        Vector2 offset = material.GetTextureOffset("_Tex_Mask");
                        material.SetVector("_EffectMask_ST", new Vector4(scale.x, scale.y, offset.x, offset.y));
                        material.SetFloat("_StudyOpacity", name.Contains("hair_texiao1") ? .85f : name.Contains("texiao3") ? .12f : .18f);
                    }
                    if (material.GetFloat("_FurMode") > .5f)
                    {
                        string noiseGuid = AssetDatabase.FindAssets("fur_noise t:Texture2D", new[] { Root + "/SourceArt" }).FirstOrDefault();
                        if (noiseGuid != null)
                            material.SetTexture("_NoiseMap", AssetDatabase.LoadAssetAtPath<Texture>(AssetDatabase.GUIDToAssetPath(noiseGuid)));
                    }
                    EditorUtility.SetDirty(material);
                }
            }

            RenderSettings.ambientMode = AmbientMode.Trilight;
            RenderSettings.ambientSkyColor = new Color(.70f, .77f, .82f);
            RenderSettings.ambientEquatorColor = new Color(.62f, .68f, .72f);
            RenderSettings.ambientGroundColor = new Color(.43f, .48f, .57f);
            RenderSettings.ambientIntensity = 1;
            RenderSettings.fog = false;
            RenderSettings.skybox = GetMaterial("BrahmaStudioSky", "AetherGazer/Brahma Wujian/Studio Sky");
            RenderSettings.skybox.SetColor("_Top", new Color(.70f, .75f, .80f));
            RenderSettings.skybox.SetColor("_Horizon", new Color(.82f, .85f, .86f));
            RenderSettings.defaultReflectionMode = DefaultReflectionMode.Custom;
            RenderSettings.customReflectionTexture = CreateStudioReflection();
            RenderSettings.reflectionIntensity = 1;

            Light key = GameObject.Find("Key Light").GetComponent<Light>();
            key.color = new Color(1, .985f, .97f);
            key.intensity = 1.08f;
            key.transform.rotation = Quaternion.Euler(42, -24, 0);
            key.shadows = LightShadows.Soft;
            key.shadowStrength = .55f;
            key.shadowBias = .035f;
            key.shadowNormalBias = .12f;
            RenderSettings.sun = key;
            Light fill = GameObject.Find("Fill Light").GetComponent<Light>();
            fill.color = new Color(.78f, .91f, 1);
            fill.intensity = .36f;
            fill.transform.rotation = Quaternion.Euler(15, 135, 0);
            fill.shadows = LightShadows.None;

            Camera camera = GameObject.Find("Study Camera").GetComponent<Camera>();
            camera.transform.position = new Vector3(0, 1.02f, -4.7f);
            camera.transform.LookAt(new Vector3(0, .91f, 0));
            camera.clearFlags = CameraClearFlags.Skybox;
            camera.GetUniversalAdditionalCameraData().renderPostProcessing = false;
            camera.GetUniversalAdditionalCameraData().antialiasing = AntialiasingMode.SubpixelMorphologicalAntiAliasing;
            GameObject floor = GameObject.Find("Study Floor");
            floor.GetComponent<Renderer>().sharedMaterial = GetMaterial("BrahmaStudyFloor", "AetherGazer/Brahma Wujian/Studio Floor");
            floor.GetComponent<Renderer>().sharedMaterial.SetColor("_BaseColor", new Color(.56f, .62f, .70f));
            floor.transform.localScale = new Vector3(12, 1, 12);
            BrahmaWujianPipeline pipeline = UnityEngine.Object.FindAnyObjectByType<BrahmaWujianPipeline>();
            pipeline.reflectionPlaneY = floor.transform.position.y;
            pipeline.outline = true;
            pipeline.hairTransmission = false;
            pipeline.furLayers = 24;
            pipeline.Rebuild();
            EditorUtility.SetDirty(pipeline);
        }

        static Material GetMaterial(string name, string shaderName)
        {
            string path = Root + "/Rendering/" + name + ".mat";
            Shader shader = Shader.Find(shaderName);
            if (!shader || ShaderUtil.ShaderHasError(shader)) throw new InvalidOperationException(shaderName + " has shader errors.");
            Material material = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (!material)
            {
                material = new Material(shader) { name = name };
                AssetDatabase.CreateAsset(material, path);
            }
            material.shader = shader;
            EditorUtility.SetDirty(material);
            return material;
        }

        static Cubemap CreateStudioReflection()
        {
            string path = Root + "/Rendering/BrahmaStudioReflection.asset";
            Cubemap cube = AssetDatabase.LoadAssetAtPath<Cubemap>(path);
            if (cube) return cube;
            const int size = 64;
            cube = new Cubemap(size, TextureFormat.RGBAHalf, true) { name = "Brahma Studio Softboxes" };
            for (int face = 0; face < 6; face++)
            {
                Color[] pixels = new Color[size * size];
                for (int y = 0; y < size; y++)
                for (int x = 0; x < size; x++)
                {
                    float u = 2 * (x + .5f) / size - 1;
                    float v = 2 * (y + .5f) / size - 1;
                    Vector3 direction = face switch
                    {
                        0 => new Vector3(1, -v, -u), 1 => new Vector3(-1, -v, u),
                        2 => new Vector3(u, 1, v), 3 => new Vector3(u, -1, -v),
                        4 => new Vector3(u, -v, 1), _ => new Vector3(-u, -v, -1)
                    };
                    direction.Normalize();
                    Color ambient = Color.Lerp(new Color(.13f,.17f,.23f), new Color(.55f,.63f,.69f), direction.y * .5f + .5f);
                    float softbox = Mathf.Pow(Mathf.Max(0, Vector3.Dot(direction, new Vector3(.4f,.6f,-.7f).normalized)), 28);
                    float fillbox = Mathf.Pow(Mathf.Max(0, Vector3.Dot(direction, new Vector3(-.7f,.2f,.4f).normalized)), 20);
                    pixels[y * size + x] = ambient + new Color(2.4f,2.3f,2.2f) * softbox + new Color(.6f,.85f,1.1f) * fillbox;
                }
                cube.SetPixels(pixels, (CubemapFace)face);
            }
            cube.Apply(true, false);
            AssetDatabase.CreateAsset(cube, path);
            return cube;
        }

        [MenuItem("Tools/Studies/Brahma Wujian/Render Reference Views")]
        public static void CaptureViews()
        {
            Camera camera = GameObject.Find("Study Camera").GetComponent<Camera>();
            GameObject[] forms = { GameObject.Find("Brahma_Wujian_102003"), GameObject.Find("Brahma_Wujian_605603") };
            bool[] active = forms.Select(form => form.activeSelf).ToArray();
            Vector3 position = camera.transform.position;
            Quaternion rotation = camera.transform.rotation;
            float fov = camera.fieldOfView;
            float aspect = camera.aspect;
            try
            {
                foreach (GameObject form in forms)
                {
                    foreach (GameObject other in forms) other.SetActive(other == form);
                    Renderer[] renderers = form.GetComponentsInChildren<Renderer>().Where(r => r.enabled && r is not ParticleSystemRenderer).ToArray();
                    Bounds bounds = renderers[0].bounds;
                    foreach (Renderer renderer in renderers.Skip(1)) bounds.Encapsulate(renderer.bounds);
                    camera.fieldOfView = 27;
                    camera.aspect = .8f;
                    float distance = Mathf.Max(bounds.size.y, bounds.size.x / camera.aspect) * .56f /
                        Mathf.Tan(camera.fieldOfView * Mathf.Deg2Rad * .5f);
                    foreach (int angle in new[] { 0, 90, 180 })
                    {
                        camera.transform.position = bounds.center + Quaternion.Euler(0, angle, 0) * new Vector3(0, .02f, -distance);
                        camera.transform.LookAt(bounds.center);
                        Capture(camera, Root + "/Rendering/" + form.name + "_" + angle + ".png", 1200, 1500);
                    }
                    Vector3 target = new(bounds.center.x, bounds.max.y - bounds.size.y * .31f, bounds.center.z);
                    camera.transform.position = target + new Vector3(0, 0, -distance * .63f);
                    camera.transform.LookAt(target);
                    Capture(camera, Root + "/Rendering/" + form.name + "_Detail.png", 1200, 1500);
                    camera.transform.position = bounds.center + Quaternion.Euler(0, 35, 0) * new Vector3(0, .02f, -distance);
                    camera.transform.LookAt(bounds.center);
                    Capture(camera, Root + "/Rendering/" + form.name + "_ThreeQuarter.png", 1200, 1500);
                    Vector3 legs = new(bounds.center.x, bounds.min.y + bounds.size.y * .28f, bounds.center.z);
                    camera.transform.position = legs + new Vector3(0, .03f, -distance * .59f);
                    camera.transform.LookAt(legs);
                    Capture(camera, Root + "/Rendering/" + form.name + "_Legs.png", 1200, 1500);
                }
            }
            finally
            {
                for (int i = 0; i < forms.Length; i++) forms[i].SetActive(active[i]);
                camera.transform.SetPositionAndRotation(position, rotation);
                camera.fieldOfView = fov;
                camera.aspect = aspect;
            }
            AssetDatabase.Refresh();
            Debug.Log("Brahma front, side, back and material detail renders saved.");
        }

        internal static void Capture(Camera camera, string path, int width, int height)
        {
            RenderTexture previous = RenderTexture.active;
            RenderTexture oldTarget = camera.targetTexture;
            float aspect = camera.aspect;
            RenderTexture target = new(width * 2, height * 2, 24, RenderTextureFormat.ARGB32);
            RenderTexture resolved = new(width, height, 0, RenderTextureFormat.ARGB32);
            Texture2D image = new(width, height, TextureFormat.RGB24, false);
            try
            {
                camera.aspect = width / (float)height;
                camera.targetTexture = target;
                camera.Render();
                Graphics.Blit(target, resolved);
                RenderTexture.active = resolved;
                image.ReadPixels(new Rect(0,0,width,height),0,0);
                image.Apply();
                File.WriteAllBytes(path, image.EncodeToPNG());
            }
            finally
            {
                camera.targetTexture = oldTarget;
                camera.aspect = aspect;
                RenderTexture.active = previous;
                UnityEngine.Object.DestroyImmediate(image);
                UnityEngine.Object.DestroyImmediate(target);
                UnityEngine.Object.DestroyImmediate(resolved);
            }
        }

        [MenuItem("Tools/Studies/Brahma Wujian/Validate Rendering")]
        public static void ValidateRendering()
        {
            Directory.CreateDirectory(".tmp");
            foreach (string guid in AssetDatabase.FindAssets("t:Material", new[] { Root + "/Materials", Root + "/Rendering" }))
            {
                Material material = AssetDatabase.LoadAssetAtPath<Material>(AssetDatabase.GUIDToAssetPath(guid));
                for (int pass = 0; pass < material.passCount; pass++)
                    ShaderUtil.CompilePass(material, pass, true);
                if (ShaderUtil.ShaderHasError(material.shader))
                    throw new InvalidOperationException("Shader failed compilation: " + material.shader.name);
            }
            Camera camera = GameObject.Find("Study Camera").GetComponent<Camera>();
            Light fill = GameObject.Find("Fill Light").GetComponent<Light>();
            Material floor = GameObject.Find("Study Floor").GetComponent<Renderer>().sharedMaterial;
            Vector3 position = camera.transform.position;
            Quaternion rotation = camera.transform.rotation;
            float aspect = camera.aspect;
            float reflection = floor.GetFloat("_ReflectionStrength");
            float fillIntensity = fill.intensity;
            try
            {
                camera.aspect = 1.5f;
                camera.transform.position = new Vector3(0, 2.3f, -5.8f);
                camera.transform.LookAt(new Vector3(0, .7f, 0));
                floor.SetFloat("_ReflectionStrength", .6f);
                Capture(camera, ".tmp/BrahmaReflectionOn.png", 1200, 800);
                floor.SetFloat("_ReflectionStrength", 0);
                Capture(camera, ".tmp/BrahmaReflectionOff.png", 1200, 800);
                fill.intensity = 0;
                Capture(camera, ".tmp/BrahmaFillOff.png", 1200, 800);
            }
            finally
            {
                camera.transform.SetPositionAndRotation(position, rotation);
                camera.aspect = aspect;
                floor.SetFloat("_ReflectionStrength", reflection);
                fill.intensity = fillIntensity;
            }
            Debug.Log("Brahma shader passes compiled. Reflection and fill-light comparison frames saved to .tmp.");
        }

    }
}
