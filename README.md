Automation wrapper for iozone

Description:
  
Location of underlying workload:

Packages required: gcc,bc

To run:
```
[root@hawkeye ~]# git clone https://github.com/redhat-performance/iozone-wrapper
[root@hawkeye ~]# iozone-wrapper/iozone/iozone_run.sh

  --all_test: executes all the predefined tests, which currently are
    incache, incache_fsync, incache_mmap, incache_fsync, incache_mmap
    out_of_cach dio.
  --devices_to_use <dev_a, dev_b>: comma separate list of devices to create
    the filesystem on. Default none.
  --dio_filelimit <MB>: maximum size the file may be when doing directio.
    default is 4096
  --directio: run test as directio
  --eatmem: Run the program eatmem to reduce memory usage for out-of-cache
    Disabled by default
  --eatmem_out_of_cache_start: Starting amount of memory to be consumed.
    Default is 128
  --eatmem_out_of_cache_end: End amount of memory to be consumed.
    Default is 1024
  --file_count_list <1,2....>: Comma separated list of how many files to be
    created on each filesystem. Default is 1.
  --filesystems <xfs,ext4,ext3,gfs,gfs2>: comma separted list of filesystem
    types to test. Default is xfs
  --help: usage message
  --incache: run the test so the files fit in cache.
  --max_file_size <x>:  Total size of all files created.  Size is in G.
    Default is 10
  --mount_location <dir>:  Directory where all mount directories are to
    be created.  Default is /iozone/iozone
  --incache_filelimit <xMB>:  Maximum file size to use for in cache test.
    Default is 4096.
  --iozone_kit <kit>:  Which izone kit version to pull.
    Default is iozone3_490
  --outofcache: Run the test so the files are out of cache.  Default is not to
  --outcache_multiplier <x>: Multiplier for max out of cache file size
    compared to incache size.  Default is 4.
  --results_dir <dir>:  Where to place the results from the run.  The default
   is the <current directory>/results
  --swap: Turn off swap during testing, and reenable it when done.
  --syncedincache: Run the test incache with fsync
  --test_prefix <string>:  Prefix to add to the results file.
    Default is test_run
  --tools_git: Pointer to the test_tools git.  Default is https://github.com/redhat-performance/test_tools-wrappers.  Top directory is always test_tools
  --tunecompare: perform tune comparison, default is off
    Values tuning:
		vm.dirty_ratio: 85
		vm.dirty_background_ratio: 80
		vm.swappiness: 0
  --verbose: Set the shell verbose flag
======================================================================
iozone options
======================================================================
  --auto: operate in auto mode
  --iozone_umount: remount between tests.  Only 1 mount point supported.
    Defaul is no
  --page_size <x>: Minimum file size in kBytes for auto mode. Default is 1024
  --quick <x>: Factor used to speed-up the runs.
   incache_memory=incache_memory/do_quick.  Default is 1
  --test_type: Comma separated list of tests to run.  Default is 0,1

General options
  --home_parent <value>: Our parent home directory.  If not set, defaults to current working directory.
  --host_config <value>: default is the current host name.
  --iterations <value>: Number of times to run the test, defaults to 1.
  --pbench: use pbench-user-benchmark and place information into pbench, defaults to do not use.
  --pbench_user <value>: user who started everything. Defaults to the current user.
  --pbench_copy: Copy the pbench data, not move it.
  --pbench_stats: What stats to gather. Defaults to all stats.
  --run_label: the label to associate with the pbench run. No default setting.
  --run_user: user that is actually running the test on the test system. Defaults to user running wrapper.
  --sys_type: Type of system working with, aws, azure, hostname.  Defaults to hostname.
  --sysname: name of the system running, used in determining config files.  Defaults to hostname.
  --tuned_setting: used in naming the tar file, default for RHEL is the current active tuned.  For non
    RHEL systems, default is none.
  --usage: this usage message.

Example usage
  Test: incache, using iozone tests 0 through 12
  results: current directory/testing.
  filesys: xfs
  Mount location: /iozone/iozone
  Number files per mount point: 1 and 2
  Test prefix: io_test_all
  Total file size:  Default of 64G
  Disk to use: /dev/nvme3n1 and /dev/nvme2n1
  iozone_run.sh --incache --results_dir /home/ec2-user/dave --mount_location /iozone/iozone
   --devices_to_use /dev/nvme3n1,/dev/nvme2n1 --filesys xfs --file_count_list 1,2
   --test_prefix io_test_all --max_file_size 64
   --test_type 0,1,2,3,4,5,6,7,8,9,10,11,12

```

Note: The script does not install pbench for you.  You need to do that manually.
