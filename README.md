# fixpictdate
the script tries to fix the missing picture creation date in JPEG files

# prerequesites
the script uses bash, unix tools and exiv2 

# simple command line
./fixpictdate.sh <directory_with_pictures>

# functionality
The script goes through all *.jpg and *.jpeg files in the directory and detect those without the picture creation date information.
For those files the script tries to find the mention of the picture date in:
1. the name of the picture,
2. the name of the directory.
If it found it it puts the detected date as the picture creation date into the picture file.
The non fixed files are listed in a "tofix" file in the root of the picture directory.

# application
The are several occasions where the picture creation date is either not stored in the jpeg file (for example during the conversion from the raw file) or was removed from it by intention (for example by posting to the social networks). As many picture databases/managers rely on the picture creation infomation such picture files become invisible for the viewer or at least not visible in the time view. So the provided script is to fix this issue as good as it can be made using automatic approach (see functionality). My idea is that this script is started on the regular basis on directory acting as the main picture storage an repairs the picture date for all new files missing it. Additional the user shall look into "tofix" file produced by script, to manually fix the issue for the files, which could not fixed automaticall. The most convenient fix in this case is to put the picture date into the file name, so the script will fill the internal creation date field of the field during the next run time.  

# installation steps

## Windows

1. Install "git for windows". It will also provide the Bash Shell (Git Bash)
2. Install exiv2, the msvc64 variant. Just extract the zip file to any place.
3. Add the <dir-where-you-extracted-exiv2>/bin directory to the PATH windows environment variable
4. Start Git Bash
5. Check the exiv2 is in the PATH by calling "exiv2". Fix the PATH if the programm cannot be found.

## Unix (Debian)

1. install git (sudo apt-get install git
2. install exiv2 (sudo apt-get install exiv2)

## Common part
1. In the Bash shell:
2. Change to the directory you would like to install the fixpictdate into
3. Clone the fixpictate (git clone https://github.com/dimitri-rebrikov/fixpictdate.git)
4. Switch to the fixpictdate subdirectory 
5. Call ./test.sh
6. If the test was not ok, inspect the output and then the ./tmp/test/fixpictdate.sh.log to finde the issue

# performance
The call of the exiv2 is relatively time consuming.
And the script calls the exiv2 for every picture separately.
So if there are many pictures in the directory the script might run a noticeable amount of time, even hours.
To improve the peformance the script creates a cache file stored in the picture directory,
so called next time/repeately it does the exiv2 call only on new/changed files.

# exclude directories
The script uses for the search for picture file the unix' find command. 
It is possible to define several exclusion rules in find's -path syntax
and provide them to the script using the NOTPATH environment variable.
Example: `NOTPATH="*/#recycle/*,*/temp/*,*/tmp/*" ./fixpictdate.sh /path/to/picture/dir` 

# dry run
if an enviroment variable DRYRUN=1 is defined, the script will not change any file but just write into the log file the command it would do without DRYRUN
Example: `DRYRUN=1 ./fixpictdate.sh /path/to/picture/dir` 

# log 
the scripts writes a log file into the picture directory. 
To steer the verbosity of log you can define the LOGLEVEL environment variable.
"1" for the INFO verbosity (default value)
"2" for the DEBUG verbosity 
"3" for the TRACE verbosity
Example: `LOGLEVEL=2 ./fixpictdate.sh /path/to/picture/dir` 


# test
There is a test suite for the fuctionality. 
The test script is test.sh and the test data are in the test folder.

