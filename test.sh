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
        picture_date=`exiftool -s3 -datetimeoriginal  -d '%Y:%m:%d %H:%M' "$test_run_dir/$test_file"`
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

# copy the files for the 1st test
cp -p -r "$test1_source_dir"/* "$test_run_dir"

# run the main script in the test dir
./fixpictdate.sh "$test_run_dir"

check_expectations "$test1_expectations_file"
test1_cc=$?

echo -e "\nSecond test run\n"

# copy the files for the 2nd test
cp -p -r "$test2_source_dir"/* "$test_run_dir"

# re-run the main script in the test dir
./fixpictdate.sh "$test_run_dir"

# retest the 1st expectations as the fix ran in the same directory
check_expectations "$test1_expectations_file"
test1_rr_cc=$?

# retest the 1st expectations as the fix ran in the same directory
check_expectations "$test2_expectations_file"
test2_cc=$?

if [ "$test1_cc" -eq 0 ] && [ "$test1_rr_cc" -eq 0 ] && [ "$test2_cc" -eq 0 ]; then 
    echo "Total Test result: OK"
else 
    echo "Total Test result: FAIL"
fi