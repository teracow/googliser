![icon](images/icon.png) googliser.sh
---
This is a **[BASH](https://en.wikipedia.org/wiki/Bash_\(Unix_shell\))** script to perform fast image downloads sourced from **[Google Images](https://www.google.com/imghp?hl=en)** based upon a user-specified search-phrase. It's a web-page scraper that feeds a list of image URLs to **[Wget](https://en.wikipedia.org/wiki/Wget)** to download images in parallel then combines them into a gallery image. The idea is to build a picture of a phrase. 

(This is an expansion upon a solution provided by [ShellFish](https://stackoverflow.com/questions/27909521/download-images-from-google-with-command-line) and has been updated to handle Google page-code that was changed in April 2016.)

---
###**Description:**

1. The user supplies a search-phrase and some other optional parameters on the command line. 

2. A sub-directory is created below the current directory with the name of this search-phrase.

3. [Google Images](https://www.google.com.au/imghp?hl=en) is then queried and the results saved.

4. The results are parsed and all image links are extracted and saved to a URL list file. Any links for **YouTube** and **Vimeo** are removed.

5. The script then iterates through this URL list and downloads the first [**n**]umber of available images into this sub-directory. Up to **1,000** images can be requested. Up to [**p**]arallel images can be downloaded at the same time.  If an image is unavailable, the script skips it and continues downloading until it has acquired the required number of images or the [**f**]ailure limit is reached. 

6. Lastly, a thumbnail gallery image is built using [ImageMagick](http://www.imagemagick.org)'s **montage** into a [PNG](https://en.wikipedia.org/wiki/Portable_Network_Graphics) file.

---
###**Sample Outputs:**

These images have been scaled down for easier distribution.

    $ ./googliser.sh --phrase "puppies" --title 'Puppies!' --upper-size 100000 --lower-size 2000 --failures 0
![puppies](images/googliser\-gallery\-\(puppies\)-s.png)

    $ ./googliser.sh -n 380 -p "cows" -u 250000 -l 10000 -f 0 -k
![cows](images/googliser\-gallery\-\(cows\)\-s.png)  

---
###**Usage:**

    $ ./googliser.sh [PARAMETERS] ...

Allowable parameters are indicated with a hyphen then a single character or the alternative form with 2 hypens and the full-text. Single character parameters (without arguments) can be concatenated. e.g. `-cdeghkqsv`. Parameters can be specified as follows:  


***Required***

`-p` or `--phrase [STRING]`  
The search-phrase to look for. Enclose whitespace in quotes e.g. *"small brown cows"*  


***Optional***

`-a` or `--parallel [INTEGER]`  
How many parallel image downloads? Default is 8. Maximum is 40.

`-c` or `--colour`  
Display with nice ANSI coloured text. 

`-d` or `--debug`  
Put the debug log into the image sub-directory afterward. If selected, debugging output is appended to '**debug.log**' in the image sub-directory. This file is always created in the temporary build directory. Great for finding out what external commands and parameters were used!

`-e` or `--delete-after`  
Delete the downloaded images after building the thumbnail gallery. Umm, don't specify this and `--no-gallery` at the same time.

`-f` or `--failures [INTEGER]`  
How many download failures before exiting? Default is 40. Enter 0 for unlimited (this can potentially try to download every result so only use this if there are many failures).

`-g` or `--no-gallery`  
Don't create a thumbnail gallery. Err, don't specify this and `--delete-after` at the same time.

`-h` or `--help`  
Display this help then exit.

`-i` or `--title [STRING]`  
Specify a custom title for the gallery. Default is to use the search-phrase. Enclose whitespace in quotes e.g. *'This is what cows look like!'*

`-k` or `--skip-no-size`  
Some servers do not report a byte file-size, so this parameter will ensure these image files are not downloaded. Specifying this will speed up downloading but will generate more failures.

`-l` or `--lower-size [INTEGER]`  
Only download image files larger than this many bytes. Some servers do not report a byte file-size, so these will be downloaded anyway and checked afterward (unless `-k --skip-no-size` is specified). Default is 1,000 bytes. I've found this setting useful for skipping files sent by servers that give me HTML instead of the JPG I requested. ![smiley](images/smiley.png)

`-n` or `--number [INTEGER]`  
Number of images to download. Default is 25. Maximum is 1,000.

`-q` or `--quiet`  
Suppress standard display output. Error messages are still shown.

`-r` or `--retries [INTEGER]`  
Number of download retries for each image. Default is 3. Maximum is 100.

`-s` or `--save-links`  
Put the URL results file into the image sub-directory afterward. If selected, the URL list will be found in '**download.links.list**' in the image sub-directory. This file is always created in the temporary build directory.

`-t` or `--timeout [INTEGER]`  
Number of seconds before Wget gives up. Default is 15. Maximum is 600 (10 minutes).

`-u` or `--upper-size [INTEGER]`  
Only download image files smaller than this many bytes. Some servers do not report a byte file-size, so these will be downloaded anyway and checked afterward (unless `-k --skip-no-size` is specified). Default is 0 (unlimited).

`-v` or `--version`  
Show script version then exit.

`-z` or `--lightning`  * in development - non-functional in this release *  
Lightning mode! This cancels slow downloads which really speeds things up!

**Usage Examples:**

    $ ./googliser.sh -p "cows"
This will download the first 25 available images for the search-phrase *"cows"*

    $ ./googliser.sh --number 250 --phrase "kittens" --parallel 12 --failures 0
This will download the first 250 available images for the search-phrase *"kittens"*, download up to 12 images at once and ignore the failures limit.

    $ ./googliser.sh --number 56 --phrase "fish" --upper-size 50000 --lower-size 2000 --failures 0 --debug
This will download the first 56 available images for the search-phrase *"fish"* but only if the image files are between 2KB and 50KB in size, ignore the failures limit and write a debug file.

    $ ./googliser.sh -n 80 -p "storm clouds" -dscg
This will download the first 80 available images for the search-phrase *"storm clouds"*, ensure that both the debug and URL links files are placed in the target directory, use coloured display output and won't create a thumbnail gallery.

---
###**Return Values ($?):**  

0 : success!  
1 : required external program unavailable.  
2 : specified parameter incorrect - help shown.  
3 : unable to create sub-directory for 'search-phrase'.  
4 : could not get a list of search results from Google.  
5 : image download aborted as failure-limit was reached or ran out of images.  
6 : thumbnail gallery build failed.  
7 : unable to create a temporary build directory.

---
###**Notes:**

- To download 1,000 images, you need to be lucky enough for Google to find 1,000 results for your search term, and for those images to be available for download. I sometimes get more failed downloads than successful downloads (depending on what I'm searching for). In practice, I've never actually had Google return 1,000 results. Best was about 986.

- Only [PNG](https://en.wikipedia.org/wiki/Portable_Network_Graphics), [JPG](https://en.wikipedia.org/wiki/JPEG) (& [JPEG](https://en.wikipedia.org/wiki/JPEG)), [GIF](https://en.wikipedia.org/wiki/GIF) and [PHP](https://en.wikipedia.org/wiki/PHP) files are available for download.

- If **identify** (from ImageMagick) is installed, every downloaded file is checked to ensure that it is actually an image. Every file is renamed according to the image type determined by **identify**. If ImageMagic is not available, then no type-checking occurs.

- Every link that cannot be downloaded, or is outside the specified byte-size range, counts as a 'failure'. A good way to see lots of failures quickly is to specify a narrow byte-size range. e.g. `--lower-size 12000 --upper-size 13000`.

- The failures percentage shown after download is the number of failed downloads as a percentage of the total number of image downloads attempted - this includes successful downloads. e.g. 25 images downloaded OK with 8 download failures yields a total of 33 downloads attempted. And 8 / 33 = **24%**.

- The final search results count is determined by adding together the number of images required (default is 25) with the number of allowable failures (default is 40). Search results initially download in groups of 100. So, for the defaults shown, the script downloads the first group of 100. Then trims it so only the first 65 results remain. Then downloads these as images. Results can be shorter though depending on other factors such as URLs returned with invalid names, Google not sending many results from the requested search, etc... The URL results list is only trimmed after dealing with these issues. The count can also change between searches as Google don't always return the same results - even for identical searches.

- When the gallery is being built, it will only create a thumbnail from the first image of a multi-image file (like an animated **GIF**).

- The thumbnail sizes in the gallery are no larger than 400 x 400 pixels. At least one dimension will be 400 pixels, though. So, requesting more images will result in a gallery image with larger dimensions.

- Thumbnail gallery building can be disabled if not required by using `-g --no-gallery`. Why? As a test, I built from 380 images (totalling 32.6MB) which created a single gallery image file that is 201MB with dimensions of 8,064 x 7,876 (63.5MP). This took **montage** a bit over 20 minutes to render on my old Atom D510 CPU. ![smiley](images/smiley.png)

- Typically, downloads run quite fast and then get slower as the required number of images is reached due to less parallel Wgets running (which I'll refer to as download slots). Sometimes downloads will appear to stall, as all the download slots are being held up by servers that are not responding/slow to respond or are downloading very large files. New download slots won't open up until at least one of these completes, fails or times-out. If you download a large enough number of files, all the download slots can end up like this. This is perfectly normal behaviour and the problem will sort itself out. Grab a coffee.

- Sometimes, you may also see a slowdown when downloading the last image (e.g. when something like 24 out of 25 images have downloaded without issue). This leaves only one download slot available to use. However, this slot keeps encountering a series of problem links (as mentioned above) and so can take some time to get that last image as the script works it way through the links list. Grab a danish to go with that coffee. ![smiley](images/smiley.png)

- I wrote this scraper so that users do not need to obtain an API key from Google to download multiple images. 

- It uses [GNU Wget](https://en.wikipedia.org/wiki/Wget) as I think it's more widely available than alternatives such as [cURL](https://github.com/curl/curl).

- The temporary build directory is `/dev/shm/googliser.PID.UNIQ` where PID is shown in the title of the script when it runs and UNIQ will be any 3 random alpha-numeric characters. 

- This script will need to be updated from time-to-time as Google periodically change their search results page-code. The last functional check of this script by me was on 2017-01-05. The latest copy can be found **[here](https://github.com/teracow/googliser)**.  

---
###**Development Environment:**

- [openSUSE](https://www.opensuse.org/) - *13.2 64b*
- GNU BASH - *v4.2.53*
- GNU sed - *v4.2.2*
- GNU grep - *v2.20*
- GNU Wget - *v1.16*
- [ImageMagick](http://www.imagemagick.org) - *v6.9.6-6 Q16 x86_64 2016-12-02*
- Kate - *v3.14.9*
- [ReText](https://github.com/retext-project/retext) - *v5.0.0*
- Konsole - *v2.14.2*
- KDE Development Platform - *v4.14.9*
- QT - *v5.4.2*
- [Find Icons](http://findicons.com/icon/131388/search) - script icon

**Also tested on:**

- [openSUSE](https://www.opensuse.org/) - *LEAP 42.1 64b*
- [Ubuntu](http://www.ubuntu.com/) - *14.04.5 LTS 64b*

Suggestions / comments / bug reports / advice (are|is) most welcome. :) [email me](mailto:teracow@gmail.com)

---
###**Known Issues:**

- (2017-01-05) - None.

---
###**Work-in-Progress:**

- (2017-01-05) - working on new 'lightning' mode.
 
---
###**To-Do List:**

- (2017-01-05) - None.
