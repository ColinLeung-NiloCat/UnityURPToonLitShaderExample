# Unity URP Simplified Toon Lit Shader Example (for learning shader writing in URP)
A very simple toon lit shader example, to help people writing their first custom toon lit shader in URP.

Because this toon lit shader was created to help people learning shader writing the first time in URP, it is an extremely simplified version of the original one (I removed 80% of my original code, while just keeping only the most useful & easy to understand sections), to make sure everyone can understand it easily.

Maybe I simplified it too much, now it is a "How to write a custom lit shader in URP" example, instead of a good toon lit example (lots of toon lit tricks not included in this shader, for simplicity reason).

Why creating this "simplified version" toon lit shader?
-------------------
Lots of my shader friends are looking for a toon lit example shader in URP (not Shader Graph), I want them to switch to URP with me, so I decided to provide a simple enough example URP toon lit shader. 

Some screenshots from the original shader:
-------------------
URPStandardLit(Left) vs our shader(Right)
![screenshot](https://i.imgur.com/Ma4wwQv.png)

Apply our shader to different models
![screenshot](https://i.imgur.com/AgDKEil.png)

Unlit______________________________________________________________________________
![screenshot](https://i.imgur.com/tQyWLCl.png)

vs our shader______________________________________________________________________
![screenshot](https://i.imgur.com/B8DoTHj.png)

Apply our shader to another model (2020-2 early version screen shots)
![screenshot](https://i.imgur.com/KxdjhCx.png)
![screenshot](https://i.imgur.com/6t2FMcg.png)
![screenshot](https://i.imgur.com/LBTNZCH.png)
![screenshot](https://i.imgur.com/X6hAD7W.png)
![screenshot](https://i.imgur.com/WIGyMVx.png)
![screenshot](https://i.imgur.com/zou7PxL.png)
![screenshot](https://i.imgur.com/CZHnfMC.png)


How to try this simplified example shader in my project?
-------------------
1. Clone all .shader & .hlsl files into your URP project.
2. Put these files inside the same folder.
3. Change your character's material's shader to "SimpleURPToonLitExample(With Outline)"
4. (optional) edit material properties
5. setup DONE, you can now test your character with light probe/directional light/point light/spot light
6. most important: open these shader files, spend some time reading it, you will understand how to write custom lit shader in URP very quickly
7. most important: open "SimpleURPToonLitOutlineExample_LightingEquation.hlsl", edit it, experiment with your own toon lighting equation ideas, which is the key part of toon lit shader!

What is not included in this simplified example shader?
-------------------
For simplicity reason, I removed most of the features from the original shader (deleted 80% of the original shader code), else this shader will be way too complex for reading & learning.The removed features are:
- face sphere proxy normal
- hair "angel ring" reflection
- smooth outline normal auto baking
- character bounding sphere proxy normal
- rim light
- specular lighting
- HSV control shadow & outline color
- 2D mouth renderer
- stencil local hair shadow on face
- depth offset for eye rendering over hair
- most of the extra input options like AO, specular, normal map...
- LOTS of sliders to control lighting, final color & outline

When will the original toon lit shader(Full version) release?
-------------------
We don't have ETA now, we are still working on it, here are some videos about the original toon lit shader:
- https://youtu.be/uVI_QOioER4
- https://youtu.be/YtAiCHBvZr0
- https://youtu.be/QWB060rVjFI
- https://youtu.be/URVgKT5c3PM
- https://youtu.be/6Gx0LxByfWk


Editor environment requirement
-----------------------
- URP 7.2.1 or above
- Unity 2019.3 or above

