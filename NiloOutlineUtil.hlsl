// For more information, visit -> https://github.com/ColinLeung-NiloCat/UnityURPToonLitShaderExample

#ifndef Include_NiloOutlineUtil
#define Include_NiloOutlineUtil

// If your project has a faster way to get camera fov in shader, you can replace this slow function to your method.
// For example, you write cmd.SetGlobalFloat("_CurrentCameraFOV",cameraFOV) using a new RendererFeature in C#.
// For this tutorial shader, we will keep things simple and use this slower but convenient method to get camera fov
float GetFOVFactor()
{
    //https://answers.unity.com/questions/770838/how-can-i-extract-the-fov-information-from-the-pro.html
    /*float t = unity_CameraProjection._m11;
    float Rad2Deg = 180 / 3.1415;
    float fov = atan(1.0f / t) * 2.0 * Rad2Deg;*/

    //unity_CameraProjection._m11 is actually cot(FOV),
    //so 1/unity_CameraProjection._m11 is tan(FOV), which is (Size of View Plane / Distance to Object)
    //in this use case, if our change of FOV cause size of view plane (in world space) become 2x, we want our outline to also become 2x to compensate this change,
    //and make the outline width same with original
    //converting it back to FOV angle cause some lost of accuracy and speed
    return (1.0f/unity_CameraProjection._m11);
}
float ApplyOutlineDistanceFadeOut(float inputMulFix)
{
    //make outline "fadeout" if character is too small in camera's view
    return saturate(inputMulFix);
}
float GetOutlineCameraFovAndDistanceFixMultiplier(float positionVS_Z)
{
    float cameraMulFix;
    if(unity_OrthoParams.w == 0)
    {
        ////////////////////////////////
        // Perspective camera case
        ////////////////////////////////

        // keep outline similar width on screen accoss all camera distance       
        cameraMulFix = abs(positionVS_Z);
        // keep outline similar width on screen accoss all camera fov
        // this is done BEFORE OutlineDistanceFadeOut because, for example,
        // a character 1m away from camera with fov of 90
        // appears the same size in camera as a character sqrt(3)m away from camera with fov of 60
        cameraMulFix *= GetFOVFactor();

        // can replace to a tonemap function if a smooth stop is needed
        cameraMulFix = ApplyOutlineDistanceFadeOut(cameraMulFix);

        //to match the outline with before this optimization. Should actually be 180 / 3.1415 (Rad2Deg), but 60 will do
        cameraMulFix *= 60;
    }
    else
    {
        ////////////////////////////////
        // Orthographic camera case
        ////////////////////////////////
        float orthoSize = abs(unity_OrthoParams.y);
        orthoSize = ApplyOutlineDistanceFadeOut(orthoSize);
        cameraMulFix = orthoSize * 50; // 50 is a magic number to match perspective camera's outline width
    }

    return cameraMulFix * 0.00005; // mul a const to make return result = default normal expand amount WS
}
#endif

