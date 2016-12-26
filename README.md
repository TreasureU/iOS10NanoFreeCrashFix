# iOS10NanoFreeCrashFix
在iOS 10.0和10.1上，存在一个内存分配相关的系统bug，在nano_free时会产生崩溃，本文件可以帮助修复这个问题。

最早确定问题并提出解决方案的微信移动团队的公开文章：https://mp.weixin.qq.com/s?__biz=MzAwNDY1ODY2OQ==&mid=2649286446&idx=1&sn=bc466e24751cfe553c59a8f786134034&chksm=8334c3acb4434abaf6aef0abd1f6891995699f47c4027c7ba2352849e04c98553136a2254a65&mpshare=1&scene=1&srcid=1226qEEY2uOFme8bcPWX89ru&key=564c3e9811aee0ab553a265111745d85cf3012b7d8cf0eb8b4c0811068a299a0cc254966186bcac2ea2378d24b71fe92d0cd96f11e0f59baf19c0204f26cbf3af52bad4e4f7d19426e7e533bf23b3578&ascene=0&uin=NTI1NDg2NTM1&devicetype=iMac+MacBookPro12%2C1+OSX+OSX+10.12.2+build(16C67)&version=12010110&nettype=WIFI&fontScale=100&pass_ticket=aR4V%2FjVncsqORZrS0KqIFvVcCJYVLUk5wFgDvgeuX4BYy%2FvgW0F2uyOkYgScyBs8

Nano_Free Crash的背景知识：
* 当一个 iOS 应用启动后，此应用的所有内存分配申请，都会由一个或多个 zone 结构体来处理。
* 在 iOS < 10.0 以及 iOS >= 10.2 的环境中，只存在一个这样的 zone。我们把它称作 Scalable Zone。
* 在 iOS >= 10.0 以及 iOS < 10.2 的环境中，存在两个 Zone。分别是 Scalable Zone 和 Nano Zone。
* 在 iOS >= 10.0 以及 iOS < 10.2 的环境中，Scalable Zone 和 Nano Zone 各有分工。Scalable Zone 负责处理大于 256 字节的内存分配申请，而 Nano Zone 负责处理小于等于 256 字节的内存分配申请。
* 由 Scalable Zone 负责分配的内存，必须由 Scalable Zone 释放，不能由 Nano Zone 释放。反之亦然。
* 每个 Zone 在释放一片内存前，会检查这片内存是不是由自己分配的。如果不是，则会在当前 stack 释放一个 Abort 信号。程序终止。
* Nano Zone 用以下语句检查内存是否由自己分配：if(ptr>>28 == 0x17) {/*属于 Nano Zone*/}

Nano_Free Crash的成因：
* 在 iOS >= 10.0 以及 iOS < 10.2 的环境中，当 Scalable Zone 进行分配内存操作的次数超过了一个上限后，Scalable Zone 会分配出满足 if(ptr>>28 == 0x17) 条件的内存。当这片内存在未来某一时刻被释放时，会由 Nano Zone 接手，从而触发 Abort 信号，程序终止。

结合上述分析，我们不难得出以下推论：
* FUP 发生的几率和程序的内存申请次数、内存占用总量、内存碎片化程度成正相关。
* 也就是说，随着用户活跃度增加，发生 FUP 的可能性会上升。
* FUP 发生时的调用栈没有参考意义。（Zone 错配发生在申请内存时，而非释放内存时。）

修复方案：
1.创建一个自己的zone命名为 guard zone。
2.修改Nano zone的函数指针，重定向到guard zone.
	a.对于没有传入指针的函数，直接重定向到guard zone。
	b.对于有传入指针的函数，先用size判断所属的zone，再进行分发。