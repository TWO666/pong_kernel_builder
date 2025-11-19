
# Pong_Kernel_Builder

[![Build Kernel](https://github.com/TWO666/pong_kernel_builder/actions/workflows/build_kernel_pong.yml/badge.svg)](https://github.com/TWO666/pong_kernel_builder/actions/workflows/build_kernel_pong.yml)
[![GitHub Release](https://img.shields.io/github/v/release/TWO666/pong_kernel_builder?include_prereleases&sort=date&display_name=tag&style=flat&logo=github)](https://github.com/TWO666/pong_kernel_builder/releases)
[![License](https://img.shields.io/github/license/TWO666/pong_kernel_builder?style=flat&logo=opensourceinitiative&logoColor=white)](LICENSE)

## 📋 Description

An automated kernel builder for Nothing Phone 2 (Pong) that supports multiple KernelSU variants including SukiSU Ultra, KernelSU Next, MKSU, and official KernelSU. This project provides both GitHub Actions workflows for cloud building and local build scripts for manual compilation.


**Kernel**: [helloboy017_kernel_pong](https://github.com/TWO666/helloboy017_kernel_pong) (A CLO based kernel from [HELLBOY017](https://github.com/HELLBOY017/kernel_nothing_sm8475))

## ✨ Features

- 🏗️ **Automated Building**: GitHub Actions workflow for continuous integration
- 🔧 **Multiple KSU Support**: SukiSU Ultra, KernelSU Next, MKSU, and official KernelSU
- 🛡️ **SUSFS Integration**: Built-in SUSFS (Kernel SU File System) support for enhanced root hiding
- ⚡ **KPM Support**: Kernel Patch Manager support for SukiSU Ultra
- 🎯 **Local Building**: Standalone build scripts for local compilation
- 📦 **AnyKernel3 Packaging**: Ready-to-flash zip packages
- 🔄 **ccache Optimization**: Fast incremental builds with ccache support

## 🚀 Quick Start

1. **Building**:
   - **Cloud Building**: Use GitHub Actions workflow by triggering the build action
   - **Local Building**: Run `build_kernel_pong_local.sh` for standard builds.
     
     ⚠️ **Strongly Recommended**: Use Podman/Docker containers or virtual machines for environment isolation to avoid potential conflicts with your host system dependencies.

2. **Flashing**: Use the generated AnyKernel3 zip with your preferred recovery or kernel flasher.


## ⚖️ Disclaimer

This project is licensed under the [MIT License](LICENSE). 

However, strictly speaking:
**This project and its contributors are not responsible for any negative outcomes, including but not limited to: Earth explosion, nuclear war, data loss, or startup failure.**


## 🙏 Acknowledgements

Special thanks (in no particular order):

| Git Address | Description |
| --- | --- |
| [https://github.com/MiguVT/Meteoric_KernelSU_SUSFS](https://github.com/MiguVT/Meteoric_KernelSU_SUSFS) | workflow |
| [https://github.com/cctv18/oppo_oplus_realme_sm8650](https://github.com/cctv18/oppo_oplus_realme_sm8650) | workflow |
| [https://github.com/cctv18/oneplus_sm8650_toolchain](https://github.com/cctv18/oneplus_sm8650_toolchain) | Toolchain |
| [https://github.com/HELLBOY017/kernel_nothing_sm8475](https://github.com/HELLBOY017/kernel_nothing_sm8475) | CLO based kernel |
| [https://github.com/WildKernels/AnyKernel3.git](https://github.com/WildKernels/AnyKernel3.git) | AnyKernel3 |
| [https://gitlab.com/simonpunk/susfs4ksu.git](https://gitlab.com/simonpunk/susfs4ksu.git) | susfs4ksu (gitlab) |
| [https://github.com/ShirkNeko/susfs4ksu.git](https://github.com/ShirkNeko/susfs4ksu.git) | susfs4ksu (github) |
| [https://github.com/ShirkNeko/SukiSU_patch.git](https://github.com/ShirkNeko/SukiSU_patch.git) | SukiSU_patch |
| [https://github.com/ShirkNeko/SukiSU-Ultra](https://github.com/ShirkNeko/SukiSU-Ultra) | SukiSU-Ultra |
| [https://github.com/pershoot/KernelSU-Next](https://github.com/pershoot/KernelSU-Next) | KernelSU-Next |
| [https://github.com/WildKernels/kernel_patches](https://github.com/WildKernels/kernel_patches) | WildKSU_patches |