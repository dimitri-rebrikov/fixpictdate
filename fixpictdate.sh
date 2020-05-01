#! /bin/bash
pict_dir=$1

# name of the cache file
pictmap_file=fixpictdate_cache.txt

# name of the file with the cases
# which need to be fixed manually
tofix_file=fixpictdate_tofix.txt

# checks the last complettion code 
# and exits the script if it wasn't 0 
check_cc () {
    cc=$?
    if [ "$cc" -ne "0" ]; then
        exit $cc
    fi
}

log () {
    echo $@
}

# the assotiative array with the picture information
# filepath->file_change_date<\t>picture_original_date
declare -A pictmap

# load the picture info for the file from the pictmap
# into the variable pictmap_change_date and pictmap_original_date
get_pictinfo() {
    #1 param: file path
    local pictmap_line=${pictmap[$1]}
    local -a pictmap_arr
    IFS=$';' read -r -a pictmap_arr <<< "$pictmap_line"
    pictmap_change_date=${pictmap_arr[0]}
    pictmap_original_date=${pictmap_arr[1]}
    log "existing info for $1 -> change date: $pictmap_change_date, original date: $pictmap_original_date"
}

# stores the picture info for the file
# into the pictmap
put_pictinfo() {
    #1 param: file path
    #2 param: file change date
    #3 param: picture original date
    local pictmap_line="$2;$3"
    log "store in pictmap: $1 -> $pictmap_line"
    pictmap[$1]="$pictmap_line" 
}

# tries to fix the missing picture original date
# analysing the file name and the directory
fix_pictdate() {
    local file_name=`basename "$file"`
    log "file name: $file_name"
    # todo try to detect the date/time by the file name
    local file_dir=`dirname "$file"`
    log "file dir: $file_dir"
    # todo if not successful by file name use the dir name

    # todo
    # finaly compare the change date with detected 
    # if they are the same but the detected date is missing the time component -> use the change date as original date 

    # dummy: return "no success"
    return 1
}

cd $pict_dir

log "load the pictmap from the $pictmap_file" 
# file structure: file_path<\t>file_change_date<\t>picture_original_date
if [ -f "$pictmap_file" ]; then
    declare -a pictmap_arr
    while IFS= read -r pictmap_line; do
        log "loading line $pictmap_line"
        pictmap_arr=()
        IFS=$';' read -r -a pictmap_arr <<< "$pictmap_line"
        log "splitted into \"${pictmap_arr[0]}\" \"${pictmap_arr[1]}\" \"${pictmap_arr[2]}\""
        put_pictinfo "${pictmap_arr[0]}" "${pictmap_arr[1]}" "${pictmap_arr[2]}"
    done < "$pictmap_file" 
fi
 
# find all *.jpg or *.jpeg pictures in the folder,
# analyse their original date and try to fix it
for file in `find . -type f \( -iname '*.jpg' -o -iname '*.jpeg' \)` ; do 
    log "processing: $file"
    file_change_date=`date "+%Y:%m:%d %H:%M:%S" -r "$file"`
    log "change date: $file_change_date"
    get_pictinfo "$file" # loads pictmap_change_date and pictmap_original_date
    if [ "$file_change_date" = "$pictmap_change_date" ]; then
        log "file already handled and not changed since that so skip it"
        continue
    fi
    # use exiftool to request the picture original date 
    file_original_date=`exiftool -s3 -datetimeoriginal "$file"`
    check_cc
    log "the original date from file: $file_original_date"
    put_pictinfo "$file" "$file_change_date" "$file_original_date"
    if [ -z "$file_original_date" ]; then
        fix_pictdate "$file"
        if [ "$?" -eq '0' ]; then
            put_pictinfo "$file" "$new_change_date" "$fixed_original_date"
        fi
    fi
done

# store the pictmap (back) into the pictmap file 
# overwriting the old one
echo -n "" > "$pictmap_file"
echo -n "" > "$tofix_file"
for file in "${!pictmap[@]}"; do 
    echo -e "$file;${pictmap[$file]}" >> "$pictmap_file"; 
    get_pictinfo "$file"
    if [ -z "$pictmap_original_date" ]; then
        echo -e "$file;${pictmap[$file]}" >> "$tofix_file";
    fi  
done