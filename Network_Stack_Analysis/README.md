# 自选实验：Linux 内核网络协议栈分析

本实验为高级操作系统课程的自选实验，通过编写 TCP 客户端/服务器程序并借助 GDB 远程调试，深入分析 Linux 内核网络协议栈从用户态系统调用到驱动层的完整数据发送/接收路径。

## 实验目的

- 理解 Linux 内核网络协议栈的分层结构（Socket 层 → 传输层 → 网络层 → 链路层 → 设备驱动）
- 掌握数据包在各层的流转过程和关键内核函数
- 学会使用 GDB 对运行在 QEMU 中的内核进行远程调试
- 分析 TCP 三次握手及数据收发在内核中的实现细节

## 实验环境

- **模拟器**：QEMU（`qemu-system-i386`，携带 e1000 网卡模拟）
- **内核版本**：Linux 内核（i386 架构，带调试符号的 `vmlinux`）
- **根文件系统**：`rootfs/rootfs.img.gz`
- **调试工具**：GDB + Python 内核调试脚本（lx-symbols）
- **网络转发**：QEMU 用户态网络，hostfwd 将宿主机端口 8080 转发到虚拟机 8080

## 文件说明

| 文件 | 说明 |
|------|------|
| `client_in_to_out.c` | TCP 客户端程序，连接服务器并发送一段测试数据 |
| `server8081.c` | TCP 服务器程序，监听 8081 端口，接收客户端消息并回应 |
| `client.gdb` | GDB 调试脚本，在协议栈各层设置断点，追踪数据发送/接收全路径 |
| `client_debug.log` | GDB 调试运行时输出的日志，记录各层函数触发情况 |
| `run` | QEMU 启动脚本，支持普通启动和 GDB 远程调试（`-s -S`）模式 |
| `研究报告github.doc` | 完整研究报告，包含实验设计、内核函数分析与结论 |

## 实验原理

### 网络协议栈分层（发送路径）

```
用户程序 send()
    │
    ▼
[Socket 层]   sock_sendmsg()
    │
    ▼
[协议层]      inet_sendmsg()
    │
    ▼
[传输层 TCP]  tcp_sendmsg() → tcp_transmit_skb()
    │
    ▼
[网络层 IP]   ip_queue_xmit() → ip_output()
    │
    ▼
[链路层]      dst_neigh_output() → neigh_hh_output()
    │
    ▼
[设备子系统]  dev_queue_xmit()
    │
    ▼
[网卡驱动]    e1000 发送
```

### 网络协议栈分层（接收路径）

```
[网卡驱动]    e1000 接收中断
    │
    ▼
[设备子系统]  net_rx_action() → netif_receive_skb()
    │
    ▼
[网络层 IP]   ip_rcv()
    │
    ▼
[传输层 TCP]  tcp_v4_rcv()
    │
    ▼
[Socket 层]   sock_recvmsg()
    │
    ▼
用户程序 read()
```

## 关键 GDB 断点（client.gdb）

| 断点函数 | 所属层次 | 说明 |
|----------|----------|------|
| `sock_sendmsg` / `sock_recvmsg` | Socket 层 | 用户态与内核边界 |
| `inet_sendmsg` | 协议族层 | IPv4 发送入口 |
| `tcp_sendmsg` | TCP 传输层 | TCP 数据发送 |
| `tcp_transmit_skb` | TCP 传输层 | 构建 TCP 段并下发 |
| `ip_queue_xmit` | IP 网络层 | IP 路由与分片 |
| `ip_output` | IP 网络层 | IP 报文最终输出 |
| `dst_neigh_output` | 邻居子系统 | ARP 邻居查找 |
| `dev_queue_xmit` | 设备子系统 | 数据包进入发送队列 |
| `net_rx_action` | 设备子系统 | 软中断接收 |
| `netif_receive_skb` | 设备子系统 | 接收帧分发 |
| `ip_rcv` | IP 网络层 | IP 报文接收入口 |

## 实验步骤

1. **编译内核与程序**
   ```bash
   # 编译带调试符号的内核
   make ARCH=i386 menuconfig  # 开启 CONFIG_DEBUG_INFO
   make ARCH=i386 bzImage

   # 编译测试程序（静态链接，方便放入 initramfs）
   gcc -static -g -o client_in_to_out client_in_to_out.c
   gcc -static -g -o server8081 server8081.c
   ```

2. **启动 QEMU（GDB 调试模式）**
   ```bash
   ./run s
   # QEMU 将在 localhost:1234 等待 GDB 连接
   ```

3. **启动 GDB 并加载调试脚本**
   ```bash
   gdb vmlinux
   (gdb) source client.gdb
   ```

4. **观察输出**  
   GDB 会在各层断点处打印 skb 指针、数据长度、协议字段等信息，结合 `client_debug.log` 分析完整调用链。

## 核心数据结构

| 结构体 | 说明 |
|--------|------|
| `sk_buff`（skb） | 网络数据包在内核中的统一表示，贯穿协议栈各层 |
| `sock` / `socket` | 套接字在内核中的表示 |
| `inet_sock` | IPv4 特定的套接字扩展 |
| `tcp_sock` | TCP 套接字，包含发送/接收缓冲区、序列号等 |
| `net_device` | 网络设备（网卡）抽象 |

## 参考资料

- 《深入理解 Linux 网络技术内幕》（Understanding Linux Network Internals）
- 《Linux 内核源代码情景分析》
- Linux 内核源码 `net/ipv4/` 目录
- 课程讲义：网络协议栈与内核通信机制
