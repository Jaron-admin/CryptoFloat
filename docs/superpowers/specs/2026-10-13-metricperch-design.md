# MetricPerch · 数栖：双显示与系统监测

## 已确认的意图

让行情、自定义 REST JSON 字段和本机系统数据可同时出现在行情悬浮窗和 Windows 主屏任务栏内部。两处独立选择内容、顺序、单位、字体和颜色。默认同时开启行情悬浮窗与任务栏系统监测；这是用户最后的修订，覆盖早期“任务栏默认关闭”的建议。

软件、公开仓库、双语说明和新发行包改名 MetricPerch，中文名数栖。保留便携 user_data、单实例及全部既有用户自定义数据。Windows 首发，平台差异隔离；本轮不实现其他平台的原生采集或任务栏适配。

用户已授权自动完成设计、实施文档、开发与新增本地测试，不再逐份等待文档确认。测试用临时配置和独立进程，不操作现有桌面。computer-use 必须另行征求同意。

## 产品行为

- 悬浮窗沿用已有关注项、显示模板、字体、主题、标题、图标和位置。升级时绝不覆盖自定义标题。
- 任务栏默认启用，初始内容 CPU、内存百分比、上传、下载。可加入其他系统指标、已有行情和自定义 API 字段/文字模板。配置支持拖拽与上下移动。
- 任务栏独立启停、宽度、单/双行、文字/数字字体、字体大小、深浅主题、单位简写与换算。不复用悬浮窗的透明度控制。
- 数据源定义和本机设备选择共享；显示选择与外观独立。设置内明确当前编辑“悬浮窗”或“任务栏”，保留紧凑 Material 3，设置窗口保持不透明。
- 草稿在设置内预览。保存成功后统一提交；取消恢复原状态；保存失败保留草稿。不能因为更改排序而重新请求所有行情。
- CPU/内存/GPU 百分比，内存与显存已用/总量，上传下载及磁盘读写速率。采样默认 1 秒，可选 1–60 秒；允许自动或手选网卡、显卡，磁盘可全部或单盘。
- 不可用数据显示 —，有效零值才显示 0；启动、休眠恢复和设备切换先重新建立基线。每个面板只根据自己的依赖判断过期。
- 网卡自动模式统计活动物理接口，避免把 VPN 及物理承载重复相加；手选接口支持虚拟网卡。GPU 自动固定一个实际适配器，显示型号并允许手选。

## 数据模型与迁移

AppConfig 保留原悬浮窗字段作为兼容投影，新增独立 DisplayProfile/TaskbarConfig、SystemMonitorSettings、系统指标选择和自定义字段显式选择。统一的 displayFor/withDisplay 接口让设置页编辑当前目标，不复制共享 API 密钥。

旧 schema 1 迁移为 schema 2。把旧默认行情行、未被模板引用而自动显示的自定义字段、模板顺序和所有显示选项完整保留。历史导入也走同一规范化路径。新增任务栏使用默认系统项，保留原始配置备份。未知的更高版本不得用默认配置自动覆盖。

每个显示配置显式列出需要的行情、自定义字段、系统指标；模板的字段引用也加入依赖。采集订阅是两个启用面板的依赖并集，去重；面板各自有状态集合。删除共享源/字段必须检查两个面板，包括关闭中的面板，避免静默删除内容。汇率缓存共享，换算目标分别应用。

## 模块边界

1. DisplayProfile / display dependencies：纯 Dart 配置、引用解析、版本迁移。
2. SystemMetricsService：消费 Windows 本机采集快照，保持 valid/warmingUp/unavailable/stale 状态；其他平台返回不支持。
3. Windows SystemMetrics：后台采样 Win32/PDH/DXGI，主消息线程只读缓存快照。无自装驱动，无管理员要求；不可用计数器单独降级。
4. 共享显示解析：把面板配置与数据解析为文本、单位、颜色、更新时间；Flutter 和原生任务栏使用相同结果。
5. TaskbarHost：独立轻量原生子进程及 IPC。它只接收显示文本/样式，不接收 API URL 或密钥。随主程序退出，断开连接立即撤除显示。
6. 设置编辑：共享源目录/本机设备设置和两个显示目标，草稿与已提交状态分开。

## Windows 采集口径

CPU 使用 PDH Processor Information(_Total)；内存 GlobalMemoryStatusEx。网速使用 GetIfTable2 的 64 位累计字节与单调时间差。磁盘用 PhysicalDisk，每次只选 _Total 或某个实例，不能重复求和。

GPU Engine 计数按 GPU LUID/物理节点/引擎汇总进程后取最忙引擎；不相加不同引擎。GPU Adapter Memory 的 Dedicated/Shared Usage 表示机器使用量，DXGI 描述提供容量；不能用 QueryVideoMemoryInfo 的进程预算冒充全机显存。核显/无法确定分母时不伪造百分比。

英文计数器使用 PdhAddEnglishCounterW；检查每项 CStatus。速率首样本为 warmingUp；设备变化、计数回退、休眠恢复需重建基线。

## 任务栏兼容规则

首期主屏、Windows 标准任务栏，独立原生文本子窗口挂接任务栏，不把 Flutter 主窗口挂到 Explorer。原生进程隔离跨进程 DPI 影响。自行实现，参考公开机制，不拷贝第三方非 MIT 代码。

Windows 11 没有受支持的第三方预留布局槽位。只有确认有可用区域才显示；不能确认、空间不足或宿主不支持时暂停。任务栏重启、主题/DPI变化重新发现与布局；自动隐藏时不残留桌面浮条。恢复后自动显示。保留用户配置和悬浮窗，不强制唤出已隐藏悬浮窗。

状态明确区分 disabled/displaying/waiting/noSpace/unsupported/error，设置内说明实际状态。任务栏右键可进入设置、刷新、显示悬浮窗、关闭任务栏、退出。托盘继续作为恢复入口。

## 品牌与交付

版本 1.3.0；可执行文件 metricperch.exe，任务栏宿主 metricperch_taskbar.exe，新发行包 MetricPerch-Windows-x64-1.3.0.zip。内部兼容标识（旧单实例协议、已存密钥引用）保留，避免旧新程序同时运行或凭据失效。公开仓库改名时保留干净的历史和发行记录，私人备份仓库不动。

构建产物不包含 user_data、密钥、日志、个人路径、测试临时数据。保留中英文 README 和 MIT；旧版用户数据不会进入发布包。真实 Windows 桌面兼容性验证需要单独允许操作桌面，纯本地测试不得声称验证过真实任务栏。

## 验收

- 旧设置迁移、取消/保存失败、字段/主题/图标不丢失。
- 两处项目、顺序、单位、样式独立；共享数据请求去重；状态互不污染。
- CPU/内存/网速/GPU/显存/磁盘的有效值、缺失、计数器重置及首帧处理。
- 原生任务栏协议、可用区域判定、断连回收、布局和格式化的隔离测试。
- 中英文紧凑布局、拖拽/按钮排序、已有便携/单实例/菜单/字体回归。
- 全套测试、静态分析、Windows release 构建及发行包隐私审计。

## 调研来源

- https://www.microsoft.com/en-us/windows/windows-11-specifications
- https://github.com/zhongyang219/TrafficMonitor/blob/master/Help_en-us.md
- https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setparent
- https://devblogs.microsoft.com/directx/gpus-in-the-task-manager/
- https://learn.microsoft.com/en-us/windows/win32/api/netioapi/nf-netioapi-getiftable2
- https://learn.microsoft.com/en-us/windows/win32/perfctrs/collecting-performance-data
