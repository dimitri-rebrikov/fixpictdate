#!/bin/bash

test_source_dir=./test/picts
test_tmp_dir=./tmp
test_run_dir=$test_tmp_dir/test
expectations_file=./test/expectations.txt

rm -rf "$test_run_dir"
mkdir -p "$test_run_dir"
cp -r "$test_source_dir"/* "$test_run_dir"

./fixpictdate.sh "$test_run_dir"

