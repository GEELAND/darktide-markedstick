# Changelog

The public version numbering starts here. Earlier internal iteration numbers
are archived under `build/dev/` and never shipped.

> **Display-name fix, applied to the 1.1.0 zip as well.** The mod list used to
> show "Stick Skeleton", while the folder, the `.mod` file and the mod id have
> always been MarkedStick. Both zips were rebuilt with that one string changed
> -- English, Simplified Chinese and Traditional Chinese now all read
> **MarkedStick**. Nothing else in either build differs.

## 1.3.0

First build that acts on the measurements instead of just taking them.

Measured over two matches on the same map (one with the mod on, one off): about
**2.3 ms of frame time per skeleton**, with the mod costing nothing while no
skeleton is up. Three marked enemies therefore cost 6-8 ms, which is the 20 fps
that was reported.

- **23 percent fewer quads per skeleton.** The two dim halo bands are drawn on
  every second / third bead instead of on all of them. Consecutive beads sit 0.7
  bead-widths apart while the outer band is more than six widths across, so
  neighbours already overlap almost completely: the line is unchanged, there are
  simply fewer squares under it. The last bead of every segment keeps the full
  ladder so a limb does not end in a hard edge. 534 drawn squares per skeleton
  became 409.
- **Markers the engine is not drawing are skipped entirely** (behind the camera,
  off screen, past `max_distance`). Nothing is on screen, so nothing has to be
  cleared or laid out.
- **The clock is calibrated once per session.** The engine's performance counter
  is undocumented; its numbers looked like seconds, which is why the previous
  report could only say "under 0.5 ms" about this mod's own share. It is now
  measured against `os.clock` and the report states the unit it found
  (`timer=engine 1.02e+07 units/s`), so the number is auditable rather than
  assumed.
- **Two-minute reports no longer reset the counters.** They were snapshots that
  threw the past away, so the line printed on returning to the hub described only
  the last two minutes. A session now accumulates from mission start to hub.

## 1.2.2

Fixes for the report added in 1.2.1 -- the first session it logged was useless,
in two different ways, and both are now guarded by tests:

- Frame time was divided by 1000 twice, so a 13 ms frame was logged as
  "avg 0.01 ms (73671.7 fps)". Everything is milliseconds from ingestion now, and
  an assertion pins 60 fps to "avg 16.00 ms (62.5 fps)".
- The lines that carried a percent sign were destroyed by the log channel: DMF
  runs every message through `string.format` again, so "2.5% of a frame" was read
  as a conversion and logged as `string.format: invalid option '% |'` -- four
  errors a minute, and the three most useful lines never appeared. The report now
  says `pct`, and a new guard fails the suite if any line that reaches chat or the
  log contains a literal percent sign.
- The bucket line now also carries our own cost per bucket, so one session
  separates "the frame got slower" from "our Lua got slower".

## 1.2.1

- New `/stick_perf`, and the same report written to the DMF log every two
  minutes and once when you get back to the hub. It answers "this build costs
  frames" with numbers: frame time bucketed by how many skeletons were on
  screen, this mod's own share of that frame, and how the share splits between
  clearing the pool, resolving joints and drawing. A session can be read from
  the log afterwards, so nothing has to be screenshotted mid-fight.
- The accounting is always on inside a mission. It costs a handful of timer
  reads per marker per frame -- less than one bead -- and it uses the engine's
  performance counter when the build exposes one, reporting `timer=os.clock`
  when it has to fall back.

## 1.2.0

- The mod list shows **MarkedStick** in every language instead of
  "Stick Skeleton". The name is the mod's identity and now matches the folder,
  the `.mod` file and the mod id exactly, which is also what the release page
  calls it.
- Your marks stay yours. A target holds exactly one tag, so a teammate who
  re-tags the enemy you marked takes that tag in the game's own books -- the
  skeleton used to follow the tag and turn into their colour. Ownership is now
  one-way while a marker lives: once yours, always yours. It still works in the
  other direction, so an enemy only a teammate had marked turns yours the moment
  you tag it.
- Keystone marks now reach trash. The psyker keystone also marks scabs and
  dregs, which cannot be tagged by hand at all, so the elite/special filter hid
  every one of them. A keystone outline now draws a skeleton whatever the breed.
  Horde bodies you tag by hand are still skipped, so the screen does not fill up.

## 1.1.0

Public numbering moves to 1.x, matching the release line the mod was published
under. Nothing was rewritten -- this is the 1.0 look, tuned.

- New shipped defaults, taken from the approved screenshots: joint dots 200
  (was 120), beads per segment 24 (was 14), teammates' line weight 8 (was 6)
  and teammates' joint dots 150 (was 120). The two colour sets are now equally
  thick; the colour is what tells them apart.
- Honest tooltips: with the shipped 8 px cord the bead ceiling only binds up
  close, because every segment is already full well below 14 at range. The
  slider still has its full 2-24 range, it just does what it says and no more.
- Everything from 0.2.2 is included: attribution compares tag ids against the
  player's own tag list, the master switch and the teammates switch act on
  skeletons already on screen, and `/stick_own` reports the attribution.

## 0.2.2

- Fixed: the player's own marks were painted with the teammates' colour set.
  Cause: the player manager takes a player *index*, so `local_player()` answered
  nil, "who am I" was empty and every tagged enemy fell through to "somebody
  else". Attribution now compares the tag id against the ids the game records on
  the player's own tag extension (integer equality, no identity assumption), and
  a frame that cannot be attributed keeps the previous verdict instead of
  repainting.
- Fixed: the switches did nothing while skeletons were already on screen. The
  master switch now tears the markers down, and turning "teammates' marks" off
  removes the teammate skeletons that are up rather than waiting for a re-tag.
  Both were also why the player's own colour/cycle settings looked dead: the
  wrong colour set was drawing.
- New `/stick_own`: which player the game thinks you are, how many tag ids it
  says you own, and the tag id behind each live mark.

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
