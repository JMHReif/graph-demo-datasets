#!/bin/bash

FILE_PREFIX=venmo
EXT=csv

DEMO=demo
DIR1=staging-smallerFiles
DIR2=final-trimmedFiles
#BULKFOLDER=adminImportFiles

SIZE=500000

echo 'Start time:' $(date +'%Y-%m-%d %T')
mkdir -p $DEMO
mkdir -p $DIR1
mkdir -p $DIR2
#mkdir -p $BULKFOLDER

#Quote entire file
csvformat -U 1 ../${FILE_PREFIX}.${EXT} > ${FILE_PREFIX}.${EXT}

lines=`wc -l < ${FILE_PREFIX}.${EXT}`
echo 'Lines in original file:' $lines

#Create demo file
head -n10000 ${FILE_PREFIX}.${EXT} > demo/${FILE_PREFIX}_demo.${EXT}
csvcut -c 2-8,71-123,360-362 demo/${FILE_PREFIX}_demo.${EXT} | csvformat -U 1 > demo/${FILE_PREFIX}_demo_trim.${EXT}
echo 'Created demo file'

#Calculate expected number of files
expectedFilecount=$((${lines}/${SIZE} + 1))
echo 'Expected number of generated smaller files:' $expectedFilecount

#turn original file into smaller ones
num=1
startLine=0
while [ $num -le $expectedFilecount ]
do
    echo 'Start while'
    start=$(($startLine+1))
    end=$(($startLine+${SIZE}))
    if [ "${num}" -gt 1 ]; then
        head -n1 ${FILE_PREFIX}.${EXT} >> ${DIR1}/${FILE_PREFIX}_${num}.${EXT}
    fi
    sed -n "${start},${end}p" ${FILE_PREFIX}.${EXT} >> ${DIR1}/${FILE_PREFIX}_${num}.${EXT}
    #echo $(($startLine+1)) $(($startLine+${SIZE})) $FILE_PREFIX.$EXT $DIR1/${FILE_PREFIX}_$num.${EXT}
    ((num++))
    startLine=$((startLine + $SIZE))
done
chmod 755 $DIR1/*.csv
echo 'Complete - split original file into smaller files'

#trim columns of data to most valuable
for file in ${DIR1}/*
do 
    echo 'Working with' $file
    num=$(echo "${file##*/}" | tr -dc '0-9')
    #echo $num
    csvcut -c 2-8,71-123,360-362 $file | csvformat -U 1 > $DIR2/${FILE_PREFIX}_${num}_trim.${EXT}
done
chmod 755 ${DIR2}/*.csv
echo 'Complete - create trimmed and quoted versions of smaller files'

Cleanup staging file directories
rm -r ${DIR1}
echo 'Cleanup on staging file directories'

# #Format for neo4j-admin import
# mkdir -p ${BULKFOLDER}/apps
# mkdir -p ${BULKFOLDER}/pay
# mkdir -p ${BULKFOLDER}/fromUser
# mkdir -p ${BULKFOLDER}/toUser
# mkdir -p ${BULKFOLDER}/appPay
# mkdir -p ${BULKFOLDER}/payFrom
# mkdir -p ${BULKFOLDER}/payTo

# counter=1
# iteration=1
# while [ "$counter" -le "$expectedFilecount" ]
# do
#     nextNumber=$(($counter+1))
#     echo 'Combining file #s:' $counter 'and' $nextNumber
#     inputFile1=${DIR2}/${FILE_PREFIX}_${counter}_trim
#     inputFile2=${DIR2}/${FILE_PREFIX}_${nextNumber}_trim
#     outputFile=${FILE_PREFIX}_${iteration}

#     #nodes
#     csvcut -c 3-7 ${inputFile1}.${EXT} > ${BULKFOLDER}/apps/${outputFile}_applications.${EXT}
#     csvcut -c 8-9,13,37,56-60 ${inputFile1}.${EXT} > ${BULKFOLDER}/pay/${outputFile}_payments.${EXT}
#     csvcut -c 38-39,41-42,44-47,49-52,54-55 ${inputFile1}.${EXT} > ${BULKFOLDER}/fromUser/${outputFile}_startUser.${EXT}
#     csvcut -c 15-19,21-22,24-27,29-32,34-36 ${inputFile1}.${EXT} > ${BULKFOLDER}/toUser/${outputFile}_endUser.${EXT}

#     #relationships
#     csvcut -c 6,9 ${inputFile1}.${EXT} > ${BULKFOLDER}/appPay/${outputFile}_appPayments.${EXT}
#     csvcut -c 9,47 ${inputFile1}.${EXT} > ${BULKFOLDER}/payFrom/${outputFile}_paymentsFrom.${EXT}
#     csvcut -c 9,27 ${inputFile1}.${EXT} > ${BULKFOLDER}/payTo/${outputFile}_paymentsTo.${EXT}

#     if [ -f "${inputFile2}.${EXT}" ]; then
#         sed 1d ${inputFile2}.${EXT} | csvcut -c 3-7 >> ${BULKFOLDER}/apps/${outputFile}_applications.${EXT}
#         sed 1d ${inputFile2}.${EXT} | csvcut -c 8-9,13,37,56-60 >> ${BULKFOLDER}/pay/${outputFile}_payments.${EXT}
#         sed 1d ${inputFile2}.${EXT} | csvcut -c 38-39,41-42,44-47,49-52,54-55 >> ${BULKFOLDER}/fromUser/${outputFile}_startUser.${EXT}
#         sed 1d ${inputFile2}.${EXT} | csvcut -c 15-19,21-22,24-27,29-32,34-36 >> ${BULKFOLDER}/toUser/${outputFile}_endUser.${EXT}
#         sed 1d ${inputFile2}.${EXT} | csvcut -c 6,9 >> ${BULKFOLDER}/appPay/${outputFile}_appPayments.${EXT}
#         sed 1d ${inputFile2}.${EXT} | csvcut -c 9,47 >> ${BULKFOLDER}/payFrom/${outputFile}_paymentsFrom.${EXT}
#         sed 1d ${inputFile2}.${EXT} | csvcut -c 9,27 >> ${BULKFOLDER}/payTo/${outputFile}_paymentsTo.${EXT}
#     fi

#     ((counter+=2))
#     ((iteration++))
# done
# chmod -R 755 ${BULKFOLDER}/*/*.csv
# echo 'Complete - create files for admin import'

# echo 'End time:' $(date +'%Y-%m-%d %T')