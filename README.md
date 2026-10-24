# Stick Skeleton

A neon stick-figure skeleton, drawn in the UI layer, on every elite or special your class ability marks.

An outline lives in 3D and is sorted by depth, so a nearer enemy's outline always paints over a farther one. This is not an outline: it is a UI widget, drawn after every 3D pass, so nothing can cover it. It also says *which part* you are looking at -- head, torso, hands, feet -- which a silhouette cannot.

---

## Requirements

- Warhammer 40,000: Darktide
- **Darktide Mod Framework (DMF)** -- the mod will not load without it

## Install

1. Install DMF.
2. Unzip `MarkedStick_v0.2.1.zip` into your `mods` folder. You should end up with `mods/MarkedStick/MarkedStick.mod`.
3. Enable **Stick Skeleton** in the in-game mod list.

**The zip must be unzipped.** Dropping the archive into `mods` does nothing -- the framework only scans `.mod` files, and a zipped mod simply never appears in the list.

## What it draws

- **14 bead chains**: spine, neck, collarbones, upper arms, forearms, thighs, shins. Each is a chain of small squares, because the UI renderer cannot rotate a rect -- and the segmented look is the point.
- **6 joint dots**: head, torso, both hands, both feet. A dot is never smaller than 1.8x the line width, so a joint never reads as just another bead.
- **One scale for the whole figure**: every width is derived from the projected height of the skeleton, so the proportions hold at 3 m and at 40 m instead of turning into a blob.
- **Four-band neon**: a near-white core plus three halos at 252 / 158 / 66 / 28 alpha, each wider than the last. A single halo band is a hard edge; four are a falloff.
- **Distance** in metres under the skeleton.
- **Optional motion**: a sine breath (never a blink) and an RGB colour cycle, both starting from the colour you picked. The head can carry its own colour.
- **Your marks and your teammates'**, as two complete colour sets. The split comes from the game's own tag record (who applied the tag), so it is exact and it follows an enemy the moment somebody re-tags it.

Range never takes the lines away. The chains and the joint dots are drawn at every distance; what recedes is the glow, which dims towards a floor so a far target is a thin neon line instead of six disconnected dots.

## Settings

| Setting | Default | What it does |
|---|---|---|
| Enable | on | master switch |
| Body colour | pink | one pick re-tints the whole skeleton |
| Head colour | same as body | neck segment + head dot only |
| RGB cycle / speed | on / 100 | hue drifts from your picked colour, 9 s per lap at 100 |
| Breathing / depth / speed | on / 40 / 300 | sine brightness sway; depth is capped at 80 so it can never blink out |
| Line thickness | 8 | bead core width in pixels at close range |
| Glow | 50 | halo spread and brightness; 0 leaves only the lit cores. A small pixel floor keeps it working at range |
| Joint dot size | 120 | percentage of line width, floored at 180 % |
| Teammates' marks | on | draw enemies a teammate tagged too; off draws yours only |
| Teammates' colour / head colour | cyan | their own set, independent of yours |
| Teammates' cycle / speed | on / 100 | their cycle has its own origin and speed |
| Teammates' breathing / depth / speed | on / 40 / 300 | independent of your own breathing |
| Teammates' thickness / glow / joint size | 6 / 50 / 120 | a touch thinner by default, so your own mark stays the louder one |
| Beads per segment | 14 | ceiling, 2-24. Also the performance lever |
| Head / torso / arms / legs / distance | on | per-group switches, shared by both sets |

With the default thickness of 8 the joint dots sit on their 1.8x floor, so the size slider only starts to bite above 180.

## Commands

| Command | What it does |
|---|---|
| `/stick_diag` | lifecycle state: units tracked, marked, markers alive, error counters |
| `/stick_rig` | dumps the real skeleton of a marked unit -- every bone name the game will enumerate, each joint candidate with its world position, and the breed's hit zones. Long output, 40 lines per page; run it again for the next page. |
| `/stick_glow` | prints the numbers the last drawn frame used for the neon glow: setting, projected ratio, core and halo widths, brightness lift. Attach it if the glow slider ever looks dead. |

`/stick_rig` is the diagnostic to attach to a bug report if a limb is missing, `/stick_glow` if the neon strength looks wrong.

## Limits

- The skeleton is drawn from the game's own bones. A segment whose joint does not resolve on a breed is skipped whole -- it is never drawn to a guessed position. Enemies with fewer than six usable joints fall back to the head and torso dots.
- At point-blank range (a human closer than about 1.3 m) the feet leave the widget's coordinate space and clip.
- Joint dots are concentric squares: the UI renderer has no circle primitive. At the sizes used they read as dots.
- There is deliberately no line-of-sight test. A marked enemy behind a wall is still drawn; that is what the mod is for.

## Language

The menu and descriptions follow the game's language setting: English, Simplified Chinese, or Traditional Chinese. Any other language falls back to English.

## 中文速览

**安装**：解压 `MarkedStick_v0.2.1.zip` 到 `mods` 目录（必须解压，zip 直接丢进去不会出现在列表里），得到 `mods/MarkedStick/MarkedStick.mod`，然后在 mod 列表里启用「竹节虫骨架」。需要 DMF 框架。

**它是干什么的**：给被职业技能标记的精英与专家画一副霓虹竹节虫骨架——躯干、头颈、锁骨、双臂、双腿由小珠子串成，头/躯干/双手/双脚各一个发光点。画在 UI 层，任何轮廓都盖不住它。

**默认外观**：粗细 8、霓虹强度 50、关节点 120、呼吸开启（强度 40、速度 300）、RGB 循环开启。全部 28 项设置都可在菜单里改。

**自己与他人分开显示**：你自己标记的敌人用一套颜色（默认品红），队友标记的敌人用另一套（默认青色），两套都各自带身体色、头部色、RGB 循环与速度、霓虹强度、粗细、关节点大小、呼吸灯。判断依据是游戏自己记录的标记者，所以队友重新标记同一个敌人时颜色会立刻跟着换。不想要队友的标记就把「队友的标记」关掉。

**命令**：`/stick_diag` 看状态；`/stick_rig` 导出被标记敌人身上真实的骨骼名（长输出，分批查看）——某个肢体没画出来就把这个输出附在反馈里；`/stick_glow` 打印上一帧霓虹光晕的实际数值（设置值、投影比例、芯与三层光晕的宽度、亮度增益），霓虹强度看着不对就附它。
