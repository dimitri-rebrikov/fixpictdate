#!/bin/bash

# the path to the dir with the test pictures
test1_source_dir=./test/picts1
test2_source_dir=./test/picts2

# the path to the temporary dir
test_tmp_dir=./tmp

# the path to the dir to run the test in
test_run_dir=$test_tmp_dir/test

# the file with the test expectations
test1_expectations_file=./test/expectations1.txt
test2_expectations_file=./test/expectations2.txt

# directory filter
NOTPATH="*/#recycle/*,*/temporary*/*"

check_cc () {
    cc=$?
    if [ "$cc" -ne "0" ]; then
        echo "Error!"
        exit $cc
    fi
}

check_expectations() {
    local expectations_file=$1
    # iterate over the expectations and compare the with the real results
    local -a expectation_arr
    result=OK
    echo "check expectations from $expectations_file"
    while IFS= read -r expectation_line; do
        expectation_arr=()
        IFS=$';' read -r -a expectation_arr <<< "$expectation_line"
        test_file=${expectation_arr[0]}
        expected_date=${expectation_arr[1]}
        expectation_description=${expectation_arr[2]}
        echo -e "\nTEST $expectation_description"
        echo "file: $test_run_dir/$test_file"
        picture_date=`exiv2 -K Exif.Photo.DateTimeOriginal -Pv "$test_run_dir/$test_file"`
        picture_date=${picture_date:0:16} #cut the seconds as exiv2 dosen't support formatting
        echo "expected: $expected_date , got: $picture_date"
        if [ "$expected_date" = "$picture_date" ]; then
            echo OK
        else
            echo FAIL
            result=FAIL
        fi
    done < "$expectations_file" 
    echo -e "\nTest Result: $result"
    if [ "$result" = "OK" ]; then 
        return 0
    else 
        return 1
    fi
}

# checks that every file fixed by the script (logged in the given log file)
# has the same fixed date in all three common EXIF date fields
# (DateTimeOriginal, DateTimeDigitized/CreateDate and Image.DateTime/ModifyDate)
check_fixed_dates() {
    local log_file=$1
    local result=OK
    local line rel fixed_date file
    local exp16 dto dtd dtm
    while IFS= read -r line; do
        # log line: "...: INFO set the pict orig date for ./<path>.jpg to 2020:01:15 15:16" or "... 15:16:00"
        rel=`echo "$line" | sed 's/.*set the pict orig date for //'`
        fixed_date=`echo "$rel" | grep -oE '[0-9]{4}:[0-9]{2}:[0-9]{2} [0-9]{2}:[0-9]{2}(:[0-9]{2})?$'`
        rel=`echo "$rel" | sed -E 's/ to [0-9]{4}:[0-9]{2}:[0-9]{2} [0-9]{2}:[0-9]{2}(:[0-9]{2})?$//'`
        file="$test_run_dir/${rel#./}"
        exp16=${fixed_date:0:16} # cut the seconds as exiv2 dosen't support formatting
        echo -e "\nTEST all three date fields of $rel"
        echo "expected: $exp16"
        dto=`exiv2 -K Exif.Photo.DateTimeOriginal -Pv "$file" 2>/dev/null`
        dtd=`exiv2 -K Exif.Photo.DateTimeDigitized -Pv "$file" 2>/dev/null`
        dtm=`exiv2 -K Exif.Image.DateTime -Pv "$file" 2>/dev/null`
        echo "DateTimeOriginal:  ${dto:0:16}"
        echo "DateTimeDigitized: ${dtd:0:16}"
        echo "Image DateTime:    ${dtm:0:16}"
        if [ -n "$exp16" ] && [ "${dto:0:16}" = "$exp16" ] && [ "${dtd:0:16}" = "$exp16" ] && [ "${dtm:0:16}" = "$exp16" ]; then
            echo OK
        else
            echo FAIL
            result=FAIL
        fi
    done < <( grep "set the pict orig date for" "$log_file" )
    echo -e "\nAll-date Test Result: $result"
    if [ "$result" = "OK" ]; then 
        return 0
    else 
        return 1
    fi
}


# (re-)create the test dir
rm -rf "$test_run_dir"
mkdir -p "$test_run_dir"

echo -e "\nFirst test run\n"

# restore the file creation dates of the pictures so the tests work as expected
find "$test1_source_dir" -name "*.jpg" -exec  touch -t 202005021426  '{}' \;

# copy the files for the 1st test
cp -p -r "$test1_source_dir"/* "$test_run_dir"

# run the main script in the test dir
LOGLEVEL=2 NOTPATH="$NOTPATH" ./fixpictdate.sh "$test_run_dir"
check_cc

cached1=`grep "DEBUG the file is known" "$test_run_dir/fixpictdate.sh.log" | wc -l`

if [ "$cached1" -gt 0 ]; then
    echo "FAIL: General failure the log file contains info about cache entries ($cached1) but it must have no"
    exit 1
fi

check_expectations "$test1_expectations_file"
test1_cc=$?

echo -e "\nSecond test run\n"

# restore the file creation dates of the pictures so the tests work as expected
find "$test2_source_dir" -name "*.jpg" -exec  touch -t 202005021426  '{}' \;

# copy the files for the 2nd test
cp -p -r "$test2_source_dir"/* "$test_run_dir"

# comment this in to simulate caching failure
#rm "$test_run_dir/fixpictdate_cache.txt"

# re-run the main script in the test dir
LOGLEVEL=2 NOTPATH="$NOTPATH" ./fixpictdate.sh "$test_run_dir"
check_cc

# retest the 1st expectations as the fix ran in the same directory
check_expectations "$test1_expectations_file"
test1_rr_cc=$?

# retest the 1st expectations as the fix ran in the same directory
check_expectations "$test2_expectations_file"
test2_cc=$?

cached2=`grep "DEBUG the file is known" "$test_run_dir/fixpictdate.sh.log" | wc -l`

if [ "$cached2" -eq 0 ]; then
    echo "FAIL: Caching does not work"
fi


echo -e "\nTest file removing\n"

test_remove_file_cc=0
file_to_simulate_removing="dir005/pict008 .jpg"

cache_found1=`grep "$file_to_simulate_removing" "$test_run_dir/fixpictdate_cache.txt" | wc -l`
if [ "$cache_found1" -ne "1" ]; then 
    echo "FAIL: the file $file_to_simulate_removing shall be in the cache file"
    test_remove_file_cc=-1
fi

tofix_found1=`grep "$file_to_simulate_removing" "$test_run_dir/fixpictdate_tofix.txt" | wc -l`
if [ "$tofix_found1" -ne "1" ]; then 
    echo "FAIL: the file $file_to_simulate_removing shall be in the to-fix file"
    test_remove_file_cc=-1
fi

# simulate the removing of a file
rm "$test_run_dir/$file_to_simulate_removing"

# re-run the main script in the test dir
LOGLEVEL=2 NOTPATH="$NOTPATH" ./fixpictdate.sh "$test_run_dir"
check_cc

# the file shall be removed from cache and from tofix fles
cache_found2=`grep "$file_to_simulate_removing" "$test_run_dir/fixpictdate_cache.txt" | wc -l`
if [ "$cache_found2" -ne "0" ]; then 
    echo "FAIL: the file $file_to_simulate_removing shal NOT be in the cache file anymore"
    test_remove_file_cc=-1
fi

tofix_found2=`grep "$file_to_simulate_removing" "$test_run_dir/fixpictdate_tofix.txt" | wc -l`
if [ "$tofix_found2" -ne "0" ]; then 
    echo "FAIL: the file $file_to_simulate_removing shal NOT be in the to-fix file anymore"
    test_remove_file_cc=-1
fi

# test for counting
counting_test_cc=0
if [ `grep "Finish: files found: 21, fixed: 15, not fixed: 4" "$test_run_dir/fixpictdate.sh.log" | wc -l` -ne 1 ]; then
    echo "FAIL: counting files from the 1st test run"
    counting_test_cc=-1
fi
if [ `grep "Finish: files found: 29, fixed: 4, not fixed: 5" "$test_run_dir/fixpictdate.sh.log" | wc -l` -ne 1 ]; then
    echo "FAIL: counting files from the 2nd test run"
    counting_test_cc=-1
fi
if [ `grep "Finish: files found: 28, fixed: 0, not fixed: 4" "$test_run_dir/fixpictdate.sh.log" | wc -l` -ne 1 ]; then
    echo "FAIL: counting files from the 3rd test run"
    counting_test_cc=-1
fi

# check that the fixed files have the date in all three EXIF date fields
check_fixed_dates "$test_run_dir/fixpictdate.sh.log"
triple_cc=$?

# regression test: a picture with a stale DateTimeDigitized (CreateDate) but
# without a DateTimeOriginal shall get all three date fields set from the
# folder date. This mimics e.g. PhotoPrism which prefers the CreateDate over
# the DateTimeOriginal, so a fix that only wrote DateTimeOriginal was ignored.
echo -e "\nTest stale CreateDate override (PhotoPrism regression)\n"

regress_dir=$test_tmp_dir/regress
rm -rf "$regress_dir"
mkdir -p "$regress_dir/dir2018_11_03"

# a normal picture without any date plus a stale digitization date
cp "$test1_source_dir/dir005/pict008 .jpg" "$regress_dir/dir2018_11_03/pict.jpg"
exiv2 -M"set Exif.Photo.DateTimeDigitized 2021:03:04 05:06:07" "$regress_dir/dir2018_11_03/pict.jpg"
check_cc

# fix the picture date from the folder name
LOGLEVEL=2 ./fixpictdate.sh "$regress_dir"
check_cc

regress_cc=0
regress_file="$regress_dir/dir2018_11_03/pict.jpg"
regress_exp="2018:11:03 12:00"
regress_dto=`exiv2 -K Exif.Photo.DateTimeOriginal -Pv "$regress_file" 2>/dev/null`
regress_dtd=`exiv2 -K Exif.Photo.DateTimeDigitized -Pv "$regress_file" 2>/dev/null`
regress_dtm=`exiv2 -K Exif.Image.DateTime -Pv "$regress_file" 2>/dev/null`
echo "expected:            $regress_exp"
echo "DateTimeOriginal:    ${regress_dto:0:16}"
echo "DateTimeDigitized:   ${regress_dtd:0:16}"
echo "Image DateTime:      ${regress_dtm:0:16}"
if [ "${regress_dto:0:16}" = "$regress_exp" ] && [ "${regress_dtd:0:16}" = "$regress_exp" ] && [ "${regress_dtm:0:16}" = "$regress_exp" ]; then
    echo OK
else
    echo FAIL
    regress_cc=-1
fi

# check all test results
if [ "$test1_cc" -eq 0 ] && [ "$test1_rr_cc" -eq 0 ] \
    && [ "$test2_cc" -eq 0 ] && [ "$cached2" -gt 0 ] \
    && [ "$test_remove_file_cc" -eq 0 ] \
    && [ "$triple_cc" -eq 0 ] && [ "$regress_cc" -eq 0 ]; then 
    echo -e "\nTotal Test result: OK"
else 
    echo -e "\nTotal Test result: FAIL"
fi
