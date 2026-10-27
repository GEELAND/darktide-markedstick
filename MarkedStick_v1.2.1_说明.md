# MarkedStick 1.2.1 说明（自测版：把帧数问题变成数字）

> **游戏内名字**：mod 列表里三语都显示 **MarkedStick**。

## 0. 先看这一条：zip 必须解压

`MarkedStick_v1.2.1.zip` **不能直接丢进 `mods/`**。DMF 只扫目录、不读 zip，直接放进去 mod 列表里
不会出现这个 mod。

```
解压 MarkedStick_v1.2.1.zip → 得到 MarkedStick/ 文件夹
放到 <游戏目录>/mods/MarkedStick/
确认 <游戏目录>/mods/MarkedStick/MarkedStick.mod 存在
进游戏 → mod 列表启用「MarkedStick」→ 重启或重载
```

## 1. 这一版多了什么

一个自测器。它会算三件事：

1. **帧时间按"场上骨架数量"分桶**（0 个 / 1-2 个 / 3-4 个 / 5 个以上）。
   同一个关卡、同一张显卡，只有骨架数量在变，桶与桶之间的差值就是**多一个骨架的真实代价**。
2. **本 mod 自己的 Lua 占了这一帧多少**（毫秒 + 百分比）。
3. **这部分开销花在哪**：清空 1370 个 pass 池 / 解析 17 个关节 / 把珠子写进 pass。

计时用引擎自带的高精度计数器（`Application.query_performance_counter`）；如果这个构建没暴露它，
会退回 `os.clock`，报告里会写 `timer=os.clock`——那种情况下精度只有 1 毫秒，数字只能当参考。

## 2. 你需要做的事

1. 装好，进游戏，正常打**一局**（最好打满，中间多遇到精英/专家；灵能请带上会标记小兵的基石）。
2. 打完后**回飞船**（或者直接等两分钟以上也行）。
3. 告诉我一声，我去读游戏日志把数字拿出来。

数据是自动写的：**每两分钟一次**，以及**回到飞船时**一次（同时会打在聊天框里）。
所以就算你打完直接 alt-F4，日志里也已经有数据。

## 3. 想要更准的对照（可选，但很有价值）

**再打一局，把 mod 里的「启用」总开关关掉**。这样日志里会多出一批"0 个骨架"的帧，
而且是同一台机器、同一个关卡，对照最干净。

## 4. 手动看一眼

游戏里输 `/stick_perf`，5 行统计会打到聊天框，同时写进日志。它**不会清空**计数
（新任务开始时自动开新的一轮）。

## 5. 日志在哪

```
%APPDATA%\Fatshark\Darktide\console_logs\console-<日期>-<时间>-<id>.log
```

里面搜 `[perf]` 就是统计行，形如：

```
[MOD][MarkedStick][INFO] [perf] session: 412.3 s, 24700 frames, avg 16.69 ms (59.9 fps), max 21.4 ms, timer=engine
[MOD][MarkedStick][INFO] [perf] frame time by skeletons on screen: 0 -> 15.90 ms (n=8200)  |  1-2 -> 16.40 ms (n=11000)  |  3-4 -> 17.80 ms (n=4600)
[MOD][MarkedStick][INFO] [perf] our Lua: 0.412 ms/frame = 2.5% of a frame at 2.13 skeletons (widget 0.381, scan 0.031)
[MOD][MarkedStick][INFO] [perf] inside a widget frame: clear pool 41% | draw writes 33% | joints 26%
[MOD][MarkedStick][INFO] [perf] light sources drawn: 128/frame avg, 176 max (beads + joint dots), 6 markers max, skipped 0 frames
```

（上面是格式示例，数字以实测为准。）

## 6. 回退

把 `mods/MarkedStick/` 整个删掉，或者换回 `MarkedStick_v1.2.0.zip` 解压覆盖。设置不会丢。
