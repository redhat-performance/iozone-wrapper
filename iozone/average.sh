#!/bin/bash - 
#===============================================================================
#
#          FILE:  average.sh
# 
#         USAGE:  ./average.sh
# 
#   DESCRIPTION:  
# 
#       OPTIONS:  ---
#  REQUIREMENTS:  ---
#          BUGS:  ---
#         NOTES:  ---
#        AUTHOR: Jirka Hladky (JH), jhladky AT redhat DOT com
#       COMPANY: Red Hat, Inc.
#       CREATED: 02/03/2010 06:30:13 PM CET
#      REVISION:  ---
#     COPYRIGHT: Copyright (c) 2010, Red Hat, Inc. All rights reserved.
#     
# This copyrighted material is made available to anyone wishing to use,
# modify, copy, or redistribute it subject to the terms and conditions
# of the GNU General Public License v.2.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software Foundation,
# Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
#===============================================================================

set -o nounset                              # Treat unset variables as an error

OUTPUT_DIR="Average"

PREFIX_DIR=${1:-./}
AVERAGE_TABLE_BIN=$(find -L `pwd` -perm /u+x -name average_table.pl | tail -n 1)
ANALYSIS_IOZONE_BIN=$(find -L `pwd` -perm /u+x -name analysis-iozone.pl | tail -n 1)

if [[ -z ${AVERAGE_TABLE_BIN} ]]
then
    echo "Cannot find average_table.pl executable. Exit.\n" 2>&1
    exit 1
fi

if [[ -z ${ANALYSIS_IOZONE_BIN} ]]
then
    echo "Cannot find analysis-iozone.pl executable. Exit.\n" 2>&1
    exit 1
fi

cd ${PREFIX_DIR}
rm -rfv ${OUTPUT_DIR}
mkdir -v ${OUTPUT_DIR}

RUN_DIR=$(find . -maxdepth 1 -type d -name "Run*")

# ./Run_2 ./Run_1 ./Run_3  -> Run_2 Run_1 Run_3
RUN_DIR=${RUN_DIR//.\//}

#Run_2 Run_1 Run_3 -> $1 $2 $3
set ${RUN_DIR}
REFERENCE_DIR=$1
shift
RUN_DIR=$@

for FILE_1 in $(find ${REFERENCE_DIR} -type f -name "*iozone")
do
    INPUT_FILES="\"${FILE_1}\""
    LENGTH=1
    for DIR in ${RUN_DIR}
    do
	# Run_1/ext3/iozone_incache_default.iozone -> Run_2/ext3/iozone_incache_default.iozone
	FILE_2=${FILE_1/#${REFERENCE_DIR}/${DIR}}

	if [[ -f ${FILE_2} ]] 
	then
	    INPUT_FILES="${INPUT_FILES} \"${FILE_2}\""
	    ((LENGTH++))
	fi

    done

    if (( LENGTH > 1 ))
    then
	# Run_1/ext4/iozone_incache_default.iozone -> Average/ext4/iozone_incache_default.iozone
	NEW_FILE=${FILE_1/#${REFERENCE_DIR}/${OUTPUT_DIR}}
	COUNTER=1
	OUTPUT_FILE=${NEW_FILE}
	while [[ -f ${OUTPUT_FILE} ]]
	do
	    echo "File ${OUTPUT_FILE} exists already!" 2>&1
	    OUTPUT_FILE=${NEW_FILE}_$(printf "%03d" ${COUNTER})
	    ((COUNTER++))
	    echo "Trying ${OUTPUT_FILE}" 2>&1
	done
	
	PARRENT_DIR=$(dirname ${OUTPUT_FILE})
	if [[ ! -d ${PARRENT_DIR} ]]
	then
	    mkdir -p -v ${PARRENT_DIR}
	fi

	COMMAND="${AVERAGE_TABLE_BIN} ${INPUT_FILES} > \"${OUTPUT_FILE}\""
	echo ${COMMAND}
	eval ${COMMAND}

	ANALYSIS_FILE=${OUTPUT_FILE/%.iozone/_analysis+rawdata.log}
	COMMAND2="${ANALYSIS_IOZONE_BIN} ${OUTPUT_FILE}"
	echo ${COMMAND2}
	(
	    printf "\nAverage of ${LENGTH} files: ${INPUT_FILES}. ANALYSIS:\n\n"
	    eval ${COMMAND2}

	    printf "\nAverage RAWDATA:\n\n"
	    cat ${OUTPUT_FILE}
	) > ${ANALYSIS_FILE}


    fi
done
