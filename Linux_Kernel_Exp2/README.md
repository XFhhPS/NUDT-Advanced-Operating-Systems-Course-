# 实验二：Linux 内核进程调度分析

本实验为高级操作系统课程的必做实验，通过编写多进程测试程序并结合 GDB 远程调试，深入分析 Linux 内核 CFS（完全公平调度器）的工作原理与进程切换机制。

## 实验目的

- 理解 Linux 进程调度的基本流程（`__schedule` → `context_switch` → `__switch_to`）
- 掌握 CFS 调度器的核心数据结构（红黑树、`vruntime`）
- 观察 `enqueue_task_fair` / `dequeue_task_fair` 时红黑树的动态变化
- 理解时钟中断（`smp_apic_timer_interrupt`）触发调度的机制
- 学会通过 GDB 脚本批量采集内核调度事件并生成时序日志

## 实验环境

- **模拟器**：QEMU（`qemu-system-i386`）
- **内核版本**：Linux 内核（i386 架构，带调试符号的 `vmlinux`）
- **调试工具**：GDB + lx-symbols 内核扩展
- **测试程序**：`abc.c`（多进程循环输出）

## 文件说明

| 文件 | 说明 |
|------|------|
| `abc.c` | 测试程序：主进程 fork 两个子进程，三个进程分别循环打印 A/B/C，并通过 `sched_yield()` 主动触发调度 |
| `abc5_7.gdb` | GDB 调试脚本：在 `__schedule`、`__switch_to`、`enqueue_task_fair`、`dequeue_task_fair` 等关键调度函数设置断点，自动记录进程切换事件与 CFS 队列状态 |
| `gdb_timeline_github.log` | GDB 调试产生的时序日志，记录每次调度事件的进程 PID、`vruntime`、运行队列长度等信息 |
| `时序图.xlsx` | 根据日志绘制的进程调度时序图，直观展示 A/B/C 三个进程的调度顺序 |
| `实验报告2github.doc` | 完整实验报告，包含实验分析、CFS 原理说明与结论 |

## 测试程序说明（abc.c）

```c
// 三个进程分别循环输出字符，并主动让出 CPU
// 父进程: 输出 'A'，子进程1: 输出 'B'，子进程2: 输出 'C'
void print_char(char c) {
    while (1) {
        write(2, &c, 1);   // 系统调用，触发内核路径
        sched_yield();      // 主动放弃 CPU，触发 __schedule
    }
}
```

**触发的内核路径**：`sched_yield()` → `sys_sched_yield()` → `__schedule()` → `pick_next_task_fair()` → `context_switch()` → `__switch_to()`

## 关键 GDB 断点（abc5_7.gdb）

| 断点 | 说明 |
|------|------|
| `__schedule` | 进程调度主函数，每次切换进程时触发 |
| `__switch_to` | 实际切换 CPU 上下文（寄存器、栈、段描述符等） |
| `enqueue_task_fair` | 进程加入 CFS 红黑树时触发，打印队列状态 |
| `dequeue_task_fair` | 进程移出 CFS 红黑树时触发，打印队列状态 |
| `smp_apic_timer_interrupt` | 时钟中断，定期触发调度检查 |
| `do_IRQ` | 外部中断处理入口 |
| `do_fast_syscall_32` | 系统调用入口，打印系统调用号 |
| `set_tsk_need_resched` | 设置进程重调度标志 |

每个断点触发时，脚本自动打印：
- 当前进程 PID 和进程名（`comm`）
- `TIF_NEED_RESCHED` 标志
- 当前进程 `vruntime`
- 运行队列中进程数量（`nr_running`）

## CFS 调度器原理

### 核心思想
CFS（Completely Fair Scheduler）为每个进程维护一个虚拟运行时间 `vruntime`，始终选择 `vruntime` 最小的进程运行，以保证长期公平性。

### 关键数据结构

| 结构 | 说明 |
|------|------|
| `task_struct.se.vruntime` | 进程累计虚拟运行时间 |
| `cfs_rq.tasks_timeline` | 红黑树根节点，所有可运行进程按 `vruntime` 排序 |
| `cfs_rq.rb_leftmost` | 红黑树最左节点 = `vruntime` 最小进程 = 下一个被调度的进程 |
| `rq.nr_running` | 当前 CPU 运行队列中的进程总数 |

### 进程切换流程

```
时钟中断 / sched_yield()
    │
    ▼
__schedule()
    │
    ├── dequeue_task_fair(当前进程)   # 从红黑树移除
    ├── pick_next_task_fair()         # 选取 vruntime 最小的进程
    ├── enqueue_task_fair(当前进程)   # 若未退出则重新入队
    │
    ▼
context_switch()
    │
    ▼
__switch_to()                         # 切换寄存器、栈指针
```

## 实验步骤

1. **编译测试程序**
   ```bash
   gcc -static -g -o abc abc.c
   ```

2. **将 abc 放入 initramfs 并启动 QEMU**
   ```bash
   qemu-system-i386 -nographic -kernel bzImage -initrd rootfs.img.gz \
     -append "rdinit=/home/nudt/abc console=ttyS0 norandmaps" -s -S
   ```

3. **启动 GDB 并加载脚本**
   ```bash
   gdb vmlinux
   (gdb) source abc5_7.gdb
   # 脚本会自动连接 QEMU、设置断点、开始记录日志
   ```

4. **分析日志**  
   查看 `gdb_timeline_github.log` 中的时序记录，结合 `时序图.xlsx` 分析三个进程的调度顺序与 `vruntime` 变化规律。

## 参考资料

- 《Linux 内核设计与实现》第 4 章：进程调度
- 《深入理解 Linux 内核》第 7 章：进程调度
- Linux 内核源码 `kernel/sched/core.c`、`kernel/sched/fair.c`
- 课程讲义：进程调度与 CFS 调度器
