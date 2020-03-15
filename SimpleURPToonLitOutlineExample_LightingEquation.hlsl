//https://github.com/ColinLeung-NiloCat/UnityURPToonLitShaderExample

//This file is intented for you to edit and experiment with different lighting equation.
//Add/edit whatever code you want here

// #ifndef XXX + #define XXX + #endif is a safe guard best practice in almost every .hlsl, 
// doing this can make sure your .hlsl's user can include this .hlsl anywhere anytime without producing any multi include conflict
#ifndef SimpleURPToonLitOutlineExample_LightingEquation_Include
#define SimpleURPToonLitOutlineExample_LightingEquation_Include

half3 ShadeGIDefaultMethod(SurfaceData surfaceData, LightingData lightingData)
{
    half3 SH_Sum = 0;

    // a fake way to hide the 3D feeling by average SH
    SH_Sum += SampleSH(+lightingData.normalWS);
    SH_Sum += SampleSH(-lightingData.normalWS);
    SH_Sum /= 2.0;

    return surfaceData.albedo * (_IndirectLightConstColor + SH_Sum * _IndirectLightMultiplier);   
}
half3 ShadeSingleLightDefaultMethod(SurfaceData surfaceData, LightingData lightingData, Light light)
{
    half3 N = lightingData.normalWS;
    half3 V = lightingData.viewDirectionWS;
    half3 L = light.direction;

    //lighting equation, edit it according to your needs, write whatever you want here
    //=====================================================================================
    half lightAttenuation = saturate(dot(N,L)) > 0 ? 1 : _Transimition; // simple cel shade
    lightAttenuation *= lerp(1,light.shadowAttenuation,_ReceiveShadowMappingAmount);// light's shadow map
    lightAttenuation *= light.distanceAttenuation; // light's distnace fade
    lightAttenuation *= _DirectLightMultiplier; // don't want direct lighting becomes too bright for toon lit characters? lower this value
    return surfaceData.albedo * light.color * lightAttenuation;
    //=====================================================================================
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
// then switch to your own lighting equation here!
////////////////////////////////////////////////////////////////////////////////////////////////////////////

// We split lighting into: 
//- indirect
//- main light 
//- additional light 
// for a more isolated lighting control, just in case you need a separate equation for main light & additional light
half3 ShadeGI(SurfaceData surfaceData, LightingData lightingData)
{
    //you can switch to ShadeGIYourMethod(...) !
    return ShadeGIDefaultMethod(surfaceData, lightingData); 
}
half3 ShadeMainLight(SurfaceData surfaceData, LightingData lightingData, Light light)
{
    //you can switch to your ShadeMainLightYourMethod(...) !
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
