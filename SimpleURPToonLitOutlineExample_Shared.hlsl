//https://github.com/ColinLeung-NiloCat/UnityURPToonLitShaderExample

// #ifndef XXX + #define XXX + #endif is a safe guard best practice in almost every .hlsl, 
// doing this can make sure your .hlsl's user can include this .hlsl anywhere anytime without producing any multi include conflict
#ifndef SimpleURPToonLitOutlineExample_Shared_Include
#define SimpleURPToonLitOutlineExample_Shared_Include

// We don't have "UnityCG.cginc" in SRP/URP's package anymore, so:
// Including the following two hlsl files is enough for shading with Universal Pipeline. Everything is included in them.
// Core.hlsl will include SRP shader library, all constant buffers not related to materials (perobject, percamera, perframe).
// It also includes matrix/space conversion functions and fog.
// Lighting.hlsl will include the light functions/data to abstract light constants. You should use GetMainLight and GetLight functions
// that initialize Light struct. Lighting.hlsl also include GI, Light BDRF functions. It also includes Shadows.

// Required by all Universal Render Pipeline shaders.
// It will include Unity built-in shader variables (except the lighting variables)
// (https://docs.unity3d.com/Manual/SL-UnityShaderVariables.html
// It will also include many utilitary functions. 
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

// Include this if you are doing a lit shader. This includes lighting shader variables,
// lighting and shadow functions
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

// Material shader variables are not defined in SRP or URP shader library.
// This means _BaseColor, _BaseMap, _BaseMap_ST, and all variables in the Properties section of a shader
// must be defined by the shader itself. If you define all those properties in CBUFFER named
// UnityPerMaterial, SRP can cache the material properties between frames and reduce significantly the cost
// of each drawcall.
// In this case, although URP's LitInput.hlsl contains the CBUFFER for the material
// properties defined above. As one can see this is not part of the ShaderLibrary, it specific to the
// URP Lit shader.
// So we are not going to use LitInput.hlsl, we will implement everything by ourself.
//#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"

//note:
//subfix OS means object space (e.g. positionOS = position object space)
//subfix WS means world space (e.g. positionWS = position world space)

// all pass will share this Attributes struct (define data needed from Unity app to our vertex shader)
struct Attributes
{
    float3 positionOS   : POSITION;
    half3 normalOS     : NORMAL;
    half4 tangentOS    : TANGENT;
    float2 uv           : TEXCOORD0;
};

// all pass will share this Varyings struct (define data needed from our vertex shader to our fragment shader)
struct Varyings
{
    float2 uv                       : TEXCOORD0;
    float4 positionWSAndFogFactor   : TEXCOORD2; // xyz: positionWS, w: vertex fog factor
    half3 normalWS                 : TEXCOORD3;

#ifdef _MAIN_LIGHT_SHADOWS
    float4 shadowCoord              : TEXCOORD6; // compute shadow coord per-vertex for the main light
#endif
    float4 positionCS               : SV_POSITION;
};

///////////////////////////////////////////////////////////////////////////////////////
// CBUFFER and Uniforms 
// (you should put all uniforms of all passes inside this single UnityPerMaterial CBUFFER! else SRP batching is not possible!)
///////////////////////////////////////////////////////////////////////////////////////

// all sampler2D don't need to put inside CBUFFER 
sampler2D _BaseMap; 
sampler2D _EmissionMap;

// put all your uniforms(usually things inside properties{} at the start of .shader file) inside this CBUFFER, in order to make SRP batcher compatible
CBUFFER_START(UnityPerMaterial)

    // base color
    float4 _BaseMap_ST;
    half4 _BaseColor;

    // alpha
    float _UseAlphaClipping;
    half _Cutoff;

    //lighting
    half3 _IndirectLightConstColor;
    half _IndirectLightMultiplier;
    half _DirectLightMultiplier;
    half _CelShadeMidPoint;
    half _CelShadeSoftness;

    // shadow mapping
    half _ReceiveShadowMappingAmount;

    //emission
    float _UseEmission;
    half3 _EmissionColor;
    half3 _EmissionMapChannelMask;

    // outline
    float _OutlineWidth;
    half3 _OutlineColor;

CBUFFER_END

//a special uniform for applyShadowBiasFixToHClipPos() only, it is not a per material uniform, 
//so it is fine to write it outside our UnityPerMaterial CBUFFER
half3 _LightDirection;

struct SurfaceData
{
    half3 albedo;
    half  alpha;
    half3 emission;
};
struct LightingData
{
    half3 normalWS;
    float3 positionWS;
    half3 viewDirectionWS;
    float4 shadowCoord;
};

///////////////////////////////////////////////////////////////////////////////////////
// compile time const helper functions for .shader file
///////////////////////////////////////////////////////////////////////////////////////

struct VertexShaderWorkSetting
{
    bool isOutline;
    bool applyShadowBiasFixToHClipPos;
};
VertexShaderWorkSetting GetDefaultVertexShaderWorkSetting()
{
    VertexShaderWorkSetting output;
    output.isOutline = false;
    output.applyShadowBiasFixToHClipPos = false;
    return output;
}

///////////////////////////////////////////////////////////////////////////////////////
// vertex shared functions
///////////////////////////////////////////////////////////////////////////////////////

float3 TransformPositionOSToOutlinePositionOS(Attributes input)
{
    float3 outlineNormalOSUnitVector = normalize(input.normalOS); //normalize, just in case model's data is incorrect
    return input.positionOS + outlineNormalOSUnitVector * _OutlineWidth; //you can replace it to your own method! Here we will use the most simple method for tutorial reason, it is not the best method!
}

// if param "isOutline" is false = do regular MVP transform
// if param "isOutline" is ture = do regular MVP transform + push vertex out a bit according to normal direction
Varyings VertexShaderWork(Attributes input, VertexShaderWorkSetting setting)
{
    Varyings output;

    // bool isOutline should be always a compile time constant, so using if() here has no performance cost
    if(setting.isOutline)
    {
        input.positionOS = TransformPositionOSToOutlinePositionOS(input);
    }

    // VertexPositionInputs contains position in multiple spaces (world, view, homogeneous clip space)
    // Our compiler will strip all unused references (say you don't use view space).
    // Therefore there is more flexibility at no additional cost with this struct.
    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS);

    // Similar to VertexPositionInputs, VertexNormalInputs will contain normal, tangent and bitangent
    // in world space. If not used it will be stripped.
    VertexNormalInputs vertexNormalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    // Computes fog factor per-vertex.
    float fogFactor = ComputeFogFactor(vertexInput.positionCS.z);

    // TRANSFORM_TEX is the same as the old shader library.
    output.uv = TRANSFORM_TEX(input.uv,_BaseMap);

    // packing posWS.xyz & fog into a vector4
    output.positionWSAndFogFactor = float4(vertexInput.positionWS, fogFactor);
    output.normalWS = vertexNormalInput.normalWS;

#ifdef _MAIN_LIGHT_SHADOWS
    // shadow coord for the light is computed in vertex.
    // After URP 7.21, URP will always resolve shadows in light space, no more screen space resolve.
    // In this case shadowCoord will be the vertex position in light space.
    output.shadowCoord = GetShadowCoord(vertexInput);
#endif

    // Here comes the flexibility of the input structs.
    // We just use the homogeneous clip position from the vertex input
    output.positionCS = vertexInput.positionCS;

    // ShadowCaster pass needs special process to clipPos, else shadow artifact will appear
    //--------------------------------------------------------------------------------------
    // bool applyShadowBiasFixToHClipPos should be always a compile time constant, so using if() here has no performance cost
    if(setting.applyShadowBiasFixToHClipPos)
    {
        //see GetShadowPositionHClip() in URP/Shaders/ShadowCasterPass.hlsl 
        float3 positionWS = vertexInput.positionWS;
        float3 normalWS = vertexNormalInput.normalWS;
        float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, _LightDirection));

        #if UNITY_REVERSED_Z
        positionCS.z = min(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
        #else
        positionCS.z = max(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
        #endif
        output.positionCS = positionCS;
    }
    //--------------------------------------------------------------------------------------    

    return output;
}

///////////////////////////////////////////////////////////////////////////////////////
// fragment shared functions (Step1: prepare data for lighting)
///////////////////////////////////////////////////////////////////////////////////////
half4 GetFinalBaseColor(Varyings input)
{
    return tex2D(_BaseMap, input.uv) * _BaseColor;
}
half3 GetFinalEmissionColor(Varyings input)
{
    if(_UseEmission)
    {
        return tex2D(_EmissionMap, input.uv).rgb * _EmissionColor.rgb * _EmissionMapChannelMask;
    }

    return 0;
}
void DoClipTestToTargetAlphaValue(half alpha) 
{
    //2020-6-8: disable to fix an iOS compile fail bug
    /*
    if(_UseAlphaClipping)
    {   
        clip(alpha - _Cutoff);
    }
    */

    //2020-6-8: now temp use this method, it is not good, don't learn it, should convert this back to a normal shader_feature
    clip(alpha - _Cutoff + (1.0001-_UseAlphaClipping));
}
SurfaceData InitializeSurfaceData(Varyings input)
{
    SurfaceData output;

    // albedo & alpha
    float4 baseColorFinal = GetFinalBaseColor(input);
    output.albedo = baseColorFinal.rgb;
    output.alpha = baseColorFinal.a;
    DoClipTestToTargetAlphaValue(output.alpha);//early exit if possible

    //emission
    output.emission = GetFinalEmissionColor(input);

    return output;
}

///////////////////////////////////////////////////////////////////////////////////////
// fragment shared functions (Step2: calculate lighting & final color)
///////////////////////////////////////////////////////////////////////////////////////

//all lighting equation written inside this .hlsl,
//just by editing this .hlsl can control most of the visual result.
#include "SimpleURPToonLitOutlineExample_LightingEquation.hlsl"

// this function contains no lighting logic, it just pass lighting results data around
half3 ShadeAllLights(SurfaceData surfaceData, LightingData lightingData)
{
    // Indirect lighting
    half3 indirectResult = ShadeGI(surfaceData, lightingData);

    //////////////////////////////////////////////////////////////////////////////////
    // Light struct is provided by URP to abstract light shader variables.
    // It contains light's
    // - direction
    // - color
    // - distanceAttenuation 
    // - shadowAttenuation
    //
    // URP take different shading approaches depending on light and platform.
    // You should never reference light shader variables in your shader, instead use the 
    // -GetMainLight()
    // -GetLight()
    // funcitons to fill this Light struct.
    //////////////////////////////////////////////////////////////////////////////////

    //==============================================================================================
    // Main light is the brightest directional light.
    // It is shaded outside the light loop and it has a specific set of variables and shading path
    // so we can be as fast as possible in the case when there's only a single directional light
    // You can pass optionally a shadowCoord (computed per-vertex). If so, shadowAttenuation will be
    // computed.
    Light mainLight;
#ifdef _MAIN_LIGHT_SHADOWS
    mainLight = GetMainLight(lightingData.shadowCoord);
#else
    mainLight = GetMainLight();
#endif 

    // Main light
    half3 mainLightResult = ShadeMainLight(surfaceData, lightingData, mainLight);

    //==============================================================================================
    // All additional lights

    half3 additionalLightSumResult = 0;

#ifdef _ADDITIONAL_LIGHTS
    // Returns the amount of lights affecting the object being renderer.
    // These lights are culled per-object in the forward renderer of URP.
    int additionalLightsCount = GetAdditionalLightsCount();
    for (int i = 0; i < additionalLightsCount; ++i)
    {
        // Similar to GetMainLight(), but it takes a for-loop index. This figures out the
        // per-object light index and samples the light buffer accordingly to initialized the
        // Light struct. If _ADDITIONAL_LIGHT_SHADOWS is defined it will also compute shadows.
        Light light = GetAdditionalLight(i, lightingData.positionWS);

        // Different functions used to shade the additional light.
        additionalLightSumResult += ShadeAdditionalLight(surfaceData, lightingData, light);
    }
#endif
    //==============================================================================================
    // emission
    half3 emissionResult = surfaceData.emission;

    return CompositeAllLightResults(indirectResult, mainLightResult, additionalLightSumResult, emissionResult);
}

half3 ConvertSurfaceColorToOutlineColor(half3 originalSurfaceColor)
{
    return originalSurfaceColor * _OutlineColor;
}

//only the .shader file will call this function
half4 ShadeFinalColor(Varyings input, bool isOutline)
{
    //////////////////////////////////////////////////////////////////////////////////////////
    //first prepare all data for lighting function
    //////////////////////////////////////////////////////////////////////////////////////////

    //SurfaceData:
    SurfaceData surfaceData = InitializeSurfaceData(input);

    //LightingData:
    LightingData lightingData;
    lightingData.positionWS = input.positionWSAndFogFactor.xyz;
    lightingData.viewDirectionWS = SafeNormalize(GetCameraPositionWS() - lightingData.positionWS);  
    lightingData.normalWS = normalize(input.normalWS); //interpolated normal is NOT unit vector

#ifdef _MAIN_LIGHT_SHADOWS
    lightingData.shadowCoord = input.shadowCoord;
#endif
 
    //////////////////////////////////////////////////////////////////////////////////////////
    // lighting calculation START
    //////////////////////////////////////////////////////////////////////////////////////////

    half3 color = ShadeAllLights(surfaceData, lightingData);

    //////////////////////////////////////////////////////////////////////////////////////////
    // lighting calculation END
    //////////////////////////////////////////////////////////////////////////////////////////

    // outline (isOutline should be a compile time const, so no performance cost here)
    if(isOutline)
    {
        color = ConvertSurfaceColorToOutlineColor(color);
    }

    // fog
    half fogFactor = input.positionWSAndFogFactor.w;
    // Mix the pixel color with fogColor. You can optionaly use MixFogColor to override the fogColor
    // with a custom one.
    color = MixFog(color, fogFactor);

    return half4(color,1);
}

//////////////////////////////////////////////////////////////////////////////////////////
// fragment shared functions (for ShadowCaster pass & DepthOnly pass to use only)
//////////////////////////////////////////////////////////////////////////////////////////
half4 BaseColorAlphaClipTest(Varyings input)
{
    DoClipTestToTargetAlphaValue(GetFinalBaseColor(input).a);
    return 0;
}

#endif
