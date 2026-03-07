# 使用命令：gdb -x abc5_7.gdb vmlinux
##########################
### 阶段1: 初始化配置 ###
##########################
define setup_kernel_breaks
  break do_execve
  
  break __schedule
  
  break kernel/sched/core.c:3188
  
  break __switch_to
  commands
   printf "[SWITCH] Next PID:%d\n", next_p->pid
    continue
  end
  
  break process_32.c:318
  commands
  printf "[SWITCH] Next PID:%d\n", next_p->pid
    bt
    continue
  end
  
  break smp_apic_timer_interrupt
  break do_IRQ
  
  break ret_from_intr
  break ret_from_exception
  break restore_all
  
  break do_page_fault
  
  break do_fast_syscall_32
  commands
    printf "[SYSCALL] NR:%d\n", (int)((struct pt_regs*)regs)->orig_ax
    continue
  end
  
 break arch/x86/entry/common.c:486
  commands
    printf "[SYSCALL] NR:%d\n", (int)((struct pt_regs*)regs)->orig_ax
    continue
  end
  
  break enqueue_task_fair
  commands
    printf "[ENQUEUE] PID:%d Name:%s\n", p->pid, p->comm
      printf "CFS Queue Info:\n"
  printf "Root: PID=%d vruntime=%lu\n", \
         ((struct task_struct*)((void*)$lx_per_cpu("runqueues").cfs.tasks_timeline.rb_node - 0x4c))->pid, \
         ((struct task_struct*)((void*)$lx_per_cpu("runqueues").cfs.tasks_timeline.rb_node - 0x4c))->se.vruntime
  printf "Leftmost: PID=%d vruntime=%lu\n", \
         ((struct task_struct*)((void*)$lx_per_cpu("runqueues").cfs.rb_leftmost - 0x4c))->pid, \
         ((struct task_struct*)((void*)$lx_per_cpu("runqueues").cfs.rb_leftmost - 0x4c))->se.vruntime
    continue
  end
  
  break dequeue_task_fair
  commands
    printf "[DEQUEUE] PID:%d Name:%s\n", p->pid, p->comm
      printf "CFS Queue Info:\n"
  printf "Leftmost: PID=%d vruntime=%lu\n", \
         ((struct task_struct*)((void*)$lx_per_cpu("runqueues").cfs.rb_leftmost - 0x4c))->pid, \
         ((struct task_struct*)((void*)$lx_per_cpu("runqueues").cfs.rb_leftmost - 0x4c))->se.vruntime
  printf "Root: PID=%d vruntime=%lu\n", \
         ((struct task_struct*)((void*)$lx_per_cpu("runqueues").cfs.tasks_timeline.rb_node - 0x4c))->pid, \
         ((struct task_struct*)((void*)$lx_per_cpu("runqueues").cfs.tasks_timeline.rb_node - 0x4c))->se.vruntime
    continue
  end
  
  break prepare_exit_to_usermode
  
  break set_tsk_need_resched
end

define init_logging
  set pagination off
  set logging file timeline.log
  set logging overwrite on
  set logging on
end
##########################
### 阶段2: 执行流程 ###
##########################
define main_flow
  setup_kernel_breaks
  disable
  add-symbol-file /home/nudt/abc 0x080482b0
  break abc.c:main
  continue
  enable
  continue
 end
##########################
### 阶段3: 事件处理 ###
##########################

define hook-stop
  printf "[Breaked]\n"
  printf "Now process pid=%d, comm=%s, mm=%p\n", $lx_current().pid, $lx_current().comm, $lx_current().mm
  printf "Now process TIF_NEED_RESCHED =%d\n",$lx_thread_info($lx_current()).flags& (1 << 3) ? 1 : 0
  printf "Now process vruntime =%lu\n",$lx_current().se.vruntime
  printf "Running processes: %d\n", $lx_per_cpu("runqueues").nr_running

 
  if $bpnum == 18
    printf "[USER] Hit main()\n"
    stop
  else
    printf "[KERNEL] Breakpoint\n"
    continue
  end
end
##########################
### 执行入口 ###
##########################
target remote localhost:1234
init_logging
main_flow