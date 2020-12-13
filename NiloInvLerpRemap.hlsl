// https://github.com/ronja-tutorials/ShaderTutorials/blob/master/Assets/047_InverseInterpolationAndRemap/Interpolation.cginc
// edit float to half for optimization, because we usually use this to process color data(half)

#ifndef Include_NiloInvLerpRemap
#define Include_NiloInvLerpRemap

// just like smoothstep(), but linear, not clamped
half invLerp(half from, half to, half value) 
{
    return (value - from) / (to - from);
}
half invLerpClamp(half from, half to, half value)
{
    return saturate(invLerp(from,to,value));
}
// full control remap, but slower
half remap(half origFrom, half origTo, half targetFrom, half targetTo, half value)
{
    half rel = invLerp(origFrom, origTo, value);
    return lerp(targetFrom, targetTo, rel);
}
#endif
