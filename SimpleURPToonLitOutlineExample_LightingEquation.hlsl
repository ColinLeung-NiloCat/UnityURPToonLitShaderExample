// For more information, visit -> https://github.com/ColinLeung-NiloCat/UnityURPToonLitShaderExample

// This file is intented for you to edit and experiment with different lighting equation.
// Add or edit whatever code you want here

// #ifndef XXX + #define XXX + #endif is a safe guard best practice in almost every .hlsl, 
// doing this can make sure your .hlsl's user can include this .hlsl anywhere anytime without producing any multi include conflict
#ifndef SimpleURPToonLitOutlineExample_LightingEquation_Include
#define SimpleURPToonLitOutlineExample_LightingEquation_Include

half3 ShadeGIDefaultMethod(ToonSurfaceData surfaceData, LightingData lightingData)
{
    // hide 3D feeling by ignoring all detail SH
    // SH 1 (only use this)
    // SH 234 (ignored)
    // SH 56789 (ignored)
    // we just want to tint some average envi color only
    half3 averageSH = SampleSH(0);

    // occlusion
    // separated control for indirect occlusion
    half indirectOcclusion = lerp(1, surfaceData.occlusion, _OcclusionIndirectStrength);
    half indirectLight = averageSH * _IndirectLightMultiplier * indirectOcclusion;
    return max(indirectLight, _IndirectLightMinColor); // can prevent completely black if lightprobe was not baked
}

// Most important part: lighting equation, edit it according to your needs, write whatever you want here, be creative!
// this function will be used by all direct lights (directional/point/spot)
half3 ShadeSingleLightDefaultMethod(ToonSurfaceData surfaceData, LightingData lightingData, Light light, bool isAdditionalLight)
{
    half3 N = lightingData.normalWS;
    half3 L = light.direction;
    half3 V = lightingData.viewDirectionWS;
    half3 H = normalize(L+V);

    half NoL = dot(N,L);

    half lightAttenuation = 1;

    // light's shadow map. If you prefer hard shadow, you can smoothstep() light.shadowAttenuation to make it sharp.
    lightAttenuation *= lerp(1,light.shadowAttenuation,_ReceiveShadowMappingAmount);

    // light's distance & angle fade for point light & spot light (see GetAdditionalPerObjectLight() in Lighting.hlsl)
    // Lighting.hlsl -> https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl
    lightAttenuation *= light.distanceAttenuation;

    // N dot L
    // simplest 1 line cel shade, you can always replace this line by your own better method !
    half celShadeResult = smoothstep(_CelShadeMidPoint-_CelShadeSoftness,_CelShadeMidPoint+_CelShadeSoftness, NoL);

    // don't want direct lighting's cel shade effect looks too strong? set ignoreValue to a higher value
    lightAttenuation *= lerp(celShadeResult,1, isAdditionalLight? _AdditionalLightIgnoreCelShade : _MainLightIgnoreCelShade);

    // don't want direct lighting becomes too bright for toon lit characters? set this value to a lower value 
    lightAttenuation *= _DirectLightMultiplier;

    // occlusion
    // separated control for direct occlusion
    half directOcclusion = lerp(1, surfaceData.occlusion, _OcclusionDirectStrength);
    lightAttenuation *= directOcclusion;

    return light.color * lightAttenuation;
}

half3 CompositeAllLightResultsDefaultMethod(half3 indirectResult, half3 mainLightResult, half3 additionalLightSumResult, half3 emissionResult, ToonSurfaceData surfaceData, LightingData lightingData)
{
    // [you can write anything here]
    // here we don't allow result brighter than albedo, preventing light over bright
    // while still want to preserve light color's hue
    half3 rawLightSum = max(indirectResult, mainLightResult + additionalLightSumResult);
    half lightLuminance = Luminance(rawLightSum);
    half3 finalLight = rawLightSum / max(1,lightLuminance / max(1,log10(lightLuminance)));
    return surfaceData.albedo * finalLight + emissionResult;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Implement your own lighting equation here! 
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

half3 ShadeGIYourMethod(ToonSurfaceData surfaceData, LightingData lightingData)
{
    return 0; //write your own equation here ! (see ShadeGIDefaultMethod(...))
}
half3 ShadeMainLightYourMethod(ToonSurfaceData surfaceData, LightingData lightingData, Light light)
{
    return 0; //write your own equation here ! (see ShadeSingleLightDefaultMethod(...))
}
half3 ShadeAllAdditionalLightsYourMethod(ToonSurfaceData surfaceData, LightingData lightingData, Light light)
{
    return 0; //write your own equation here ! (see ShadeSingleLightDefaultMethod(...))
}
half3 CompositeAllLightResultsYourMethod(half3 indirectResult, half3 mainLightResult, half3 additionalLightSumResult, half3 emissionResult)
{
    return 0; //write your own equation here ! (see CompositeAllLightResultsDefaultMethod(...))
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Once you have implemented an equation in the above section, switch to use your own lighting equation in below section!
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// We split lighting functions into: 
//- indirect
//- main light 
//- additional light (point light/spot light)

half3 ShadeGI(ToonSurfaceData surfaceData, LightingData lightingData)
{
    //you can switch to ShadeGIYourMethod(...) !
    return ShadeGIDefaultMethod(surfaceData, lightingData); 
}
half3 ShadeMainLight(ToonSurfaceData surfaceData, LightingData lightingData, Light light)
{
    //you can switch to ShadeMainLightYourMethod(...) !
    return ShadeSingleLightDefaultMethod(surfaceData, lightingData, light, false); 
}
half3 ShadeAdditionalLight(ToonSurfaceData surfaceData, LightingData lightingData, Light light)
{
    //you can switch to ShadeAllAdditionalLightsYourMethod(...) !
    return ShadeSingleLightDefaultMethod(surfaceData, lightingData, light, true); 
}
half3 CompositeAllLightResults(half3 indirectResult, half3 mainLightResult, half3 additionalLightSumResult, half3 emissionResult, ToonSurfaceData surfaceData, LightingData lightingData)
{
    //you can switch to CompositeAllLightResultsYourMethod(...) !
    return CompositeAllLightResultsDefaultMethod(indirectResult,mainLightResult,additionalLightSumResult,emissionResult, surfaceData, lightingData); 
}

#endif
