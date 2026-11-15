using UnityEngine;

namespace WuchangStudy
{
    [ExecuteAlways]
    public sealed class WuchangLighting : MonoBehaviour
    {
        public Light keyLight;
        public Camera studyCamera;
        public Renderer[] surfaces;
        private MaterialPropertyBlock properties;
        private static readonly int LightDirection = Shader.PropertyToID("_StudyLightDirection");
        private static readonly int HalfVector = Shader.PropertyToID("_HalfVector");

        private void LateUpdate()
        {
            if (!keyLight || !studyCamera || surfaces == null)
                return;

            properties ??= new MaterialPropertyBlock();
            Vector3 lightDirection = -keyLight.transform.forward;
            foreach (Renderer surface in surfaces)
            {
                if (!surface)
                    continue;
                Vector3 viewDirection = (studyCamera.transform.position - surface.bounds.center).normalized;
                surface.GetPropertyBlock(properties);
                properties.SetVector(LightDirection, lightDirection);
                properties.SetVector(HalfVector, (lightDirection + viewDirection).normalized);
                surface.SetPropertyBlock(properties);
            }
        }
    }
}
