#!/bin/bash

# the path to the dir with the test pictures
test_source_dir=./test/picts
# the path to the temporary dir
test_tmp_dir=./tmp
# the path to the dir to run the test in
test_run_dir=$test_tmp_dir/test
# the file with the test expectations
expectations_file=./test/expectations.txt

# (re-)create the test dir
rm -rf "$test_run_dir"
mkdir -p "$test_run_dir"
cp -p -r "$test_source_dir"/* "$test_run_dir"

# run the main script in the test dir
./fixpictdate.sh "$test_run_dir"

# iterate over the expectations and compare the with the real results
declare -a expectation_arr
result=OK
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
