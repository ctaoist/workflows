# OpenWrt 两阶段编译说明

本目录保存 OpenWrt 固件配置、DIY 脚本、vermagic 补丁和按平台划分的文件覆盖层。GitHub Actions 使用两个手动 workflow 完成基础镜像与固件编译。

## 目录结构

```text
openwrt/
├── README.md
├── init_x86_64.config       # x86_64 基础镜像最小配置
├── init_filogic.config      # Filogic 基础镜像最小配置
├── *.config                 # 固件配置文件
├── diy-part1.sh             # 更新 feeds 前执行
├── diy-part2.sh             # 更新 feeds 后执行，并处理 vermagic 补丁
├── vermagic                 # 固定的内核 vermagic
├── vermagic_patch           # vermagic 内核补丁
└── files/
    ├── x86/                 # x86_64 固件文件覆盖层
    └── filogic/             # MediaTek Filogic 固件文件覆盖层
```

配置文件必须直接放在 `openwrt/` 下，并以 `.config` 结尾。workflow 根据配置中的下列选项自动识别平台：

- `CONFIG_TARGET_x86_64=y`：使用 x86_64 镜像。
- `CONFIG_TARGET_mediatek_filogic=y`：使用 Filogic 镜像。

`init_x86_64.config` 和 `init_filogic.config` 专供第一个 workflow 构建平台基础镜像。Filogic 最小配置必须保留 `CONFIG_PACKAGE_kmod-mediatek_hnat=y`，因为当前源码的 MediaTek 网卡补丁依赖该内核模块提供的 HNAT 定义。

## 仓库 Secrets

运行前需要在 GitHub 仓库的 `Settings > Secrets and variables > Actions` 中配置：

- `DOCKERHUB_USERNAME`：Docker Hub 用户名。
- `DOCKERHUB_TOKEN`：具有镜像推送和拉取权限的 Docker Hub Access Token。

镜像仓库固定为：

```text
DOCKERHUB_USERNAME/autowrt
```

## 第一步：构建基础镜像

手动运行 `.github/workflows/openwrt-base-images.yml`。

该 workflow 会并行处理 x86_64 和 Filogic，生成以下镜像：

```text
autowrt:toolchain-x86_64
autowrt:toolchain-filogic
autowrt:x86_64
autowrt:filogic
```

工具链镜像只包含：

- Ubuntu 编译依赖。
- OpenWrt 源码。
- 平台最小配置。
- `tools/compile` 编译结果。
- `toolchain/compile` 编译结果。

工具链镜像不会执行 DIY 脚本，也不会应用 files 覆盖层或自定义 feeds。

最终基础镜像会在工具链镜像上更新源码、更新默认 feeds、为两个平台应用 `vermagic_patch`，然后编译内核、所选 OpenWrt `kmod-*` 和基础软件包。基础镜像不会执行 DIY 脚本，也不会应用 files 覆盖层。

基础镜像只保留内核和基础配置所需 kmod 的编译缓存。全部 kmod、SDK 和 ImageBuilder 位于独立的可选产物阶段，不会进入最终 Docker Hub 基础镜像。

根据手动运行时勾选的选项，还可以生成并发布：

- x86_64 与 Filogic SDK。
- x86_64 与 Filogic 独立版 ImageBuilder，内置本次编译的软件包和 kmod。
- 两个平台的 kmod 软件包目录压缩包。
- 对应的 SHA256 校验文件。

勾选任一可选产物后，文件会同时保存为 GitHub Actions Artifact，并在两个平台全部构建成功后发布到同一个 GitHub Release。两个选项都不勾选时，只构建并推送基础镜像，不创建该 Release。

### rebuild_toolchain

- 不勾选：优先拉取并复用 Docker Hub 上已有的工具链镜像。
- 勾选：强制重新编译并覆盖两个平台的工具链镜像。
- 镜像不存在，或者仓库、分支、平台、工具链结构版本不匹配时，会自动重新构建。

以下情况建议勾选：

- GCC、Binutils、musl 或其他工具链组件升级。
- 目标 CPU、ABI 或 libc 配置变化。
- 内核头文件或 OpenWrt 大版本变化。
- 工具链相关编译配置发生变化。

### build_all_kmods

- 勾选：加入 `CONFIG_ALL_KMODS=y`，编译当前平台支持的全部 OpenWrt kmod 软件包。
- 不勾选：只编译基础配置实际选择的 kmod。
- 默认不勾选。
- 该选项不会触发工具链重建，也不会放大全平台基础镜像；全部 kmod 仅在可选产物阶段编译并打包发布。

### build_sdk_imagebuilder

- 勾选：生成并发布当前平台的 SDK 和独立版 ImageBuilder。
- 不勾选：跳过 SDK 和 ImageBuilder 生成。
- 默认不勾选。
- 如果同时勾选 `build_all_kmods`，独立版 ImageBuilder 会包含本次编译的全部可用 kmod；否则只包含基础配置实际编译的软件包和 kmod。

## 第二步：编译固件

基础镜像构建并推送成功后，手动运行 `.github/workflows/openwrt-firmware.yml`。

### config_file

填写 `openwrt/` 下的配置文件名，例如：

```text
sl3000.config
```

只能填写文件名，不能填写目录或绝对路径。当前仅支持 x86_64 和 MediaTek Filogic 配置。

### update_source_code

- 不勾选：使用基础镜像中固定的 OpenWrt 源码提交。
- 勾选：编译前拉取当前源码分支的最新提交。

源码大版本、工具链或 ABI 发生变化时，不应只勾选此选项；应先运行第一个 workflow 并勾选 `rebuild_toolchain`。

### apply_files

- 不勾选：不向固件应用文件覆盖层。
- 勾选：根据配置平台自动选择覆盖层。

平台映射：

```text
x86_64  -> openwrt/files/x86/
filogic -> openwrt/files/filogic/
```

覆盖层目录中的路径对应固件根目录。例如：

```text
openwrt/files/filogic/etc/banner
```

最终会覆盖固件中的：

```text
/etc/banner
```

不要把其他 CPU 架构的二进制文件放入错误的平台目录。

### release_title

可填写自定义 GitHub Release 标题。留空时自动生成：

```text
OpenWrt <配置文件名> <编译时间>
```

标题只能使用单行文本。

## 第二阶段执行内容

第二个 workflow 会：

1. 根据配置自动选择 `autowrt:x86_64` 或 `autowrt:filogic`。
2. 检查基础镜像结构版本和平台是否匹配。
3. 根据选项更新 OpenWrt 源码。
4. 执行 `diy-part1.sh` 并更新、安装自定义 feeds。
5. 两个平台都执行 `diy-part2.sh`，修改默认 IP 并确保 vermagic 补丁生效。
6. 根据选项应用对应平台的 files 覆盖层。
7. 载入所选 `.config` 并执行完整固件编译。
8. 上传 GitHub Actions Artifact。
9. 创建 GitHub Release 并上传固件文件。

旧的 workflow 运行记录和 GitHub Release 不会被自动删除。

## 推荐执行顺序

首次使用：

1. 配置 Docker Hub Secrets。
2. 运行基础镜像 workflow，并勾选 `rebuild_toolchain`。
3. 等待两个平台镜像全部推送成功。
4. 运行固件 workflow，选择配置和编译选项。

普通固件更新：

1. 修改或添加 `openwrt/*.config`、DIY 脚本或 files 覆盖层。
2. 如果只修改配置、DIY 或 files，可直接运行固件 workflow。
3. 如果基础源码、内核或基础软件包需要更新，先运行基础镜像 workflow，通常无需重建工具链。
4. 如果工具链相关内容变化，勾选 `rebuild_toolchain` 后重新构建基础镜像。

## 注意事项

- Docker Hub 上的平台标签是可变标签，每次成功构建都会覆盖原标签。
- 第二个 workflow 默认不更新源码、不应用 files。
- `diy-part2.sh` 对 vermagic 补丁进行幂等处理，补丁已经应用时不会重复失败。
- 如果第二个 workflow 提示基础镜像版本过旧，需要先重新运行基础镜像 workflow。
- x86_64 与 Filogic 不能混用工具链、配置文件或含架构相关二进制的 files 覆盖层。
