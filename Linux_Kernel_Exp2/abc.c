#include <stdio.h>
#include <unistd.h>
#include <sys/wait.h>
#include <sched.h>

void print_char(char c) {
    while (1) {
        write(2, &c, 1);  // 系统调用write输出字符:cite[5]
        sched_yield();     // 主动放弃CPU，触发调度:cite[5]:cite[8]
    }
}

int main() {
    pid_t pid1, pid2;

    // 创建子进程1
    if ((pid1 = fork()) == 0) {
        print_char('A');
        _exit(0);
    }

    // 创建子进程2
    if ((pid2 = fork()) == 0) {
        print_char('B');
        _exit(0);
    }

    // 父进程执行C输出
    print_char('C');
    // 等待子进程结束
    waitpid(pid1, NULL, 0);
    waitpid(pid2, NULL, 0);
    return 0;
}
