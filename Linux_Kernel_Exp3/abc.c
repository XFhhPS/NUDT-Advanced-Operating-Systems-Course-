#include <string.h>
#include <stdlib.h>

char bar[3968]="\n";
char foo[4096]="this is not a test\n";

void output_loop(char * str)
{
  int i;
  for(i=0; i<20; i++){
    write(2, str, strlen(str));
    sched_yield();
  }
}

void main(){
  int pid1, pid2, status;

  write(2, foo, strlen(foo));
  strcpy(foo, "you are modified\n");
  write(2, foo, strlen(foo));
    
  if (!(pid1 = fork())){
    output_loop("B  ");
    exit(0);
  }

  if (!(pid2 = fork())){
    output_loop("C  ");
    exit(0);
  }

  output_loop("A  ");
  waitpid(pid1, &status, 0);
  waitpid(pid2, &status, 0);
  write(2, "\n", 1);

  while(1);

  exit(0);
}
