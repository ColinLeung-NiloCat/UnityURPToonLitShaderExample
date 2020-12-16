// For more information, visit -> https://github.com/ColinLeung-NiloCat/UnityURPToonLitShaderExample

/*
This shader is a simple example showing you how to write your first URP custom lit shader(toon) with "minimum" shader code.
You can use this shader as a starting point, add/edit code to develop your own custom lit shader for URP10.2.2 or above.

*Usually, just by editing "SimpleURPToonLitOutlineExample_LightingEquation.hlsl" alone can control most of the visual result.

This shader includes 4 passes:
0.SurfaceColor  pass    (this pass will always render to the color buffer _CameraColorTexture)
1.Outline       pass    (this pass will always render to the color buffer _CameraColorTexture)
2.ShadowCaster  pass    (only for URP's shadow mapping, this pass won't render at all if your character don't cast shadow)
3.DepthOnly     pass    (only for URP's depth texture _CameraDepthTexture's rendering, this pass won't render at all if your project don't render URP's offscreen depth prepass)

*Because most of the time, you use this toon lit shader for unique characters, so all lightmap & GPU instancing related code are removed for simplicity.
*For batching, we only rely on SRP batcher, which is the most practical batching method in URP for rendering lots of unique skinnedmesh characters

*In this shader, we choose static uniform branching over "shader_feature & multi_compile" for some of the togglable feature like "_UseEmission","_UseOcclusion"..., 
because:
    - we want to avoid this shader's build time takes too long (2^n)
    - we want to avoid rendering spike when a new shader variant was seen by the camera first time (create GPU program)
    - we want to avoid increasing ShaderVarientCollection's complexity
    - we want to avoid shader size becomes too large easily (2^n)
    - we want to avoid breaking SRP batcher's batching because SRP batcher is per shader variant batching, not per shader
    - all modern GPU(include newer mobile devices) can handle static uniform branching with "almost" no performance cost
*/
Shader "SimpleURPToonLitExample(With Outline)"
{
    Properties
    {
        // all properties will try to follow URP Lit shader's naming convention
        // so switching your URP lit material's shader to this toon lit shader will preserve most of the original properties if defined in this shader

        // URP Lit shader's naming convention:
        // https://gist.github.com/phi-lira/225cd7c5e8545be602dca4eb5ed111ba#file-universalpipelinetemplateshader-shader

        [Header(Base Color)]
        [MainTexture]_BaseMap("_BaseMap (Albedo)", 2D) = "white" {}
        [HDR][MainColor]_BaseColor("_BaseColor", Color) = (1,1,1,1)

        [Header(Alpha)]
        [Toggle(_UseAlphaClipping)]_UseAlphaClipping("_UseAlphaClipping", Float) = 0
        _Cutoff("_Cutoff (Alpha Cutoff)", Range(0.0, 1.0)) = 0.5

        [Header(Emission)]
        [Toggle]_UseEmission("_UseEmission (on/off Emission completely)", Float) = 0
        [HDR] _EmissionColor("_EmissionColor", Color) = (0,0,0)
        _EmissionMulByBaseColor("_EmissionMulByBaseColor", Range(0,1)) = 0
        [NoScaleOffset]_EmissionMap("_EmissionMap", 2D) = "white" {}
        _EmissionMapChannelMask("_EmissionMapChannelMask", Vector) = (1,1,1,0)

        [Header(Occlusion)]
        [Toggle]_UseOcclusion("_UseOcclusion (on/off Occlusion completely)", Float) = 0
        _OcclusionStrength("_OcclusionStrength", Range(0.0, 1.0)) = 1.0
        _OcclusionIndirectStrength("_OcclusionIndirectStrength", Range(0.0, 1.0)) = 0.5
        _OcclusionDirectStrength("_OcclusionDirectStrength", Range(0.0, 1.0)) = 0.75
        [NoScaleOffset]_OcclusionMap("_OcclusionMap", 2D) = "white" {}
        _OcclusionMapChannelMask("_OcclusionMapChannelMask", Vector) = (1,0,0,0)
        _OcclusionRemapStart("_OcclusionRemapStart", Range(0,1)) = 0
        _OcclusionRemapEnd("_OcclusionRemapEnd", Range(0,1)) = 1

        [Header(Lighting)]
        _IndirectLightMinColor("_IndirectLightMinColor", Color) = (0.1,0.1,0.1,1) // can prevent completely black if lightprobe not baked
        _IndirectLightMultiplier("_IndirectLightMultiplier", Range(0,1)) = 1
        _DirectLightMultiplier("_DirectLightMultiplier", Range(0,1)) = 0.25
        _CelShadeMidPoint("_CelShadeMidPoint", Range(-1,1)) = -.5
        _CelShadeSoftness("_CelShadeSoftness", Range(0,1)) = 0.05
        _MainLightIgnoreCelShade("_MainLightIgnoreCelShade", Range(0,1)) = 0
        _AdditionalLightIgnoreCelShade("_AdditionalLightIgnoreCelShade", Range(0,1)) = 0.9

        [Header(Shadow mapping)]
        _ReceiveShadowMappingAmount("_ReceiveShadowMappingAmount", Range(0,1)) = 0.75
        _ReceiveShadowMappingPosOffset("_ReceiveShadowMappingPosOffset (increase it if is face!)", Float) = 0

        [Header(Outline)]
        _OutlineWidth("_OutlineWidth (World Space)", Range(0,4)) = 1
        _OutlineColor("_OutlineColor", Color) = (0.5,0.5,0.5,1)
        _OutlineZOffset("_OutlineZOffset (View Space) (increase it if is face!)", Range(0,1)) = 0.0001
        [NoScaleOffset]_OutlineZOffsetMaskTex("_OutlineZOffsetMask (black is apply ZOffset)", 2D) = "black" {}
        _OutlineZOffsetMaskRemapStart("_OutlineZOffsetMaskRemapStart", Range(0,1)) = 0
        _OutlineZOffsetMaskRemapEnd("_OutlineZOffsetMaskRemapEnd", Range(0,1)) = 1
    }
    SubShader
    {       
        Tags 
        {
            // SRP introduced a new "RenderPipeline" tag in Subshader. This allows you to create shaders
            // that can match multiple render pipelines. If a RenderPipeline tag is not set it will match
            // any render pipeline. In case you want your subshader to only run in URP, set the tag to
            // "UniversalPipeline"
            
            // for this subshader, we only want to render in URP only.
            // the tag is "UniversalPipeline", not "UniversalRenderPipeline"
            // https://github.com/Unity-Technologies/Graphics/pull/1431/
            "RenderPipeline" = "UniversalPipeline"

            // more explict SubShader tag to avoid confusion (this is a tutorial shader)
            "RenderType"="Opaque"
            "UniversalMaterialType" = "Lit"
            "Queue"="Geometry"
        }
        
        // We can extract all passes shared hlsl code into a HLSLINCLUDE section, just to remove duplicated code in each pass
        HLSLINCLUDE

        // all Passes will need this
        #pragma shader_feature_local_fragment _UseAlphaClipping

        ENDHLSL

        // SurfaceColor pass (Forward lighting). Shades GI, all lights, emission and fog in a single pass.
        // Compared to Builtin pipeline forward renderer, URP forward renderer will
        // render a scene with multiple lights with less drawcalls and less overdraw.
        Pass
        {               
            Name "SurfaceColor"
            Tags
            {
                // "Lightmode" tag must be "UniversalForward" in order to render lit objects in URP.
                "LightMode" = "UniversalForward"
            }

            // more explict render state to avoid confusion (this is a tutorial shader)
            // you can expose these render state to material inspector if needed
            Cull Back
            Blend One Zero
            ZTest LEqual
            ZWrite On

            HLSLPROGRAM

            // -------------------------------------
            // Universal Render Pipeline keywords (you can always copy this section from URP's Lit.shader)
            // When doing custom shaders you most often want to copy and paste these #pragmas
            // These multi_compile variants are stripped from the build depending on:
            // 1) Settings in the URP Asset assigned in the GraphicsSettings at build time
            // e.g If you disabled AdditionalLights in the asset then all _ADDITIONA_LIGHTS variants
            // will be stripped from build
            // 2) Invalid combinations are stripped. e.g variants with _MAIN_LIGHT_SHADOWS_CASCADE
            // but not _MAIN_LIGHT_SHADOWS are invalid and therefore stripped.
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fog
            // -------------------------------------

            #pragma vertex VertexShaderWork
            #pragma fragment ShadeFinalColor

            // because this pass is just a SurfaceColor pass, no need any special #define
            // (no special #define)

            // all shader logic written inside this .hlsl, must write #include AFTER all #define
            #include "SimpleURPToonLitOutlineExample_Shared.hlsl"

            ENDHLSL
        }
        
        // Outline pass. Same as "SurfaceColor" pass, but 
        // -vertex position are pushed out a bit base on normal direction
        // -also color is darker
        // -Cull Front instead of Cull Back because it is a must for extra pass outline method
        Pass 
        {
            Name "Outline"
            Tags 
            {
                //"LightMode" = "UniversalForward" // IMPORTANT: don't write this line for any custom pass! else this outline pass will not be rendered by URP!

                // If you need to add a custom pass to your shader (outline, planar shadow....),
                // - Write "LightMode" = "YourCustomPassTag" inside your shader's custom pass's Tags{}
                // - Add a rendererFeature C#, write cmd.DrawRenderers() to render this custom pass
            }

            Cull Front // Cull Front is a must for extra pass outline method

            HLSLPROGRAM

            // Direct copy all keywords from "SurfaceColor" pass
            // -------------------------------------
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            // -------------------------------------
            #pragma multi_compile_fog
            // -------------------------------------

            #pragma vertex VertexShaderWork
            #pragma fragment ShadeFinalColor

            // because this is an Outline pass, define "ToonShaderIsOutline" to inject outline related code into both VertexShaderWork() and ShadeFinalColor()
            #define ToonShaderIsOutline

            // all shader logic written inside this .hlsl, must write #include AFTER all #define
            #include "SimpleURPToonLitOutlineExample_Shared.hlsl"

            ENDHLSL
        }
 
        // ShadowCaster pass. Used for rendering URP's shadowmaps
        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            // more explict render state to avoid confusion
            ZWrite On // the only goal of this pass is to write depth!
            ZTest LEqual // early exit at Early-Z stage if possible            
            ColorMask 0 // we don't care about color, we just want to write depth, ColorMask 0 will save some write bandwidth
            Cull Back // support Cull[_Cull] requires "flip vertex normal" using VFACE in fragment shader, which is maybe beyond the scope of a simple tutorial shader

            HLSLPROGRAM

            // the only keywords we need in this pass = _UseAlphaClipping, which is already defined inside the HLSLINCLUDE block
            // (so no need to write any multi_compile or shader_feature in this pass)

            #pragma vertex VertexShaderWork
            #pragma fragment BaseColorAlphaClipTest // we only need to do Clip(), no need shading

            // because it is a ShadowCaster pass, define "ToonShaderApplyShadowBiasFix" to inject "remove shadow mapping artifact" code into VertexShaderWork()
            #define ToonShaderApplyShadowBiasFix

            // all shader logic written inside this .hlsl, must write #include AFTER all #define
            #include "SimpleURPToonLitOutlineExample_Shared.hlsl"

            ENDHLSL
        }

        // DepthOnly pass. Used for rendering URP's offscreen depth prepass (you can search DepthOnlyPass.cs in URP package)
        // Usually when depth texture is needed, we need to perform this depth prepass for this toon shader. 
        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            // more explict render state to avoid confusion
            ZWrite On // the only goal of this pass is to write depth!
            ZTest LEqual // early exit at Early-Z stage if possible            
            ColorMask 0 // we don't care about color, we just want to write depth, ColorMask 0 will save some write bandwidth
            Cull Back // support Cull[_Cull] requires "flip vertex normal" using VFACE in fragment shader, which is maybe beyond the scope of a simple tutorial shader

            HLSLPROGRAM

            // the only keywords we need in this pass = _UseAlphaClipping, which is already defined inside the HLSLINCLUDE block
            // (so no need to write any multi_compile or shader_feature in this pass)

            #pragma vertex VertexShaderWork
            #pragma fragment BaseColorAlphaClipTest // we only need to do Clip(), no need color shading

            // because Outline area should write to depth also, define "ToonShaderIsOutline" to inject outline related code into VertexShaderWork()
            #define ToonShaderIsOutline

            //all shader logic written inside this .hlsl, must write #include AFTER all #define
            #include "SimpleURPToonLitOutlineExample_Shared.hlsl"

            ENDHLSL
        }
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}
