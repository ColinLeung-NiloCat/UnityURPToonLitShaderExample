//https://github.com/ColinLeung-NiloCat/UnityURPToonLitShaderExample

/*
This shader is a simple example showing you how to write your first URP toon lit shader with "minimum" shader code.
You can use this shader as a starting point, add/edit code to develop your own custom toon lit shader for URP.

*Usually, just by editing "SimpleURPToonLitOutlineExample_LightingEquation.hlsl" alone can control most of the visual result.

This shader includes 4 passes:
0.SurfaceColor pass (this pass will always render to the color buffer)
1.Outline pass (this pass will always render to the color buffer)
2.ShadowCaster pass (only for URP's shadow mapping, this pass won't render at all if your project don't use shadow mapping)
3.DepthOnly pass (only for URP's depth texture rendering, this pass won't render at all if your project don't use depth texture)

*because most of the time, you use a toon lit shader for characters, so all lightmap & instancing related code are removed for simplicity.

*In this shader, we choose static uniform branching over "shader_feature & multi_compile" for our togglable feature like "_UseEmission", because:
    - we want to avoid this shader's build time takes too long (2^n)
    - we want to avoid rendering spike when a new shader variant was seen by the camera first time (create GPU program)
    - we want to avoid increasing ShaderVarientCollection's complexity
    - we want to avoid shader size becomes too large easily (2^n)
    - we want to avoid breaking SRP batcher's batching because it is batched per shader variant, not per shader
    - all modern GPU(include newer mobile devices) can handle static uniform branching with "almost" no performance cost
*/
Shader "SimpleURPToonLitExample(With Outline)"
{
    Properties
    {
        // all texture properties will follow URP Lit shader's naming convention
        // so switching your URP lit material's shader to this toon lit shader will preserve most of the original properties value if defined here

        // URP Lit shader's naming convention:
        // https://gist.github.com/phi-lira/225cd7c5e8545be602dca4eb5ed111ba#file-universalpipelinetemplateshader-shader

        [Header(Base Color)]
        [HDR][MainColor]_BaseColor("_BaseColor", Color) = (1,1,1,1)
        [MainTexture]_BaseMap("_BaseMap (albedo)", 2D) = "white" {}

        [Header(Alpha)]
        [Toggle]_UseAlphaClipping("_UseAlphaClipping", Float) = 1
        _Cutoff("_Cutoff (Alpha Cutoff)", Range(0.0, 1.0)) = 0.5

        [Header(Lighting)]
        _IndirectLightConstColor("_IndirectLightConstColor", Color) = (0.5,0.5,0.5,1)
        _IndirectLightMultiplier("_IndirectLightMultiplier", Range(0,1)) = 1
        _DirectLightMultiplier("_DirectLightMultiplier", Range(0,1)) = 0.25
        _CelShadeMidPoint("_CelShadeMidPoint", Range(-1,1)) = -.5
        _CelShadeSoftness("_CelShadeSoftness", Range(0,1)) = 0.05

        [Header(Shadow mapping)]
        _ReceiveShadowMappingAmount("_ReceiveShadowMappingAmount", Range(0,1)) = 0.5

        [Header(Emission)]
        [Toggle]_UseEmission("_UseEmission (on/off completely)", Float) = 0
        [HDR] _EmissionColor("_EmissionColor", Color) = (0,0,0)
        _EmissionMap("_EmissionMap", 2D) = "white" {}
        _EmissionMapChannelMask("_EmissionMapChannelMask", Vector) = (1,1,1,1)

        [Header(Outline)]
        _OutlineWidth("_OutlineWidth (Object Space)", Range(0, 0.1)) = 0.0015
        _OutlineColor("_OutlineColor", Color) = (0.3,0.3,0.3,1)
    }
    SubShader
    {       
        Tags 
        {
            // With SRP we introduced a new "RenderPipeline" tag in Subshader. This allows you to create shaders
            // that can match multiple render pipelines. If a RenderPipeline tag is not set it will match
            // any render pipeline. In case you want your subshader to only run in URP, set the tag to
            // "UniversalRenderPipeline"
            "RenderPipeline" = "UniversalPipeline"
        }
        
        // ------------------------------------------------------------------
        // Forward pass. Shades GI, emission, fog and all lights in a single pass.
        // Compared to Builtin pipeline forward renderer, URP forward renderer will
        // render a scene with multiple lights with less drawcalls and less overdraw.
        Pass
        {               
            Name "SurfaceColor"
            Tags
            {
                // "Lightmode" tag must be "UniversalForward" or not be defined, in order to render objects in URP.
                "LightMode" = "UniversalForward"
            }

            HLSLPROGRAM
            
            // -------------------------------------
            // Universal Render Pipeline keywords
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
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _SHADOWS_SOFT
            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fog
            // -------------------------------------

            //all shader logic written inside this .hlsl
            #include "SimpleURPToonLitOutlineExample_Shared.hlsl"

            #pragma vertex BaseColorPassVertex
            #pragma fragment BaseColorPassFragment

            Varyings BaseColorPassVertex(Attributes input)
            {
                VertexShaderWorkSetting setting = GetDefaultVertexShaderWorkSetting();

                //regular pass
                //so no change to setting

                return VertexShaderWork(input, setting);
            }

            half4 BaseColorPassFragment(Varyings input) : SV_TARGET
            {
                // set 2nd param "isOutline" to false because this pass is not an outline pass
                return ShadeFinalColor(input, false);
            }

            ENDHLSL
        }
        
        // ------------------------------------------------------------------
        // Outline pass. Similar to "SurfaceColor" pass, but vertex position are pushed out a bit base on normal direction, also color is darker 
        Pass 
        {
            Name "Outline"
            Tags 
            {
                //"LightMode" = "UniversalForward" // IMPORTANT: don't write this line for any custom +pass! else this outline pass will not be rendered in URP!
            }
            Cull Front // Cull Front is a must for extra pass outline method

            HLSLPROGRAM

            //copy from the first pass
            // -------------------------------------
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _SHADOWS_SOFT
            // -------------------------------------
            #pragma multi_compile_fog
            // -------------------------------------

            #include "SimpleURPToonLitOutlineExample_Shared.hlsl"

            #pragma vertex OutlinePassVertex
            #pragma fragment OutlinePassFragment

            Varyings OutlinePassVertex(Attributes input)
            {
                VertexShaderWorkSetting setting = GetDefaultVertexShaderWorkSetting();

                // set param "isOutline" to true because this pass is an Outline pass
                // setting to true = push vertex out a bit base on normal direction
                setting.isOutline = true;

                return VertexShaderWork(input, setting);
            }

            half4 OutlinePassFragment(Varyings input) : SV_TARGET
            {
                // set 2nd param "isOutline" to true because this pass is an Outline pass
                return ShadeFinalColor(input, true);
            }

            ENDHLSL
        }
        

        // Used for rendering URP's shadowmaps
        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            //we don't care about color, we just write to depth
            ColorMask 0

            HLSLPROGRAM

            #pragma vertex ShadowCasterPassVertex
            #pragma fragment ShadowCasterPassFragment

            #include "SimpleURPToonLitOutlineExample_Shared.hlsl"

            Varyings ShadowCasterPassVertex(Attributes input)
            {
                VertexShaderWorkSetting setting = GetDefaultVertexShaderWorkSetting();

                setting.isOutline = false; //(you can delete this line, this line is just a note) the correct value is false here, else self shadow is not correct
                setting.applyShadowBiasFixToHClipPos = true;//important for shadow caster pass, else shadow artifact will appear

                return VertexShaderWork(input, setting);
            }

            half4 ShadowCasterPassFragment(Varyings input) : SV_TARGET
            {
                return BaseColorAlphaClipTest(input);
            }

            ENDHLSL
        }

        // Used for depth prepass
        // If depth texture is needed, we need to perform a depth prepass for this shader. 
        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            //we don't care about color, we just write to depth
            ColorMask 0

            HLSLPROGRAM
            #pragma vertex DepthOnlyPassVertex
            #pragma fragment DepthOnlyPassFragment

            #include "SimpleURPToonLitOutlineExample_Shared.hlsl"

            Varyings DepthOnlyPassVertex(Attributes input)
            {
                VertexShaderWorkSetting setting = GetDefaultVertexShaderWorkSetting();

                // set param "isOutline" to ture because outline should affect depth (e.g. handle depth of field's correctly at outline area)
                // setting "isOutline" to true = push vertex out a bit according to normal direction
                setting.isOutline = true;

                return VertexShaderWork(input, setting);
            }

            half4 DepthOnlyPassFragment(Varyings input) : SV_TARGET
            {
                return BaseColorAlphaClipTest(input);
            }

            ENDHLSL
        }
    }
}
