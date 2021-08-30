#!/bin/bash - 
#===============================================================================
#
#          FILE:  compare.sh
# 
#         USAGE:  ./compare.sh 
# 
#   DESCRIPTION:  
# 
#       OPTIONS:  ---
#  REQUIREMENTS:  ---
#          BUGS:  ---
#         NOTES:  ---
#        AUTHOR: Jirka Hladky (JH), jhladky AT redhat DOT com
#       COMPANY: Red Hat, Inc.
#       CREATED: 02/03/2010 05:30:13 PM CET
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

REFERENCE_DIR="Average"
OUTPUT_DIR="Compare"

PREFIX_DIR=${1:-./}
ANALYSIS_IOZONE_BIN=$(find `pwd` -perm /u+x -name analysis-iozone.pl)

if [[ -z ${ANALYSIS_IOZONE_BIN} ]]
then
    echo "Cannot find analysis-iozone.pl executable. Exit.\n" 2>&1
    exit 1
fi

cd ${PREFIX_DIR}
RUN_DIR=$(find . -maxdepth 1 -type d -name "Run*")

# ./Run_2 ./Run_1 ./Run_3  -> Run_2 Run_1 Run_3
#echo ${RUN_DIR}
RUN_DIR=${RUN_DIR//.\//}
#echo ${RUN_DIR}

rm -rfv ${OUTPUT_DIR}
mkdir -v ${OUTPUT_DIR}

for FILE_1 in $(find ${REFERENCE_DIR} -type f -name "*iozone")
do
    for DIR in ${RUN_DIR}
    do
	FILE_2=${FILE_1/#${REFERENCE_DIR}/${DIR}}
	#echo ${FILE_2}

	# Average/ext4/iozone_incache_default.iozone -> ext4/iozone_incache_default.iozone
	NEW_FILE=${FILE_1/#${REFERENCE_DIR}\/}   
	
	# ext4/iozone_incache_default.iozone -> ext4-iozone_incache_default.iozone
	NEW_FILE=${NEW_FILE//\//-}

	# ext4-iozone_incache_default.iozone -> Compare/Run_1-vs-Average-ext4-iozone_incache_default.iozone
	NEW_FILE="${OUTPUT_DIR}/${DIR}-vs-${REFERENCE_DIR}-${NEW_FILE}"

	#echo ${FILE_1}
	#echo ${NEW_FILE}

	COUNTER=1
	OUTPUT_FILE=${NEW_FILE}
	while [[ -f ${OUTPUT_FILE} ]]
	do
	    echo "File ${OUTPUT_FILE} exists already!" 2>&1
	    OUTPUT_FILE=${NEW_FILE}_$(printf "%03d" ${COUNTER})
	    ((COUNTER++))
	    echo "Trying ${OUTPUT_FILE}" 2>&1
	done

	if [[ -f ${FILE_2} ]] 
	then
	    COMMAND="${ANALYSIS_IOZONE_BIN} ${FILE_1} ${FILE_2} > ${OUTPUT_FILE}"
	    echo ${COMMAND}
	    eval ${COMMAND}
	    #analysis-iozone.pl ${FILE_1} ${FILE_2} > 
	fi
    done
done
