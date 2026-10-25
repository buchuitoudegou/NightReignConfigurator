# Nightreign Configurator

自选夜王、永夜版本、特异地形和 Map pattern 的黑夜君临无缝联机配置器。

## 1. 下载与配置

1. **[下载便携版 ZIP](https://github.com/buchuitoudegou/NightReignConfigurator/releases/download/v0.1.1-preview/Nightreign-Configurator-v0.1.1-preview-win-x64.zip)**，完整解压到独立文件夹，不要放进游戏目录。其他版本见 [Releases](https://github.com/buchuitoudegou/NightReignConfigurator/releases)。
2. 先安装游戏与无缝联机，再双击 **一键配置.cmd**。首次需联网，程序会自动下载 PowerShell、ME3 和 Smithbox（约 392 MiB），显示下载进度、实时速度和预计剩余时间。
3. 核对自动检测到的路径，点击 **验证并保存**。如果没有检测到，请手动选择：
   - **游戏**：Steam 游戏目录下的 `Game/nightreign.exe`。
   - **无缝 DLL**：无缝安装目录中的 `nrsc.dll`，旁边应有 `nrsc_settings.ini`。
   - 其余依赖路径会自动填入，无需另外安装。

需要修改联机密码时，点击配置器里的 **无缝设置**，编辑已有配置文件。

## 2. 使用方法

1. 打开 **Nightreign-Configurator.exe**，选择夜王、是否永夜、特异地形；需要固定地图时填写 **Map pattern 编号**。
2. 点击 **确定并生成**，完成后关闭配置器。夜王或地形全部不选时，按原版权重随机。
3. 登录 Steam，双击 **启动游戏.cmd**，自动加载最近生成的 `regulation.bin`。
4. 如果启用了固定 Map，房主锁定器会同时打开。**进入圆桌厅后点击“应用房主锁定”**，保持锁定器开启，仅由房主操作。

修改选项前先退出游戏，重新生成后再启动。移动程序文件夹后，重新运行“一键配置.cmd”。

版本兼容、固定地图的验证状态、故障处理和开发说明见 **[详细文档](DETAILS.md)**；第三方来源与许可证见 [THIRD_PARTY.md](THIRD_PARTY.md)。
