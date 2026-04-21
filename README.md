# Iozone Benchmark Wrapper

## Description

This wrapper facilitates the automated execution of the Iozone filesystem benchmark. Iozone is an industry-standard tool for measuring filesystem I/O performance across a wide range of operations including sequential reads/writes, random I/O, and memory-mapped I/O.

The wrapper provides:
- Automated Iozone download, build, and execution.
- Multiple test modes: in-cache, out-of-cache, direct I/O, fsync, and mmap.
- Support for multiple filesystems (XFS, ext4, ext3, GFS, GFS2).
- Support for x86_64, i386, s390/s390x, and aarch64 architectures.
- Automatic memory-based problem sizing for in-cache and out-of-cache tests.
- Multi-iteration runs with automatic averaging and comparison.
- Result collection, processing, and verification.
- CSV and JSON output formats.
- System configuration metadata capture.
- Integration with test_tools framework.
- Optional Performance Co-Pilot (PCP) integration.
- Optional kernel tuned parameter comparison.
- LVM and raw block device support.

## Command-Line Options

```
Test Mode Options (all enabled by default if none specified):
  --incache: Run in-cache tests.
  --incache_filelimit <MB>: Max file size for in-cache tests (default: 4096 MB).
  --syncedincache: Run in-cache tests with fsync.
  --mmapincache: Run in-cache tests with mmap.
  --outofcache: Run out-of-cache tests.
  --directio: Run direct I/O tests.
  --dio_filelimit <MB>: Max file size for direct I/O tests (default: 4096 MB).
  --all_test: Execute all predefined tests.

Memory & Performance Tuning Options:
  --eatmem: Use the eatmem program to reduce available memory for out-of-cache testing.
  --eatmem_out_of_cache_start <MB>: Starting memory consumption for eatmem (default: 128).
  --eatmem_out_of_cache_end <MB>: Ending memory consumption for eatmem (default: 1024).
  --eatmem_free_memory <MB>: Memory to keep free when using eatmem (default: 180).
  --tunecompare: Compare default vs. tuned kernel parameters.
  --swap: Disable swap during testing, re-enable after.

File & Filesystem Options:
  --filesystems <xfs,ext4,ext3,gfs,gfs2>: Comma-separated list of filesystems to test (default: xfs).
  --devices_to_use <dev_a,dev_b,...>: Devices for filesystem creation (default: auto-detected via grab_disks).
  --mount_location <dir>: Base directory for mount points (default: /iozone/iozone).
  --file_count_list <1,2,...>: Number of files per mount point (default: 1).
  --max_file_size <GB>: Total file size for testing (default: 10 GB).
  --lvm_disk: Use LVM volumes instead of raw devices.

Iozone-Specific Options:
  --iozone_kit <kit>: Iozone package to download (default: iozone3_490).
  --auto: Use auto-mode testing instead of throughput mode.
  --page_size <KB>: Minimum file size for auto-mode (default: 1024 KB).
  --quick <factor>: Divisor for in-cache memory to speed up tests (default: 1).
  --test_type <0,1,2,...>: Iozone test types (0=write, 1=read, etc.; default: 0,1).
  --iozone_options <args>: Additional iozone arguments passed directly to the binary.
  --iozone_umount: Remount filesystem between tests.
  --outcache_multiplier <x>: Multiplier for out-of-cache max size (default: 4).

Output Options:
  --results_dir <dir>: Output directory (default: current_dir/results).
  --test_prefix <string>: Prefix for result files (default: test_run).

General test_tools options:
  --tools_git <value>: Git repo to retrieve the required tools from.
      Default: https://github.com/redhat-performance/test_tools-wrappers
  --verbose: Enable verbose shell output (set -x).
  --help / --usage: Display usage information.
```

## What the Script Does

The `iozone_run.sh` script performs the following workflow:

1. **Environment Setup**:
   - Clones the test_tools-wrappers repository if not present (default: ~/test_tools).
   - Sources error codes and general setup utilities.
   - Gathers hardware data for system characterization.

2. **Package Installation**:
   - Installs required dependencies via package_tool (gcc, make, bc, perl, wget, etc.).
   - Dependencies are defined in iozone-wrapper.json for different OS variants (RHEL, Ubuntu).

3. **System Preparation**:
   - Captures CPU info, dmesg, and BIOS info via dmidecode.
   - Detects CPU count, speeds, and NUMA topology.
   - Calculates available disk space (uses 90% of available).

4. **Binary Builds**:
   - Compiles `create_file` utility for pre-allocating sparse test files.
   - Compiles `eatmem` utility if out-of-cache memory reduction is needed.
   - Downloads and builds Iozone from source (default: iozone3_490) or uses installed system version.
   - Detects architecture for correct Iozone build target (linux-AMD64, linux-arm, linux-S390X, etc.).

5. **Memory Parameter Calculation**:
   - Detects total system memory from /proc/meminfo.
   - Calculates in-cache file size as highest power of 2 fitting in available memory.
   - Computes out-of-cache range based on memory and multiplier settings.
   - Applies direct I/O file size limits.

6. **Filesystem Setup**:
   - For each configured filesystem type, obtains available block devices.
   - Creates LVM volumes (if `--lvm_disk`) or formats raw devices directly.
   - Mounts filesystems at configured mount points.

7. **Test Execution**:
   - Drops page caches before each test.
   - For each enabled test mode (in-cache, in-cache+fsync, in-cache+mmap, direct I/O, out-of-cache):
     - Optionally launches eatmem process to reduce available memory.
     - Runs Iozone pinned to CPU 0 via taskset.
     - Performs analysis on results via analysis-iozone.pl.
   - Optionally compares default vs. tuned kernel parameters (if `--tunecompare`).
   - Repeats for configured number of iterations.

8. **Data Collection**:
   - Captures system configuration (CPU, memory, NUMA topology, kernel version).
   - Records test parameters and mode configurations.
   - Logs timestamps for each filesystem test run.
   - Optionally records PCP performance data.

9. **Multi-Run Processing** (if iterations > 1):
   - Averages results across all runs (average.sh, average_table.pl).
   - Compares each individual run against the average (compare.sh).
   - Flags regressions >5% and improvements >5%.

10. **Result Processing**:
    - Extracts performance metrics from analysis files.
    - Generates CSV files with filesystem, test mode, and performance data.
    - Creates JSON output via csv_to_json.
    - Optionally sends results to PCP archive via results2pcp_multiple.

11. **Verification**:
    - Validates results against Pydantic schema (results_iozone_auto_schema.py or results_iozone_tput_schema.py).
    - Ensures all required fields are present and valid.
    - Uses csv_to_json and verify_results from test_tools.

12. **Output**:
    - Creates results directory with raw output, processed CSV/JSON, and system metadata.
    - Saves all raw Iozone output files, analysis logs, and configuration dumps.
    - Optionally saves PCP performance data.
    - Archives results to configured storage location via save_results.

## Dependencies

Location of underlying workload: Downloaded from http://www.iozone.org/src/current/ (default: iozone3_490).

**General packages required**: bc, gcc, git, make, wget, unzip, zip

**Additional packages for platform-specific builds**:
- RHEL/Fedora: perf, perl-Math-BigInt, perl-Math-BigRat.
- Ubuntu/Debian: linux-tools-generic, libmath-bigint-perl.

To run:
```bash
git clone https://github.com/redhat-performance/iozone-wrapper
cd iozone-wrapper/iozone
./iozone_run.sh
```

The script requires root privileges. It will automatically detect your CPU architecture and build Iozone for the correct target.

## The Iozone Benchmark

Iozone is a filesystem benchmark tool that generates and measures a variety of file operations. It tests I/O performance for the following operations:

- **Initial Write**: First write to a new file.
- **Rewrite**: Overwriting an existing file.
- **Read**: Sequential read of a file.
- **Re-read**: Second sequential read (may benefit from caching).
- **Random Read**: Reading random positions within a file.
- **Random Write**: Writing to random positions within a file.
- **Backward Read**: Reading a file in reverse.
- **Record Rewrite**: Rewriting specific records within a file.
- **Stride Read**: Reading with a stride pattern.
- **Fwrite/Frewrite**: Write/rewrite using fwrite() library calls.
- **Fread/Freread**: Read/re-read using fread() library calls.

### Test Modes

1. **In-Cache**: File sizes fit within system memory. Tests filesystem and cache performance.
2. **In-Cache + fsync**: Same as in-cache but forces data to disk after writes.
3. **In-Cache + mmap**: Uses memory-mapped I/O for file operations.
4. **Direct I/O**: Bypasses the OS page cache, testing raw device performance.
5. **Out-of-Cache**: File sizes exceed available memory, forcing disk I/O.

### Performance Metrics

- **Auto mode**: Reports throughput in KB/s for each operation across combinations of record sizes and file sizes. The wrapper computes geometric means across all sizes to produce aggregate metrics.
- **Throughput mode**: Reports aggregate throughput with 1, 2, and 4 concurrent processes for each operation.

## Output Files

The results directory contains:

- **results_iozone.csv**: CSV file with filesystem, test mode, and performance metrics
- **results_iozone.json**: Validated JSON output
- **Run_N/\<filesystem\>/**: Per-iteration raw Iozone output and analysis logs
  - `iozone_<prefix>_<mode>_default.iozone`: Raw Iozone output
  - `iozone_<mode>_default_analysis+rawdata.log`: Analysis with geometric means
- **Average/**: Averaged results across all iterations (if iterations > 1)
- **Compare/**: Comparison of each run against the average (if iterations > 1)
- **config/**: System configuration snapshots (cpuinfo, dmesg, dmidecode, NUMA layout)
- **build-run.log**: Compilation and test execution log
- **meta_data.yml**: System metadata (CPU, memory, kernel version)
- **test_results_report**: PASS/FAIL/WARN status marker
- **PCP data** (if --use_pcp option used): Performance Co-Pilot monitoring data

## Examples

### Basic run with defaults
```bash
./iozone_run.sh
```
This runs with:
- All test modes enabled (in-cache, in-cache+fsync, in-cache+mmap, direct I/O, out-of-cache).
- XFS filesystem.
- Automatic device detection.
- 1 iteration.
- Automatic memory-based problem sizing.

### Run only in-cache tests
```bash
./iozone_run.sh --incache
```
Tests only in-cache performance where file sizes fit within system memory.

### Run with direct I/O only
```bash
./iozone_run.sh --directio
```
Bypasses the OS page cache to test raw device performance.

### Run on specific filesystems
```bash
./iozone_run.sh --filesystems xfs,ext4
```
Tests both XFS and ext4 filesystems.

### Run on specific devices
```bash
./iozone_run.sh --devices_to_use /dev/sdb,/dev/sdc
```
Uses specified block devices instead of auto-detection.

### Run with LVM
```bash
./iozone_run.sh --lvm_disk --devices_to_use /dev/sdb
```
Creates an LVM volume on the specified device for testing.

### Run multiple iterations
```bash
./iozone_run.sh --iterations 3
```
Runs 3 iterations and generates averaged results and per-run comparisons.

### Run in auto mode
```bash
./iozone_run.sh --auto
```
Uses Iozone auto mode, which tests across a matrix of file sizes and record sizes.

### Run with reduced memory (out-of-cache with eatmem)
```bash
./iozone_run.sh --outofcache --eatmem
```
Reduces available memory to force out-of-cache I/O patterns.

### Run quick in-cache test
```bash
./iozone_run.sh --incache --quick 4
```
Divides the in-cache memory size by 4 for faster testing.

### Compare default vs. tuned kernel parameters
```bash
./iozone_run.sh --tunecompare
```
Runs tests with both default and tuned kernel settings, then compares results.

### Run with PCP monitoring
```bash
./iozone_run.sh --use_pcp
```
Collects Performance Co-Pilot data during the run.

### Combination example
```bash
./iozone_run.sh --incache --directio --filesystems xfs,ext4 --iterations 3 --use_pcp
```
Runs in-cache and direct I/O tests on XFS and ext4, with 3 iterations and PCP monitoring.

## How Memory Sizing Works

The script automatically calculates file sizes for each test mode based on system memory:

### In-Cache File Size
1. Detects total system memory from /proc/meminfo.
2. Calculates the highest power of 2 that fits within available memory:
   ```
   file_size = 2^floor(log2(available_memory))
   ```
3. Applies the `--quick` divisor if specified (default: 1).
4. Caps at `--incache_filelimit` (default: 4096 MB).

### Out-of-Cache File Size
1. Starts at `--eatmem_out_of_cache_start` (default: 128 MB).
2. Ends at `--eatmem_out_of_cache_end` (default: 1024 MB).
3. Multiplied by `--outcache_multiplier` (default: 4) for maximum test size.
4. If `--eatmem` is enabled, reduces available memory to force disk I/O.

### Direct I/O File Size
- Capped at `--dio_filelimit` (default: 4096 MB).
- Uses the same base calculations as in-cache sizing.

## Return Codes

The script uses standardized error codes from test_tools error_codes:
- **0**: Success
- **1**: Generic error (directory creation, build failures, disk space errors).
- **101**: Git clone failure
- **E_GENERAL**: General execution errors (package installation, build failures, test execution failures, validation failures).

Exit codes indicate specific failure points for automated testing workflows. The `test_results_report` file in the results directory contains the overall test status (PASS, FAIL, or WARN).

## Notes

### Architecture Support
- **x86_64**: Built as linux-AMD64.
- **i386/i486/i586/i686**: Built as linux.
- **aarch64**: Built as linux-arm.
- **s390/s390x**: Built as linux-S390 or linux-S390X.

### Filesystem Support
- **XFS**: Default filesystem. Well-suited for large files and high throughput.
- **ext4/ext3**: Supported for comparison testing.
- **GFS/GFS2**: Supported for cluster filesystem testing (requires cluster setup).

### Root Privileges
The script requires root privileges to create filesystems, mount devices, drop page caches, and modify kernel parameters.

### Memory Considerations
- In-cache tests size files to fit within system memory, testing cache and filesystem performance.
- Out-of-cache tests deliberately exceed available memory, forcing actual disk I/O.
- The `--eatmem` option uses a helper program that allocates memory to further reduce what is available to the filesystem cache.
- The `--quick` option can significantly reduce in-cache test time by using smaller file sizes.

### Multi-Run Analysis
- When running multiple iterations, the wrapper automatically computes averaged results.
- Each individual run is compared against the average, with regressions >5% and improvements >5% flagged.
- Geometric mean is used to aggregate performance across file sizes and record sizes.

### Kernel Tuning Comparison
- The `--tunecompare` option runs each test twice: once with default kernel parameters and once with tuned parameters.
- This is useful for evaluating the impact of sysctl tuning on I/O performance.

### Troubleshooting
- If Iozone fails to build, verify that gcc and make are installed.
- If filesystem creation fails, verify that the specified devices are available and not in use.
- The script requires root privileges; running as non-root will fail immediately.
- Use `--verbose` to enable shell tracing (set -x) for debugging.
- Check `build-run.log` in the results directory for compilation and execution details.
- If performance is unexpectedly low, check that no other I/O-intensive workloads are running.
- Use `--use_pcp` to collect detailed performance counters for analysis.
