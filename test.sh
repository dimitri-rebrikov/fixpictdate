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
if [ `grep "Finish: files found: 18, fixed: 12, not fixed: 4" "$test_run_dir/fixpictdate.sh.log" | wc -l` -ne 1 ]; then
    echo "FAIL: counting files from the 1st test run"
    counting_test_cc=-1
fi
if [ `grep "Finish: files found: 26, fixed: 4, not fixed: 5" "$test_run_dir/fixpictdate.sh.log" | wc -l` -ne 1 ]; then
    echo "FAIL: counting files from the 2nd test run"
    counting_test_cc=-1
fi
if [ `grep "Finish: files found: 25, fixed: 0, not fixed: 4" "$test_run_dir/fixpictdate.sh.log" | wc -l` -ne 1 ]; then
    echo "FAIL: counting files from the 3rd test run"
    counting_test_cc=-1
fi

# check all test results
if [ "$test1_cc" -eq 0 ] && [ "$test1_rr_cc" -eq 0 ] \
    && [ "$test2_cc" -eq 0 ] && [ "$cached2" -gt 0 ] \
    && [ "$test_remove_file_cc" -eq 0 ]; then 
    echo -e "\nTotal Test result: OK"
else 
    echo -e "\nTotal Test result: FAIL"
fi
