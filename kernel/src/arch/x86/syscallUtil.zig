pub const ERROR_RETURN: u32 = 0xFFFFFFFF; // -1
pub const SUCCESS_RETURN: u32 = 0x00000000; // 0

pub const errno = enum(i32) {
    EPERM = 1, // Operation not permitted
    ENOENT = 2, // No such file or directory
    ESRCH = 3, // No such process
    EINTR = 4, // Interrupted system call
    EIO = 5, // Input/output error
    ENXIO = 6, // No such device or address
    E2BIG = 7, // Argument list too long
    ENOEXEC = 8, // Exec format error
    EBADF = 9, // Bad file descriptor
    ECHILD = 10, // No child processes
    EAGAIN = 11, // Resource temporarily unavailable
    ENOMEM = 12, // Cannot allocate memory
    EACCES = 13, // Permission denied
    EFAULT = 14, // Bad address
    ENOTBLK = 15, // Block device required
    EBUSY = 16, // Device or resource busy
    EEXIST = 17, // File exists
    EXDEV = 18, // Invalid cross-device link
    ENODEV = 19, // No such device
    ENOTDIR = 20, // Not a directory
    EISDIR = 21, // Is a directory
    EINVAL = 22, // Invalid argument
    ENFILE = 23, // Too many open files in system
    EMFILE = 24, // Too many open files
    ENOTTY = 25, // Inappropriate ioctl for device
    ETXTBSY = 26, // Text file busy
    EFBIG = 27, // File too large
    ENOSPC = 28, // No space left on device
    ESPIPE = 29, // Illegal seek
    EROFS = 30, // Read-only file system
    EMLINK = 31, // Too many links
    EPIPE = 32, // Broken pipe
    EDOM = 33, // Numerical argument out of domain
    ERANGE = 34, // Numerical result out of range
    EDEADLK = 35, // Resource deadlock avoided
    ENAMETOOLONG = 36, // File name too long
    ENOLCK = 37, // No locks available
    ENOSYS = 38, // Function not implemented
    ENOTEMPTY = 39, // Directory not empty
    ELOOP = 40, // Too many levels of symbolic links
    ENOMSG = 42, // No message of desired type
    EIDRM = 43, // Identifier removed
    ECHRNG = 44, // Channel number out of range
    EL2NSYNC = 45, // Level 2 not synchronized
    EL3HLT = 46, // Level 3 halted
    EL3RST = 47, // Level 3 reset
    ELNRNG = 48, // Link number out of range
    EUNATCH = 49, // Protocol driver not attached
    ENOCSI = 50, // No CSI structure available
    EL2HLT = 51, // Level 2 halted
    EBADE = 52, // Invalid exchange
    EBADR = 53, // Invalid request descriptor
    EXFULL = 54, // Exchange full
    ENOANO = 55, // No anode
    EBADRQC = 56, // Invalid request code
    EBADSLT = 57, // Invalid slot
    EBFONT = 59, // Bad font file format
    ENOSTR = 60, // Device not a stream
    ENODATA = 61, // No data available
    ETIME = 62, // Timer expired
    ENOSR = 63, // Out of streams resources
    ENONET = 64, // Machine is not on the network
    ENOPKG = 65, // Package not installed
    EREMOTE = 66, // Object is remote
    ENOLINK = 67, // Link has been severed
    EADV = 68, // Advertise error
    ESRMNT = 69, // Srmount error
    ECOMM = 70, // Communication error on send
    EPROTO = 71, // Protocol error
    EMULTIHOP = 72, // Multihop attempted
    EDOTDOT = 73, // RFS specific error
    EBADMSG = 74, // Bad message
    EOVERFLOW = 75, // Value too large for defined data type
    ENOTUNIQ = 76, // Name not unique on network
    EBADFD = 77, // File descriptor in bad state
    EREMCHG = 78, // Remote address changed
    ELIBACC = 79, // Can not access a needed shared library
    ELIBBAD = 80, // Accessing a corrupted shared library
    ELIBSCN = 81, // .lib section in a.out corrupted
    ELIBMAX = 82, // Attempting to link in too many shared libraries
    ELIBEXEC = 83, // Cannot exec a shared library directly
    EILSEQ_2 = 84, // Invalid or incomplete multibyte or wide character
    ERESTART = 85, // Interrupted system call should be restarted
    ESTRPIPE_2 = 86, // Streams pipe error
    EUSERS = 87, // Too many users
    ENOTSOCK = 88, // Socket operation on non-socket
    EDESTADDRREQ = 89, // Destination address required
    EMSGSIZE = 90, // Message too long
    EPROTOTYPE = 91, // Protocol wrong type for socket
    ENOPROTOOPT = 92, // Protocol not available
    EPROTONOSUPPORT = 93, // Protocol not supported
    ESOCKTNOSUPPORT = 94, // Socket type not supported
    EOPNOTSUPP = 95, // Operation not supported
    EPFNOSUPPORT = 96, // Protocol family not supported
    EAFNOSUPPORT = 97, // Address family not supported by protocol
    EADDRINUSE = 98, // Address already in use
    EADDRNOTAVAIL = 99, // Cannot assign requested address
    ENETDOWN = 100, // Network is down
    ENETUNREACH = 101, // Network is unreachable
    ENETRESET = 102, // Network dropped connection on reset
    ECONNABORTED = 103, // Software caused connection abort
    ECONNRESET = 104, // Connection reset by peer
    ENOBUFS = 105, // No buffer space available
    EISCONN = 106, // Transport endpoint is already connected
    ENOTCONN = 107, // Transport endpoint is not connected
    ESHUTDOWN = 108, // Cannot send after transport endpoint shutdown
    ETOOMANYREFS = 109, // Too many references: cannot splice
    ETIMEDOUT = 110, // Connection timed out
    ECONNREFUSED = 111, // Connection refused
    EHOSTDOWN = 112, // Host is down
    EHOSTUNREACH = 113, // No route to host
    EALREADY = 114, // Operation already in progress
    EINPROGRESS = 115, // Operation now in progress
    ESTALE = 116, // Stale file handle
    EUCLEAN = 117, // Structure needs cleaning
    ENOTNAM = 118, // Not a XENIX named type file
    ENAVAIL = 119, // No XENIX semaphores available
    EISNAM = 120, // Is a named type file
    EREMOTEIO = 121, // Remote I/O error
    EDQUOT = 122, // Disk quota exceeded
    ENOMEDIUM_2 = 123, // No medium found
    EMEDIUMTYPE = 124, // Wrong medium type
    ECANCELED_2 = 125, // Operation canceled
    ENOKEY = 126, // Required key not available
    EKEYEXPIRED = 127, // Key has expired
    EKEYREVOKED = 128, // Key has been revoked
    EKEYREJECTED = 129, // Key was rejected by service
    EOWNERDEAD_2 = 130, // Owner died
    ENOTRECOVERABLE_2 = 131, // State not recoverable
    ERFKILL = 132, // Operation not possible due to RF-kill
    EHWPOISON = 133, // Memory page has hardware error
    ENOTSUP = 134, // Not supported parameter or option
    ENOMEDIUM = 135, // Missing media
    EILSEQ = 138, // Invalid multibyte sequence
    EOVERFLOW_2 = 139, // Value too large
    ECANCELED = 140, // Asynchrononous operation stopped before normal completion
    ENOTRECOVERABLE = 141, // State not recoverable
    EOWNERDEAD = 142, // Previous owner died
    ESTRPIPE = 143, // Streams pipe error
};

pub const syscallNames = [_][]const u8{
    "restart_syscall", // man/ cs/0x00 - - - - - -
    "exit", // man/ cs/ 0x01 int error_code - - - - -
    "fork", // man/ cs/ 0x02 - - - - - -
    "read", // man/ cs/ 0x03 unsigned int fd char *buf size_t count - - -
    "write", // man/ cs/ 0x04 unsigned int fd const char *buf size_t count - - -
    "open", // man/ cs/ 0x05 const char *filename int flags umode_t mode - - -
    "close", // man/ cs/ 0x06 unsigned int fd - - - - -
    "waitpid", // man/ cs/ 0x07 pid_t pid int *stat_addr int options - - -
    "creat", // man/ cs/ 0x08 const char *pathname umode_t mode - - - -
    "link", // man/ cs/ 0x09 const char *oldname const char *newname - - - -
    "unlink", // man/ cs/ 0x0a const char *pathname - - - - -
    "execve", // man/ cs/ 0x0b const char *filename const char *const *argv const char *const *envp - - -
    "chdir", // man/ cs/ 0x0c const char *filename - - - - -
    "time", // man/ cs/ 0x0d time_t *tloc - - - - -
    "mknod", // man/ cs/ 0x0e const char *filename umode_t mode unsigned dev - - -
    "chmod", // man/ cs/ 0x0f const char *filename umode_t mode - - - -
    "lchown", // man/ cs/ 0x10 const char *filename uid_t user gid_t group - - -
    "break", // man/ cs/ 0x11 ? ? ? ? ? ?
    "oldstat", // man/ cs/ 0x12 ? ? ? ? ? ?
    "lseek", // man/ cs/ 0x13 unsigned int fd off_t offset unsigned int whence - - -
    "getpid", // man/ cs/ 0x14 - - - - - -
    "mount", // man/ cs/ 0x15 char *dev_name char *dir_name char *type unsigned long flags void *data -
    "umount", // man/ cs/ 0x16 char *name int flags - - - -
    "setuid", // man/ cs/ 0x17 uid_t uid - - - - -
    "getuid", // man/ cs/ 0x18 - - - - - -
    "stime", // man/ cs/ 0x19 time_t *tptr - - - - -
    "ptrace", // man/ cs/ 0x1a long request long pid unsigned long addr unsigned long data - -
    "alarm", // man/ cs/ 0x1b unsigned int seconds - - - - -
    "oldfstat", // man/ cs/ 0x1c ? ? ? ? ? ?
    "pause", // man/ cs/ 0x1d - - - - - -
    "utime", // man/ cs/ 0x1e char *filename struct utimbuf *times - - - -
    "stty", // man/ cs/ 0x1f ? ? ? ? ? ?
    "gtty", // man/ cs/ 0x20 ? ? ? ? ? ?
    "access", // man/ cs/ 0x21 const char *filename int mode - - - -
    "nice", // man/ cs/ 0x22 int increment - - - - -
    "ftime", // man/ cs/ 0x23 ? ? ? ? ? ?
    "sync", // man/ cs/ 0x24 - - - - - -
    "kill", // man/ cs/ 0x25 pid_t pid int sig - - - -
    "rename", // man/ cs/ 0x26 const char *oldname const char *newname - - - -
    "mkdir", // man/ cs/ 0x27 const char *pathname umode_t mode - - - -
    "rmdir", // man/ cs/ 0x28 const char *pathname - - - - -
    "dup", // man/ cs/ 0x29 unsigned int fildes - - - - -
    "pipe", // man/ cs/ 0x2a int *fildes - - - - -
    "times", // man/ cs/ 0x2b struct tms *tbuf - - - - -
    "prof", // man/ cs/ 0x2c ? ? ? ? ? ?
    "brk", // man/ cs/ 0x2d unsigned long brk - - - - -
    "setgid", // man/ cs/ 0x2e gid_t gid - - - - -
    "getgid", // man/ cs/ 0x2f - - - - - -
    "signal", // man/ cs/ 0x30 int sig __sighandler_t handler - - - -
    "geteuid", // man/ cs/ 0x31 - - - - - -
    "getegid", // man/ cs/ 0x32 - - - - - -
    "acct", // man/ cs/ 0x33 const char *name - - - - -
    "umount2", // man/ cs/ 0x34 ? ? ? ? ? ?
    "lock", // man/ cs/ 0x35 ? ? ? ? ? ?
    "ioctl", // man/ cs/ 0x36 unsigned int fd unsigned int cmd unsigned long arg - - -
    "fcntl", // man/ cs/ 0x37 unsigned int fd unsigned int cmd unsigned long arg - - -
    "mpx", // man/ cs/ 0x38 ? ? ? ? ? ?
    "setpgid", // man/ cs/ 0x39 pid_t pid pid_t pgid - - - -
    "ulimit", // man/ cs/ 0x3a ? ? ? ? ? ?
    "oldolduname", // man/ cs/ 0x3b ? ? ? ? ? ?
    "umask", // man/ cs/ 0x3c int mask - - - - -
    "chroot", // man/ cs/ 0x3d const char *filename - - - - -
    "ustat", // man/ cs/ 0x3e unsigned dev struct ustat *ubuf - - - -
    "dup2", // man/ cs/ 0x3f unsigned int oldfd unsigned int newfd - - - -
    "getppid", // man/ cs/ 0x40 - - - - - -
    "getpgrp", // man/ cs/ 0x41 - - - - - -
    "setsid", // man/ cs/ 0x42 - - - - - -
    "sigaction", // man/ cs/ 0x43 int const struct old_sigaction * struct old_sigaction * - - -
    "sgetmask", // man/ cs/ 0x44 - - - - - -
    "ssetmask/my debugPrint", // man/ cs/ 0x45 int newmask - - - - -
    "setreuid", // man/ cs/ 0x46 uid_t ruid uid_t euid - - - -
    "setregid", // man/ cs/ 0x47 gid_t rgid gid_t egid - - - -
    "sigsuspend", // man/ cs/ 0x48 int unused1 int unused2 old_sigset_t mask - - -
    "sigpending", // man/ cs/ 0x49 old_sigset_t *uset - - - - -
    "sethostname", // man/ cs/ 0x4a char *name int len - - - -
    "setrlimit", // man/ cs/ 0x4b unsigned int resource struct rlimit *rlim - - - -
    "getrlimit", // man/ cs/ 0x4c unsigned int resource struct rlimit *rlim - - - -
    "getrusage", // man/ cs/ 0x4d int who struct rusage *ru - - - -
    "gettimeofday", // man/ cs/ 0x4e struct timeval *tv struct timezone *tz - - - -
    "settimeofday", // man/ cs/ 0x4f struct timeval *tv struct timezone *tz - - - -
    "getgroups", // man/ cs/ 0x50 int gidsetsize gid_t *grouplist - - - -
    "setgroups", // man/ cs/ 0x51 int gidsetsize gid_t *grouplist - - - -
    "select", // man/ cs/ 0x52 int n fd_set *inp fd_set *outp fd_set *exp struct timeval *tvp -
    "symlink", // man/ cs/ 0x53 const char *old const char *new - - - -
    "oldlstat", // man/ cs/ 0x54 ? ? ? ? ? ?
    "readlink", // man/ cs/ 0x55 const char *path char *buf int bufsiz - - -
    "uselib", // man/ cs/ 0x56 const char *library - - - - -
    "swapon", // man/ cs/ 0x57 const char *specialfile int swap_flags - - - -
    "reboot", // man/ cs/ 0x58 int magic1 int magic2 unsigned int cmd void *arg - -
    "readdir", // man/ cs/ 0x59 ? ? ? ? ? ?
    "mmap", // man/ cs/ 0x5a ? ? ? ? ? ?
    "munmap", // man/ cs/ 0x5b unsigned long addr size_t len - - - -
    "truncate", // man/ cs/ 0x5c const char *path long length - - - -
    "ftruncate", // man/ cs/ 0x5d unsigned int fd unsigned long length - - - -
    "fchmod", // man/ cs/ 0x5e unsigned int fd umode_t mode - - - -
    "fchown", // man/ cs/ 0x5f unsigned int fd uid_t user gid_t group - - -
    "getpriority", // man/ cs/ 0x60 int which int who - - - -
    "setpriority", // man/ cs/ 0x61 int which int who int niceval - - -
    "profil", // man/ cs/ 0x62 ? ? ? ? ? ?
    "statfs", // man/ cs/ 0x63 const char * path struct statfs *buf - - - -
    "fstatfs", // man/ cs/ 0x64 unsigned int fd struct statfs *buf - - - -
    "ioperm", // man/ cs/ 0x65 unsigned long from unsigned long num int on - - -
    "socketcall", // man/ cs/ 0x66 int call unsigned long *args - - - -
    "syslog", // man/ cs/ 0x67 int type char *buf int len - - -
    "setitimer", // man/ cs/ 0x68 int which struct itimerval *value struct itimerval *ovalue - - -
    "getitimer", // man/ cs/ 0x69 int which struct itimerval *value - - - -
    "stat", // man/ cs/ 0x6a const char *filename struct __old_kernel_stat *statbuf - - - -
    "lstat", // man/ cs/ 0x6b const char *filename struct __old_kernel_stat *statbuf - - - -
    "fstat", // man/ cs/ 0x6c unsigned int fd struct __old_kernel_stat *statbuf - - - -
    "olduname", // man/ cs/ 0x6d struct oldold_utsname * - - - - -
    "iopl", // man/ cs/ 0x6e ? ? ? ? ? ?
    "vhangup", // man/ cs/ 0x6f - - - - - -
    "idle", // man/ cs/ 0x70 ? ? ? ? ? ?
    "vm86old", // man/ cs/ 0x71 ? ? ? ? ? ?
    "wait4", // man/ cs/ 0x72 pid_t pid int *stat_addr int options struct rusage *ru - -
    "swapoff", // man/ cs/ 0x73 const char *specialfile - - - - -
    "sysinfo", // man/ cs/ 0x74 struct sysinfo *info - - - - -
    "ipc", // man/ cs/ 0x75 unsigned int call int first unsigned long second unsigned long third void *ptr long fifth
    "fsync", // man/ cs/ 0x76 unsigned int fd - - - - -
    "sigreturn", // man/ cs/ 0x77 ? ? ? ? ? ?
    "clone", // man/ cs/ 0x78 unsigned long unsigned long int * int * unsigned long -
    "setdomainname", // man/ cs/ 0x79 char *name int len - - - -
    "uname", // man/ cs/ 0x7a struct old_utsname * - - - - -
    "modify_ldt", // man/ cs/ 0x7b ? ? ? ? ? ?
    "adjtimex", // man/ cs/ 0x7c struct __kernel_timex *txc_p - - - - -
    "mprotect", // man/ cs/ 0x7d unsigned long start size_t len unsigned long prot - - -
    "sigprocmask", // man/ cs/ 0x7e int how old_sigset_t *set old_sigset_t *oset - - -
    "create_module", // man/ cs/ 0x7f ? ? ? ? ? ?
    "init_module", // man/ cs/ 0x80 void *umod unsigned long len const char *uargs - - -
    "delete_module", // man/ cs/ 0x81 const char *name_user unsigned int flags - - - -
    "get_kernel_syms", // man/ cs/ 0x82 ? ? ? ? ? ?
    "quotactl", // man/ cs/ 0x83 unsigned int cmd const char *special qid_t id void *addr - -
    "getpgid", // man/ cs/ 0x84 pid_t pid - - - - -
    "fchdir", // man/ cs/ 0x85 unsigned int fd - - - - -
    "bdflush", // man/ cs/ 0x86 int func long data - - - -
    "sysfs", // man/ cs/ 0x87 int option unsigned long arg1 unsigned long arg2 - - -
    "personality", // man/ cs/ 0x88 unsigned int personality - - - - -
    "afs_syscall", // man/ cs/ 0x89 ? ? ? ? ? ?
    "setfsuid", // man/ cs/ 0x8a uid_t uid - - - - -
    "setfsgid", // man/ cs/ 0x8b gid_t gid - - - - -
    "_llseek", // man/ cs/ 0x8c ? ? ? ? ? ?
    "getdents", // man/ cs/ 0x8d unsigned int fd struct linux_dirent *dirent unsigned int count - - -
    "_newselect", // man/ cs/ 0x8e ? ? ? ? ? ?
    "flock", // man/ cs/ 0x8f unsigned int fd unsigned int cmd - - - -
    "msync", // man/ cs/ 0x90 unsigned long start size_t len int flags - - -
    "readv", // man/ cs/ 0x91 unsigned long fd const struct iovec *vec unsigned long vlen - - -
    "writev", // man/ cs/ 0x92 unsigned long fd const struct iovec *vec unsigned long vlen - - -
    "getsid", // man/ cs/ 0x93 pid_t pid - - - - -
    "fdatasync", // man/ cs/ 0x94 unsigned int fd - - - - -
    "_sysctl", // man/ cs/ 0x95 ? ? ? ? ? ?
    "mlock", // man/ cs/ 0x96 unsigned long start size_t len - - - -
    "munlock", // man/ cs/ 0x97 unsigned long start size_t len - - - -
    "mlockall", // man/ cs/ 0x98 int flags - - - - -
    "munlockall", // man/ cs/ 0x99 - - - - - -
    "sched_setparam", // man/ cs/ 0x9a pid_t pid struct sched_param *param - - - -
    "sched_getparam", // man/ cs/ 0x9b pid_t pid struct sched_param *param - - - -
    "sched_setscheduler", // man/ cs/ 0x9c pid_t pid int policy struct sched_param *param - - -
    "sched_getscheduler", // man/ cs/ 0x9d pid_t pid - - - - -
    "sched_yield", // man/ cs/ 0x9e - - - - - -
    "sched_get_priority_max", // man/ cs/ 0x9f int policy - - - - -
    "sched_get_priority_min", // man/ cs/ 0xa0 int policy - - - - -
    "sched_rr_get_interval", // man/ cs/ 0xa1 pid_t pid struct __kernel_timespec *interval - - - -
    "nanosleep", // man/ cs/ 0xa2 struct __kernel_timespec *rqtp struct __kernel_timespec *rmtp - - - -
    "mremap", // man/ cs/ 0xa3 unsigned long addr unsigned long old_len unsigned long new_len unsigned long flags unsigned long new_addr -
    "setresuid", // man/ cs/ 0xa4 uid_t ruid uid_t euid uid_t suid - - -
    "getresuid", // man/ cs/ 0xa5 uid_t *ruid uid_t *euid uid_t *suid - - -
    "vm86", // man/ cs/ 0xa6 ? ? ? ? ? ?
    "query_module", // man/ cs/ 0xa7 ? ? ? ? ? ?
    "poll", // man/ cs/ 0xa8 struct pollfd *ufds unsigned int nfds int timeout - - -
    "nfsservctl", // man/ cs/ 0xa9 ? ? ? ? ? ?
    "setresgid", // man/ cs/ 0xaa gid_t rgid gid_t egid gid_t sgid - - -
    "getresgid", // man/ cs/ 0xab gid_t *rgid gid_t *egid gid_t *sgid - - -
    "prctl", // man/ cs/ 0xac int option unsigned long arg2 unsigned long arg3 unsigned long arg4 unsigned long arg5 -
    "rt_sigreturn", // man/ cs/ 0xad ? ? ? ? ? ?
    "rt_sigaction", // man/ cs/ 0xae int const struct sigaction * struct sigaction * size_t - -
    "rt_sigprocmask", // man/ cs/ 0xaf int how sigset_t *set sigset_t *oset size_t sigsetsize - -
    "rt_sigpending", // man/ cs/ 0xb0 sigset_t *set size_t sigsetsize - - - -
    "rt_sigtimedwait", // man/ cs/ 0xb1 const sigset_t *uthese siginfo_t *uinfo const struct __kernel_timespec *uts size_t sigsetsize - -
    "rt_sigqueueinfo", // man/ cs/ 0xb2 pid_t pid int sig siginfo_t *uinfo - - -
    "rt_sigsuspend", // man/ cs/ 0xb3 sigset_t *unewset size_t sigsetsize - - - -
    "pread64", // man/ cs/ 0xb4 unsigned int fd char *buf size_t count loff_t pos - -
    "pwrite64", // man/ cs/ 0xb5 unsigned int fd const char *buf size_t count loff_t pos - -
    "chown", // man/ cs/ 0xb6 const char *filename uid_t user gid_t group - - -
    "getcwd", // man/ cs/ 0xb7 char *buf unsigned long size - - - -
    "capget", // man/ cs/ 0xb8 cap_user_header_t header cap_user_data_t dataptr - - - -
    "capset", // man/ cs/ 0xb9 cap_user_header_t header const cap_user_data_t data - - - -
    "sigaltstack", // man/ cs/ 0xba const struct sigaltstack *uss struct sigaltstack *uoss - - - -
    "sendfile", // man/ cs/ 0xbb int out_fd int in_fd off_t *offset size_t count - -
    "getpmsg", // man/ cs/ 0xbc ? ? ? ? ? ?
    "putpmsg", // man/ cs/ 0xbd ? ? ? ? ? ?
    "vfork", // man/ cs/ 0xbe - - - - - -
    "ugetrlimit", // man/ cs/ 0xbf ? ? ? ? ? ?
    "mmap2", // man/ cs/ 0xc0 ? ? ? ? ? ?
    "truncate64", // man/ cs/ 0xc1 const char *path loff_t length - - - -
    "ftruncate64", // man/ cs/ 0xc2 unsigned int fd loff_t length - - - -
    "stat64", // man/ cs/ 0xc3 const char *filename struct stat64 *statbuf - - - -
    "lstat64", // man/ cs/ 0xc4 const char *filename struct stat64 *statbuf - - - -
    "fstat64", // man/ cs/ 0xc5 unsigned long fd struct stat64 *statbuf - - - -
    "lchown32", // man/ cs/ 0xc6 ? ? ? ? ? ?
    "getuid32", // man/ cs/ 0xc7 ? ? ? ? ? ?
    "getgid32", // man/ cs/ 0xc8 ? ? ? ? ? ?
    "geteuid32", // man/ cs/ 0xc9 ? ? ? ? ? ?
    "getegid32", // man/ cs/ 0xca ? ? ? ? ? ?
    "setreuid32", // man/ cs/ 0xcb ? ? ? ? ? ?
    "setregid32", // man/ cs/ 0xcc ? ? ? ? ? ?
    "getgroups32", // man/ cs/ 0xcd ? ? ? ? ? ?
    "setgroups32", // man/ cs/ 0xce ? ? ? ? ? ?
    "fchown32", // man/ cs/ 0xcf ? ? ? ? ? ?
    "setresuid32", // man/ cs/ 0xd0 ? ? ? ? ? ?
    "getresuid32", // man/ cs/ 0xd1 ? ? ? ? ? ?
    "setresgid32", // man/ cs/ 0xd2 ? ? ? ? ? ?
    "getresgid32", // man/ cs/ 0xd3 ? ? ? ? ? ?
    "chown32", // man/ cs/ 0xd4 ? ? ? ? ? ?
    "setuid32", // man/ cs/ 0xd5 ? ? ? ? ? ?
    "setgid32", // man/ cs/ 0xd6 ? ? ? ? ? ?
    "setfsuid32", // man/ cs/ 0xd7 ? ? ? ? ? ?
    "setfsgid32", // man/ cs/ 0xd8 ? ? ? ? ? ?
    "pivot_root", // man/ cs/ 0xd9 const char *new_root const char *put_old - - - -
    "mincore", // man/ cs/ 0xda unsigned long start size_t len unsigned char * vec - - -
    "madvise", // man/ cs/ 0xdb unsigned long start size_t len int behavior - - -
    "getdents64", // man/ cs/ 0xdc unsigned int fd struct linux_dirent64 *dirent unsigned int count - - -
    "fcntl64", // man/ cs/ 0xdd unsigned int fd unsigned int cmd unsigned long arg - - -
    "not", // implemented  0xde
    "not", // implemented  0xdf
    "gettid", // man/ cs/ 0xe0 - - - - - -
    "readahead", // man/ cs/ 0xe1 int fd loff_t offset size_t count - - -
    "setxattr", // man/ cs/ 0xe2 const char *path const char *name const void *value size_t size int flags -
    "lsetxattr", // man/ cs/ 0xe3 const char *path const char *name const void *value size_t size int flags -
    "fsetxattr", // man/ cs/ 0xe4 int fd const char *name const void *value size_t size int flags -
    "getxattr", // man/ cs/ 0xe5 const char *path const char *name void *value size_t size - -
    "lgetxattr", // man/ cs/ 0xe6 const char *path const char *name void *value size_t size - -
    "fgetxattr", // man/ cs/ 0xe7 int fd const char *name void *value size_t size - -
    "listxattr", // man/ cs/ 0xe8 const char *path char *list size_t size - - -
    "llistxattr", // man/ cs/ 0xe9 const char *path char *list size_t size - - -
    "flistxattr", // man/ cs/ 0xea int fd char *list size_t size - - -
    "removexattr", // man/ cs/ 0xeb const char *path const char *name - - - -
    "lremovexattr", // man/ cs/ 0xec const char *path const char *name - - - -
    "fremovexattr", // man/ cs/ 0xed int fd const char *name - - - -
    "tkill", // man/ cs/ 0xee pid_t pid int sig - - - -
    "sendfile64", // man/ cs/ 0xef int out_fd int in_fd loff_t *offset size_t count - -
    "futex", // man/ cs/ 0xf0 u32 *uaddr int op u32 val struct __kernel_timespec *utime u32 *uaddr2 u32 val3
    "sched_setaffinity", // man/ cs/ 0xf1 pid_t pid unsigned int len unsigned long *user_mask_ptr - - -
    "sched_getaffinity", // man/ cs/ 0xf2 pid_t pid unsigned int len unsigned long *user_mask_ptr - - -
    "set_thread_area", // man/ cs/ 0xf3 ? ? ? ? ? ?
    "get_thread_area", // man/ cs/ 0xf4 ? ? ? ? ? ?
    "io_setup", // man/ cs/ 0xf5 unsigned nr_reqs aio_context_t *ctx - - - -
    "io_destroy", // man/ cs/ 0xf6 aio_context_t ctx - - - - -
    "io_getevents", // man/ cs/ 0xf7 aio_context_t ctx_id long min_nr long nr struct io_event *events struct __kernel_timespec *timeout -
    "io_submit", // man/ cs/ 0xf8 aio_context_t long struct iocb * * - - -
    "io_cancel", // man/ cs/ 0xf9 aio_context_t ctx_id struct iocb *iocb struct io_event *result - - -
    "fadvise64", // man/ cs/ 0xfa int fd loff_t offset size_t len int advice - -
    "not", // implemented  0xfb
    "exit_group", // man/ cs/ 0xfc int error_code - - - - -
    "lookup_dcookie", // man/ cs/ 0xfd u64 cookie64 char *buf size_t len - - -
    "epoll_create", // man/ cs/ 0xfe int size - - - - -
    "epoll_ctl", // man/ cs/ 0xff int epfd int op int fd struct epoll_event *event - -
    "epoll_wait", // man/ cs/ 0x100 int epfd struct epoll_event *events int maxevents int timeout - -
    "remap_file_pages", // man/ cs/ 0x101 unsigned long start unsigned long size unsigned long prot unsigned long pgoff unsigned long flags -
    "set_tid_address", // man/ cs/ 0x102 int *tidptr - - - - -
    "timer_create", // man/ cs/ 0x103 clockid_t which_clock struct sigevent *timer_event_spec timer_t * created_timer_id - - -
    "timer_settime", // man/ cs/ 0x104 timer_t timer_id int flags const struct __kernel_itimerspec *new_setting struct __kernel_itimerspec *old_setting - -
    "timer_gettime", // man/ cs/ 0x105 timer_t timer_id struct __kernel_itimerspec *setting - - - -
    "timer_getoverrun", // man/ cs/ 0x106 timer_t timer_id - - - - -
    "timer_delete", // man/ cs/ 0x107 timer_t timer_id - - - - -
    "clock_settime", // man/ cs/ 0x108 clockid_t which_clock const struct __kernel_timespec *tp - - - -
    "clock_gettime", // man/ cs/ 0x109 clockid_t which_clock struct __kernel_timespec *tp - - - -
    "clock_getres", // man/ cs/ 0x10a clockid_t which_clock struct __kernel_timespec *tp - - - -
    "clock_nanosleep", // man/ cs/ 0x10b clockid_t which_clock int flags const struct __kernel_timespec *rqtp struct __kernel_timespec *rmtp - -
    "statfs64", // man/ cs/ 0x10c const char *path size_t sz struct statfs64 *buf - - -
    "fstatfs64", // man/ cs/ 0x10d unsigned int fd size_t sz struct statfs64 *buf - - -
    "tgkill", // man/ cs/ 0x10e pid_t tgid pid_t pid int sig - - -
    "utimes", // man/ cs/ 0x10f char *filename struct timeval *utimes - - - -
    "fadvise64_64", // man/ cs/ 0x110 int fd loff_t offset loff_t len int advice - -
    "vserver", // man/ cs/ 0x111 ? ? ? ? ? ?
    "mbind", // man/ cs/ 0x112 unsigned long start unsigned long len unsigned long mode const unsigned long *nmask unsigned long maxnode unsigned flags
    "get_mempolicy", // man/ cs/ 0x113 int *policy unsigned long *nmask unsigned long maxnode unsigned long addr unsigned long flags -
    "set_mempolicy", // man/ cs/ 0x114 int mode const unsigned long *nmask unsigned long maxnode - - -
    "mq_open", // man/ cs/ 0x115 const char *name int oflag umode_t mode struct mq_attr *attr - -
    "mq_unlink", // man/ cs/ 0x116 const char *name - - - - -
    "mq_timedsend", // man/ cs/ 0x117 mqd_t mqdes const char *msg_ptr size_t msg_len unsigned int msg_prio const struct __kernel_timespec *abs_timeout -
    "mq_timedreceive", // man/ cs/ 0x118 mqd_t mqdes char *msg_ptr size_t msg_len unsigned int *msg_prio const struct __kernel_timespec *abs_timeout -
    "mq_notify", // man/ cs/ 0x119 mqd_t mqdes const struct sigevent *notification - - - -
    "mq_getsetattr", // man/ cs/ 0x11a mqd_t mqdes const struct mq_attr *mqstat struct mq_attr *omqstat - - -
    "kexec_load", // man/ cs/ 0x11b unsigned long entry unsigned long nr_segments struct kexec_segment *segments unsigned long flags - -
    "waitid", // man/ cs/ 0x11c int which pid_t pid struct siginfo *infop int options struct rusage *ru -
    "not", // implemented  0x11d
    "add_key", // man/ cs/ 0x11e const char *_type const char *_description const void *_payload size_t plen key_serial_t destringid -
    "request_key", // man/ cs/ 0x11f const char *_type const char *_description const char *_callout_info key_serial_t destringid - -
    "keyctl", // man/ cs/ 0x120 int cmd unsigned long arg2 unsigned long arg3 unsigned long arg4 unsigned long arg5 -
    "ioprio_set", // man/ cs/ 0x121 int which int who int ioprio - - -
    "ioprio_get", // man/ cs/ 0x122 int which int who - - - -
    "inotify_init", // man/ cs/ 0x123 - - - - - -
    "inotify_add_watch", // man/ cs/ 0x124 int fd const char *path u32 mask - - -
    "inotify_rm_watch", // man/ cs/ 0x125 int fd __s32 wd - - - -
    "migrate_pages", // man/ cs/ 0x126 pid_t pid unsigned long maxnode const unsigned long *from const unsigned long *to - -
    "openat", // man/ cs/ 0x127 int dfd const char *filename int flags umode_t mode - -
    "mkdirat", // man/ cs/ 0x128 int dfd const char * pathname umode_t mode - - -
    "mknodat", // man/ cs/ 0x129 int dfd const char * filename umode_t mode unsigned dev - -
    "fchownat", // man/ cs/ 0x12a int dfd const char *filename uid_t user gid_t group int flag -
    "futimesat", // man/ cs/ 0x12b int dfd const char *filename struct timeval *utimes - - -
    "fstatat64", // man/ cs/ 0x12c int dfd const char *filename struct stat64 *statbuf int flag - -
    "unlinkat", // man/ cs/ 0x12d int dfd const char * pathname int flag - - -
    "renameat", // man/ cs/ 0x12e int olddfd const char * oldname int newdfd const char * newname - -
    "linkat", // man/ cs/ 0x12f int olddfd const char *oldname int newdfd const char *newname int flags -
    "symlinkat", // man/ cs/ 0x130 const char * oldname int newdfd const char * newname - - -
    "readlinkat", // man/ cs/ 0x131 int dfd const char *path char *buf int bufsiz - -
    "fchmodat", // man/ cs/ 0x132 int dfd const char * filename umode_t mode - - -
    "faccessat", // man/ cs/ 0x133 int dfd const char *filename int mode - - -
    "pselect6", // man/ cs/ 0x134 int fd_set * fd_set * fd_set * struct __kernel_timespec * void *
    "ppoll", // man/ cs/ 0x135 struct pollfd * unsigned int struct __kernel_timespec * const sigset_t * size_t -
    "unshare", // man/ cs/ 0x136 unsigned long unshare_flags - - - - -
    "set_robust_list", // man/ cs/ 0x137 struct robust_list_head *head size_t len - - - -
    "get_robust_list", // man/ cs/ 0x138 int pid struct robust_list_head * *head_ptr size_t *len_ptr - - -
    "splice", // man/ cs/ 0x139 int fd_in loff_t *off_in int fd_out loff_t *off_out size_t len unsigned int flags
    "sync_file_range", // man/ cs/ 0x13a int fd loff_t offset loff_t nbytes unsigned int flags - -
    "tee", // man/ cs/ 0x13b int fdin int fdout size_t len unsigned int flags - -
    "vmsplice", // man/ cs/ 0x13c int fd const struct iovec *iov unsigned long nr_segs unsigned int flags - -
    "move_pages", // man/ cs/ 0x13d pid_t pid unsigned long nr_pages const void * *pages const int *nodes int *status int flags
    "getcpu", // man/ cs/ 0x13e unsigned *cpu unsigned *node struct getcpu_cache *cache - - -
    "epoll_pwait", // man/ cs/ 0x13f int epfd struct epoll_event *events int maxevents int timeout const sigset_t *sigmask size_t sigsetsize
    "utimensat", // man/ cs/ 0x140 int dfd const char *filename struct __kernel_timespec *utimes int flags - -
    "signalfd", // man/ cs/ 0x141 int ufd sigset_t *user_mask size_t sizemask - - -
    "timerfd_create", // man/ cs/ 0x142 int clockid int flags - - - -
    "eventfd", // man/ cs/ 0x143 unsigned int count - - - - -
    "fallocate", // man/ cs/ 0x144 int fd int mode loff_t offset loff_t len - -
    "timerfd_settime", // man/ cs/ 0x145 int ufd int flags const struct __kernel_itimerspec *utmr struct __kernel_itimerspec *otmr - -
    "timerfd_gettime", // man/ cs/ 0x146 int ufd struct __kernel_itimerspec *otmr - - - -
    "signalfd4", // man/ cs/ 0x147 int ufd sigset_t *user_mask size_t sizemask int flags - -
    "eventfd2", // man/ cs/ 0x148 unsigned int count int flags - - - -
    "epoll_create1", // man/ cs/ 0x149 int flags - - - - -
    "dup3", // man/ cs/ 0x14a unsigned int oldfd unsigned int newfd int flags - - -
    "pipe2", // man/ cs/ 0x14b int *fildes int flags - - - -
    "inotify_init1", // man/ cs/ 0x14c int flags - - - - -
    "preadv", // man/ cs/ 0x14d unsigned long fd const struct iovec *vec unsigned long vlen unsigned long pos_l unsigned long pos_h -
    "pwritev", // man/ cs/ 0x14e unsigned long fd const struct iovec *vec unsigned long vlen unsigned long pos_l unsigned long pos_h -
    "rt_tgsigqueueinfo", // man/ cs/ 0x14f pid_t tgid pid_t pid int sig siginfo_t *uinfo - -
    "perf_event_open", // man/ cs/ 0x150 struct perf_event_attr *attr_uptr pid_t pid int cpu int group_fd unsigned long flags -
    "recvmmsg", // man/ cs/ 0x151 int fd struct mmsghdr *msg unsigned int vlen unsigned flags struct __kernel_timespec *timeout -
    "fanotify_init", // man/ cs/ 0x152 unsigned int flags unsigned int event_f_flags - - - -
    "fanotify_mark", // man/ cs/ 0x153 int fanotify_fd unsigned int flags u64 mask int fd const char *pathname -
    "prlimit64", // man/ cs/ 0x154 pid_t pid unsigned int resource const struct rlimit64 *new_rlim struct rlimit64 *old_rlim - -
    "name_to_handle_at", // man/ cs/ 0x155 int dfd const char *name struct file_handle *handle int *mnt_id int flag -
    "open_by_handle_at", // man/ cs/ 0x156 int mountdirfd struct file_handle *handle int flags - - -
    "clock_adjtime", // man/ cs/ 0x157 clockid_t which_clock struct __kernel_timex *tx - - - -
    "syncfs", // man/ cs/ 0x158 int fd - - - - -
    "sendmmsg", // man/ cs/ 0x159 int fd struct mmsghdr *msg unsigned int vlen unsigned flags - -
    "setns", // man/ cs/ 0x15a int fd int nstype - - - -
    "process_vm_readv", // man/ cs/ 0x15b pid_t pid const struct iovec *lvec unsigned long liovcnt const struct iovec *rvec unsigned long riovcnt unsigned long flags
    "process_vm_writev", // man/ cs/ 0x15c pid_t pid const struct iovec *lvec unsigned long liovcnt const struct iovec *rvec unsigned long riovcnt unsigned long flags
    "kcmp", // man/ cs/ 0x15d pid_t pid1 pid_t pid2 int type unsigned long idx1 unsigned long idx2 -
    "finit_module", // man/ cs/ 0x15e int fd const char *uargs int flags - - -
    "sched_setattr", // man/ cs/ 0x15f pid_t pid struct sched_attr *attr unsigned int flags - - -
    "sched_getattr", // man/ cs/ 0x160 pid_t pid struct sched_attr *attr unsigned int size unsigned int flags - -
    "renameat2", // man/ cs/ 0x161 int olddfd const char *oldname int newdfd const char *newname unsigned int flags -
    "seccomp", // man/ cs/ 0x162 unsigned int op unsigned int flags void *uargs - - -
    "getrandom", // man/ cs/ 0x163 char *buf size_t count unsigned int flags - - -
    "memfd_create", // man/ cs/ 0x164 const char *uname_ptr unsigned int flags - - - -
    "bpf", // man/ cs/ 0x165 int cmd union bpf_attr *attr unsigned int size - - -
    "execveat", // man/ cs/ 0x166 int dfd const char *filename const char *const *argv const char *const *envp int flags -
    "socket", // man/ cs/ 0x167 int int int - - -
    "socketpair", // man/ cs/ 0x168 int int int int * - -
    "bind", // man/ cs/ 0x169 int struct sockaddr * int - - -
    "connect", // man/ cs/ 0x16a int struct sockaddr * int - - -
    "listen", // man/ cs/ 0x16b int int - - - -
    "accept4", // man/ cs/ 0x16c int struct sockaddr * int * int - -
    "getsockopt", // man/ cs/ 0x16d int fd int level int optname char *optval int *optlen -
    "setsockopt", // man/ cs/ 0x16e int fd int level int optname char *optval int optlen -
    "getsockname", // man/ cs/ 0x16f int struct sockaddr * int * - - -
    "getpeername", // man/ cs/ 0x170 int struct sockaddr * int * - - -
    "sendto", // man/ cs/ 0x171 int void * size_t unsigned struct sockaddr * int
    "sendmsg", // man/ cs/ 0x172 int fd struct user_msghdr *msg unsigned flags - - -
    "recvfrom", // man/ cs/ 0x173 int void * size_t unsigned struct sockaddr * int *
    "recvmsg", // man/ cs/ 0x174 int fd struct user_msghdr *msg unsigned flags - - -
    "shutdown", // man/ cs/ 0x175 int int - - - -
    "userfaultfd", // man/ cs/ 0x176 int flags - - - - -
    "membarrier", // man/ cs/ 0x177 int cmd int flags - - - -
    "mlock2", // man/ cs/ 0x178 unsigned long start size_t len int flags - - -
    "copy_file_range", // man/ cs/ 0x179 int fd_in loff_t *off_in int fd_out loff_t *off_out size_t len unsigned int flags
    "preadv2", // man/ cs/ 0x17a unsigned long fd const struct iovec *vec unsigned long vlen unsigned long pos_l unsigned long pos_h rwf_t flags
    "pwritev2", // man/ cs/ 0x17b unsigned long fd const struct iovec *vec unsigned long vlen unsigned long pos_l unsigned long pos_h rwf_t flags
    "pkey_mprotect", // man/ cs/ 0x17c unsigned long start size_t len unsigned long prot int pkey - -
    "pkey_alloc", // man/ cs/ 0x17d unsigned long flags unsigned long init_val - - - -
    "pkey_free", // man/ cs/ 0x17e int pkey - - - - -
    "statx", // man/ cs/ 0x17f int dfd const char *path unsigned flags unsigned mask struct statx *buffer -
    "arch_prctl", // man/ cs/ 0x180 ? ? ? ? ? ?
};
