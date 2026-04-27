# 实验三：Linux 内核内存管理与反向映射（RMAP）

本实验为高级操作系统课程的必做实验，通过编写多进程内存操作程序并结合 GDB 远程调试，深入分析 Linux 内核的内存管理机制，重点关注写时复制（Copy-on-Write, CoW）与物理页反向映射（Reverse Mapping, RMAP）。

## 实验目的

- 理解 Linux 虚拟内存系统的基本结构（VMA、页表、物理页）
- 掌握 `fork()` 后的写时复制（CoW）机制及其触发过程
- 深入分析物理页反向映射（RMAP）的数据结构与工作原理
- 理解缺页中断（`do_page_fault`）的处理流程
- 学会通过 GDB 观察内存映射、`mm_struct`、`vm_area_struct` 等内核结构

## 实验环境

- **模拟器**：QEMU（`qemu-system-i386`）
- **内核版本**：Linux 内核（i386 架构，带调试符号的 `vmlinux`）
- **调试工具**：GDB + lx-symbols 内核扩展
- **测试程序**：`abc.c`（含内存共享与写操作）

## 文件说明

| 文件 | 说明 |
|------|------|
| `abc.c` | 测试程序：父进程操作全局字符数组（`foo`/`bar`），随后 fork 两个子进程，验证 CoW 行为；`while(1)` 防止进程退出，便于观察内存映射 |
| `gdb调试原始记录.txt` | GDB 调试的原始输出记录，包含内存结构体字段值、页表条目等信息 |
| `os实验三.drawio` | 实验架构图，展示 `mm_struct`、`vm_area_struct`、`anon_vma`、物理页（`page`）之间的关系 |
| `实验报告github.doc` | 完整实验报告，包含实验分析、RMAP 原理说明与结论 |

## 测试程序说明（abc.c）

```c
char bar[3968] = "\n";          // BSS/数据段全局数组
char foo[4096] = "this is not a test\n";  // 数据段全局数组

void main() {
    // 父进程先读后写 foo，触发对全局变量的修改
    write(2, foo, strlen(foo));
    strcpy(foo, "you are modified\n");  // 写操作
    write(2, foo, strlen(foo));

    fork();  // 子进程1 (B)
    fork();  // 子进程2 (C)

    // 三个进程循环输出，sched_yield() 主动触发调度
    output_loop("A  " / "B  " / "C  ");
    
    while(1);  // 保持进程存活，便于 GDB 观察内存映射
}
```

**关键观察点**：
- `fork()` 后父子进程共享物理页，但页表标记为只读
- 任意进程发生写操作时触发缺页中断，内核分配新物理页（CoW）
- 通过 RMAP 可从物理页找到所有引用它的进程（`anon_vma` 链）

## 核心概念

### 1. 写时复制（Copy-on-Write）

`fork()` 后，父子进程的页表项指向同一物理页，但标记为**只读**。当任一进程尝试写入时：

```
写操作 → 缺页异常（Page Fault）
    │
    ▼
do_page_fault()
    │
    ▼
handle_mm_fault() → do_wp_page()
    │
    ▼
alloc_page()          # 分配新物理页
    │
    ▼
copy_user_highpage()  # 复制原页面内容
    │
    ▼
更新页表项 → 新页设为可写，原页引用计数 -1
```

### 2. 反向映射（RMAP）

RMAP 解决"给定一个物理页，如何找到所有映射它的进程"的问题，主要用于内存回收（`kswapd`）。

**匿名页（anonymous page）RMAP 链**：

```
struct page
    └── mapping → struct anon_vma
                      └── rb_root（红黑树）
                              └── anon_vma_chain
                                      └── vma → vm_area_struct
                                                   └── vm_mm → mm_struct（进程）
```

**关键数据结构**：

| 结构体 | 说明 |
|--------|------|
| `mm_struct` | 进程内存描述符，包含所有 VMA 链表和页表基地址 |
| `vm_area_struct`（VMA） | 描述一段连续虚拟地址区域的属性（权限、映射类型等） |
| `anon_vma` | 匿名映射反向映射的锚点，被一组共享物理页的进程共用 |
| `anon_vma_chain` | 连接 `anon_vma` 与 `vm_area_struct` 的中间节点 |
| `struct page` | 物理页描述符，`mapping` 字段指向 `anon_vma`（匿名页）或 `address_space`（文件页） |

### 3. 关键内核函数

| 函数 | 所在文件 | 说明 |
|------|----------|------|
| `do_page_fault` | `arch/x86/mm/fault.c` | 缺页中断处理入口 |
| `handle_mm_fault` | `mm/memory.c` | 根据缺页原因分发处理 |
| `do_wp_page` | `mm/memory.c` | 写保护页处理（CoW 核心） |
| `page_add_anon_rmap` | `mm/rmap.c` | 将匿名页加入 RMAP |
| `try_to_unmap` | `mm/rmap.c` | 遍历 RMAP 解除所有映射（内存回收时使用） |
| `anon_vma_fork` | `mm/rmap.c` | `fork` 时复制 RMAP 结构 |

## GDB 调试要点

```bash
# 查看当前进程的内存映射
(gdb) p $lx_current()->mm->mmap

# 查看 VMA 链表
(gdb) p/x $lx_current()->mm->mmap->vm_start
(gdb) p/x $lx_current()->mm->mmap->vm_end

# 查看进程页表基地址
(gdb) p/x $lx_current()->mm->pgd

# 在缺页中断处设断点
(gdb) break do_page_fault
(gdb) commands
    p address
    p error_code
    continue
end
```

## 实验步骤

1. **编译测试程序**
   ```bash
   gcc -static -g -o abc abc.c
   ```

2. **将 abc 放入 initramfs 并启动 QEMU（调试模式）**
   ```bash
   qemu-system-i386 -nographic -kernel bzImage -initrd rootfs.img.gz \
     -append "rdinit=/home/nudt/abc console=ttyS0 norandmaps" -s -S
   ```

3. **GDB 连接并调试**
   ```bash
   gdb vmlinux
   (gdb) target remote localhost:1234
   (gdb) add-symbol-file /path/to/abc 0x080482b0
   (gdb) break do_page_fault
   (gdb) continue
   ```

4. **分析 RMAP 结构**  
   在 `fork()` 后设断点，检查父子进程的 `anon_vma` 共享情况，以及 CoW 发生后物理页的引用计数变化。

## 参考资料

- 《深入理解 Linux 内核》第 8、9 章：内存管理
- 《深入 Linux 内核架构》第 4 章：虚拟内存管理
- Linux 内核源码 `mm/rmap.c`、`mm/memory.c`、`mm/page_alloc.c`
- 课程讲义：内存管理与反向映射
