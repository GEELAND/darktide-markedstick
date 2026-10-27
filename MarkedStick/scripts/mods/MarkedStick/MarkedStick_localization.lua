return {
	-- The name the mod list shows. It is the same in every language on purpose:
	-- it is the mod's identity, not a description, so it is not translated --
	-- a player comparing two screenshots of the list should see one name.
	-- The internal identifiers (folder, .mod file, mod id, template name, every
	-- setting key) have always been MarkedStick, so this only makes the visible
	-- name agree with them.
	mod_name = {
		en = "MarkedStick",
		["zh-cn"] = "MarkedStick",
		["zh-tw"] = "MarkedStick",
	},
	mod_description = {
		en = "Draws a neon stick-figure skeleton on the enemies your marks land on: elites and specials, plus the trash a keystone mark reaches (those cannot be tagged by hand). A bead-chain spine, neck, collarbones, arms and legs, with glowing joint dots on the head, torso, hands and feet -- the head in its own colour if you want it. Every width scales with the projected height of the whole figure, so the skeleton keeps its proportions at any range, and the light is built from the same four-band ladder a neon tube uses. Optional sine breathing and an RGB colour cycle, both starting from the colour you picked. Your marks keep your colours even if a teammate re-tags the same enemy. Drawn in the UI layer, so no outline can ever cover it.",
		["zh-cn"] = "给被标记的敌人画一副霓虹竹节虫骨架：精英与专家，以及被基石天赋标记到的小兵（这类敌人无法手动标记）。躯干、头颈、锁骨、双臂、双腿全部由小珠子串成，头、躯干、双手、双脚上各放一个明显的发光点——头部可以单独配色。所有粗细随整具骨架的投影高度同步缩放，任何距离都保持比例；光感来自霓虹灯管同款四层光晕阶梯。可选项：正弦呼吸灯与 RGB 循环，起点都是你选的颜色。你标记的敌人即使之后被队友重新标记，也保持你的颜色。画在 UI 层，任何轮廓都盖不住。",
		["zh-tw"] = "給被標記的敵人畫一副霓虹竹節蟲骨架：精英與專家，以及被基石天賦標記到的小兵（這類敵人無法手動標記）。軀幹、頭頸、鎖骨、雙臂、雙腿全部由小珠子串成，頭、軀幹、雙手、雙腳上各放一個明顯的發光點——頭部可以單獨配色。所有粗細隨整具骨架的投影高度同步縮放，任何距離都保持比例；光感來自霓虹燈管同款四層光暈階梯。可選項：正弦呼吸燈與 RGB 循環，起點都是你選的顏色。你標記的敵人即使之後被隊友重新標記，也保持你的顏色。畫在 UI 層，任何輪廓都蓋不住。",
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
		en = "How far the light spreads from the beads, and how bright that skirt is. 0 turns all four halo bands off and leaves only the lit cores; above 100 widens every band and brightens it. The bands still scale with the figure, but a small pixel floor keeps the knob readable on a distant target instead of scaling to nothing.",
		["zh-cn"] = "光从珠子向外扩散的范围，以及这层光的亮度。0 会关掉全部四层光晕、只留发光的芯；超过 100 会同时加宽并提亮每一层。光晕仍随骨架缩放，但保留了一个最小像素宽度，所以远处的目标上这个滑块也不会变成没反应。",
		["zh-tw"] = "光從珠子向外擴散的範圍，以及這層光的亮度。0 會關掉全部四層光暈、只留發光的芯；超過 100 會同時加寬並提亮每一層。光暈仍隨骨架縮放，但保留了一個最小像素寬度，所以遠處的目標上這個滑桿也不會變成沒反應。",
	},
	stick_dot_size_title = {
		en = "Joint dot size (%%)",
		["zh-cn"] = "关节点大小（%%）",
		["zh-tw"] = "關節點大小（%%）",
	},
	stick_dot_size_description = {
		en = "Dot diameter as a percentage of the line width. Whatever the slider says, the dot is never allowed below 180 percent of the line width -- that floor is what keeps a distant joint readable as a dot instead of another bead. The default of 200 puts the joints clearly above that floor.",
		["zh-cn"] = "关节点直径相对于线宽的百分比。无论滑块调到多低，圆点直径都不会小于线宽的 180%%——正是这条下限保证了远处的关节仍然读作一个点，而不是又一颗珠子。默认 200 已经高于这条下限。",
		["zh-tw"] = "關節點直徑相對於線寬的百分比。無論滑塊調到多低，圓點直徑都不會小於線寬的 180%%——正是這條下限保證了遠處的關節仍然讀作一個點，而不是又一顆珠子。預設 200 已經高於這條下限。",
	},
	stick_density_title = {
		en = "Beads per segment",
		["zh-cn"] = "每段珠子数",
		["zh-tw"] = "每段珠子數",
	},
	stick_density_description = {
		en = "Upper limit on how many beads one skeleton segment may use. A segment gets as many as fit at the current bead size, so this only bites when a segment is long on screen -- i.e. up close. At mid and long range every segment is already full well below 14, which is why raising it there changes nothing. Lower it to thin the cord, or to save performance on a weak machine.",
		["zh-cn"] = "单条骨架线段上最多放多少颗珠子。每段只放到“当前珠径下装得下”的数量，所以只有在**近距离、线段在屏幕上够长**时才会用到 14 以上；中远距离各段早就放满了，再往上调不会有变化。调低会让线更细，也能省性能。",
		["zh-tw"] = "單條骨架線段上最多放多少顆珠子。每段只放到「目前珠徑下裝得下」的數量，所以只有在**近距離、線段在螢幕上夠長**時才會用到 14 以上；中遠距離各段早就放滿了，再往上調不會有變化。調低會讓線更細，也能省效能。",
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
	stick_keystone_enabled_title = {
		en = "Keystone marks",
		["zh-cn"] = "基石天赋的标记",
		["zh-tw"] = "基石天賦的標記",
	},
	stick_keystone_enabled_description = {
		en = "Also draw a skeleton on enemies your keystone talent marks by itself. It gets its own colour set, because these marks are the talent's bookkeeping rather than a tag -- the psyker keystone also marks scabs and dregs, which cannot be tagged by hand at all. Off hides them completely, which is worth knowing on a weak machine: one keystone can hold several skeletons at once.",
		["zh-cn"] = "基石天赋自动标记的敌人也画骨架。它单独有一套颜色，因为这些标记不是「标记」而是天赋自己的记账——灵能基石连血痂、渣滓都会标，而这些敌人根本无法手动标记。关掉则完全不显示；机器较弱时值得注意：一个基石可能同时挂着好几具骨架。",
		["zh-tw"] = "基石天賦自動標記的敵人也畫骨架。它單獨有一套顏色，因為這些標記不是「標記」而是天賦自己的記帳——靈能基石連血痂、渣滓都會標，而這些敵人根本無法手動標記。關掉則完全不顯示；機器較弱時值得注意：一個基石可能同時掛著好幾具骨架。",
	},
	stick_keystone_color_title = {
		en = "Keystone colour",
		["zh-cn"] = "基石标记的颜色",
		["zh-tw"] = "基石標記的顏色",
	},
	stick_keystone_color_description = {
		en = "The gas colour for enemies the keystone marked. A third set on top of your own colour and your teammates', so all three can be told apart at a glance.",
		["zh-cn"] = "被基石标记的敌人所用的颜色。在你自己的颜色和队友的颜色之外，这是第三套，三者一眼可分。",
		["zh-tw"] = "被基石標記的敵人所用的顏色。在你自己的顏色和隊友的顏色之外，這是第三套，三者一眼可分。",
	},
	stick_keystone_head_color_title = {
		en = "Keystone head colour",
		["zh-cn"] = "基石标记的头部颜色",
		["zh-tw"] = "基石標記的頭部顏色",
	},
	stick_keystone_head_color_description = {
		en = "The colour of the neck segment and the head dot on a keystone mark. Defaults to its body colour.",
		["zh-cn"] = "基石标记的头颈段与头部关节点的颜色。默认与其身体颜色相同。",
		["zh-tw"] = "基石標記的頭頸段與頭部關節點的顏色。預設與其身體顏色相同。",
	},
	stick_keystone_rgb_title = {
		en = "Keystone colour cycle",
		["zh-cn"] = "基石标记的 RGB 循环",
		["zh-tw"] = "基石標記的 RGB 循環",
	},
	stick_keystone_rgb_description = {
		en = "Drifts the hue of the keystone set around the wheel, starting from the colour picked above. Runs on its own clock, so it does not drag the other two sets with it.",
		["zh-cn"] = "让基石标记那一套的色相绕环漂移，起点是上面选的颜色。它走自己的时钟，不会带动另外两套。",
		["zh-tw"] = "讓基石標記那一套的色相繞環漂移，起點是上面選的顏色。它走自己的時鐘，不會帶動另外兩套。",
	},
	stick_keystone_rgb_speed_title = {
		en = "Keystone cycle speed (%% of 9 s per lap)",
		["zh-cn"] = "基石 RGB 速度（%% of 9 秒一圈）",
		["zh-tw"] = "基石 RGB 速度（%% of 9 秒一圈）",
	},
	stick_keystone_rgb_speed_description = {
		en = "How fast the keystone set's hue travels. 100 is one lap every nine seconds.",
		["zh-cn"] = "基石那一套的色相移动多快。100 表示九秒一圈。",
		["zh-tw"] = "基石那一套的色相移動多快。100 表示九秒一圈。",
	},
	stick_keystone_breath_title = {
		en = "Keystone breathing",
		["zh-cn"] = "基石标记的呼吸灯",
		["zh-tw"] = "基石標記的呼吸燈",
	},
	stick_keystone_breath_description = {
		en = "A sine sway in brightness for the keystone set, independent of the other two sets.",
		["zh-cn"] = "基石那一套的亮度正弦起伏，与另外两套互不干扰。",
		["zh-tw"] = "基石那一套的亮度正弦起伏，與另外兩套互不干擾。",
	},
	stick_keystone_breath_depth_title = {
		en = "Keystone breath depth",
		["zh-cn"] = "基石呼吸强度",
		["zh-tw"] = "基石呼吸強度",
	},
	stick_keystone_breath_depth_description = {
		en = "How far the keystone set dims at the bottom of each breath, as a percentage. 0 gives a steady lamp; the ceiling of 80 keeps a fifth of the light so it never blinks out.",
		["zh-cn"] = "基石那一套每次呼吸最暗时亮度下降多少（百分比）。填 0 为恒定满亮；上限 80 保证最暗仍留五分之一的光，不会熄灭。",
		["zh-tw"] = "基石那一套每次呼吸最暗時亮度下降多少（百分比）。填 0 為恆定滿亮；上限 80 保證最暗仍留五分之一的光，不會熄滅。",
	},
	stick_keystone_breath_speed_title = {
		en = "Keystone breath speed",
		["zh-cn"] = "基石呼吸速度",
		["zh-tw"] = "基石呼吸速度",
	},
	stick_keystone_breath_speed_description = {
		en = "How fast the keystone set breathes. 300 is the fastest.",
		["zh-cn"] = "基石那一套呼吸的快慢。300 最快。",
		["zh-tw"] = "基石那一套呼吸的快慢。300 最快。",
	},
	stick_keystone_thickness_title = {
		en = "Keystone thickness",
		["zh-cn"] = "基石标记的线条粗细",
		["zh-tw"] = "基石標記的線條粗細",
	},
	stick_keystone_thickness_description = {
		en = "Line thickness for keystone marks. Slightly thinner than your own by default, so the enemies you deliberately marked stay the loudest thing on screen.",
		["zh-cn"] = "基石标记的线条粗细。默认比你自己标记的略细一点，让你主动标记的敌人始终是画面上最醒目的。",
		["zh-tw"] = "基石標記的線條粗細。預設比你自己標記的略細一點，讓你主動標記的敵人始終是畫面上最醒目的。",
	},
	stick_keystone_glow_title = {
		en = "Keystone glow (%% of the main setting)",
		["zh-cn"] = "基石标记的霓虹强度（%% of 主设置）",
		["zh-tw"] = "基石標記的霓虹強度（%% of 主設置）",
	},
	stick_keystone_glow_description = {
		en = "Halo spread and brightness for keystone marks. 0 leaves only the lit cores.",
		["zh-cn"] = "基石标记的光晕扩散范围与亮度。0 只留发光的芯。",
		["zh-tw"] = "基石標記的光暈擴散範圍與亮度。0 只留發光的芯。",
	},
	stick_keystone_dot_size_title = {
		en = "Keystone joint dot size",
		["zh-cn"] = "基石标记的关节点大小",
		["zh-tw"] = "基石標記的關節點大小",
	},
	stick_keystone_dot_size_description = {
		en = "Joint dot size on keystone marks, as a share of their line width. Below 180 the joints stop reading as dots, so that is the floor.",
		["zh-cn"] = "基石标记的关节点大小，按其线宽的比例计算。低于 180 关节点就不再像点，所以那是下限。",
		["zh-tw"] = "基石標記的關節點大小，按其線寬的比例計算。低於 180 關節點就不再像點，所以那是下限。",
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
		en = "Line thickness for teammates' marks. Same weight as your own by default; lower it if you want your own mark to stand out more.",
		["zh-cn"] = "队友标记的线条粗细。默认与你自己的相同；想让自己的标记更醒目就往下调。",
		["zh-tw"] = "隊友標記的線條粗細。預設與你自己的相同；想讓自己的標記更醒目就往下調。",
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
		en = "Joint dot size on teammates' marks, as a share of their line width. Below 180 the joints stop reading as dots, so that is the floor. The default of 150 sits on that floor, i.e. the smallest a joint can be and still read as one.",
		["zh-cn"] = "队友标记的关节点大小，按其线宽的比例计算。低于 180 关节点就不再像点，所以那是下限。默认 150 就停在这条下限上，也就是关节还能读作一个点的最小值。",
		["zh-tw"] = "隊友標記的關節點大小，按其線寬的比例計算。低於 180 關節點就不再像點，所以那是下限。預設 150 就停在這個下限上，也就是關節還能讀作一個點的最小值。",
	},
}
