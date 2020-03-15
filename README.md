# UnityURPToonLitShaderExample
A very simple toon lit shader example, for you to learn writing custom shader in Unity URP.

How to try this shader in my project?
-------------------
1. Clone a .shader & two .hlsl files into your URP project (needs URP 7.2.1 or above)
2. Put these 3 files them inside the same folder.
3. Change your character's material's shader to "SimpleURPToonLitExample(With Outline)"
4. (optional) edit material properties
5. DONE

What is removed from in the example?
-------------------
For simplicity, we removed these features from this example shader, else this shader will be too complex for learning.
- face sphere proxy normal
- GI sphere proxy normal
- rim light
- specular lighting
- HSV control shadow & outline color
- 2D mouth renderer
- stencil local hair shadow on face
- depth offset for eye rendering over hair
- lots of little features to control final color..........

