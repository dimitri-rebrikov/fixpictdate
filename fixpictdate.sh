#! /bin/bash
pict_dir=`realpath $1`

if [ -z "$LOGLEVEL" ]; then
    LOGLEVEL=1
fi

if [ -z "$DRYRUN" ]; then 
    DRYRUN=0
fi

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

# the assotiative array with the picture information
# filepath->file_change_date<\t>picture_original_date
declare -A pictmap

#
# Functions
#

log () {
   echo -e `date "+%Y:%m:%d %H:%M:%S"`: $@ >> "$log_file"
}

log_INFO () {
    if [ "$LOGLEVEL" -ge 1 ]; then
        log "INFO $@"
    fi
}

log_DEBUG () {
    if [ "$LOGLEVEL" -ge 2 ]; then
        log "DEBUG $@"
    fi
}

log_TRACE () {
    if [ "$LOGLEVEL" -ge 3 ]; then
        log "TRACE $@"
    fi
}

# load the picture info for the file from the pictmap
# into the variable pictmap_change_date and pictmap_original_date
get_pictinfo() {
    #1 param: file path
    local pictmap_line=${pictmap[$1]}
    local -a pictmap_arr
    IFS=$';' read -r -a pictmap_arr <<< "$pictmap_line"
    pictmap_change_date=${pictmap_arr[0]}
    pictmap_original_date=${pictmap_arr[1]}
    log_TRACE "existing info for $1 -> change date: $pictmap_change_date, original date: $pictmap_original_date"
}

# stores the picture info for the file
# into the pictmap
put_pictinfo() {
    #1 param: file path
    #2 param: file change date
    #3 param: picture original date
    local pictmap_line="$2;$3"
    log_TRACE "store in pictmap: $1 -> $pictmap_line"
    pictmap[$1]="$pictmap_line" 
}

# loads the DateTimeOriginal into file_original_date variable
load_file_original_date() {
    local file=$1
    file_original_date=`exiv2 -K Exif.Photo.DateTimeOriginal -Pv "$file" 2>> "$log_file"`
    cc=$?
    # cc shall be either 0 (ok) or 1 (no Date found)
    if [ "$cc" -ne "0" ] && [ "$cc" -ne "1" ]; then
        log_INFO "error $cc during exiv2 read call on $file"
        exit 1
    fi 
}

#puts the DateTimeOriginal into the file
set_date_time_original() {
    local file=$1
    local fix_date_time=$2
    log_INFO "set the pict orig date for $file to $fix_date_time"
    local fix_command="exiv2 -M\"set Exif.Photo.DateTimeOriginal ${fix_date_time}\" \"${file}\""
    if [ "$DRYRUN" -ne 1 ]; then
        eval "$fix_command" >> "$log_file" 2>&1
        cc=$?
        # cc shall be 0 (ok)
        if [ "$cc" -ne "0" ]; then
            log_INFO "error $cc during exiv2 write call on $file"
            log_INFO "command: $fix_command"
            exit 1
        fi
    else
        log_INFO "It's dry run, otherwise would do:\n$fix_command"
    fi
}

# tries to fix the missing picture original date
# analysing the file name, the directory name and the file change date
fix_pictdate() {
    local file=$1
    log_DEBUG "try to fix $file"
    local filename=`basename "$file"`
    log_TRACE "file name: $filename"
    local dir=`dirname "$file"`
    log_TRACE "file dir: $dir"
    local fix_date_time
    local fix_date
    local fix_month
    if [[ "$filename" =~ $pattern_date_time_seconds ]]; then
        fix_date_time="${BASH_REMATCH[1]}:${BASH_REMATCH[2]}:${BASH_REMATCH[3]} ${BASH_REMATCH[4]}:${BASH_REMATCH[5]}:${BASH_REMATCH[6]}"
        log_DEBUG "detected the date/time (sec) from file name: $fix_date_time"
    elif [[ "$filename" =~ $pattern_date_time ]]; then
        fix_date_time="${BASH_REMATCH[1]}:${BASH_REMATCH[2]}:${BASH_REMATCH[3]} ${BASH_REMATCH[4]}:${BASH_REMATCH[5]}"
        log_DEBUG "detected the date/time from file name: $fix_date_time"
    elif [[ "$filename" =~ $pattern_date ]]; then
        fix_date="${BASH_REMATCH[1]}:${BASH_REMATCH[2]}:${BASH_REMATCH[3]}"
        log_DEBUG "detected the date from the file name: $fix_date"   
    elif [[ "$dir" =~ $pattern_date ]]; then
        fix_date="${BASH_REMATCH[1]}:${BASH_REMATCH[2]}:${BASH_REMATCH[3]}"
        log_DEBUG "detected the date from the dir name: $fix_date"   
    elif [[ "$dir" =~ $pattern_month ]]; then
        fix_month="${BASH_REMATCH[1]}:${BASH_REMATCH[2]}"
        log_DEBUG "detected the month from the dir name: $fix_month"
    fi
    if [ -z "$fix_date_time" ]; then
        if [ -n "$fix_date" ]; then
            local change_date=`date "+%Y:%m:%d" -r "$file"`
            log_DEBUG "the file change date is: $change_date"
            if [ "$fix_date" = "$change_date" ]; then
                log_DEBUG "the fix and the change dates are the same so just use the change date/time as the fix date/time"
                fix_date_time=`date "+%Y:%m:%d %H:%M:%S" -r "$file"`
            else
                log_DEBUG "the fix and the chage dates differ so just use the 12:00 as the time"
                fix_date_time="$fix_date 12:00:00"
            fi
        elif [ -n "$fix_month" ]; then
            local change_month=`date "+%Y:%m" -r "$file"`
            log_DEBUG "the file change month is: $change_month"
            if [ "$fix_month" = "$change_month" ]; then
                log_DEBUG "the fix and the change months are the same so just use the change date/time as the fix date/time"
                fix_date_time=`date "+%Y:%m:%d %H:%M:%S" -r "$file"`
            else
                log_DEBUG "the fix and the chage dates differ so just use the first day of the month an the 12:00 as the time"
                fix_date_time="${fix_month}:01 12:00:00"
            fi
        fi
    fi
    if [ -n "$fix_date_time" ]; then
        set_date_time_original "$file" "$fix_date_time"
        load_file_original_date "$file"
        file_change_date=`date "+%Y:%m:%d %H:%M:%S" -r "$file"`
        put_pictinfo "$file" "$file_change_date" "$file_original_date"
    else
        log_INFO "could not detect the date for use for fix $file"
    fi
}

#
#  Main code
#

if [ "$DRYRUN" -eq 1 ]; then
    log_INFO "This is a dry run. No files will be changed."
fi

log_INFO "search for pictures in $pict_dir"
cd $pict_dir

declare find_NOTPATH=""
if [ -n "$NOTPATH" ]; then
    log_INFO "exclude directories $NOTPATH"
    IFS=$','
    for notpath_elem in $NOTPATH; do
        find_NOTPATH="$find_NOTPATH -not -path \"$notpath_elem\""
    done <<< "$NOTPATH"
    unset IFS
fi

# file structure: file_path<\t>file_change_date<\t>picture_original_date
if [ -f "$pictmap_file" ]; then
    log_INFO "load existing pictures info from the $pictmap_file" 
    declare -a pictmap_arr
    while IFS= read -r pictmap_line; do
        log_TRACE "loading line $pictmap_line"
        pictmap_arr=()
        IFS=$';' read -r -a pictmap_arr <<< "$pictmap_line"
        log_TRACE "splitted into \"${pictmap_arr[0]}\" \"${pictmap_arr[1]}\" \"${pictmap_arr[2]}\""
        put_pictinfo "${pictmap_arr[0]}" "${pictmap_arr[1]}" "${pictmap_arr[2]}"
    done < "$pictmap_file"
else    
    log_INFO "the file is $pictmap_file not found"
fi

find_command="find . -type f \( -iname '*.jpg' -o -iname '*.jpeg' \) $find_NOTPATH -print0"
log_DEBUG "find command for pictures: $find_command"

# find all *.jpg or *.jpeg pictures in the folder,
# analyse their original date and try to fix it
while IFS= read -r -d '' file; do 
    log_DEBUG "processing: $file"
    file_change_date=`date "+%Y:%m:%d %H:%M:%S" -r "$file"`
    log_DEBUG "change date: $file_change_date"
    get_pictinfo "$file" # loads pictmap_change_date and pictmap_original_date
    if [ "$file_change_date" != "$pictmap_change_date" ]; then
        log_DEBUG "the file is new or was changed"
        load_file_original_date "$file"
    else
        log_DEBUG "the file is known"
        file_original_date=$pictmap_original_date
    fi
    log_DEBUG "the picture original date: $file_original_date"
    put_pictinfo "$file" "$file_change_date" "$file_original_date"
    if [ -z "$file_original_date" ]; then
        fix_pictdate "$file"
    fi
done < <( eval "$find_command" )

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

sort -o "$pictmap_file" "$pictmap_file"
sort -o "$tofix_file" "$tofix_file"