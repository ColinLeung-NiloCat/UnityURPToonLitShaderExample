// For more information, visit -> https://github.com/ColinLeung-NiloCat/UnityURPToonLitShaderExample

/*
This shader is a simple and short example showing you how to write your first URP custom toon lit shader with "minimum" shader code.
You can use this shader as a starting point, add/edit code to develop your own custom toon lit shader for URP14(Unity2022.3) or above.

Usually, just by editing "SimpleURPToonLitOutlineExample_LightingEquation.hlsl" alone can control most of the visual result.

This shader includes 5 passes:
0.UniversalForwardOnly  pass    (this pass will always render to the _CameraColorAttachment* & _CameraDepthAttachment*)
1.Outline               pass    (this pass will always render to the _CameraColorAttachment* & _CameraDepthAttachment*)
2.ShadowCaster          pass    (only for URP's shadow caster rendering, render to the _MainLightShadowmapTexture* and _AdditionalLightsShadowmapTexture*. This pass won't render at all if your character don't cast shadow)
3.DepthOnly             pass    (only for URP's _CameraDepthTexture's rendering. This pass won't render at all if your project don't render URP's offscreen depth prepass)
4.DepthNormalsOnly      pass    (only for URP's _CameraDepthTexture + _CameraNormalsTexture's rendering. This pass won't render at all if your project don't render URP's offscreen depth+normal prepass)

- Because most of the time, you use this toon lit shader for unique dynamic characters, so all lightmap related code are removed for simplicity.
- For batching, we only rely on SRP batching, which is the most practical batching method in URP for rendering lots of unique animated SkinnedMeshRenderer characters using the same shader

Most of the properties will try to follow URP Lit shader's naming convention,
so switching your URP lit material's shader to this toon lit shader will preserve most of the original properties if defined in this shader.
For URP Lit shader's naming convention, see URP's Lit.shader.

In this shader, sometimes we choose "conditional move (a?b:c)" or "static uniform branching (if(_Uniform))" over "shader_feature & multi_compile" for some of the toggleable features, 
because:
    - we want to avoid this shader's build time takes too long (2^n)
    - we want to avoid shader size and memory usage becomes too large easily (2^n), 2GB memory iOS mobile will crash easily if you use too much multi_compile
    - we want to avoid rendering spike/hiccup when a new shader variant was seen by the camera first time ("create GPU program" in profiler)
    - we want to avoid increasing ShaderVariantCollection's keyword combination complexity
    - we want to avoid breaking SRP batching because SRP batching is per shader variant batching, not per shader

    All modern GPU(include the latest high-end mobile devices) can handle "static uniform branching" with "almost" no performance cost (if register pressure is not the bottleneck).
    Usually, there exist 4 cases of branching, here we sorted them by cost, from lowest cost to highest cost,
    and you usually only need to worry about the "case 4" only!

    case 1 - compile time constant if():
        // absolutely 0 performance cost for any platform, unity's shader compiler will treat the false side of if() as dead code and remove it completely
        // shader compiler is very good at dead code removal
        #define SHOULD_RUN_FANCY_CODE 0
        if(SHOULD_RUN_FANCY_CODE) {...}

    case 2 - static uniform branching if():
        // reasonable low performance cost (except OpenGLES2, OpenGLES2 doesn't have branching and will always run both paths and discard the false path)
        // since OpenGLES2 is not important anymore in 2024, we will use static uniform branching if() when suitable
        CBUFFER_START(UnityPerMaterial)
            float _ShouldRunFancyCode; // usually controlled by a [Toggle] in material inspector, or material.SetFloat(1 or 0) in C#
        CBUFFER_END
        if(_ShouldRunFancyCode) {...}

    case 3 - dynamic branching if() without divergence inside a wavefront/warp: 
        bool shouldRunFancyCode = (some shader calculation); // all pixels inside a wavefront/warp(imagine it is a group of 8x8 pixels) all goes into the same path, then no divergence.
        if(shouldRunFancyCode) {...}

    case 4 - dynamic branching if() WITH divergence inside a wavefront/warp: 
        // this is the only case that will make GPU really slow! You will want to avoid it as much as possible
        bool shouldRunFancyCode = (some shader calculation); // pixels inside a wavefront/warp(imagine it is a group of 8x8 pixels) goes into different paths, even it is 63 vs 1 within a 8x8 thread group, it is still divergence!
        if(shouldRunFancyCode) {...} 

    If you want to understand the difference between case 1-4,
    Here are some extra resources about the cost of if() / branching / divergence in shader:
    - https://stackoverflow.com/questions/37827216/do-conditional-statements-slow-down-shaders
    - https://stackoverflow.com/questions/5340237/how-much-performance-do-conditionals-and-unused-samplers-textures-add-to-sm2-3-p/5362006#5362006
    - https://twitter.com/bgolus/status/1235351597816795136
    - https://twitter.com/bgolus/status/1235254923819802626?s=20
    - https://www.shadertoy.com/view/wlsGDl?fbclid=IwAR1ByDhQBck8VO0AMPS5XpbtBPSzSN9Mh8clW4itRgDIpy5ROcXW1Iyf86g

    [TLDR] 
    Just remember(even for mobile platform): 
    - if() itself is not evil, you CAN use it if you know there is no divergence inside a wavefront/warp, still, it is not free on mobile.
    - "a ? b : c" is just a conditional move(movc / cmov) in assembly code, don't worry using it if you have calculated b and c already
    - Don't try to optimize if() or "a ? b : c" by replacing them by lerp(b,c,step())..., because "a ? b : c" is always faster if you have calculated b and c already
    - branching is not evil, still it is not free. Sometimes we can use branching to help GPU run faster if the skipped task is heavy!
    - but, divergence is evil! If you want to use if(condition){...}else{...}, make sure the "condition" is the same within as many groups of 8x8 pixels as possible

    [Note from the developer (1)]
    Using shader permutation(multi_compile/shader_feature) is still the fastest way to skip shader calculation,
    because once the code doesn't exist, it will enable many compiler optimizations. 
    If you need the best GPU performance, and you can accept long build time and huge memory usage, you can use multi_compile/shader_feature more, especially for features with texture read.

    NiloToonURP's character shader will always prefer shader permutation if it can skip any texture read, 
    because the GPU hardware has very strong ALU(pure calculation) power growth since 2015 (including mobile), 
    but relatively weak growth in memory bandwidth(usually means buffer/texture read).
    (https://community.arm.com/developer/tools-software/graphics/b/blog/posts/moving-mobile-graphics#siggraph2015)

    And when GPU is waiting for receiving texture fetch, it won't become idle, 
    GPU will still continue any available ALU work(latency hiding) until there is 100% nothing to calculate anymore, 
    also bandwidth is the biggest source of heat generation (especially on mobile without active cooling = easier overheat/thermal throttling). 
    So we should try our best to keep memory bandwidth usage low (since more ALU is ok, but more texture read is not ok),
    the easiest way is to remove texture read using shader permutation.

    But if the code is ALU only(pure calculation), and calculation is simple on both paths on the if & else side, NiloToonURP will prefer "a ? b : c". 
    The rest will be static uniform branching (usually means heavy ALU only code inside an if()).

    [Note from the developer (2)]
    If you are working on a game project, not a generic tool like NiloToonURP, you will always want to pack 4data (occlusion/specular/smoothness/any mask.....) into 1 RGBA texture(for fragment shader), 
    and pack 4data (outlineWidth/ZOffset/face area mask....) into another RGBA texture(for vertex shader), to reduce the number of texture read without changing visual result(if we ignore texture compression).
    But since NiloToonURP is a generic tool that is used by different person/team/company, 
    we know it is VERY important for all users to be able to apply NiloToon shader to any model easily/fast/without effort,
    and we know that it is almost not practical if we force regular user to pack their texture into a special format just for NiloToon shader,
    so we decided we will keep every texture separated, even it is VERY slow compared to the packed texture method.
    That is a sad decision in terms of performance, but a good decision for ease of use. 
    If user don't need the best performance, this decision is actually a plus to them since it is much more flexible when using this shader.  

    [About multi_compile or shader_feature's _vertex and _fragment suffixes]
    In unity 2020.3, unity added _vertex, _fragment suffixes to multi_compile and shader_feature
    https://docs.unity3d.com/2020.3/Documentation/Manual/SL-MultipleProgramVariants.html (Using stage-specific keyword directives)

    The only disadvantage of NOT using _vertex and _fragment suffixes is only compilation time, not build size/memory usage:
    https://docs.unity3d.com/2020.3/Documentation/Manual/SL-MultipleProgramVariants.html (Stage-specific keyword directives)
    "Unity identifies and removes duplicates afterwards, so this redundant work does not affect build sizes or runtime performance; 
    however, if you have a lot of stages and/or variants, the time wasted during shader compilation can be significant."

---------------------------------------------------------------------------
More information about mobile GPU optimization can be found here, most of the best practice can apply both GPU(Mali & Adreno):
https://developer.arm.com/solutions/graphics-and-gaming/arm-mali-gpu-training

[Shader build time and memory]
https://blog.unity.com/engine-platform/2021-lts-improvements-to-shader-build-times-and-memory-usage

[Support SinglePassInstancing]
https://docs.unity3d.com/2022.2/Documentation/Manual/SinglePassInstancing.html

[Conditionals can affect #pragma directives]
preprocessor conditionals can be used to influence, which #pragma directives are selected.
https://forum.unity.com/threads/new-shader-preprocessor.790328/
https://docs.unity3d.com/Manual/shader-variant-stripping.html
Example code:
{
    #ifdef SHADER_API_DESKTOP
        #pragma multi_compile _ RED GREEN BLUE WHITE
    #else
       #pragma shader_feature RED GREEN BLUE WHITE
    #endif
}
{
    #if SHADER_API_DESKTOP
        #pragma geometry ForwardPassGeometry
    #endif
}
{
    #if SHADER_API_DESKTOP
        #pragma vertex DesktopVert
    #else
        #pragma vertex MobileVert
    #endif
}
{
    #if SHADER_API_DESKTOP
       #pragma multi_compile SHADOWS_LOW SHADOWS_HIGH
       #pragma multi_compile REFLECTIONS_LOW REFLECTIONS_HIGH
       #pragma multi_compile CAUSTICS_LOW CAUSTICS_HIGH
    #elif SHADER_API_MOBILE
       #pragma multi_compile QUALITY_LOW QUALITY_HIGH
       #pragma shader_feature CAUSTICS // Uses shader_feature, so Unity strips variants that use CAUSTICS if there are no Materials that use the keyword at build time.
    #endif
}
But this will not work (Keywords coming from pragmas (shader_feature, multi_compile and variations) will not affect other pragmas.):
{
    #pragma shader_feature WIREFRAME_MODE_ON
 
    #ifdef WIREFRAME_MODE_ON
        #pragma geometry ForwardPassGeometry
    #endif
}

[Write .shader and .hlsl using an IDE]
Rider is the best IDE for writing shader in Unity, there should be no other better tool than Rider.
If you never used Rider to write hlsl before, we highly recommend trying it for a month for free.
https://www.jetbrains.com/rider/

[hlsl code is inactive in Rider]  
You may encounter an issue that some hlsl code is inactive within the #if #endif section, so Rider's "auto complete" and "systax highlightd" is not active, 
to solve this problem, please switch the context using the "Unity Shader Context picker in the status bar" UI at the bottom right of Rider

For details, see this Rider document about "Unity Shader Context picker in the status bar":
https://github.com/JetBrains/resharper-unity/wiki/Switching-code-analysis-context-for-hlsl-cginc-files-in-Rider
*/ 
Shader "SimpleURPToonLitExample(With Outline)"
{
    Properties
    {
        [Header(High Level Setting)]
        [ToggleUI]_IsFace("Is Face? (face/eye/mouth)", Float) = 0

        [Header(Base Color)]
        [MainTexture]_BaseMap("Base Map", 2D) = "white" {}
        [HDR][MainColor]_BaseColor("Base Color", Color) = (1,1,1,1)

        [Header(Alpha Clipping)]
        [Toggle(_UseAlphaClipping)]_UseAlphaClipping("Enable?", Float) = 0
        _Cutoff("    Cutoff", Range(0.0, 1.0)) = 0.5

        [Header(Emission)]
        [Toggle]_UseEmission("Enable?", Float) = 0
        [HDR] _EmissionColor("    Color", Color) = (0,0,0)
        _EmissionMulByBaseColor("    Mul Base Color", Range(0,1)) = 0
        [NoScaleOffset]_EmissionMap("    Emission Map", 2D) = "white" {}
        _EmissionMapChannelMask("        ChannelMask", Vector) = (1,1,1,0)

        [Header(Occlusion)]
        [Toggle]_UseOcclusion("Enable?", Float) = 0
        _OcclusionStrength("    Strength", Range(0.0, 1.0)) = 1.0
        [NoScaleOffset]_OcclusionMap("    OcclusionMap", 2D) = "white" {}
        _OcclusionMapChannelMask("        ChannelMask", Vector) = (1,0,0,0)
        _OcclusionRemapStart("        RemapStart", Range(0,1)) = 0
        _OcclusionRemapEnd("        RemapEnd", Range(0,1)) = 1

        [Header(Indirect Light)]
        _IndirectLightMinColor("Min Color", Color) = (0.1,0.1,0.1,1) // can prevent completely black if light prob is not baked
        _IndirectLightMultiplier("Multiplier", Range(0,1)) = 1
        
        [Header(Direct Light)]
        _DirectLightMultiplier("Brightness", Range(0,1)) = 1
        _CelShadeMidPoint("MidPoint", Range(-1,1)) = -0.5
        _CelShadeSoftness("Softness", Range(0,1)) = 0.05
        _MainLightIgnoreCelShade("Remove Shadow", Range(0,1)) = 0
        
        [Header(Additional Light)]
        _AdditionalLightIgnoreCelShade("Remove Shadow", Range(0,1)) = 0.9

        [Header(Shadow Mapping)]
        _ReceiveShadowMappingAmount("Strength", Range(0,1)) = 0.65
        _ShadowMapColor("    Shadow Color", Color) = (1,0.825,0.78)
        _ReceiveShadowMappingPosOffset("    Depth Bias", Float) = 0

        [Header(Outline)]
        _OutlineWidth("Width", Range(0,4)) = 1
        _OutlineColor("Color", Color) = (0.5,0.5,0.5,1)
        
        [Header(Outline ZOffset)]
        _OutlineZOffset("ZOffset (View Space)", Range(0,1)) = 0.0001
        [NoScaleOffset]_OutlineZOffsetMaskTex("    Mask (black is apply ZOffset)", 2D) = "black" {}
        _OutlineZOffsetMaskRemapStart("    RemapStart", Range(0,1)) = 0
        _OutlineZOffsetMaskRemapEnd("    RemapEnd", Range(0,1)) = 1
    }
    SubShader
    {       
        Tags 
        {
            // SRP introduced a new "RenderPipeline" tag in Subshader. This allows you to create shaders
            // that can match multiple render pipelines. If a RenderPipeline tag is not set it will match
            // any render pipeline. In case you want your SubShader to only run in URP, set the tag to
            // "UniversalPipeline"

            // here "UniversalPipeline" tag is required, because we only want this shader to run in URP.
            // If Universal render pipeline is not set in the graphics settings, this SubShader will fail.

            // One can add a SubShader below or fallback to Standard built-in to make this
            // material works with both Universal Render Pipeline and Builtin-RP

            // the tag value is "UniversalPipeline", not "UniversalRenderPipeline", be careful!
            "RenderPipeline" = "UniversalPipeline"

            // explicit SubShader tag to avoid confusion
            "RenderType" = "Opaque"
            "IgnoreProjector" = "True"
            "UniversalMaterialType" = "ComplexLit"
            "Queue"="Geometry"
        }
        
        // You can use LOD to control if this SubShader should be used.
        // if this SubShader is not allowed to be use due to LOD,
        // Unity will consider the next SubShader 
        LOD 100
        
        // We can extract duplicated hlsl code from all passes into this HLSLINCLUDE section. Less duplicated code = Less error
        HLSLINCLUDE

        // all Passes will need this keyword
        #pragma shader_feature_local_fragment _UseAlphaClipping

        ENDHLSL

        // [#0 Pass - ForwardLit]
        // Forward only pass.
        // Acts also as an opaque forward fallback for deferred rendering.
        // Shades GI, all lights, shadow, emission and fog in a single pass.
        // Compared to Builtin pipeline forward renderer, URP forward renderer will
        // render a scene with multiple lights with less draw calls and less overdraw.
        Pass
        {               
            Name "ForwardLit"
            Tags
            {
                // "LightMode" matches the "ShaderPassName" set in UniversalRenderPipeline.cs. 
                // SRPDefaultUnlit and passes with no LightMode tag are also rendered by URP

                // "LightMode" tag must be "UniversalForward" in order to render lit objects in URP.
                "LightMode" = "UniversalForwardOnly"
            }

            // -------------------------------------
            // Render State Commands
            // - explicit render state to avoid confusion
            // - you can expose these render state to material inspector if needed (see URP's Lit.shader)
            Blend One Zero
            ZWrite On
            Cull Off
            ZTest LEqual

            HLSLPROGRAM
            #pragma target 2.0

            // -------------------------------------
            // Shader Stages
            #pragma vertex VertexShaderWork
            #pragma fragment ShadeFinalColor

            // -------------------------------------
            // Material Keywords
            // (all shader_feature that we needed were extracted to a shared SubShader level HLSL block already)
            
            // -------------------------------------
            // Universal Pipeline keywords
            // You can always copy this section from URP's ComplexLit.shader
            // When doing custom shaders you most often want to copy and paste these #pragma multi_compile
            // These multi_compile variants are stripped from the build depending on:
            // 1) Settings in the URP Asset assigned in the GraphicsSettings at build time
            // e.g If you disabled AdditionalLights in all the URP assets then all _ADDITIONA_LIGHTS variants
            // will be stripped from build
            // 2) Invalid combinations are stripped.
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ EVALUATE_SH_MIXED EVALUATE_SH_VERTEX
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
            #pragma multi_compile_fragment _ _LIGHT_LAYERS
            #pragma multi_compile_fragment _ _LIGHT_COOKIES
            #pragma multi_compile _ _FORWARD_PLUS
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
            #pragma multi_compile_fog
            #pragma multi_compile_fragment _ DEBUG_DISPLAY

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            //--------------------------------------
            // Defines
            // - because this pass is just a ForwardLitOnly pass, no need any special #define
            // (no special #define)

            // -------------------------------------
            // Includes
            // - all shader logic written inside this .hlsl, remember to write all #define BEFORE writing #include
            #include "SimpleURPToonLitOutlineExample_Shared.hlsl"

            ENDHLSL
        }
        
        // [#1 Pass - Outline]
        // Same as the above "ForwardLit" pass, but: 
        // - vertex position are pushed out a bit base on normal direction
        // - also color is tinted by outline color
        // - Cull Front instead of Cull Off because Cull Front is a must for any 2 pass outline method
        Pass 
        {
            Name "Outline"
            Tags 
            {
                // IMPORTANT: don't write this line for any custom pass(e.g. outline pass)! 
                // else this outline pass(custom pass) will not be rendered by URP!
                //"LightMode" = "UniversalForwardOnly" 

                // [Important CPU performance note]
                // If you need to add a custom pass to your shader (e.g. outline pass, planar shadow pass, Xray overlay pass when blocked....),
                // follow these steps:
                // (1) Add a new Pass{} to your shader
                // (2) Write "LightMode" = "YourCustomPassTag" inside new Pass's Tags{}
                // (3) Add a new custom RendererFeature(C#) to your renderer,
                // (4) write cmd.DrawRenderers() with ShaderPassName = "YourCustomPassTag"
                // (5) if done correctly, URP will render your new Pass{} for your shader, in a SRP-batching friendly way (usually in 1 big SRP batch)

                // For tutorial purpose, current everything is just shader files without any C#, so this Outline pass is actually NOT SRP-batching friendly.
                // If you are working on a project with lots of characters, make sure you use the above method to make Outline pass SRP-batching friendly!
            }

            // -------------------------------------
            // Render State Commands
            // - Cull Front is a must for extra pass outline method
            Blend One Zero
            ZWrite On
            Cull Front
            ZTest LEqual

            HLSLPROGRAM
            #pragma target 2.0
            
            // -------------------------------------
            // Shader Stages
            #pragma vertex VertexShaderWork
            #pragma fragment ShadeFinalColor

            // -------------------------------------
            // Material Keywords
            // (all shader_feature that we needed were extracted to a shared SubShader level HLSL block already)
            
            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ EVALUATE_SH_MIXED EVALUATE_SH_VERTEX
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
            #pragma multi_compile_fragment _ _LIGHT_LAYERS
            #pragma multi_compile_fragment _ _LIGHT_COOKIES
            #pragma multi_compile _ _FORWARD_PLUS
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"


            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
            #pragma multi_compile_fog
            #pragma multi_compile_fragment _ DEBUG_DISPLAY

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            //--------------------------------------
            // Defines
            // - because this is an Outline pass, define "ToonShaderIsOutline" to inject outline related code into both VertexShaderWork() and ShadeFinalColor()
            #define ToonShaderIsOutline

            // -------------------------------------
            // Includes
            // - all shader logic written inside this .hlsl, remember to write all #define BEFORE writing #include
            #include "SimpleURPToonLitOutlineExample_Shared.hlsl"

            ENDHLSL
        }
 
        // ShadowCaster pass. Used for rendering URP's shadowmaps
        Pass
        {
            Name "ShadowCaster"
            Tags
            {
                "LightMode" = "ShadowCaster"
            }

            // -------------------------------------
            // Render State Commands
            // - more explicit render state to avoid confusion
            ZWrite On // the only goal of this pass is to write depth!
            ZTest LEqual // early exit at Early-Z stage if possible            
            ColorMask 0 // we don't care about color, we just want to write depth in shadow maps, ColorMask 0 will save some write bandwidth
            Cull Off

            HLSLPROGRAM
            #pragma target 2.0

            // -------------------------------------
            // Shader Stages
            #pragma vertex VertexShaderWork
            #pragma fragment AlphaClipAndLODTest // we only need to do Clip(), no need shading

            // -------------------------------------
            // Material Keywords
            // - the only keywords we need in this pass = _UseAlphaClipping, which is already defined inside the SubShader level HLSLINCLUDE block
            // (so no need to write any extra shader_feature in this pass)

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            // This is used during shadow map generation to differentiate between directional and punctual light shadows, as they use different formulas to apply Normal Bias
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            //--------------------------------------
            // Defines
            // - because it is a ShadowCaster pass, define "ToonShaderApplyShadowBiasFix" to inject "remove shadow mapping artifact" code into VertexShaderWork()
            #define ToonShaderApplyShadowBiasFix

            // -------------------------------------
            // Includes
            // - all shader logic written inside this .hlsl, remember to write all #define BEFORE writing #include
            #include "SimpleURPToonLitOutlineExample_Shared.hlsl"

            ENDHLSL
        }

        // (X) No "GBuffer" Pass

        // DepthOnly pass. Used for rendering URP's offscreen depth prepass (you can search DepthOnlyPass.cs in URP package)
        // For example, when depth texture is on, we need to perform this offscreen depth prepass for this toon shader. 
        Pass
        {
            Name "DepthOnly"
            Tags
            {
                "LightMode" = "DepthOnly"
            }

            // -------------------------------------
            // Render State Commands
            // - more explicit render state to avoid confusion
            ZWrite On // the only goal of this pass is to write depth!
            ZTest LEqual // early exit at Early-Z stage if possible            
            ColorMask R // we don't care about RGB color, we just want to write depth, ColorMask R will save some write bandwidth
            Cull Off 
            
            HLSLPROGRAM
            #pragma target 2.0

            // -------------------------------------
            // Shader Stages
            #pragma vertex VertexShaderWork
            #pragma fragment DepthOnlyFragment // we only need to do Clip(), no need color shading
            
            // -------------------------------------
            // Material Keywords
            // - the only keywords we need in this pass = _UseAlphaClipping, which is already defined inside the SubShader level HLSLINCLUDE block
            // (so no need to write any extra shader_feature in this pass)

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            //--------------------------------------
            // Defines
            // - because Outline area should write to depth also, define "ToonShaderIsOutline" to inject outline related code into VertexShaderWork()
            #define ToonShaderIsOutline

            // -------------------------------------
            // Includes
            // - all shader logic written inside this .hlsl, remember to write all #define BEFORE writing #include
            #include "SimpleURPToonLitOutlineExample_Shared.hlsl"

            ENDHLSL
        }

        // This pass is used when drawing to a _CameraNormalsTexture texture with the forward renderer or the depthNormal prepass with the deferred renderer.
        // URP can generate a normal texture _CameraNormalsTexture + _CameraDepthTexture together when requested,
        // if requested by a renderer feature(e.g. request by URP's SSAO). 
        Pass
        {
            Name "DepthNormalsOnly"
            Tags
            {
                "LightMode" = "DepthNormalsOnly"
            }

            // -------------------------------------
            // Render State Commands
            // - more explicit render state to avoid confusion
            ZWrite On // the only goal of this pass is to write depth!
            ZTest LEqual // early exit at Early-Z stage if possible            
            ColorMask RGBA // we want to draw normal as rgb color!
            Cull Off

            HLSLPROGRAM
            #pragma target 2.0

            // -------------------------------------
            // Shader Stages
            #pragma vertex VertexShaderWork
            #pragma fragment DepthNormalsFragment // we only need to do Clip() + normal as rgb color shading
            
            // -------------------------------------
            // Material Keywords
            // - the only keywords we need in this pass = _UseAlphaClipping, which is already defined inside the SubShader level HLSLINCLUDE block
            // (so no need to write any extra shader_feature in this pass)

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT // forward-only variant
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            //--------------------------------------
            // Defines

            // -------------------------------------
            // Includes
            // - all shader logic written inside this .hlsl, remember to write all #define BEFORE writing #include
            #include "SimpleURPToonLitOutlineExample_Shared.hlsl"

            ENDHLSL
        }

        // (X) No "Meta" pass
        // (X) No "Universal2D" pass
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
    
    // Custom editor is possible! We recommend checking out LWGUI(https://github.com/JasonMa0012/LWGUI)
    //CustomEditor "LWGUI.LWGUI"
}
