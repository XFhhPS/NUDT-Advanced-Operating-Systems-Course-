# 实验一：操作系统启动过程跟踪

本实验为高级操作系统课程的必做实验，通过在 QEMU 中运行 Linux 内核并结合 GDB 远程调试，系统性地跟踪操作系统从上电到用户态进程启动的完整引导流程。

## 实验目的

- 了解计算机系统上电后 BIOS/UEFI → Bootloader → 内核的启动链路
- 理解 Linux 内核初始化（`start_kernel`）的主要阶段
- 掌握使用 QEMU + GDB 对内核进行源码级调试的方法
- 深入分析关键初始化函数（内存管理、中断、调度、文件系统等子系统的初始化）

## 实验环境

- **模拟器**：QEMU（`qemu-system-i386`）
- **内核版本**：Linux 内核（i386 架构，带调试符号的 `vmlinux`）
- **根文件系统**：自制 initramfs
- **调试工具**：GDB（`target remote localhost:1234`）
- **内核配置**：需开启 `CONFIG_DEBUG_INFO`、`CONFIG_FRAME_POINTER`

## 实验内容

### 1. 启动链路概览

```
BIOS/UEFI（上电自检 & 硬件初始化）
    │
    ▼
Bootloader（GRUB / QEMU 直接加载 bzImage）
    │
    ▼
内核解压与实模式初始化（arch/x86/boot/）
    │
    ▼
保护模式切换（arch/x86/boot/compressed/）
    │
    ▼
start_kernel()  ← 主要调试入口
    │
    ├── setup_arch()          # CPU/内存架构初始化
    ├── mm_init()             # 内存管理子系统初始化
    ├── sched_init()          # 调度器初始化
    ├── init_IRQ()            # 中断控制器初始化
    ├── time_init()           # 时钟初始化
    ├── vfs_caches_init()     # 虚拟文件系统初始化
    └── rest_init()           # 启动 init 进程（PID=1）
```

### 2. 关键断点分析

| 函数 | 所在文件 | 说明 |
|------|----------|------|
| `start_kernel` | `init/main.c` | 内核 C 代码入口，所有子系统初始化从这里开始 |
| `setup_arch` | `arch/x86/kernel/setup.c` | 解析内存映射、初始化 CPU 特性 |
| `mm_init` | `init/main.c` | 初始化 Buddy 系统、slab 分配器 |
| `sched_init` | `kernel/sched/core.c` | 初始化调度器运行队列与 CFS |
| `rest_init` | `init/main.c` | 创建 kernel_init 线程（未来的 PID 1）和 kthreadd |
| `kernel_init` | `init/main.c` | 挂载根文件系统，exec `/sbin/init` |

### 3. 调试方法

```bash
# 终端1：启动 QEMU，-s 开启 GDB server，-S 暂停等待连接
qemu-system-i386 -nographic \
  -kernel bzImage \
  -initrd rootfs.img.gz \
  -append "root=/dev/ram rdinit=/sbin/init noapic console=ttyS0 norandmaps" \
  -s -S

# 终端2：启动 GDB
gdb vmlinux
(gdb) target remote localhost:1234
(gdb) break start_kernel
(gdb) continue
```

### 4. 主要观测点

- 内核解压后的第一条 C 代码
- 页表建立与内存映射过程
- 中断描述符表（IDT）初始化
- `0` 号进程（idle）与 `1` 号进程（init）的创建
- 第一个用户态程序的 `execve` 调用

## 文件说明

| 文件 | 说明 |
|------|------|
| `实验报告github.doc` | 完整实验报告，包含调试过程截图、关键函数分析与心得 |

## 核心概念

| 概念 | 说明 |
|------|------|
| bzImage | 压缩后的 Linux 内核镜像，QEMU 可直接加载 |
| initramfs | 内存中的临时根文件系统，内核启动后首先挂载 |
| start_kernel | 所有内核子系统初始化的总入口函数 |
| PID 0 (idle) | 内核启动时存在的第一个"进程"，后续成为 CPU 空闲进程 |
| PID 1 (init) | 所有用户态进程的祖先，负责系统服务管理 |

## 参考资料

- 《Linux 内核设计与实现》第 17 章：启动过程
- 《深入理解 Linux 内核》第 18 章：系统启动
- Linux 内核源码 `init/main.c`、`arch/x86/boot/`
- 课程讲义：操作系统启动与初始化
