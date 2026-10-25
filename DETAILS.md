# 详细说明与开发文档

下载、配置和日常使用请看 [README](README.md)。

目前只接受已验证的 **1.03.5 / regulation 10350000** 原始参数；这不是对最新游戏版本的兼容承诺。房主控制器还校验游戏 EXE 的特定 SHA-256。版本不符会拒绝执行，不能通过关闭校验来升级支持。

## 下载 Smithbox

- [直接下载完整 Smithbox 2.2.6（官方 ZIP，约 283 MiB）](https://github.com/vawser/Smithbox/releases/download/2.2.6/Smithbox_2_2_6_2026_09_20_b.zip)
- [对应发布说明](https://github.com/vawser/Smithbox/releases/tag/2.2.6) · [对应源码](https://github.com/vawser/Smithbox/tree/2.2.6) · [主许可证 MIT](https://github.com/vawser/Smithbox/blob/2.2.6/LICENSE)

在下载的本仓库目录运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Get-Smithbox.ps1
```

脚本直接从官方 GitHub Release 下载固定版本，验证 SHA-256 后完整解压到 `vendor/smithbox`，保留所有附带许可证，不自动执行 Smithbox。已有目录不会被覆盖。源码构建后的 EXE 在 `dist/Nightreign-Configurator`，可在向导中选择仓库的 `vendor/smithbox`；或者在 EXE 同目录运行随包 `Get-Smithbox.ps1`，向导就会自动识别。

固定下载包 SHA-256：`9a147c319dccad4b6dd2a5adcc6f2ba3a5c11c40b079520c05260cb19994b3d7`。不依赖会变化的 latest 下载链接。游戏版本仍需满足下面的校验要求。

## 选择规则

夜王全部不选时保留原版权重；多选可选择等概率或原版权重。地形全部不选时保留原版随机，多选时保留所选地形的原始相对权重。

## 无缝配置

沿用所选 DLL 旁的 `nrsc_settings.ini`。“无缝设置”直接用记事本打开该文件；程序不解析、复制或导出密码。队伍成员仍需自行约定相同的联机设置。

“启动无缝”通过 ME3 外部加载本次生成的参数和现有无缝 DLL，动态生成本地 profile；不调用另一个无缝 launcher。请使用这个入口启动，其他入口不保证加载相同参数。便携版会自动获取 ME3、PowerShell 和完整 Smithbox；无缝联机需用户自行安装。

本机绝对路径仅保存在 `data/config.json`。换电脑后运行“环境设置”重新选择路径。不要共享整个已使用过的程序文件夹；分享软件使用干净发布 ZIP。

## 实验性固定模板

填写 Map pattern 编号并生成参数，启动时会自动打开“房主控制器”，进入圆桌厅后手动应用，仅由房主操作。固定模板会选择相应夜王和地形，不固定首圈、掉落或全部随机事件。

控制器保留原版布局，在已验证的游戏指令处选择实际模板。单人读回验证曾通过；**房主单独修改后，队友地图同步尚未完成多人验收**。请勿把它宣传为已验证的联机同步功能。游戏更新、指令不匹配、未加载无缝、生成后未重启、目标不在候选列表时均不应强制应用。

## 本地数据与恢复

`data/` 包含本机配置、基准、生成文件、请求、日志和运行暂存；不属于源码或发布内容。覆盖输出时保留 `.backup-*`。全部恢复默认再生成，可输出与基准逐字节一致的参数。生成程序回读验证改动并检查无关参数未变化。

如生成报错，查看具体消息；错误也可能发生在输出已替换之后，不应盲目认为输出仍是旧文件。进入新局前重新成功生成。关闭房主控制器前需回圆桌厅或退出游戏，按界面提示撤销。

## 构建与打包

在 Windows PowerShell 中运行 `./build.ps1 -Package`。需要 Windows .NET Framework 4.x 自带 C# 编译器。运行参数脚本另需基于 .NET 10 的 PowerShell。

输出在 `dist/Nightreign-Configurator`；ZIP 通过固定文件清单构建，即使该目录已有 data，也不会将其收入 ZIP。源码目录没有附带任何游戏参数、DLL、密码或存档。

打包 Smithbox 组件使用 `./build.ps1 -Package -BundleSmithbox <本机Smithbox目录>`。额外输出 `Nightreign-Configurator-with-Smithbox-preview.zip`；按清单复制参数读写 DLL、必要依赖、三个参数定义与本机已有许可证，记录逐文件 SHA-256。不收录 Smithbox 界面设置、项目、游戏文件或缓存。组件包仍是本地测试预览，公开分发前需补齐准确源码版本及依赖声明，见 THIRD_PARTY.md。

`tests/Smoke.ps1` 是需要本机已安装依赖的集成测试；不启动游戏，不修改无缝设置。它会在专用测试目录生成本地数据。

## 后续验证与发布准备

- 作者确认原创代码的开源许可证，并审查调用 SoulsFormats 等第三方组件的许可要求，见 THIRD_PARTY.md。
- 在独立电脑验证首次配置和真实 ME3 启动；在一致版本的多人环境验证房主锁定。
- 明确支持的无缝、ME3、Smithbox 与 PowerShell 版本，记录复现步骤。
- 对新游戏版本和第三方依赖更新重新验收后，再发布对应版本。

上述未完成验收不影响源码阅读和本地测试；实验性功能状态请以文档为准。
