# Changelog

The public version numbering starts here. Earlier internal iteration numbers
are archived under `build/dev/` and never shipped.

## 0.2.1

- Bead count range widened to 2-24 (was 4-14). The ceiling now bites both at
  point-blank range and on the long segments, so the slider has somewhere to
  go; 2 leaves only the two end beads.
- Fixed the neon strength knob reading as dead. It only ever scaled the halo
  widths by the projected figure size, which collapses to a fraction of a pixel
  at range -- so on exactly the distant targets this mod now draws, the slider
  did nothing. The halo now also carries a small pixel floor and a steeper
  brightness curve, so the knob widens and brightens the glow at every
  distance, and 0 still means a bare line.
- New `/stick_glow` command: prints the numbers the last drawn frame used
  (setting, projected ratio, core and halo widths, brightness lift). It turns
  "the slider does nothing" into either "the module computed zero" or "the
  engine ignored a non-zero" without another guessing round.

## 0.2.0

- The skeleton no longer loses its lines with range. The bead chains and the
  joint dots are drawn at every distance; what recedes is the glow, which now
  fades towards a floor instead of the chains fading out entirely. A marked
  enemy far away reads as a thin neon line rather than six disconnected dots.
- Marks are split by who made them: enemies you tagged and enemies a teammate
  tagged carry separate, complete colour sets -- body colour, head colour,
  colour cycle plus speed, glow, thickness, joint size and breathing. A
  teammate can only be told apart from you by the game's own tag record, so the
  split follows the tagger and updates the instant an enemy is re-tagged.
- New switch: "Teammates' marks", on by default. Off draws your own marks only.
- `/stick_diag` now reports `mine / theirs / hidden`.
- 28 settings.

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
