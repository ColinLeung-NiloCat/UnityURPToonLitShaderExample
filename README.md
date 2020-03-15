# UnityURPToonLitShaderExample
A very simple toon lit shader example, for you to learn writing custom shader in Unity URP.

How to try this shader in my project?
-------------------
1. Clone all .shader & .hlsl files into your URP project.
2. Put these files inside the same folder.
3. Change your character's material's shader to "SimpleURPToonLitExample(With Outline)"
4. (optional) edit material properties
5. DONE, you can now test your character with any number of lightprobe/directional light/point light/spot light

What is removed from this example shader?
-------------------
For simplicity, we removed these features from this example shader, else this shader will be way too complex for learning.
- face sphere proxy normal
- hair "angel ring" reflection
- smooth normal outline baking
- GI sphere proxy normal
- rim light
- specular lighting
- HSV control shadow & outline color
- 2D mouth renderer
- stencil local hair shadow on face
- depth offset for eye rendering over hair
- lots of sliders to control final color..........

Runtime enviroment requirment
-----------------------
- URP 7.2.1 or above
- Unity 2019.3 or above

