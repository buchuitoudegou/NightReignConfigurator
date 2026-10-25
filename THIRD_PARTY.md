# 第三方来源与许可证

## 官方 Smithbox 下载

`scripts/Get-Smithbox.ps1` 从 vawser/Smithbox 官方 GitHub Release 下载完整的 2.2.6 ZIP，校验固定 SHA-256，并保留整个发布包及其 Licenses 目录。本仓库没有提交 Smithbox 二进制，也没有修改或重新托管官方 ZIP。

- 官方仓库：https://github.com/vawser/Smithbox
- 固定发布：https://github.com/vawser/Smithbox/releases/tag/2.2.6
- 对应源码：https://github.com/vawser/Smithbox/tree/2.2.6
- 主许可证：https://github.com/vawser/Smithbox/blob/2.2.6/LICENSE
- 文件：Smithbox_2_2_6_2026_09_20_b.zip
- SHA-256：9a147c319dccad4b6dd2a5adcc6f2ba3a5c11c40b079520c05260cb19994b3d7

已核对该版本仓库主 LICENSE：MIT，版权署名 Vawser (2025)、Katalash 和 Meowmaritus (2018)。该主许可证不能替代依赖自己的许可证；SoulsFormats 附带 GPL v3 文本。保留随包声明；重新分发或修改组件时按各组件许可证处理。

## 可选本地精简包

`build.ps1 -BundleSmithbox <目录>` 支持生成本地测试用的精简参数组件包，记录文件哈希并附带已有许可证。这不是本仓库的官方 Smithbox 下载机制。任意本机安装目录可能与固定版本不同；重新分发该精简包前，需整理其准确对应源码及全部依赖声明。

该功能使用 Andre.SoulsFormats、DotNext、BouncyCastle、CommunityToolkit.HighPerformance、ZstdNet、zstd，以及三个 Nightreign 参数定义。未经逐版本审核的本地精简 ZIP 不应作为正式 Release 上传。

## 其他依赖

配置器使用 Windows/.NET Framework、基于 .NET 10 的 PowerShell、ME3，以及用户自行安装的 Nightreign Seamless Co-op。游戏参数、EXE、存档、无缝密码和无缝 DLL 均不在源码仓库中。地图模板列表在首次配置时从用户本机游戏参数提取。

本项目自身尚未指定开源许可证；第三方许可证仅适用于相应第三方内容。
