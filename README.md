# Stick Skeleton

A neon stick-figure skeleton, drawn in the UI layer, on every elite or special your class ability marks.

An outline lives in 3D and is sorted by depth, so a nearer enemy's outline always paints over a farther one. This is not an outline: it is a UI widget, drawn after every 3D pass, so nothing can cover it. It also says *which part* you are looking at -- head, torso, hands, feet -- which a silhouette cannot.

---

## Requirements

- Warhammer 40,000: Darktide
- **Darktide Mod Framework (DMF)** -- the mod will not load without it

## Install

1. Install DMF.
2. Unzip `MarkedStick_v0.1.0.zip` into your `mods` folder. You should end up with `mods/MarkedStick/MarkedStick.mod`.
3. Enable **Stick Skeleton** in the in-game mod list.

**The zip must be unzipped.** Dropping the archive into `mods` does nothing -- the framework only scans `.mod` files, and a zipped mod simply never appears in the list.

## What it draws

- **14 bead chains**: spine, neck, collarbones, upper arms, forearms, thighs, shins. Each is a chain of small squares, because the UI renderer cannot rotate a rect -- and the segmented look is the point.
- **6 joint dots**: head, torso, both hands, both feet. A dot is never smaller than 1.8x the line width, so a joint never reads as just another bead.
- **One scale for the whole figure**: every width is derived from the projected height of the skeleton, so the proportions hold at 3 m and at 40 m instead of turning into a blob.
- **Four-band neon**: a near-white core plus three halos at 252 / 158 / 66 / 28 alpha, each wider than the last. A single halo band is a hard edge; four are a falloff.
- **Distance** in metres under the skeleton.
- **Optional motion**: a sine breath (never a blink) and an RGB colour cycle, both starting from the colour you picked. The head can carry its own colour.

Details fade with range rather than shrinking forever: the chains drop out between roughly 20 and 30 m, the limb dots a little later, and the head and torso dots never fade -- they are the last thing you can find a target by.

## Settings

| Setting | Default | What it does |
|---|---|---|
| Enable | on | master switch |
| Body colour | pink | one pick re-tints the whole skeleton |
| Head colour | same as body | neck segment + head dot only |
| RGB cycle / speed | on / 100 | hue drifts from your picked colour, 9 s per lap at 100 |
| Breathing / depth / speed | on / 40 / 300 | sine brightness sway; depth is capped at 80 so it can never blink out |
| Line thickness | 8 | bead core width in pixels at close range |
| Glow | 50 | halo spread; 0 leaves only the lit cores |
| Joint dot size | 120 | percentage of line width, floored at 180 % |
| Beads per segment | 14 | the performance lever; 8 halves the pass count |
| Head / torso / arms / legs / distance | on | per-group switches |

With the default thickness of 8 the joint dots sit on their 1.8x floor, so the size slider only starts to bite above 180.

## Commands

| Command | What it does |
|---|---|
| `/stick_diag` | lifecycle state: units tracked, marked, markers alive, error counters |
| `/stick_rig` | dumps the real skeleton of a marked unit -- every bone name the game will enumerate, each joint candidate with its world position, and the breed's hit zones. Long output, 40 lines per page; run it again for the next page. |

`/stick_rig` is the diagnostic to attach to a bug report if a limb is missing.

## Limits

- The skeleton is drawn from the game's own bones. A segment whose joint does not resolve on a breed is skipped whole -- it is never drawn to a guessed position. Enemies with fewer than six usable joints fall back to the head and torso dots.
- At point-blank range (a human closer than about 1.3 m) the feet leave the widget's coordinate space and clip.
- Joint dots are concentric squares: the UI renderer has no circle primitive. At the sizes used they read as dots.
- There is deliberately no line-of-sight test. A marked enemy behind a wall is still drawn; that is what the mod is for.

## Language

The menu and descriptions follow the game's language setting: English, Simplified Chinese, or Traditional Chinese. Any other language falls back to English.

## 中文速览

**安装**：解压 `MarkedStick_v0.1.0.zip` 到 `mods` 目录（必须解压，zip 直接丢进去不会出现在列表里），得到 `mods/MarkedStick/MarkedStick.mod`，然后在 mod 列表里启用「竹节虫骨架」。需要 DMF 框架。

**它是干什么的**：给被职业技能标记的精英与专家画一副霓虹竹节虫骨架——躯干、头颈、锁骨、双臂、双腿由小珠子串成，头/躯干/双手/双脚各一个发光点。画在 UI 层，任何轮廓都盖不住它。

**默认外观**：粗细 8、霓虹强度 50、关节点 120、呼吸开启（强度 40、速度 300）、RGB 循环开启。全部 17 项设置都可在菜单里改。

**命令**：`/stick_diag` 看状态；`/stick_rig` 导出被标记敌人身上真实的骨骼名（长输出，分批查看）——如果某个肢体没画出来，把这个输出附在反馈里即可定位。
