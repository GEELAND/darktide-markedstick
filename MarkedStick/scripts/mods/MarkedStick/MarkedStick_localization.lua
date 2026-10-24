return {
	mod_name = {
		en = "Stick Skeleton",
		["zh-cn"] = "竹节虫骨架",
		["zh-tw"] = "竹節蟲骨架",
	},
	mod_description = {
		en = "Draws a neon stick-figure skeleton on every elite or special your class ability marks: a bead-chain spine, neck, collarbones, arms and legs, with glowing joint dots on the head, torso, hands and feet -- the head in its own colour if you want it. Every width scales with the projected height of the whole figure, so the skeleton keeps its proportions at any range, and the light is built from the same four-band ladder a neon tube uses. Optional sine breathing and an RGB colour cycle, both starting from the colour you picked. Drawn in the UI layer, so no outline can ever cover it.",
		["zh-cn"] = "给被职业技能标记的精英与专家画一副霓虹竹节虫骨架：躯干、头颈、锁骨、双臂、双腿全部由小珠子串成，头、躯干、双手、双脚上各放一个明显的发光点——头部可以单独配色。所有粗细随整具骨架的投影高度同步缩放，任何距离都保持比例；光感来自霓虹灯管同款四层光晕阶梯。可选项：正弦呼吸灯与 RGB 循环，起点都是你选的颜色。画在 UI 层，任何轮廓都盖不住。",
		["zh-tw"] = "給被職業技能標記的精英與專家畫一副霓虹竹節蟲骨架：軀幹、頭頸、鎖骨、雙臂、雙腿全部由小珠子串成，頭、軀幹、雙手、雙腳上各放一個明顯的發光點——頭部可以單獨配色。所有粗細隨整具骨架的投影高度同步縮放，任何距離都保持比例；光感來自霓虹燈管同款四層光暈階梯。可選項：正弦呼吸燈與 RGB 循環，起點都是你選的顏色。畫在 UI 層，任何輪廓都蓋不住。",
	},
	stick_enabled_title = {
		en = "Enable stick skeleton",
		["zh-cn"] = "启用竹节虫骨架",
		["zh-tw"] = "啟用竹節蟲骨架",
	},
	stick_enabled_description = {
		en = "Draw the skeleton on marked elites and specials.",
		["zh-cn"] = "在被标记的精英与专家身上显示骨架。",
		["zh-tw"] = "在被標記的精英與專家身上顯示骨架。",
	},
	stick_color_title = {
		en = "Body colour",
		["zh-cn"] = "身体颜色",
		["zh-tw"] = "身體顏色",
	},
	stick_color_description = {
		en = "The colour of the gas. The bead cores, the joint dots and the halos are all derived from it, so one pick re-tints the whole skeleton. Distance is shown by brightness, never by hue.",
		["zh-cn"] = "灯管里气体的颜色。珠子芯、关节点和光晕都由它推导出来，选一次就能整体换色。距离只用明暗表示，不会改色相。",
		["zh-tw"] = "燈管裡氣體的顏色。珠子芯、關節點和光暈都由它推導出來，選一次就能整體換色。距離只用明暗表示，不會改色相。",
	},
	stick_head_color_title = {
		en = "Head colour",
		["zh-cn"] = "头部颜色",
		["zh-tw"] = "頭部顏色",
	},
	stick_head_color_description = {
		en = "A second colour for the neck segment and the head dot, so the weakspot can be called out on its own. Defaults to the body colour, and the colour cycle drifts away from it just like it drifts away from the body colour.",
		["zh-cn"] = "头颈段与头部关节点专用色，用来单独标出弱点。默认与身体同色；RGB 循环同样以它为起点漂移，两者同步但不会混成一种。",
		["zh-tw"] = "頭頸段與頭部關節點專用色，用來單獨標出弱點。預設與身體同色；RGB 循環同樣以它為起點漂移，兩者同步但不會混成一種。",
	},
	stick_rgb_title = {
		en = "RGB cycle",
		["zh-cn"] = "RGB 循环",
		["zh-tw"] = "RGB 循環",
	},
	stick_rgb_description = {
		en = "Drift the hue around the colour wheel, starting from the colour you picked. Every marked enemy drifts together, so the skeletons on screen always share one colour.",
		["zh-cn"] = "色相绕色环漂移，起点就是你选的颜色。所有标记同步循环，场上的骨架始终同色。",
		["zh-tw"] = "色相繞色環漂移，起點就是你選的顏色。所有標記同步循環，場上的骨架始終同色。",
	},
	stick_rgb_speed_title = {
		en = "RGB speed (%%)",
		["zh-cn"] = "RGB 速度（%%）",
		["zh-tw"] = "RGB 速度（%%）",
	},
	stick_rgb_speed_description = {
		en = "100 makes one full lap of the colour wheel take nine seconds. Lower is slower and more relaxed; higher gets busy fast.",
		["zh-cn"] = "100 表示绕完一整圈色环用九秒。数值越小越慢、越沉；越大很快就显得杂乱。",
		["zh-tw"] = "100 表示繞完一整圈色環用九秒。數值越小越慢、越沉；越大很快就顯得雜亂。",
	},
	stick_breath_title = {
		en = "Breathing",
		["zh-cn"] = "呼吸灯",
		["zh-tw"] = "呼吸燈",
	},
	stick_breath_description = {
		en = "Sway the brightness smoothly with a sine, so there is never a visible step. How deep the dip goes is set by the breathing depth below; the skeleton stays readable at the darkest point.",
		["zh-cn"] = "用正弦曲线让亮度平滑起伏，所以不会有可见的跳变。起伏有多深由下面的「呼吸强度」决定；最暗的时候骨架依然看得清。",
		["zh-tw"] = "用正弦曲線讓亮度平滑起伏，所以不會有可見的跳變。起伏有多深由下面的「呼吸強度」決定；最暗的時候骨架依然看得清。",
	},
	stick_breath_depth_title = {
		en = "Breathing depth (%%)",
		["zh-cn"] = "呼吸强度（%%）",
		["zh-tw"] = "呼吸強度（%%）",
	},
	stick_breath_depth_description = {
		en = "How far the brightness drops at the bottom of each breath. 40 is the default and dips to about 60 percent of full. 0 gives a steady skeleton that does not breathe at all. Higher is a stronger pulse; the darkest setting still keeps a fifth of the light, so the skeleton never blinks out.",
		["zh-cn"] = "每次呼吸最暗时亮度下降多少。默认 40，也就是最暗约为满亮度的 60%%。填 0 则完全不呼吸、恒定满亮。数值越大起伏越强；最深也只到满亮度的 20%%，所以骨架不会熄灭。",
		["zh-tw"] = "每次呼吸最暗時亮度下降多少。預設 40，也就是最暗約為滿亮度的 60%%。填 0 則完全不呼吸、恆定滿亮。數值越大起伏越強；最深也只到滿亮度的 20%%，所以骨架不會熄滅。",
	},
	stick_breath_speed_title = {
		en = "Breathing speed (%%)",
		["zh-cn"] = "呼吸速度（%%）",
		["zh-tw"] = "呼吸速度（%%）",
	},
	stick_breath_speed_description = {
		en = "100 is a little under four seconds per breath. Lift it for a livelier pulse, drop it for a slow glow. 300 -- the default -- is a brisk 1.2 second pulse.",
		["zh-cn"] = "100 约为四秒一次呼吸。调高更活泼，调低更悠长；默认 300 是约 1.2 秒一次的轻快脉动。",
		["zh-tw"] = "100 約為四秒一次呼吸。調高更活潑，調低更悠長；預設 300 是約 1.2 秒一次的輕快脈動。",
	},
	stick_thickness_title = {
		en = "Line thickness",
		["zh-cn"] = "线条粗细",
		["zh-tw"] = "線條粗細",
	},
	stick_thickness_description = {
		en = "Width of a bead's core, in pixels at close range. The halos and the joint dots scale with it, and the whole skeleton shrinks together with distance, so a distant target keeps clean lines instead of merging into a blob.",
		["zh-cn"] = "珠子芯的宽度（近距离时的像素值）。光晕与关节点都随它一起缩放，整具骨架还会随距离一起缩小，所以远处的目标依然线条清晰，不会糊成一团。",
		["zh-tw"] = "珠子芯的寬度（近距離時的像素值）。光暈與關節點都隨它一起縮放，整具骨架還會隨距離一起縮小，所以遠處的目標依然線條清晰，不會糊成一團。",
	},
	stick_glow_title = {
		en = "Glow (%%)",
		["zh-cn"] = "霓虹强度（%%）",
		["zh-tw"] = "霓虹強度（%%）",
	},
	stick_glow_description = {
		en = "How far the light spreads from the beads. 0 turns all four halo bands off and leaves only the lit cores; above 100 widens every band. The bands scale with the figure's own size, so a distant target never becomes a blur blob.",
		["zh-cn"] = "光从珠子向外扩散的范围。0 会关掉全部四层光晕、只留发光的芯；超过 100 会加宽每一层。光晕尺寸随骨架自身大小缩放，远处的目标不会糊成一团。",
		["zh-tw"] = "光從珠子向外擴散的範圍。0 會關掉全部四層光暈、只留發光的芯；超過 100 會加寬每一層。光暈尺寸隨骨架自身大小縮放，遠處的目標不會糊成一團。",
	},
	stick_dot_size_title = {
		en = "Joint dot size (%%)",
		["zh-cn"] = "关节点大小（%%）",
		["zh-tw"] = "關節點大小（%%）",
	},
	stick_dot_size_description = {
		en = "Dot diameter as a percentage of the line width. Whatever the slider says, the dot is never allowed below 180%% of the line width -- that floor is what keeps a distant joint readable as a dot instead of another bead. With the default thickness of 8 the floor is what you are seeing.",
		["zh-cn"] = "关节点直径相对于线宽的百分比。无论滑块调到多低，圆点直径都不会小于线宽的 180%%——正是这条下限保证了远处的关节仍然读作一个点，而不是又一颗珠子。默认粗细 8 时，看到的正是这条下限。",
		["zh-tw"] = "關節點直徑相對於線寬的百分比。無論滑塊調到多低，圓點直徑都不會小於線寬的 180%%——正是這條下限保證了遠處的關節仍然讀作一個點，而不是又一顆珠子。預設粗細 8 時，看到的正是這條下限。",
	},
	stick_density_title = {
		en = "Beads per segment",
		["zh-cn"] = "每段珠子数",
		["zh-tw"] = "每段珠子數",
	},
	stick_density_description = {
		en = "Maximum number of beads on one skeleton segment. More beads make the lines denser and smoother; fewer saves performance. The design case is four marked enemies at once, where even the maximum is not a problem, so this only needs turning down on very weak hardware.",
		["zh-cn"] = "单条骨架线段上最多放多少颗珠子。珠子越多线条越密、越顺滑；调小可以省性能。设计场景是场上同时 4 个标记，那时即使拉满也不是问题，所以只有很弱的机器才需要往下调。",
		["zh-tw"] = "單條骨架線段上最多放多少顆珠子。珠子越多線條越密、越順滑；調小可以省效能。設計場景是場上同時 4 個標記，那時即使拉滿也不是問題，所以只有很弱的機器才需要往下調。",
	},
	stick_show_head_title = {
		en = "Head and neck",
		["zh-cn"] = "头颈",
		["zh-tw"] = "頭頸",
	},
	stick_show_head_description = {
		en = "Draw the neck segment and the joint dot on the head.",
		["zh-cn"] = "画头颈段与头部关节点。",
		["zh-tw"] = "畫頭頸段與頭部關節點。",
	},
	stick_show_torso_title = {
		en = "Torso",
		["zh-cn"] = "躯干",
		["zh-tw"] = "軀幹",
	},
	stick_show_torso_description = {
		en = "Draw the spine and the collarbones, with the joint dot on the torso.",
		["zh-cn"] = "画躯干中线与两条锁骨，加上躯干关节点。",
		["zh-tw"] = "畫軀幹中線與兩條鎖骨，加上軀幹關節點。",
	},
	stick_show_arms_title = {
		en = "Arms",
		["zh-cn"] = "双臂",
		["zh-tw"] = "雙臂",
	},
	stick_show_arms_description = {
		en = "Draw both arms -- upper arm and forearm -- with the joint dots on the hands.",
		["zh-cn"] = "画双臂（上臂与前臂），双手上各一个关节点。",
		["zh-tw"] = "畫雙臂（上臂與前臂），雙手上各一個關節點。",
	},
	stick_show_legs_title = {
		en = "Legs",
		["zh-cn"] = "双腿",
		["zh-tw"] = "雙腿",
	},
	stick_show_legs_description = {
		en = "Draw both legs -- thigh and shin -- with the joint dots on the feet. The hip line follows this switch.",
		["zh-cn"] = "画双腿（大腿与小腿），双脚上各一个关节点。髋线也跟这个开关走。",
		["zh-tw"] = "畫雙腿（大腿與小腿），雙腳上各一個關節點。髖線也跟著這個開關走。",
	},
	stick_show_distance_title = {
		en = "Show distance",
		["zh-cn"] = "显示距离",
		["zh-tw"] = "顯示距離",
	},
	stick_show_distance_description = {
		en = "Print the distance in metres under the skeleton.",
		["zh-cn"] = "在骨架下方显示以米为单位的距离。",
		["zh-tw"] = "在骨架下方顯示以米為單位的距離。",
	},
	stick_other_enabled_title = {
		en = "Teammates' marks",
		["zh-cn"] = "队友的标记",
		["zh-tw"] = "隊友的標記",
	},
	stick_other_enabled_description = {
		en = "Also draw a skeleton on enemies a teammate tagged. Off leaves only the enemies you tagged yourself.",
		["zh-cn"] = "队友标记的敌人也画骨架。关掉后只显示你自己标记的敌人。",
		["zh-tw"] = "隊友標記的敵人也畫骨架。關掉後只顯示你自己標記的敵人。",
	},
	stick_other_color_title = {
		en = "Teammates' colour",
		["zh-cn"] = "队友的颜色",
		["zh-tw"] = "隊友的顏色",
	},
	stick_other_color_description = {
		en = "The gas colour for enemies a teammate tagged. It is a separate set from your own colour, so the two are never confused for each other.",
		["zh-cn"] = "队友标记的敌人所用的颜色。它和你自己的颜色是两套独立的设置，两者不会混淆。",
		["zh-tw"] = "隊友標記的敵人所用的顏色。它和你自己的顏色是兩套獨立設定，兩者不會混淆。",
	},
	stick_other_head_color_title = {
		en = "Teammates' head colour",
		["zh-cn"] = "队友的头部颜色",
		["zh-tw"] = "隊友的頭部顏色",
	},
	stick_other_head_color_description = {
		en = "The colour of the neck segment and the head dot on a teammate's mark. Defaults to their body colour.",
		["zh-cn"] = "队友标记的敌人，其头颈段与头部关节点的颜色。默认与他们的身体颜色相同。",
		["zh-tw"] = "隊友標記的敵人，其頭頸段與頭部關節點的顏色。預設與他們的身體顏色相同。",
	},
	stick_other_rgb_title = {
		en = "Teammates' colour cycle",
		["zh-cn"] = "队友的 RGB 循环",
		["zh-tw"] = "隊友的 RGB 循環",
	},
	stick_other_rgb_description = {
		en = "Drift the teammates' hue around the colour wheel, with its own starting point and speed, independent of your own cycle.",
		["zh-cn"] = "让队友标记的颜色绕色环漂移，有自己的起点与速度，与你的循环互不影响。",
		["zh-tw"] = "讓隊友標記的顏色繞色環漂移，有自己的起點與速度，與你的循環互不影響。",
	},
	stick_other_rgb_speed_title = {
		en = "Teammates' cycle speed",
		["zh-cn"] = "队友的循环速度",
		["zh-tw"] = "隊友的循環速度",
	},
	stick_other_rgb_speed_description = {
		en = "How fast the teammates' hue drifts. Independent of your own cycle.",
		["zh-cn"] = "队友标记的颜色漂移得多快。与你的循环无关。",
		["zh-tw"] = "隊友標記的顏色漂移得多快。與你的循環無關。",
	},
	stick_other_breath_title = {
		en = "Teammates' breathing",
		["zh-cn"] = "队友的呼吸灯",
		["zh-tw"] = "隊友的呼吸燈",
	},
	stick_other_breath_description = {
		en = "A sine brightness sway on teammates' marks, with its own depth and speed, independent of your own breathing.",
		["zh-cn"] = "队友标记的骨架做正弦明暗呼吸，深度与速度独立设置，与你的呼吸互不影响。",
		["zh-tw"] = "隊友標記的骨架做正弦明暗呼吸，深度與速度獨立設定，與你的呼吸互不影響。",
	},
	stick_other_breath_depth_title = {
		en = "Teammates' breath depth",
		["zh-cn"] = "队友的呼吸强度",
		["zh-tw"] = "隊友的呼吸強度",
	},
	stick_other_breath_depth_description = {
		en = "How far teammates' brightness drops at the bottom of each breath. 0 gives a steady lamp; the ceiling still keeps a fifth of the light, so the mark never blinks out.",
		["zh-cn"] = "队友标记的骨架每次呼吸最暗时亮度下降多少。填 0 则恒定满亮；最深也只到满亮度的 20%%，所以不会熄灭。",
		["zh-tw"] = "隊友標記的骨架每次呼吸最暗時亮度下降多少。填 0 則恆定滿亮；最深也只到滿亮度的 20%%，所以不會熄滅。",
	},
	stick_other_breath_speed_title = {
		en = "Teammates' breath speed",
		["zh-cn"] = "队友的呼吸速度",
		["zh-tw"] = "隊友的呼吸速度",
	},
	stick_other_breath_speed_description = {
		en = "How fast teammates' marks breathe.",
		["zh-cn"] = "队友标记的骨架呼吸得多快。",
		["zh-tw"] = "隊友標記的骨架呼吸得多快。",
	},
	stick_other_thickness_title = {
		en = "Teammates' thickness",
		["zh-cn"] = "队友的线条粗细",
		["zh-tw"] = "隊友的線條粗細",
	},
	stick_other_thickness_description = {
		en = "Line thickness for teammates' marks. Thinner than your own by default, so your own mark stays the louder of the two.",
		["zh-cn"] = "队友标记的线条粗细。默认比你自己的细一点，让你自己的标记更醒目。",
		["zh-tw"] = "隊友標記的線條粗細。預設比你自己的細一點，讓你自己標記更醒目。",
	},
	stick_other_glow_title = {
		en = "Teammates' glow",
		["zh-cn"] = "队友的霓虹强度",
		["zh-tw"] = "隊友的霓虹強度",
	},
	stick_other_glow_description = {
		en = "How far the light spreads from the beads on teammates' marks. 0 leaves a clean line.",
		["zh-cn"] = "队友标记的珠子向外扩散的光有多远。填 0 只留干净的线。",
		["zh-tw"] = "隊友標記的珠子向外擴散的光有多遠。填 0 只留乾淨的線。",
	},
	stick_other_dot_size_title = {
		en = "Teammates' joint size",
		["zh-cn"] = "队友的关节点大小",
		["zh-tw"] = "隊友的關節點大小",
	},
	stick_other_dot_size_description = {
		en = "Joint dot size on teammates' marks, as a share of their line width. Below 180 the joints stop reading as dots, so that is the floor.",
		["zh-cn"] = "队友标记的关节点大小，按其线宽的比例计算。低于 180 关节点就不再像点，所以那是下限。",
		["zh-tw"] = "隊友標記的關節點大小，按其線寬的比例計算。低於 180 關節點就不再像點，所以那是下限。",
	},
}
