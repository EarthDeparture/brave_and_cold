# Visual reference analysis (owner-supplied Long Dark screenshots)

Images in docs/reference/ (internal look-dev targets only, never shipped, never used as textures).
Sampled colors below are k-means clusters from the screenshots (hex), a starting point for LUTs and sky gradients, not final values.

## What the four references establish
| Ref | Time and weather | Sky | Distant mountains | Snow | Local light | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| 01 crimson dusk town | Dusk, clear, cold | Deep plum top #43243c to magenta #813e5a to hot pink #c2506d at horizon; painted cloud wisps in pink | Flat, faceted, red-pink silhouettes with hard-edged dark blotch shadow shapes, almost no atmospheric detail | Snow takes pink/violet from the sky (#6a445b, warm #ba6a58 near the fire); deep plum shadows #25151e | Orange fire on pallets, warm window glow, dark smoke columns | The whole frame is one hue family; only fire and windows break it |
| 02 golden dusk cabin | Dusk, clear | Amber glow #e0a86d low, dusty rose-brown above #ad7d65 | Layered peaks fading into the glow (atmospheric perspective), dark silhouette conifers in front | Muted, low key #545055 | Sun behind peaks, rim-lit ridgelines | Strong depth layering, silhouettes over glow |
| 03 overcast peaks and forest | Day, thin cloud | Steel blue #557da2 fading to pale #90acc3 | Big faceted blue-grey peaks with white planes and dark blue-grey planes (#334a65), very graphic | Bright grey-blue #a6b6b8 lit, #6b7a83 shade | None | Dense conifer carpet, dark navy rocks with white caps |
| 04 bright day | Day, clear with cumulus | Saturated blue #3c6287 to pale cyan #789fbb, painted white clouds | Blue-white distant | Cyan-tinted snow (#cbd9dc lit, #7c99a4 shade), sparkle none, ice patches dark navy #243346 | None | Frosted conifers with cyan shadow side, pale yellow frozen grass tufts, first-person hand with plaid sleeve, HUD icon cluster bottom-left |

## Rules extracted (feed into GDD Section 3)
1. Shadows are never black or grey: they are a saturated cool (blue by day, plum by dusk). Snow color is the sky color at reduced luminance.
2. Distant mountains are stylized shapes, not realistic terrain: flat color planes, hard facet edges, blotchy painted shadow shapes, strong silhouette, few values. Real DEM far terrain must be run through a facet/posterize stylizer, or replaced with authored mountain meshes.
3. Foreground detail is painterly and readable: frosted conifers with a light side and a shadow side, pale dry grass tufts poking through snow, dark ice patches, deep drifts around vehicles.
4. Lighting range is huge: saturated crimson dusk, amber golden hour, cold blue noon, overcast steel; plus night (not in the refs). Exposure and color grade change more than light intensity.
5. Local warm light (fire, windows) is the only saturated warm accent in cold scenes and must be very readable from far away.
6. Skies are painted gradients with stylized cloud shapes, not simulated volumetrics.
7. Atmospheric perspective is used selectively (golden dusk) and flat-graphic elsewhere (crimson, overcast peaks).
8. Sparkle and noise are minimal; surfaces are smooth with soft edges.

## Day-night lighting range (target states; 01-04 from references, others extrapolated and to be tuned in look-dev)
| State | Sun elev. | Sky top / horizon | Key light | Shadow and ambient | Fog | Grade |
| --- | --- | --- | --- | --- | --- | --- |
| Pre-dawn | -8 to 0 | Indigo to teal-rose | None | Deep blue ambient | Cool blue-violet, dense | Low exposure, cold |
| Dawn | 0 to 8 | Plum to peach | Low warm pink-orange | Blue-violet | Pink haze near horizon | Warm horizon, cold ground |
| Morning | 8 to 30 | Blue to pale cyan | Soft warm white | Cyan-blue | Light cyan | Crisp, clean |
| Clear noon (ref 04) | 30 to 45 | #3c6287 to #789fbb | Soft white | Cyan #7c99a4 | Very light | Highest saturation blue |
| Overcast (ref 03) | any | #557da2 to #90acc3 | None (diffuse) | Blue-grey #6b7a83 | Medium grey-blue | Low contrast, flat |
| Golden hour (ref 02) | 5 to 15 | Amber #e0a86d to rose-brown | Deep gold | Brown-violet | Amber, layered depth | Warm, moody |
| Crimson dusk (ref 01) | -2 to 4 | Plum #43243c to pink #c2506d | Red-pink | Deep plum #25151e | Magenta | Monochrome hue family, fire pops |
| Twilight | -8 to -2 | Indigo to violet | None | Blue-violet | Blue | Cold, low key |
| Night, clear | below -12 | Navy, stars, aurora option | Moon cool blue-white | Near-black blue | Thin dark blue | Very low exposure, warm lights dominate |
| Blizzard | any | Milky grey-white | None | Grey | Very dense white | Desaturated, 20-40 m visibility |

Implementation targets: sky gradient + cloud layer shader driven by sun elevation; per-state color LUT and fog color blended by the game clock; exposure eased separately from light intensity; hand-authored stylized far-mountain ring; local point lights tuned for high warmth contrast.
