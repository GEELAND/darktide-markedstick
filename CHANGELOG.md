# Changelog

The public version numbering starts here. Earlier internal iteration numbers
are archived under `build/dev/` and never shipped.

## 0.1.0

First public release.

- Neon stick skeleton on marked elites and specials: 14 bead-chain segments
  (spine, neck, collarbones, arms, legs) plus six joint dots on head, torso,
  hands and feet, and the distance in metres underneath.
- Drawn in the UI layer, so no outline or 3D geometry can cover it, and no
  line-of-sight test: a marked enemy behind a wall is still drawn.
- Every width scales with the projected height of the whole figure; detail
  fades with range in linear ramps (chains out first, then limb dots; the head
  and torso dots never fade).
- Four-band neon per bead and per dot: core + three halos at 252 / 158 / 66 / 28
  alpha, each wider than the last.
- Optional sine breathing (depth 0-80, never reaches zero) and an RGB colour
  cycle; the two move brightness and hue respectively and never interfere.
- Separate head colour for the neck segment and the head dot.
- 17 settings. Defaults: breathing and the cycle on, thickness 8, glow 50,
  joint dots 120, breath depth 40, breath speed 300.
- `/stick_diag` for lifecycle state, `/stick_rig` for a full dump of the real
  skeleton of a live marked unit.
- English, Simplified Chinese and Traditional Chinese, following the game's
  language setting.
