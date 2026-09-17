using UnityEngine;
using UnityEngine.Rendering;
[ExecuteAlways]
public sealed class DaiyanPipelineScope:MonoBehaviour
{
 public RenderPipelineAsset pipeline;RenderPipelineAsset previous;bool applied;
 void OnEnable(){if(pipeline){previous=QualitySettings.renderPipeline;QualitySettings.renderPipeline=pipeline;applied=true;}}
 void OnDisable(){if(applied&&QualitySettings.renderPipeline==pipeline)QualitySettings.renderPipeline=previous;applied=false;}
}
