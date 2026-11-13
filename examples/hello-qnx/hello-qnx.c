#include <stdio.h>
#include <sys/utsname.h>

int main(void)
{
    struct utsname sys;

    printf("Hello QNX!\n");
    if (uname(&sys) != 0) {
        perror("uname");
        return 1;
    }
    printf("sysname=%s release=%s machine=%s version=%s\n",
           sys.sysname, sys.release, sys.machine, sys.version);
    return 0;
}
