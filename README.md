# fixpictdate
the script tries to fix the missing picture creation date in JPEG files

# application
The are several occasions where the picture creation date is either not stored in the jpeg file (for example during the conversion from the raw file) or was removed from it by intention (for example by posting to the social networks). As many picture databases/managers rely on the picture creation infomation such picture files become invisible for the viewer or at least not visible in the time view. So the provided script is to fix this issue as good as it can be made using automatic approach (see functionality). My idea is that this script is started on the regular basis on directory acting as the main picture storage an repairs the picture date for all new files missing it. Additional the user shall look into "tofix" file produced by script, to manually fix the issue for the files, which could not fixed automaticall. The most convenient fix in this case is to put the picture date into the file name, so the script will fill the internal creation date field of the field during the next run time.  

# prerequesites
the script uses bash and exiftools 

# command line
./fixpictdate.sh <directory_with_pictures>

# functionality
The script goes through all *.jpg and *.jpeg files in the directory and detect those without the picture creation date information.
For those files the script tries to find the mention of the picture date in:
1. the name of the picture,
2. the name of the directory.
If it found it it puts the detected date as the picture creation date into the picture file.
The non fixed files are listed in a "tofix" file in the root of the picture directory.

# performance
The call of the exiftools is relatively time consuming.
And the script calls the exiftools for every picture separately.
So if there are many pictures in the directory the script might run a noticeable amount of time, even hours.
To improve the peformance the script creates a cache file stored in the picture directory,
so called repeately it does the exiftools call only on new/changed files.

# test
There is a test suite for the fuctionality. 
The test script is test.sh and the test data are in the test folder.

