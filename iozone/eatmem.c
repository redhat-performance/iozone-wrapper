//vim: fdm=marker,fmr={,}
/*
gcc -Os -Wall -o eatmem eatmem.c
gcc -DBIT32 -Os -Wall -o eatmem32 eatmem.c

http://www.linuxinsight.com/proc_sys_vm_overcommit_memory.html
* 0 - Heuristic overcommit handling. Obvious overcommits of address space are refused. Used for a typical system. It ensures a seriously wild allocation fails while allowing overcommit to reduce swap usage. root is allowed to allocate slighly more memory in this mode. This is the default.
* 1 - Always overcommit. Appropriate for some scientific applications.
* 2 - Don't overcommit. The total address space commit for the system is not permitted to exceed swap plus a configurable percentage (default is 50) of physical RAM. Depending on the percentage you use, in most situations this means a process will not be killed while attempting to use already-allocated memory but will receive errors on memory allocation as appropriate.

Default: cat /proc/sys/vm/overcommit_memory
0

echo 2 > /proc/sys/vm/overcommit_memory

If MALLOC_CHECK_ is  set  to  0,  any  detected  heap  corruption  is silently  ignored;  
if set to 1, a diagnostic message is printed on stderr; 
if set to 2, abort(3) is called immediately; 
if set to 3, a diagnostic message is printed on stderr and the program is aborted.
Using a non-zero MALLOC_CHECK_ value can be useful because otherwise a crash may happen much later, and the true cause for the problem is then  very  hard to track down.

MALLOC_CHECK_=1 ./eatmem
*/

#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <unistd.h>
#include <signal.h>
#include <errno.h>
#include <sys/wait.h>
#include <string.h>

//#define NDEBUG
//#include <assert.h>

pid_t child_pid=0;
pid_t parrent_pid=0;

int memory_usage() 
{
	char buf[30];
	snprintf(buf, 30, "/proc/%u/statm", (unsigned)getpid());
	FILE* pf = fopen(buf, "r");
	const int pagesize = sysconf(_SC_PAGESIZE) / 1024; //Virtual memory pagesize in kB 
	if (pf) {
			unsigned size; //       total program size
			unsigned resident;//   resident set size
			unsigned share;//      shared pages
			unsigned text;//       text (code)
			unsigned lib;//        library
			unsigned data;//       data/stack
			//unsigned dt;//         dirty pages (unused in Linux 2.6)
			fscanf(pf, "%u %u %u %u %u %u", &size, &resident, &share, &text, &lib, &data);
			return size * pagesize;
	}
	fclose(pf);
	return -1;
}

void signal_handler_sigusr1(int sig)
{
    if (child_pid == 0)
    {
	//no child
        fprintf(stderr,"Process %d received signal %d.\n",getpid(),sig);
    } else {
        fprintf(stderr,"Process %d received signal %d and will send signal SIGUSR1 to it's child %d.\n",getpid(),sig,child_pid);
	kill(child_pid, SIGUSR1);  //18= SIGCONT, 12=SIGUSR2, 10=SIGUSR1
    }
}

int main(int argc, char *argv[])
{
    const int maxcnt=65536;
    long int *buf[maxcnt];
    int i=0;
    const int size = sizeof(long int) ;
    int j, max, memory_to_take; 
    int intrinsic;
    int childExitStatus;
    sigset_t mask, oldmask;



#ifdef BIT32	
    const int max_size_per_pid=1024;   //2048;
#else
    const int max_size_per_pid=maxcnt;
#endif	

    int do_fork=0; //0 means false, no fork needed
    int enough_memory=1; //0 means false, 1 means true
    char argument[20];
    
    signal(SIGUSR1, signal_handler_sigusr1);
    sigemptyset (&mask);
    sigaddset (&mask, SIGUSR1); 
    sigprocmask (SIG_BLOCK, &mask, &oldmask);   //SIGUSR1 signal is blocked
    sigdelset(&oldmask,SIGUSR1);

    parrent_pid = getpid();
    fprintf(stderr,"Process %d\n",parrent_pid);
    

    if ( argc == 2 ) {
	max=atoi(argv[1]);
    } else {
	fprintf (stderr, "Recommended usage: %s [how many MB to block (max %d)].\n",argv[0],maxcnt);
	fprintf (stderr, "Using default: %d\n",maxcnt);
	max=maxcnt;                                                     
    }                                                                       

    if ( max < 1 ) {
	fprintf (stderr, "Value %d has to bigger than 1",max);
	return(1);
    }

    memory_to_take=max;
    
    intrinsic = memory_usage();
    fprintf(stderr,"Starting memory usage in kB:\t %d\n",intrinsic);

    if (max - intrinsic/1024 > max_size_per_pid) {
	max = max_size_per_pid;
	do_fork = 1; //true
    }
    
    max -= intrinsic/1024;

    while (i<max)
    {  
	buf[i] = (long int *) malloc(1024*1024);
	if (buf[i]==NULL) {
	    max = i;
	    do_fork = 0;  //false - no memory left, so let's quit
	    enough_memory = 0; //flag set to FALSE
	    fprintf(stderr, "\nError when allocationg %d-th MB. Not enough memory. Quiting.\n",i+1);
	    break;
	} else 
	{
	    for (j=0; j < 1024*1024/size; ++j) {
	    buf[i][j]=random();
	    }
	    ++i;
	    if (i%100) {
		    fprintf(stderr,".");
	    } else {
		    fprintf(stderr,"\nAllocated %d MB\n",i);
	    }
	}
    }
    intrinsic = memory_usage();
    fprintf(stderr,"Memory usage in kB:\t %d\t in MB:\t%d\n",intrinsic,intrinsic/1024);
    j = memory_to_take-intrinsic/1024;

    if ( j>1 ) {
	snprintf(argument,20,"%d",memory_to_take-intrinsic/1024);
    } else
    {
	do_fork=0;
    }

    if ( enough_memory )
    {
	if (do_fork) 
	{
	    child_pid = vfork();
	    if (child_pid == 0)                // child
	    {
		fprintf(stderr,"Starting child %d\n",getpid());
		fprintf(stderr,"Calling execl(%s,%s,%s)\n",argv[0],argv[0],argument);
		execl(argv[0],argv[0],argument, (char *)0);
		fprintf(stderr,"Error calling execl(%s,%s,%s): %s\n",  argv[0],argv[0],argument, strerror( errno ) );
		exit(0);
	    }
	    else
	    { 
		if (child_pid < 0)            // failed to fork
		{
		    fprintf(stderr,"Failed to fork.");
		}
		else                                   // parent
		{
		    // Code only executed by parent process
		    sigprocmask (SIG_UNBLOCK, &mask, NULL);  //SIGUSR1 is not blocked anymore
		    waitpid( child_pid, &childExitStatus, 0);

		    if( !WIFEXITED(childExitStatus) )
		    {
		     fprintf(stderr,"Waitpid(%d) exited with exit status=%d\n",child_pid,WEXITSTATUS(childExitStatus));
		    }
		    else if( WIFSIGNALED(childExitStatus) )
		    {
		     fprintf(stderr, "waitpid(%d) exited due to a signal: %d\n",child_pid,WTERMSIG(childExitStatus)); 
		    }
		}
	    }
	} else 
	{
	    //do_fork false
	    fprintf(stderr,"Waiting for signal to wake-up.\n");
	    fprintf(stderr,"Use\nkill -s SIGUSR1 %d\n",getpid());
	    fprintf(stderr,"or\nkill -s SIGUSR1 %d <or any %s parrent process>\n",getpgrp(),argv[0]);
	    sigsuspend (&oldmask);                       //waiting for SIGUSR1 to continue 
	    sigprocmask (SIG_UNBLOCK, &mask, NULL);
	    printf("Process %d has been woken up.\n",parrent_pid);
	}
    } else
    {
	j=5;
	fprintf(stderr,"Sleeping for %d seconds.\n",j);
	sleep(j);
    }
	

	if ( max > 0) {
		srandom(getpid());
                i = (int) (max * (random() / (RAND_MAX + 1.0)));
                j =  (int) (1024 * 1024 / size * (random() / (RAND_MAX + 1.0)));
                fprintf(stderr,"\nProcess %d :Element at random position %d,%d is %ld\n",parrent_pid,i,j,buf[i][j]);
        }

//	fprintf(stderr,"Freeing memory.\n");
        
	for (i=0; i<max; i++)
        {
		free(buf[i]);
        }

	fprintf(stderr,"Memory freed. Process %d done.\n",getpid());
	return 0;
}

