#! /bin/bash
pict_dir=`realpath $1`

log_file="$pict_dir/$0.log"

# name of the cache file
pictmap_file=fixpictdate_cache.txt

# name of the file with the cases
# which need to be fixed manually
tofix_file=fixpictdate_tofix.txt

# patterns to apply to file and dir names to detect the date
# pattern to detect date and time (with seconds)
pattern_date_time_seconds='^.*(199[0-9]|200[0-9]|201[0-9]|2020)[-_]*([01][0-9])[-_]*([0-3][0-9])[-_]*([0-2][0-9])[-_]*([0-6][0-9])[-_]*([0-9][0-9]).*$'
# pattern to detect date and time (without seconds)
pattern_date_time='^.*(199[0-9]|200[0-9]|201[0-9]|2020)[-_]*([01][0-9])[-_]*([0-3][0-9])[-_]*([0-2][0-9])[-_]*([0-6][0-9]).*$'
# 2nd pattern to detect date if the 1st was not successful
pattern_date='^.*(199[0-9]|200[0-9]|201[0-9]|2020)[-_]*([01][0-9])[-_]*([0-3][0-9]).*$'
# 3rd pattern to detect month if the 2nd was not successful
pattern_month='^.*(199[0-9]|200[0-9]|201[0-9]|2020)[-_]*([01][0-9]).*$'

# checks the last complettion code 
# and exits the script if it wasn't 0 
check_cc () {
    cc=$?
    if [ "$cc" -ne "0" ]; then
        exit $cc
    fi
}

log () {
   echo `date "+%Y:%m:%d %H:%M:%S"`: $@ >> "$log_file"
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
    #log "existing info for $1 -> change date: $pictmap_change_date, original date: $pictmap_original_date"
}

# stores the picture info for the file
# into the pictmap
put_pictinfo() {
    #1 param: file path
    #2 param: file change date
    #3 param: picture original date
    local pictmap_line="$2;$3"
    #log "store in pictmap: $1 -> $pictmap_line"
    pictmap[$1]="$pictmap_line" 
}

# tries to fix the missing picture original date
# analysing the file name, the directory name and the file change date
fix_pictdate() {
    local file=$1
    log "try to fix $file"
    local filename=`basename "$file"`
    log "file name: $filename"
    local dir=`dirname "$file"`
    log "file dir: $dir"
    local fix_date_time
    local fix_date
    local fix_month
    if [[ $filename =~ $pattern_date_time_secondds ]]; then
        fix_date_time="${BASH_REMATCH[1]}:${BASH_REMATCH[2]}:${BASH_REMATCH[3]} ${BASH_REMATCH[4]}:${BASH_REMATCH[5]}:${BASH_REMATCH[6]}"
        log "detected the date/time (sec) from file name: $fix_date_time"
    elif [[ $filename =~ $pattern_date_time ]]; then
        fix_date_time="${BASH_REMATCH[1]}:${BASH_REMATCH[2]}:${BASH_REMATCH[3]} ${BASH_REMATCH[4]}:${BASH_REMATCH[5]}"
        log "detected the date/time from file name: $fix_date_time"
    elif [[ $filename =~ $pattern_date ]]; then
        fix_date="${BASH_REMATCH[1]}:${BASH_REMATCH[2]}:${BASH_REMATCH[3]}"
        log "detected the date from the file name: $fix_date"   
    elif [[ $dir =~ $pattern_date ]]; then
        fix_date="${BASH_REMATCH[1]}:${BASH_REMATCH[2]}:${BASH_REMATCH[3]}"
        log "detected the date from the dir name: $fix_date"   
    elif [[ $dir =~ $pattern_month ]]; then
        fix_month="${BASH_REMATCH[1]}:${BASH_REMATCH[2]}"
        log "detected the month from the dir name: $fix_month"
    fi
    if [ -z "$fix_date_time" ]; then
        if [ -n "$fix_date" ]; then
            local change_date=`date "+%Y:%m:%d" -r "$file"`
            log "the file change date is: $change_date"
            if [ "$fix_date" = "$change_date" ]; then
                log "the fix and the change dates are the same so just use the change date/time as the fix date/time"
                fix_date_time=`date "+%Y:%m:%d %H:%M:%S" -r "$file"`
            else
                log "the fix and the chage dates differ so just use the 12:00 as the time"
                fix_date_time="$fix_date 12:00:00"
            fi
        elif [ -n "$fix_month" ]; then
            local change_month=`date "+%Y:%m" -r "$file"`
            log "the file change month is: $change_month"
            if [ "$fix_month" = "$change_month" ]; then
                log "the fix and the change months are the same so just use the change date/time as the fix date/time"
                fix_date_time=`date "+%Y:%m:%d %H:%M:%S" -r "$file"`
            else
                log "the fix and the chage dates differ so just use the first day of the month an the 12:00 as the time"
                fix_date_time="${fix_month}:01 12:00:00"
            fi
        fi
    fi
    if [ -n "$fix_date_time" ]; then
        log "change the file original date to $fix_date_time"
        exiftool -overwrite_original -m "-datetimeoriginal=${fix_date_time}" "${file}" >> "$log_file" 2>&1
        file_original_date=`exiftool -s3 -datetimeoriginal "$file"`
        file_change_date=`date "+%Y:%m:%d %H:%M:%S" -r "$file"`
        put_pictinfo "$file" "$file_change_date" "$file_original_date"
    else
        log "could not detect the date for use for fix"
    fi
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
find . -type f -print0 \( -iname '*.jpg' -o -iname '*.jpeg' \) |
while IFS= read -r -d '' file; do 
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