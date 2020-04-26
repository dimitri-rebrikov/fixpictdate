#! /bin/bash
pict_dir=$1

check_cc () {
    cc=$?
    if [ "$cc" -ne "0" ]; then
        exit $cc
    fi
}

cd $pict_dir

for file in `find . -type f \( -iname '*.jpg' -o -iname '*.jpeg' \)` ; do 
    echo $file
    file_name=`basename "$file"`
    echo $file_name
    file_dir=`dirname "$file"`
    echo $file_dir
    file_change_date=`date "+%Y:%m:%d %H:%M:%S" -r "$file"`
    echo $file_change_date
    picture_date=`exiftool -s3 -datetimeoriginal "$file"`
    check_cc
    echo $picture_date
done