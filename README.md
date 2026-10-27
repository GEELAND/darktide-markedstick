# MarkedStick

A neon stick-figure skeleton, drawn in the UI layer, on every elite or special your class ability marks.

The mod list shows **MarkedStick** in every language: it is the mod's identity, and it is the same string as the folder and the `.mod` file, so what you enable in game is what you see in `mods/`.

An outline lives in 3D and is sorted by depth, so a nearer enemy's outline always paints over a farther one. This is not an outline: it is a UI widget, drawn after every 3D pass, so nothing can cover it. It also says *which part* you are looking at -- head, torso, hands, feet -- which a silhouette cannot.

---

## Requirements

- Warhammer 40,000: Darktide
- **Darktide Mod Framework (DMF)** -- the mod will not load without it

## Install

1. Install DMF.
2. Unzip `MarkedStick_v1.2.1.zip` into your `mods` folder. You should end up with `mods/MarkedStick/MarkedStick.mod`.
3. Enable **MarkedStick** in the in-game mod list.

**The zip must be unzipped.** Dropping the archive into `mods` does nothing -- the framework only scans `.mod` files, and a zipped mod simply never appears in the list.

## What it draws

- **14 bead chains**: spine, neck, collarbones, upper arms, forearms, thighs, shins. Each is a chain of small squares, because the UI renderer cannot rotate a rect -- and the segmented look is the point.
- **6 joint dots**: head, torso, both hands, both feet. A dot is never smaller than 1.8x the line width, so a joint never reads as just another bead.
- **One scale for the whole figure**: every width is derived from the projected height of the skeleton, so the proportions hold at 3 m and at 40 m instead of turning into a blob.
- **Four-band neon**: a near-white core plus three halos at 252 / 158 / 66 / 28 alpha, each wider than the last. A single halo band is a hard edge; four are a falloff.
- **Distance** in metres under the skeleton.
- **Optional motion**: a sine breath (never a blink) and an RGB colour cycle, both starting from the colour you picked. The head can carry its own colour.
- **Your marks and your teammates'**, as two complete colour sets. The split comes from the game's own tag record (who applied the tag). An enemy you marked stays yours even if a teammate re-tags it -- the colour never changes under your hands -- while an enemy that was only theirs turns yours the moment you tag it.
- **Keystone marks reach trash too.** The psyker keystone also lands on scabs and dregs, and those cannot be tagged by hand, so they used to be filtered out entirely. A keystone mark now draws a skeleton whatever the breed; horde bodies you tag by hand are still skipped.

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
| Joint dot size | 200 | percentage of line width; 180 % is the hard floor |
| Teammates' marks | on | draw enemies a teammate tagged too; off draws yours only |
| Teammates' colour / head colour | cyan | their own set, independent of yours |
| Teammates' cycle / speed | on / 100 | their cycle has its own origin and speed |
| Teammates' breathing / depth / speed | on / 40 / 300 | independent of your own breathing |
| Teammates' thickness / glow / joint size | 8 / 50 / 150 | same weight as yours; their joints sit on the 180 % floor |
| Beads per segment | 24 | ceiling, 2-24. Bites up close only. Also the performance lever |
| Head / torso / arms / legs / distance | on | per-group switches, shared by both sets |

The joint dot size is a percentage of the line width and can never go below 180 %; with the shipped 200 the dots sit clearly above that floor.

## Commands

| Command | What it does |
|---|---|
| `/stick_diag` | lifecycle state: units tracked, marked, markers alive, error counters |
| `/stick_rig` | dumps the real skeleton of a marked unit -- every bone name the game will enumerate, each joint candidate with its world position, and the breed's hit zones. Long output, 40 lines per page; run it again for the next page. |
| `/stick_glow` | prints the numbers the last drawn frame used for the neon glow: setting, projected ratio, core and halo widths, brightness lift. Attach it if the glow slider ever looks dead. |
| `/stick_own` | which player the game considers local, how many tag ids it says you own, and the tag id behind each live mark -- the answer to "why is my mark painted as a teammate's". |
| `/stick_perf` | frame time bucketed by how many skeletons were on screen, how much of that frame this mod's own Lua spent, and how the cost splits between clearing the pool and drawing. The same lines go to the DMF log every two minutes and once when you return to the hub, so a slow machine can be diagnosed from the log afterwards. |

`/stick_rig` is the diagnostic to attach to a bug report if a limb is missing, `/stick_glow` if the neon strength looks wrong.

## Limits

- The skeleton is drawn from the game's own bones. A segment whose joint does not resolve on a breed is skipped whole -- it is never drawn to a guessed position. Enemies with fewer than six usable joints fall back to the head and torso dots.
- At point-blank range (a human closer than about 1.3 m) the feet leave the widget's coordinate space and clip.
- Joint dots are concentric squares: the UI renderer has no circle primitive. At the sizes used they read as dots.
- There is deliberately no line-of-sight test. A marked enemy behind a wall is still drawn; that is what the mod is for.

## Language

The menu and descriptions follow the game's language setting: English, Simplified Chinese, or Traditional Chinese. Any other language falls back to English.

## 中文速览

**安装**：解压 `MarkedStick_v1.2.1.zip` 到 `mods` 目录（必须解压，zip 直接丢进去不会出现在列表里），得到 `mods/MarkedStick/MarkedStick.mod`，然后在 mod 列表里启用 **MarkedStick**。需要 DMF 框架。

**名字**：mod 列表里三语都显示 **MarkedStick**（不再随语言翻译）——它就是 mod 的标识，和文件夹名、`.mod` 文件名完全一致。

**它是干什么的**：给被职业技能标记的精英与专家画一副霓虹竹节虫骨架——躯干、头颈、锁骨、双臂、双腿由小珠子串成，头/躯干/双手/双脚各一个发光点。画在 UI 层，任何轮廓都盖不住它。

**默认外观**（1.1.0 定版）：粗细 8、霓虹强度 50、关节点 200、每段珠子 24、呼吸开启（强度 40、速度 300）、RGB 循环开启；队友那套默认同粗细、关节点 150、青色调。全部 28 项设置都可在菜单里改。

**自己与他人分开显示**：你自己标记的敌人用一套颜色（默认品红），队友标记的敌人用另一套（默认青色），两套都各自带身体色、头部色、RGB 循环与速度、霓虹强度、粗细、关节点大小、呼吸灯。判断依据是游戏自己记录的标记者。**你标记的敌人即使之后被队友重新标记，也保持你的颜色**（引擎里一个目标只持一个标记，队友覆盖后 tag 归他，但骨架不会在你眼前换主人）；反过来，本来只有队友标记的敌人，你一标记就变成你的。不想要队友的标记就把「队友的标记」关掉。

**基石天赋标记的小兵也会画**：灵能「扰动命运」这类基石会标记血痂/渣滓小兵，而这些敌人无法手动标记，旧版会把它们整个过滤掉。现在只要带的是基石标记，不论兵种都画骨架；**你自己手动标记的小兵仍然不画**，免得满屏骨架。

**命令**：`/stick_diag` 看状态；`/stick_rig` 导出被标记敌人身上真实的骨骼名（长输出，分批查看）——某个肢体没画出来就把这个输出附在反馈里；`/stick_glow` 打印上一帧霓虹光晕的实际数值（设置值、投影比例、芯与三层光晕的宽度、亮度增益），霓虹强度看着不对就附它；`/stick_own` 打印游戏认定的本地玩家、你名下有多少个标记 id、以及每个在场标记的 tag id——用来查“我的标记为什么显示成队友颜色”。；`/stick_perf` 打印帧时间统计（按场上骨架数量分桶的平均帧时间、本 mod 自己占了多少、其中清池/解析关节/绘制各占几成），同样的行每两分钟和回到飞船时自动写进游戏日志，卡顿可以直接事后从日志读。
