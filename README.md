# UnityURPToonLitShaderExample
A very simple toon lit shader example, for you to learn writing custom shader in URP.

Because this shader is for people learning shader writing in URP, it is an extremely simplified version from the original one (I removed 80% of my code, while just keeping only the most useful part).

Why creating this "simplified version" shader?
-------------------
Lots of my shader friends are looking for a toon lit example shader in URP, so I want them to switch to URP with me, so I decided to provide one. 

Some screenshots from the original shader:
-------------------
URPStandardLit(Left) vs our shader(Right)
![screenshot](https://i.imgur.com/Ma4wwQv.png)

Apply our shader to different models
![screenshot](https://i.imgur.com/AgDKEil.png)

Unlit__________________________________
![screenshot](https://i.imgur.com/tQyWLCl.png)

vs our shader__________________________________
![screenshot](https://i.imgur.com/B8DoTHj.png)

Apply our shader to another model (2020-2 early version screen shots)
![screenshot](https://i.imgur.com/KxdjhCx.png)
![screenshot](https://i.imgur.com/6t2FMcg.png)
![screenshot](https://i.imgur.com/rvMDoWZ.png)

How to try this simplified example shader in my project?
-------------------
1. Clone all .shader & .hlsl files into your URP project.
2. Put these files inside the same folder.
3. Change your character's material's shader to "SimpleURPToonLitExample(With Outline)"
4. (optional) edit material properties
5. DONE, you can now test your character with any number of lightprobe/directional light/point light/spot light

What is not included in this simplified example shader?
-------------------
For simplicity, we removed these features from this example shader, else this shader will be way too complex for reading & learning.
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

When will the original shader release?
-------------------
We don't have ETA now, we are still working on it, here are some videos about the original shader:
- https://youtu.be/uVI_QOioER4
- https://youtu.be/YtAiCHBvZr0
- https://youtu.be/QWB060rVjFI
- https://youtu.be/URVgKT5c3PM
- https://youtu.be/6Gx0LxByfWk


Editor enviroment requirement
-----------------------
- URP 7.2.1 or above
- Unity 2019.3 or above

