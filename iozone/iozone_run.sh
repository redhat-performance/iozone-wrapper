#!/bin/bash
#
#                         License
#
# Copyright (C) 2021  David Valin dvalin@redhat.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# Automate the iozone benchmark.
#

exit_out()
{
	echo $1
	exit $2
}

make_dir()
{
	if [[ ! -d $1 ]]; then
		mkdir -p $1
		if [ $? -ne 0 ]; then
			exit_out "Failed to create directory $1" 1
		fi
	fi
}

curdir=`pwd`
if [[ $0 == "./"* ]]; then
	chars=`echo $0 | awk -v RS='/' 'END{print NR-1}'`
	if [[ $chars == 1 ]]; then
		run_dir=`pwd`
	else
		run_dir=`echo $0 | cut -d'/' -f 1-${chars} | cut -d'.' -f2-`
		run_dir="${curdir}${run_dir}"
	fi
else
	chars=`echo $0 | awk -v RS='/' 'END{print NR-1}'`
	run_dir=`echo $0 | cut -d'/' -f 1-${chars}`
fi


arguments="$@"
test_name="iozone"
iozone_version="v1.0"


# Gather hardware information
${curdir}/test_tools/gather_data ${curdir}

if [ ! -f "/tmp/${test_name}.out" ]; then
        command="${0} $@"
        echo $command
        $command &> /tmp/${test_name}.out
	rtc=$?
	if [[ -f /tmp/${test_name}.out ]]; then
        	cat /tmp/${test_name}.out
        	rm /tmp/${test_name}.out
	fi
        exit $?
fi

exec_name=$0
# Default settings

lvm_disk=0
file_count_list="1"
fstype=""
all_test=0
auto=0
iozone_exe=""
eatmem_exe=""
do_tuned=0
test_type="0 1"
run_results=""
max_cpu=0
cpu_speed_list=""
number_cpus=0
dmidecode_file=""
data_dir=""
results_dir=`pwd`/results
devices_to_use="grab_disks"
out_dir=""
mount_location="/iozone/iozone"
page_size=1024
total_memory=0
memory4_pagecache=0
incache_memory=0
out_of_cache_end=0
out_of_cache_start=0
numa_nodes=0
data_lun=""
data_mnt_pt=""
readahead=""
iozone_actual_fs_types=""
iozone_options=""
max_file_size=10
threads=1
test_prefix="test_run"
mount_index=0
mount_list=""
iozone_output_file=""
filesys_to_use=""
resultdir=""

				### NOTE iozone ROUNDS TO NEXT LOWEST POWER OF 2. ###
outcache_multiplier=4		# Multiplier for max out of cache file size compared to incache size.
incache_filelimit=4096		# Maximum file size to use for in cache test.
dio_filelimit=4096		# MAx limit for direct i/o file size in MB's
filesystems="xfs"
eatmem_out_of_cache_start=128	# Start filesize for iozone out of cache when eatmem is activated.
eatmem_out_of_cache_end=1024	# Stop filesize for iozone out of cache when eatmem is activated.
eatmem_free_memory=180		# Memory left free for iozone when eatmem is activated.

local_watchdog_file=`pwd`/LOCALWATCHDOG

# Set for future reference.
#
configdir=$results_dir/config
buildrunlog=${results_dir}/build-run.log

arch=`arch | sed 's/i686/i386/'`

testing_dir=`pwd`
iozone_kit=iozone3_490

do_incache=0
do_incache_fsync=0
do_incache_mmap=0
do_out_of_cache=0
do_dio=0
do_eat_mem=0;	    #Program eatmem to reduce memory usage for out-of-cache run is disabled by default
do_quick=1;	    #Factor used to speed-up the runs. (( incache_memory=incache_memory/do_quick ))
do_verbose=0;
do_iozone_umount=0;   #Use iozone -U option to umount/mount HDD between different tests. See iozone documentation for more details.

#
# TUNING KNOBS USED FOR TUNING MODE
#
vm_dirty_ratio="vm.dirty_ratio"
default_vmdirtyratio=""
tuned_vm_dirty_ratio="85"

vm_dirty_background_ratio="vm.dirty_background_ratio"
default_vmdirty_bg_ratio=""
tuned_vm_dirty_background_ratio="80"

swappiness="vm.swappiness"
default_swappiness=""
tuined_sappiness="0"

swap_disabled=0

modes2run=0;
args_fs_types=""

tools_git=https://github.com/redhat-performance/test_tools-wrappers
#
# Config info
#

#
# Help message
#
usage()
{
	echo "Wrapper specific options"
	echo "======================================================================"
	echo "all_test: executes all the predefined tests, which currently are"
	echo "    incache, incache_fsync, incache_mmap, out_of_cache dio"
	echo "devices_to_use <dev_a, dev_b>: comma separate list of devices to create"
	echo "   the filesystem on. Default none."
	echo "dio_filelimit <MB>: maximun size the file may be when doing directio."
	echo "   default is 4096"
	echo "directio: run test as directio"
	echo "eatmem: Run the program eatmem to reduce memory usage for out-of-cache"
	echo "    Disabled by default"
	echo "eatmem_out_of_cache_start: Starting amount of memory to be consumed."
	echo "    Default is 128"
	echo "eatmem_out_of_cache_end: End amount of memory to be consumed."
	echo "    Default is 1024"
	echo "file_count_list <1,2....>: Comma separated list of how many files to be"
	echo "    created on each filesystem. Default is 1."
	echo "filesystems <xfs,ext4,ext3,gfs,gfs2>: comma separted list of filesystem"
	echo "    types to test. Default is xfs"
	echo "help: usage message"
	echo "incache: run the test so the files fit in cache."
	echo "max_file_size <x>:  Total size of all files created.  Size is in G."
	echo "    Default is 10"
	echo "mount_location <dir>:  Directory where all mount directories are to"
	echo "    be created.  Default is /iozone/iozone"
	echo "incache_filelimit <xMB>:  Maximum file size to use for in cache test."
	echo "    Default is 4096."
	echo "iozone_kit <kit>:  Which izone kit version to pull."
	echo "    Default is ${iozone_kit}"
	echo "outofcache: Run the test so the files are out of cache.  Default is not to"
	echo "outcache_multiplier <x>: Multiplier for max out of cache file size"
	echo "    compared to incache size.  Default is 4."
	echo "results_dir <dir>:  Where to place the results from the run.  The default"
	echo "   is the <current directory>/results"
	echo "swap: Turn off swap during testing, and reenable it when done."
	echo "syncedincache: Run the test in cache with fsync"
	echo "test_prefix <string>:  Prefix to add to the results file."
	echo "   Default is test_run"
	echo "tools_git: Pointer to the test_tools git.  Default is ${tools_git}.  Top directory is always test_tools"
	echo "tunecompare: perform tune comparison, default is off"
	echo "   Values tuning:"
	echo "		vm.dirty_ratio: 85"
	echo "		vm.dirty_background_ratio: 80"
	echo "		vm.swappiness: 0"
	echo "verbose: Set the shell verbose flag"
	echo "======================================================================"
	echo "iozone options"
	echo "======================================================================"
	echo "auto: operate in auto mode"
	echo "iozone_umount: remount between tests.  Only 1 mount point supported."
	echo "    Defaul is no"
	echo "page_size <x>: Minimum file size in kBytes for auto mode. Default is 1024"
	echo "quick <x>: Factor used to speed-up the runs."
	echo "   incache_memory=incache_memory/do_quick.  Default is 1"
	echo "test_type: Comma separated list of tests to run.  Default is 0,1"
	echo "======================================================================"
	echo "Examples"
	echo "======================================================================"
	echo "Test: incache, using iozone tests 0 then 1"
	echo "results: current directory/testing."
	echo "filesys: xfs"
	echo "Mount location: /iozone/iozone"
	echo "Disk to use: /dev/nvme3n1"
	echo "number of files: 1,2 and 4"
	echo "Total file size:  Default of 10G"
	echo "${exec_file} --incache --results_dir `pwd`/testing --test_type 0,1"
	echo "   --mount_location /iozone/iozone0 --devices_to_use /dev/nvme3n1"
	echo "   --filesys xfs --file_count_list 1,2,4 --auto"
	echo ""
	echo "Test: incache, using iozone tests 0 through 12"
	echo "results: current directory/testing."
	echo "filesys: xfs"
	echo "Mount location: /iozone/iozone"
	echo "Number files per mount point: 1 and 2"
	echo "Test prefix: io_test_all"
	echo "Total file size:  Default of 64G"
	echo "Disk to use: /dev/nvme3n1 and /dev/nvme2n1"
	echo "${exec_file} --incache --results_dir `pwd`/dave --mount_location /iozone/iozone"
	echo "   --devices_to_use /dev/nvme3n1,/dev/nvme2n1 --filesys xfs --file_count_list 1,2"
	echo "   --test_prefix io_test_all --max_file_size 64"
	echo "   --test_type 0,1,2,3,4,5,6,7,8,9,10,11,12"
	source test_tools/general_setup --usage
}

#
# Clone the repo that contains the common code and tools
#
report_usage=0
found=0
for arg in "$@"; do
	if [ $found -eq 1 ]; then
		tools_git=$arg
		break;
	fi
	if [[ $arg == "--tools_git" ]]; then
		found=1
	fi

	#
	# We do the usage check here, as we do not want to be calling
	# the common parsers then checking for usage here.  Doing so will
	# result in the script exiting with out giving the test options.
	#
	if [[ $arg == "--usage" ]]; then
		report_usage=1
	fi
done

#
# Check to see if the test tools directory exists.  If it does, we do not need to
# clone the repo.
#
if [ ! -d "test_tools" ]; then
        git clone $tools_git test_tools
        if [ $? -ne 0 ]; then
                exit_out "pulling git $tools_git failed." 1
        fi
fi

if [ $report_usage -eq 1 ]; then
	usage $0
fi

# Variables set by general setup.
#
# TOOLS_BIN: points to the tool directory
# to_home_root: home directory
# to_configuration: configuration information
# to_times_to_run: number of times to run the test
# to_pbench: Run the test via pbench
# to_puser: User running pbench
# to_run_label: Label for the run
# to_user: User on the test system running the test
# to_sys_type: for results info, basically aws, azure or local
# to_sysname: name of the system
# to_tuned_setting: tuned setting
#

source test_tools/general_setup "$@"

#
# Get processor speed info.   Report if there are multiple speeds
#
get_cpu_speed_info()
{
	# Get cpu type and speed etc.  Verify they are all running at the same speed.
	cpuspeeds=`grep "model name"  /proc/cpuinfo | sort -u | wc -l`
	if [ ${cpuspeeds} -ne 1 ]; then
		( echo ""
		  echo "CPU speeds varied ... Values below."
		  echo ""
		  grep "model name" /proc/cpuinfo | awk '{print $10}'
		  echo ""
		) >> sample_log 2>&1
	fi
	if [[ $speed_info  != "1" ]]; then
		run_results=WARN;
	fi

	temp_list=`grep "model name" /proc/cpuinfo | awk '{print $10}' |  sort -b -n -u -r`
	cpu_speed_list=""
	separ=""
	for item in $temp_list;
	do
		cpu_speed_list=${cpu_speed_list}${separ}${item}
	done
}

#
# Determine how many numa nodes we have.
#
check_for_numa()
{
	numastat >& /dev/null
	if [ $? -eq 0 ]; then
		NODES=`numastat | grep 'node[0-9]' | wc -w`
		(echo ""
		  echo "NUMA is enabled.  Policy and Hardware information below ..."
		  echo ""
		  numactl --show
		  echo ""
		  numactl --hardware
		  echo ""
		  find /sys/devices/system/node
		) > ${configdir}/NUMAlayout 2>&1
	else
		NODES=0;
	fi
	echo ${NODES}
}

#
# Prepare the system for testing.
#

prep_system()
{
	rm -f ${testing_dir}/FAILED >& /dev/null

	cp /proc/cpuinfo ${configdir}/cpuinfo

	#
	# Enable debug printing and dump memory layout
	# so dmesg can pick it up.
	#
	DMESGARG=""
	if [ `dmesg | wc -l` -eq 0 ]; then
		DMESGARG="-c"
	fi

	#
	#  Output mem statistics and report it with dmesg
	#

	echo 1 > /proc/sys/kernel/sysrq
	echo m > /proc/sysrq-trigger
	dmesg ${DMESGARG} > ${configdir}/dmesg
}

#
# Attempt to get bios firmare information
#
get_biosversion()
{
	if [ $? -eq 0 ]; then
		FIRMWARE_VERSION=`grep -A 2 "BIOS Information" ${dmidecode_file} | grep "Version" | tr -d '[	]' | sed 's/Version: //'`
		FIRMWARE_DATE=`grep -A 3 "BIOS Information" ${dmidecode_file} | grep "Release Date" | tr -d '[	]' | sed 's/Release Date: //'`
		echo "$FIRMWARE_VERSION : $FIRMWARE_DATE"
	else
		echo "unknown"
	fi
}

#
# If required build iozone.
#
retrieve_and_build_iozone()
{
	which iozone >& /dev/null
	if [ $? != 0 ]; then
		#
		# We need to build iozone. Go get the kit.
		#
		wget http://www.iozone.org/src/current/${iozone_kit}.tar
		if [ $? -ne 0 ]; then
			exit_out "wget http://www.iozone.org/src/current/${iozone_kit}.tar failed" 1
		fi
		tar xf ${iozone_kit}.tar
		#
		# cd t the source directory
		pushd ${iozone_kit}/src/current >& /dev/null
		#
		# Set the appropriate build target.
		#
		case ${arch} in
			i386|i486|i586|i686)
				build_target="linux"
			;;
			x86_64)
				build_target="linux-AMD64"
			;;
			s390)
				build_target="linux-S390"
			;;
			s390x)
				build_target="linux-S390X"
			;;
			aarch64)
				build_target="linux-arm"
			;;
			*)
				exit_out "Unknown arch ${arch}.  Cant continue" 1
			;;
		esac
		make ${build_target}  >> ${buildrunlog} 2>&1
		if [ -x "./iozone" ]; then
			cp iozone /usr/bin
		else
			exit_out "Failed to build iozone, see ${buildrunlog}" 1
		fi
		popd >& /dev/null
	fi
	iozone_exe=`which iozone`
}

#
#  build_eatmem
#
build_eatmem()
{
	pushd ${run_dir} >& /dev/null
	gcc -Wall -Os -o eatmem eatmem.c

	if [ -x "$run_dir//eatmem" ]; then
		echo "$run_dir/eatmem"
	else
		exit_out "Warning eatmem did not build, aborting" 1
	fi
	popd >& /dev/null
}

#
# Return the hightest power of 2 that's <= arg
#
get_highest_power_of_2()
{
	LIMIT=$1
	typeset -i PREV=2;
	typeset -i NEXT=${PREV};

	while [ ${NEXT} -le ${LIMIT} ]
	do
		PREV=${NEXT};
		NEXT=${NEXT}*2;
	done
	echo ${PREV};
}
#

#
# Get kernel tuning value
#
get_kernel_tune()
{
	/sbin/sysctl -n $1
}

#
# Format string for showing tuned value
#
show_default_tuned()
{
	printf "  %-47s Default:%12s   Tuned:%12s\n" $1 $2 $3
}

#
# Set tuning parameter
#
tunekernel()
{
	tune_param=$1
	shift
	tune_args="$*"

	# Get original value, then set value, then verify it got changed correctly.
	# We use the SET arg parsing to collapse whitespace to a common format.
	#
	orig_tune_val=get_kernel_tune ${tune_param}

	printf "  %-47s From:%12s   To:%12s\n" ${tune_param} ${orig_tuine_val} ${tune_args} >> ${buildrunlog}

	/sbin/sysctl -q -w ${tune_param}="${tune_args}"

	current_tune_val=`get_kernel_tune ${tune_param}`
	if [ "${current_tune_val}" != "${tune_args}" ]; then
		printf "    Warning: tuneable ${tune_params} different than what was requested.  Actually: %s\n\n" ${current_tune_val}
	fi
}

do_test()
{
	if [[ ${auto} == 1 ]]; then
		do_test_actual $1 $2 $3
	else
		for numb_files in $file_count_list;
		do
			file_list=""
			total_files=0
			for mount_pnt in $mount_list;
			do
				for count in `seq 1 $numb_files`;
				do
					file_list=${file_list}${separ}/${mount_pnt}/file_${count}
					rm /${mount_pnt}/file_${count}
					${run_dir}/create_file /${mount_pnt}/file_${count} $max_file_size
					separ=" "
					let "total_files=$total_files+1"
				done
			done
			for test_to_run in $test_type;
			do
				do_test_actual "$1" "$2" "$3" $total_files "${file_list}" "$test_to_run"
				echo File frag >> $iozone_output_file
				filefrag $file_list >> $iozone_output_file
				echo End of file frag >> $iozone_output_file
				echo ================================================ >> ${iozone_output_file}
			done
			rm -rf $file_list
		done
	fi
}
do_test_actual()
{
	compare_list=""
	# CHECK FOR EARLY LOCALWATCHDOG.  THIS STOPS SUCCESSIVE TESTS FROM STARTING
	#
	if [ -f "${local_watchdog_file}" ];then
		return;
	fi

	name_of_test=$1;
	runtest_name=$2;

	if [[ ${auto} == 1 ]]; then
		iozone_args="-az -f ${mount_pnt}/iozone-${fs} ${iozone_options} ${test_specific_args}"
	else
		iozone_args="${iozone_options} ${test_specific_args}"
	fi

	run_types="default"
	if [ $do_tuned -eq 1 ]; then
		run_types=${run_types}" tuned"
	fi

	for one_run in $run_types; do
		runtest_fq_name=${runtest_name}"_"${one_run}
		iozone_output_file=${analysis_dir}/${fs}/iozone_${test_prefix}_${runtest_fq_name}.iozone
  		iozone_analysis_file=${analysis_dir}/${fs}/iozone_${runtest_fq_name}_analysis+rawdata.log
  		if [[ -d "${mount_location}" && ${do_iozone_umount} == 1 ]]; then
			export iozone_args="-U ${data_mnt_pt} ${iozone_args}"
		fi

		(
			echo ""
			echo BEGIN ${name_of_test} '('$one_run')' run @ `date`

			#
			# If we can flush the page cache do so.
			#
			if [ -f "/proc/sys/vm/drop_caches" ]; then
				printf " Flushing and dropping page cache ... sleeping ...\n\n"
				vmstat 2 10 &
				sleep 4
				echo "Start DROP"
				# See http://www.linuxinsight.com/proc_sys_vm_drop_caches.html
				sync
				echo 3 > /proc/sys/vm/drop_caches
				wait
				echo ""
			fi

			# Setup tunings when running tuned compare mode
			#
			if [ "$one_run" == "tuned" ]; then
				echo " Setup for tuning ..."
				tunekernel $vm_dirty_ratio $tuned_vm_dirty_ratio
				tunekernel $vm_dirty_background_ratio $tuned_vm_dirty_background_ratio
				tunekernel $swappiness $tuined_sappiness
			fi
			# allow some time to settle down
			sleep 20

			# Time to run.  CPU 0, though not the most ideal, is being picked in case
			# someone turns on/off hyperthreads.
			#
			echo " Starting IOZONE executable ... binding to CPU 0"
			if [[ ${do_verbose} == 0 ]]; then
				set -x
			fi
			if [[ ${auto} == 1 ]]; then
				time taskset -c 0 ${iozone_exe} ${iozone_args} /iozone/iozone/iozone1 >& ${iozone_output_file}
				status=$?
			else
				let "file_size=$max_file_size/$4"
				echo ================================================ >> ${iozone_output_file}
				echo ${iozone_exe} -t $4 -i ${6} -+n -r ${page_size} -s${file_size}g -c -w -C ${iozone_args}-F ${5} >> ${iozone_output_file}
				time taskset -c 0  ${iozone_exe} -t $4 -i ${6} -+n -r ${page_size} -s${file_size}g -c -w -C ${iozone_args} -F ${5} >> ${iozone_output_file}
				status=$?
			fi

			if [[ ${do_verbose} == 0 ]]; then
				set +x
			fi

			#
			# Check for early watchdog abort and handle
			#
			if [ -f "${local_watchdog_file}" ]; then
				printf "\n Warning - Received watch dog event!!!  Current test aborting and cleaning up\n"
				return;
			fi

			if [ ${status} -eq 1 ]; then
				exit_out "Execution of iozone failed" 1
			fi
			if [[ ${auto} == 1 ]]; then
				(
					printf "\n${name_of_test} ANALYSIS:\n\n"
		    			${run_dir}/analysis-iozone.pl ${iozone_output_file}
		    		) > ${iozone_analysis_file};
			fi

			if [ ${one_run} == "tuned" ]; then
				echo " Reset tuning ..."
				tunekernel $vm_dirty_background_ratio $default_vmdirty_bg_ratio
				tunekernel $vm_dirty_ratio $default_vmdirtyratio
				tunekernel $swappiness $default_swappiness
			fi

			echo "END  ${name_of_test} run @ `date`"

			if [[ ${auto} == 1 ]]; then
				(
					printf "\n${name_of_test} RAWDATA:\n\n"
					cat ${iozone_output_file}
				) >> ${iozone_analysis_file};
			fi
		) >> ${buildrunlog} 2>&1

		#
		# This check is when we return from sub shell.
		#
		if [ -f "${local_watchdog_file}" ]; then
			printf "\n Warning - Received watch dog event!!!  ran out of time\n"
			return;
		fi

		if [[ $auto == 1 ]]; then
			if [ $do_tuned -eq 0 ]; then
				printf "%-8s %-17s" ${fstype} "${name_of_test}";
				grep ALL ${iozone_analysis_file} | grep '[0-9]' | cut -c13-
			else
				compare_list=${compare_list}" "${iozone_analysis_file}
				#
				# If we are in the second round then it is time to comparE.
				#
				if [ ${one_run} == "tuned" ]; then
					name_of_test=`echo ${name_of_test} | tr '[a-z]' '[A-Z]'`;
					printf "%-8s %-17s\n" ${fstype} "${name_of_test}";
					${run_dir}/analysis-iozone.pl -a ${compare_list} |
					sed 's/^ 1         ALL  /            Default ALL  /' | \
					sed 's/^ 2         ALL  /            Tuned   ALL  /' | \
					sed 's/^           ALL  /                    %DIFF/' | tail -3
					#
					# Generate comparison report
					#
					compare_report="${analysis_dir}/${fstype}/iozone_${runtest_name}_cmp-default-vs-tune.log"
					${run_dir}/analysis-iozone.pl ${compare_list} | \
					sed 's/^ 1   / Def /' | \
					sed 's/^ 2   / Tune/' > ${compare_report}
				fi
			fi
		fi
	done
}

#  fmt_printline

# Print formated line
#
fmt_printline()
{
	TEXT="$1"
	shift
	DATA=$*
	printf "%-41s = %s\n" "${TEXT}" "${DATA}";
}

obtain_info()
{
	number_cpus=`grep -c "^processor" /proc/cpuinfo`
	let "max_cpu=${number_cpus}-1"

	# get cpuspeed information.  if there's more than one speed report it.
	# also get model name and cache info.
	#

	get_cpu_speed_info
	numa_nodes=`check_for_numa`
}

perform_required_builds()
{
	retrieve_and_build_iozone
	eatmem_exe=`build_eatmem`
	if [[ "${eatmem_exe}" == "" ]]; then
		echo "Error building eatmem. Log follows:"
		echo "Disabling eatmem."
		do_eat_mem=0
		cat ${buildrunlog}
	fi
}

set_mem_vals()
{
	#
	# Total MEMORY in MB
	#
	total_memory=`grep MemTotal /proc/meminfo | awk '{ printf "%d", $2/1024 }'`

	# New memory retrieved by dropping cache and reading /proc/meminfo and convert to mb
	#
	sync
	echo 3 > /proc/sys/vm/drop_caches
	memory4_pagecache=`grep 'MemFree:' /proc/meminfo | awk '{ printf "%d", $2/1024 }'`

	incache_memory=`get_highest_power_of_2 ${memory4_pagecache}`
	if [ ${incache_memory} -eq ${memory4_pagecache} ]; then
		let "incache_memory=$incache_memory-1"
		incache_memory=`get_highest_power_of_2 ${incache_memory}`
	fi

	if (( do_eat_mem == 1 )); then
		#Find out how much memory we need to take away
		# See http://www.linuxinsight.com/proc_sys_vm_drop_caches.html
		sync
		echo 3 > /proc/sys/vm/drop_caches
		sleep 10
		free_memory=`grep MemFree /proc/meminfo | awk '{ printf "%d", $2/1024 }'`
		(( memory_to_take = free_memory - eatmem_free_memory -80 ))
		${eatmem_exe} ${memory_to_take} &
		PID=$!
		#
		# Give it a chance to do it's thing.
		#
		sleep 180
		sync
		echo 3 > /proc/sys/vm/drop_caches
		sleep 10
		new_free_memory=`grep MemFree /proc/meminfo | awk '{ printf "%d", $2/1024 }'`
		echo "Free memory after calling ${eatmem_exe} ${memory_to_take} is ${new_free_memory} MB."
		echo "Requested free memory was ${eatmem_free_memory} MB."
		if (( new_free_memory != eatmem_free_memory )); then
			(( memory_to_take = memory_to_take - eatmem_free_memory + new_free_memory ))
			echo "memory_to_take be eatmem was adjusted to ${memory_to_take} MB."
		fi
		kill -s SIGUSR1 ${PID}
		wait
		out_of_cache_start=${eatmem_out_of_cache_start}
		out_of_cache_end=${eatmem_out_of_cache_end}
	else
		out_of_cache_end=`echo "${incache_memory} ${outcache_multiplier} * f" | dc | awk '{ printf "%d",  $1 }'`
		out_of_cache_end=`get_highest_power_of_2 ${out_of_cache_end}`
		out_of_cache_start=${incache_memory}
	fi


	# Cap incache file testing
	#
	(( incache_memory=incache_memory/do_quick ))

	if [ ${incache_memory} -gt ${incache_filelimit} ]; then
		incache_maxfile=${incache_filelimit};
	else
		incache_maxfile=${incache_memory}
	fi

	#
	# Cap direct I/O.  Use in cache limit as a guide.  we can change this later.
	#

	if [ ${incache_memory} -gt ${dio_filelimit} ]; then
		dio_maxfile=${dio_filelimit};
	else
		dio_maxfile=${incache_memory}
	fi
}

set_tunings()
{
	# Get default tuning knobs values as we will flip flop between them
	# for the various runs.
	#
	if [ $do_tuned -eq 1 ]; then
		default_vmdirtyratio=`get_kernel_tune $vm_dirty_ratio`
		default_vmdirty_bg_ratio=`get_kernel_tune $vm_dirty_background_ratio`
		default_swappiness=`get_kernel_tune $swappiness`
	fi


	if [ $do_tuned -eq 1 ]; then
		echo "TUNING KERNEL PARAMETERS ..."
		show_default_tuned $vm_dirty_ratio $default_vmdirtyratio $tuned_vm_dirty_ratio
		show_default_tuned $vm_dirty_background_ratio $default_vmdirty_bg_ratio $tuned_vm_dirty_background_ratio
		show_default_tuned $swappiness $default_swappiness $tuined_sappiness
		echo ""
	fi
}

print_system_and_run_info()
{
	printf "\n"
	fmt_printline "Test"		${iozone_exe}
	fmt_printline "Hostname"	`hostname`
	fmt_printline "Date"		`date`
	fmt_printline "Distro"		`hostnamectl | grep "Operating System" | cut -d':' -f 2`
	fmt_printline "Kernel"		`uname -r`
	fmt_printline "Arch"		${arch}

	fmt_printline "CPU count : speeds MHz"			"${number_cpus} : ${cpu_speed_list}"
	fmt_printline "CPU model name"	`grep '^model name' /proc/cpuinfo |  head -1 | sed 's/model name	: //'`
	fmt_printline "CPU cache size" `grep '^cache size' /proc/cpuinfo |  head -1 | sed 's/cache size	: //'`
	fmt_printline "BIOS Information   Version : Date" `get_biosversion`
	fmt_printline "MemTotal"					"${total_memory} (MB)"
	fmt_printline "MemFree (for page cache)"			"${memory4_pagecache} (MB)"
	echo ""

	tuned_profile_name=$(tuned-adm active| perl -pl -e's#^.*:\s*(.*)#$1#')
	fmt_printline "Tuned Profile" 				"$tuned_profile_name"
	echo ""

	if [ ${numa_nodes} -gt 0 ]; then
		fmt_printline "NUMA is Enabled.  # of nodes"	${numa_nodes}
	fi

	fmt_printline "SElinux mode"				`getenforce`

	echo "FILESYSTEM configuration"
	fmt_printline "  Filesystems to test (requested)"			${filesys_to_use}
	fmt_printline "  Filesystems to test (actual)"			${iozone_actual_fs_types}
	fmt_printline "  Mount point of filesystem under test"		${data_mnt_pt}
	fmt_printline "  LUN for filesystem under test"		        ${data_lun}
	fmt_printline "  readahead for LUN above"		       		"${readahead}"
	echo ""
	fmt_printline "IOZONE version"					`${iozone_exe} -v | grep Version | awk '{ print $3 }'`
	fmt_printline "  Smallest file to work on"				"${page_size} (KB)"
	fmt_printline "  90% of Free disk space available"			"${free_space} (MB)"

	if [ ${do_incache} -eq 1 ]; then
		fmt_printline "  In Cache test maximum file size"		"${incache_maxfile} (MB)"
	fi

	if [ ${do_out_of_cache} -eq 1 ]; then
		fmt_printline "  Out of Cache test minimum file size"		"${out_of_cache_start} (MB)"
		fmt_printline "  Out of Cache test maximum file size"		"${out_of_cache_end} (MB)"
		if [[ ${do_eat_mem} == 1 ]]; then
			fmt_printline "  Free memory after running eatmem"		"${eatmem_free_memory} (MB)"
		fi
	fi

	if [ ${do_dio} -eq 1 ]; then
		fmt_printline "  Direct I/O test maximum file size"		"${dio_maxfile} (MB)"
	fi

	if (( to_times_to_run > 1 )); then
		fmt_printline "  Number of sequential runs"			"${to_times_to_run}"
	fi
	echo ""
}

print_header_info()
{
	echo ""
	echo "SUMMARY REPORT for ALL file & record sizes:       (results in MB/sec)"
	echo ""
	echo "FILE     IOZONE           ""    ALL  INIT   RE             RE   RANDOM RANDOM BACKWD  RECRE STRIDE  F      FRE     F      FRE "
	echo "SYSTEM   RUN TYPE         ""    IOS  WRITE  WRITE   READ   READ   READ  WRITE   READ  WRITE   READ  WRITE  WRITE   READ   READ"
	echo "--------------------------""--------------------------------------------------------------------------------------------------"
}

verify_disk_cache()
{
	#
	# Make sure we have enough diskspace for out of cache test
	#
	if [[ ${do_out_of_cache} == 1 ]]; then
		if [[ ${do_eat_mem} == 0 ]];then
			if [ ${out_of_cache_end} -gt ${free_space} ]; then
				echo "Warning - Not enough disk space to do out of cache run ... skipping"
				do_out_of_cache=0;
				run_results=WARN;
			fi
		else
			if [[ ${eatmem_out_of_cache_end} >  ${free_space} ]]; then
				echo "Warning - Not enough disk space to do out of cache run ... skipping"
				do_out_of_cache=0;
				run_results=WARN;
			fi
		fi
	fi
}

execute_iozone()
{
	make_dir ${analysis_dir}/${fs}

	        #Avoid mixing auto flags with throughput mode flags
        if [[ ${auto} == 1 ]]; then
                if [[ ${do_incache} -eq 1 ]]; then
                        test_specific_args=" -n ${page_size}k -g ${incache_maxfile}m -y 1k -q 1m"
                        do_test "In_Cache" "incache" ${test_specific_args}
                fi

                if [[ ${do_incache_fsync} -eq 1 ]]; then
                        test_specific_args=" -n ${page_size}k -g ${incache_maxfile}m -y 1k -q 1m -e"
                        do_test "In_Cache_+_Fsync" "incache+fsync" ${test_specific_args}
                fi

                if [[ ${do_incache_mmap} -eq 1 ]]; then
                        test_specific_args=" -n ${page_size}k -g ${incache_maxfile}m -y 1k -q 1m -B"
                        do_test "In_Cache_w_MMAP" "incache+mmap" ${test_specific_args}
                fi
        else
                if [[ ${do_incache} -eq 1 ]]; then
                        test_specific_args=""   #intentionally left empty, everybody gets one
                        do_test "In_Cache" "incache" ${test_specific_args}
                fi

                if [[ ${do_incache_fsync} -eq 1 ]]; then
                        test_specific_args=" -e"
                        do_test "In_Cache_+_Fsync" "incache+fsync" ${test_specific_args}
                fi

                if [[ ${do_incache_mmap} -eq 1 ]]; then
                        test_specific_args=" -B"
                        do_test "In_Cache_w_MMAP" "incache+mmap" ${test_specific_args}
                fi
        fi

}

execute_iozone_full()
{
	make_dir ${analysis_dir}/${fstype}

	if [ ${do_incache} -eq 1 ]; then
		do_test "In Cache" "incache" "-n ${page_size}k -g ${incache_maxfile}m -y 1k -q 1m"
	fi

	if [ ${do_incache_fsync} -eq 1 ]; then
		do_test "In Cache + Fsync" "incache+fsync" "-n ${page_size}k -g ${incache_maxfile}m -y 1k -q 1m -e"
	fi

	if [ ${do_incache_mmap} -eq 1 ]; then
		do_test "In Cache w/ MMAP" "incache+mmap" "-n ${page_size}k -g ${incache_maxfile}m -y 1k -q 1m -B"
	fi

	#
	# Fix this later.
	#
	if [ ${do_dio} -eq 1 ]; then
		do_test "Direct I/O" "directio" "-I -n ${page_size}k -g ${dio_maxfile}m -y 64k -q 1m -i 0 -i 1 -i 2 -i 3 -i 4 -i 5"
	fi

	if [ ${do_out_of_cache} -eq 1 ]; then
		if [[ ${do_eat_mem} == 1 ]];then
			${eatmem_exe} ${memory_to_take} &
			PID=$!
			sleep 180
			sync
			echo 3 > /proc/sys/vm/drop_caches
			sleep 10
			new_free_memory=`grep MemFree /proc/meminfo | awk '{ printf "%d", $2/1024 }'`
			echo "Free memory after calling ${eatmem_exe} ${memory_to_take} is ${new_free_memory}"
			echo "Requested free memory was ${eatmem_free_memory}"
			do_test "Out Of Cache" "outcache" "-n ${out_of_cache_start}m -g ${out_of_cache_end}m -y 8k -q 1m"
			kill -s SIGUSR1 ${PID}
			wait
		else
			do_test "Out Of Cache" "outcache" "-n ${out_of_cache_start}m -g ${out_of_cache_end}m -y 8k -q 1m"
		fi
	fi
}

invoke_test()
{

	verify_disk_cache

	print_system_and_run_info

	if [[ ${iozone_exe} != "" ]];then
		cd ${testing_dir};
		if [[ $auto -eq 1 ]]; then
			print_header_info
		fi

		# sequential runs
		for ((run_number=1; run_number <= to_times_to_run ; run_number++))
		do
			analysis_dir=$results_dir/Run_${run_number}
			make_dir ${analysis_dir}

   			execute_iozone
				
			echo ""

			if [ -f "${local_watchdog_file}" ];then
				break;
			fi
		done
		#  Compute averages
		if (( to_times_to_run > 1 )); then
			cd `dirname ${results_dir}`
			${run_dir}/average.sh $(basename ${results_dir})
			${run_dir}/compare.sh $(basename ${results_dir})
		fi
	else
		echo "Error building iozone. Tests skipped."
	fi
}

#
# Execute the test.
#

execute_it()
{
	#
	# Assume the test will fail and remove fail marker
	#
	run_results=FAIL

	prep_system >> ${buildrunlog} 2>&1

	obtain_info

	#
	# compile iozone and eatmem
	#
	perform_required_builds

	set_mem_vals

	set_tunings

	# Run the test itself

	if [[ $auto == 1 ]]; then
		# Determine free disk space.  Take away 10% and make sure we dont run the out of
		# memory test to fill up the drive
		#
		echo $mount_list
		free_space=0
		for mnt_pnt in $mount_list;
		do
			temp=`df --block-size=1m --portability ${mnt_pnt} | tail -1 | awk '{ printf "%d", $4*.9 }'`;
			let "free_space=$free_space+$temp"
		done

		#
		# Make sure we have enough diskspace for in cache tesT
		#
		if [ ${incache_memory} -gt ${free_space} ]; then
			echo data_dir $data_dir
			exit_out "Error: Not enough disk space on this system to even run In Cache test.   Cant continue ..." 1
		else
			invoke_test
		fi
	else
		invoke_test
	fi

	#
	# Report any failure
	#
	if [ ! -f "${testing_dir}/FAILED" ]; then
		run_results=PASS;
	fi

	#
	# Report on premature end of test.
	#
	if [ -f "${local_watchdog_file}" ]; then
		run_results=WARN;
	fi


	# Re-enable swap
	if [[ ${swap_disabled} == 1 ]]; then
		swapon -a
	fi
}

reduce_non_auto_data()
{
	header=0
	first_found=0
	cmd_line_display=0
	total_threads=0
	average_tp=""
	record_size=""
	max_tp=0
	min_tp=0
	file_size=""
	test_type=""
	total_tp==""
	procs=""
	command=""

  $TOOLS_BIN/test_header_info --front_matter --results_file /tmp/results.csv --host $to_configuration --sys_type $to_sys_type --tuned $to_tuned_setting --results_version $iozone_version --test_name $test_name

	while IFS= read -r line
	do
		if [[ $line == *"======" ]]; then
			if [[ $first_found -eq 0 ]]; then
				cmd_line_display=1
				first_found=1
				continue
			fi
			continue
		fi
		if [[ $cmd_line_display -eq 1 ]]; then
			command=$line
			cmd_line_display=0
			continue
		fi
		if [[ $line == *"Children see throughput for"* ]]; then
			work_with=`echo $line | sed "s/  / /g"`
			total_tp=`echo $work_with | cut -d'=' -f 2`
			procs=`echo $work_with | cut -d' ' -f 5`
			if [[ $work_with == *"initial"* ]]; then
				test_type=`echo $work_with | cut -d' ' -f 6,7`
			else
				test_type=`echo $work_with | cut -d' ' -f 6`
			fi
			continue
		fi
		if [[ $line == *"Avg throughput per process"* ]]; then
			average_tp=`echo $line | cut -d'=' -f 2`
			continue
		fi
		if [[ $line == *"Min throughput per process"* ]]; then
			min_tp=`echo $line | cut -d'=' -f 2`
			continue
		fi
		if [[ $line == *"Max throughput per process"* ]]; then
			max_tp=`echo $line | cut -d'=' -f 2`
			continue
		fi
		if [[ $line == *"Record Size"* ]]; then
			record_size=`echo $line | cut -d'=' -f 2`
			continue
		fi
		if [[ $line == *"File size set to"* ]]; then
			file_size=`echo $line | cut -d' ' -f 5,6`
			continue
		fi
		if [[ $line == *"End of file frag"* ]]; then
			echo =============================
			echo $command
			echo test_type: $test_type
			echo processes: $procs
			echo file_size: $file_size
			echo record_size: $record_size
			echo total throughput rate: $total_tp
			echo Max tp per proc: $max_tp
			echo Min tp per proc: $min_tp
			echo Average tp per proc: $average_tp
			first_found=0
			if [ $header -eq 0 ]; then
				header=1 
				echo processes:test_type:file_sze:record_size:Total_througput >> /tmp/results.csv
			fi
			echo ${procs}:${test_type}:${file_size}:${record_size}:${total_tp} >> /tmp/results.csv
		fi
	done  < "${1}"
}

obtain_disks()
{
	if [[ $devices_to_use == "grab_disks" ]]; then
		results=`${TOOLS_BIN}/grab_disks ${devices_to_use}`
		if [ $? -ne 0 ]; then
			exit_out "grab disks failed." 1
		fi
        	disks_found=`echo $results | cut -d: -f 2`
        	devices_to_use=`echo $results | cut -d: -f 1`
	else
		disk=`echo $disks_to_use | cut -d',' -f 1`
		disks_found=`echo $disks | tr -d -c ' '  | awk '{ print length; }'`
		let "disks_found=${disks_found}+1"
	fi
}

create_lvm()
{
	lvm_devices=`echo $devices_to_use | sed "s/ /,/g"`
	$TOOLS_BIN/lvm_create --devices ${lvm_devices} --lvm_vol iozone --lvm_grp iozone
	if [ $? -ne 0 ]; then
		exit_out "lvm create failed, exiting" 1
	fi

	mount_pnt=${mount_location}${mount_index}
	make_dir ${mount_pnt}
	umount $mount_pnt >& /dev/null
	$TOOLS_BIN/create_filesystem --fs_type $1 --mount_dir $mount_pnt --device /dev/iozone/iozone
	if [ $? -ne 0 ]; then
		exit_out "create_filesystem failed, exiting" 1
	fi
	mount_list=${mount_pnt}
	let "mount_index=${mount_index}+1"
}
###
### MAIN
###

#
# Do this once, and then simply reference the file
#

ARGUMENT_LIST=(
	"devices_to_use"
	"dio_filelimit"
	"eatmem_out_of_cache_start"
	"eatmem_out_of_cache_end"
	"file_count_list"
	"filesystems"
	"max_file_size"
	"mount_location"
	"incache_filelimit"
	"iozone_kit"
	"iterations"
	"iozone_options"
	"outcache_multiplier"
	"page_size"
	"quick"
	"results_dir"
	"test_prefix"
	"test_type"
)

NO_ARGUMENTS=(
	"all_test"
	"auto"
	"directio"
	"eatmem"
	"help"
	"incache"
	"iozone_umount"
	"lvm_disk"
 	"mmapincache"
	"outofcache"
	"swap"
	"syncedincache"
	"tunecompare"
	"verbose"
)

opts=$(getopt \
    --longoptions "$(printf "%s:," "${ARGUMENT_LIST[@]}")" \
    --longoptions "$(printf "%s," "${NO_ARGUMENTS[@]}")" \
    --name "$(basename "$0")" \
    --options "h" \
    -- "$@"
)

#
# Check for errors
#
if [ $? -ne 0 ]; then
	usage $0
fi

eval set --$opts

while [[ $# -gt 0 ]]; do
	case "$1" in
		--all_test)
			all_test=1
		;;
		--auto)
			auto=1
		;;
		--devices_to_use)
			devices_to_use=`echo $2 | sed "s/,/ /g"`
			shift 1
		;;
		--dio_filelimit)
			dio_filelimit=$2
			shift 1
		;;
		--directio)
			do_dio=1;
			modes2run=1
		;;
		--eatmem)
			do_eat_mem=1
		;;
		--eatmem_free_memory)
			eatmem_free_memory=$2
			shift 1
		;;
		--eatmem_out_of_cache_end)
			eatmem_out_of_cache_end=$2
			shift 1
		;;
		--eatmem_out_of_cache_start)
			eatmem_out_of_cache_start=$2
			shift 1
		;;
		--file_count_list)
			file_count_list=`echo $2 | sed "s/,/ /g"`
			shift 1
		;;
		--filesystems)
			filesystems=`echo $2 | sed "s/,/ /g"`
			shift 1
		;;
		--help)
			usage
		;;
		--incache)
			do_incache=1
			modes2run=1
		;;
		--incache_filelimit)
			incache_filelimit=$2
			shift 1
		;;
		--iozone_options)
			iozone_options=$2
			shift 1
		;;
		--iozone_kit)
			iozone_kit=$2
			shift 1
		;;
		--iozone_umount)
			do_iozone_umount=1
		;;
		--lvm_disk)
			lvm_disk=1
		;;
		--max_file_size)
			max_file_size=$2
			shift 1
		;;
		--mmapincache)
			do_incache_mmap=1
			modes2run=1
		;;
		--mount_location)
			mount_location=$2
			shift 1
		;;
		--outofcache)
			do_out_of_cache=1
			modes2run=1
		;;
		--outcache_multiplier)
			outcache_multiplier=$2
			shift 1
		;;
		--pagesize)
			pagesize=$2
			shift 1
		;;
		--quick)
			(( do_quick=do_quick*$2 ))
			shift 1
		;;
		--results_dir)
			results_dir=$2
			#
			# Reset these
			#
			configdir=$results_dir/config
			buildrunlog=${results_dir}/build-run.log
			shift 1
		;;
		--swap)
			swapoff -a
			swap_disabled=1
		;;
		--syncedincache)
			do_incache_fsync=1
			modes2run=1
		;;
		--test_prefix)
			test_prefix=$2
			shift 1
		;;
		--test_type)
			test_type=`echo $2 | sed "s/,/ /g"`
			shift 1
		;;
		--tunecompare)
			do_tuned=1
		;;
		--verbose)
			set -x
			do_verbose=1
		;;
		h)
			usage $0
		;;
		--)
			break
		;;
		*)
			echo "not found $1"
			usage $0
		;;
	esac
	shift;
done

if [ `id -u` -ne 0 ]; then
	exit_out "You need to run as root" 1
fi

if [ $to_pbench -eq 1 ]; then
        source ~/.bashrc

	for ((run_number=1; run_number <= to_times_to_run ; run_number++))
	do
		echo $TOOLS_BIN/execute_via_pbench --cmd_executing "$0" ${arguments} --test $test_name --spacing 11 --pbench_stats $to_pstats
		$TOOLS_BIN/execute_via_pbench --cmd_executing "$0" ${arguments} --test iozone --spacing 11 --pbench_stats $to_pstats
	done
	exit 0
fi

dir_to=""
if [[ $to_home_root != "" ]]; then
	if [[ $to_user != "" ]]; then
		dir_to=$to_home_root/$to_user
		cd $dir_to
	fi
fi
if [[ $results_dir == "" ]]; then
	if [[ $dir_to != "" ]]; then
		results_dir=$dir_to
	else
		echo results dir defaulted to the current dir.
		results_dir=`pwd`
	fi
fi

pushd $run_dir >& /dev/null
gcc -Wall -Os -o create_file create_file.c
if [ ! -x "$run_dir/create_file" ]; then
	exit_out "Error:  create_file did not build, aborting" 1
fi
popd >& /dev/null

obtain_disks

if [[ $to_sys_type != "" ]]; then
	odir=results_iozone_$to_tuned_setting
	out_dir="/tmp/${odir}"
	make_dir $out_dir
	exec &>> $out_dir/run_output
fi

dmidecode_file=`pwd`/dmidecode
dmidecode > $dmidecode_file

#
# If no test designated, then do them all.
#
if [[ $modes2run -eq 0 ]] || [[ $all_test -eq 1 ]]; then
	do_incache=1
	do_incache_fsync=1
	do_incache_mmap=1
 	do_out_of_cache=1
	do_dio=1
fi

rm -rf ${results_dir} ${local_watchdog_file} >& /dev/null
make_dir ${results_dir}
make_dir ${configdir}
touch $buildrunlog

if [[ $mount_location = "" ]]; then
	exit_out "Need to designate a mount point" 1
fi

#
# Execute things, one for each filesys
#
for fs in $filesystems; do
	mount_index=0
	mount_list=""
	separ=""

	if [ $lvm_disk -eq 1 ]; then
		create_lvm $fs
	else
		for device in $devices_to_use; do
			mount_pnt=${mount_location}${mount_index}
			make_dir ${mount_pnt}
			umount $mount_pnt >& /dev/null
			wipefs $device
			$TOOLS_BIN/create_filesystem --fs_type $fs --mount_dir $mount_pnt --device $device
			if [ $? -ne 0 ]; then
				exit_out "echo create filesystem create failed." 1
			fi
			mount_list=${mount_list}${separ}${mount_pnt}
			separ=" "
			let "mount_index=${mount_index}+1"
		done
	fi
	filesys_to_use=$fs
	execute_it $fs
	if [ $mount_index  -ne 0 ]; then
		if [ $lvm_disk -eq 1 ]; then
			$TOOLS_BIN/lvm_delete --lvm_vol iozone --lvm_grp iozone --mount_pnt ${mount_list}
		else
			$TOOLS_BIN/umount_filesystems --mount_pnt ${mount_location} --number_mount_pnts ${mount_index}
		fi
	fi
done

if [[ $run_results != "PASS"  ]]; then
        echo Failed >> ${results_dir}/test_results_report
else
        echo Ran >> ${results_dir}/test_results_report
fi

cp ${curdir}/meta_data.yml $results_dir
${curdir}/test_tools/move_data $curdir ${results_dir}
if [[ $auto -eq 0 ]]; then
	reduce_non_auto_data $iozone_output_file > $out_dir/iozone_summary
	cp -R ${results_dir} $out_dir
else
	cp -R ${results_dir} ${out_dir}
	
fi

# Archive results into single tarball
#
pushd /tmp >& /dev/null

archive_file="iozone-results.tar.gz"
make_dir $results_dir
rm -f results_pbench.tar
echo mv /tmp/results.csv ${results_dir} 
mv /tmp/results.csv ${results_dir} 
pushd ${results_dir} > /dev/null
find -L . -type f | tar --transform 's/.*\///g' -cf /tmp/results_pbench.tar --files-from=/dev/stdin
tar cf /tmp/results_iozone_${to_tuned_setting}.tar *
popd > /dev/null
${curdir}/test_tools/save_results --curdir $curdir --home_root $to_home_root --tar_file "/tmp/results_iozone_${to_tuned_setting}.tar" --test_name ${test_name} --tuned_setting=$to_tuned_setting --version None --user $to_user
popd >& /dev/null
