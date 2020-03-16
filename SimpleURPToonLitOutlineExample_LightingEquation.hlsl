//https://github.com/ColinLeung-NiloCat/UnityURPToonLitShaderExample

//This file is intented for you to edit and experiment with different lighting equation.
//Add or edit whatever code you want here

// #ifndef XXX + #define XXX + #endif is a safe guard best practice in almost every .hlsl, 
// doing this can make sure your .hlsl's user can include this .hlsl anywhere anytime without producing any multi include conflict
#ifndef SimpleURPToonLitOutlineExample_LightingEquation_Include
#define SimpleURPToonLitOutlineExample_LightingEquation_Include

half3 ShadeGIDefaultMethod(SurfaceData surfaceData, LightingData lightingData)
{
    half3 averageSH = 0;

    // trying to hide the 3D feeling by average SH
    // we just want to tint some envi color only
    averageSH += SampleSH(+lightingData.normalWS);
    averageSH += SampleSH(-lightingData.normalWS);
    averageSH /= 2.0;

    return surfaceData.albedo * (_IndirectLightConstColor + averageSH * _IndirectLightMultiplier);   
}
// this function will be used by all direct lights (directional/point/spot)
half3 ShadeSingleLightDefaultMethod(SurfaceData surfaceData, LightingData lightingData, Light light)
{
    half3 N = normalize(lightingData.normalWS);
    half3 L = normalize(light.direction);
    half3 V = normalize(lightingData.viewDirectionWS);
    half3 H = normalize(L+V);

    half NoL = dot(N,L);

    //debug   
    /*
    return 1
    * surfaceData.albedo
    * light.color 
    * 
    saturate(
        1
        * smoothstep(_CelShadeMidPoint-_CelShadeSoftness,_CelShadeMidPoint+_CelShadeSoftness, NoL)
        * min(2,light.distanceAttenuation)
        * saturate(lerp(1,light.shadowAttenuation,_ReceiveShadowMappingAmount))
        * _DirectLightMultiplier
    );
    */

    // Most important part: lighting equation, edit it according to your needs, write whatever you want here, be creative!
    //==========================================================================================================================
    half lightAttenuation = 1;

    // light's shadow map. If you like hard shadow, you can smoothstep light.shadowAttenuation.
    lightAttenuation *= saturate(lerp(1,light.shadowAttenuation,_ReceiveShadowMappingAmount));

    // light's distance & angle fade for point light & spot light (see GetAdditionalPerObjectLight() in Lighting.hlsl)
    // Lighting.hlsl -> https://github.com/Unity-Technologies/ScriptableRenderPipeline/blob/master/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl
    lightAttenuation *= min(2,light.distanceAttenuation); //max = 2, prevent over bright if light too close, can expose this number to editor if you wish to

    // N dot L
    // simplest cel shade, you can always replace this line by your own better method !
    lightAttenuation *= smoothstep(_CelShadeMidPoint-_CelShadeSoftness,_CelShadeMidPoint+_CelShadeSoftness, NoL);

    half3 resultAttenuationColor = lightAttenuation;

    // don't want direct lighting becomes too bright for toon lit characters? set this value to a lower value 
    resultAttenuationColor *= _DirectLightMultiplier;

    return surfaceData.albedo * light.color * resultAttenuationColor;
    //==========================================================================================================================
}

half3 CompositeAllLightResultsDefaultMethod(half3 indirectResult, half3 mainLightResult, half3 additionalLightSumResult, half3 emissionResult)
{
    return indirectResult + mainLightResult + additionalLightSumResult + emissionResult; //simply add them all together
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Implement your own lighting equation here! 
////////////////////////////////////////////////////////////////////////////////////////////////////////////

half3 ShadeGIYourMethod(SurfaceData surfaceData, LightingData lightingData)
{
    return 0; //write your own equation here !
}
half3 ShadeMainLightYourMethod(SurfaceData surfaceData, LightingData lightingData, Light light)
{
    return 0; //write your own equation here !
}
half3 ShadeAllAdditionalLightsYourMethod(SurfaceData surfaceData, LightingData lightingData, Light light)
{
    return 0; //write your own equation here !
}
half3 CompositeAllLightResultsYourMethod(half3 indirectResult, half3 mainLightResult, half3 additionalLightSumResult, half3 emissionResult)
{
    return 0; //write your own equation here !
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////
// then switch to using your own lighting equation here!
////////////////////////////////////////////////////////////////////////////////////////////////////////////

// We split lighting into: 
//- indirect
//- main light 
//- additional light (point light/spot light)
// for a more isolated lighting control, just in case you need a separate equation for main light & additional light, you can do it easily here

half3 ShadeGI(SurfaceData surfaceData, LightingData lightingData)
{
    //you can switch to ShadeGIYourMethod(...) !
    return ShadeGIDefaultMethod(surfaceData, lightingData); 
}
half3 ShadeMainLight(SurfaceData surfaceData, LightingData lightingData, Light light)
{
    //you can switch to ShadeMainLightYourMethod(...) !
    return ShadeSingleLightDefaultMethod(surfaceData, lightingData, light); 
}
half3 ShadeAdditionalLight(SurfaceData surfaceData, LightingData lightingData, Light light)
{
    //you can switch to ShadeAllAdditionalLightsYourMethod(...) !
    return ShadeSingleLightDefaultMethod(surfaceData, lightingData, light); 
}
half3 CompositeAllLightResults(half3 indirectResult, half3 mainLightResult, half3 additionalLightSumResult, half3 emissionResult)
{
    //you can switch to CompositeAllLightResultsYourMethod(...) !
    return CompositeAllLightResultsDefaultMethod(indirectResult,mainLightResult,additionalLightSumResult,emissionResult); 
}

#endif
