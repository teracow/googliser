![googliser](http://i.imgur.com/yahgjDC.png) googliser.sh
---
This is a BASH script to perform fast image downloads sourced from **[Google Images](https://www.google.com/imghp?hl=en)** based upon a user-specified search-phrase. In short - it's a web-page scraper that feeds a list of image URLs to **[Wget](https://www.gnu.org/software/wget/)** to download images in parallel. The idea is to build a picture of that phrase. 

(This is an expansion upon a solution provided by ShellFish **[here](https://stackoverflow.com/questions/27909521/download-images-from-google-with-command-line)** and has been updated to handle Google page-code that was changed in April 2016.)

---
**Description:**

1. The user supplies a search-phrase and some other optional parameters on the command line. 

2. A sub-directory is created below the current directory with the name of this search-phrase.

3. **[Google Images](https://www.google.com/imghp?hl=en)** is then queried and the results saved.

4. The results are parsed and all image links are extracted and saved to a URL list file. Any links for **YouTube** and **Vimeo** are removed.

5. The script then iterates through this URL list and downloads the first [**n**]umber of available images into this sub-directory. Up to **1,000** images can be requested. Up to [**p**]arallel images can be downloaded at the same time.  If an image is unavailable, the script skips it and continues downloading until it has obtained the required amount of images or its [**f**]ailures limit is reached. 

6. Lastly, a thumbnail gallery image is built using **[ImageMagick](http://www.imagemagick.org)'s montage**.

---
**Notes:**

I wrote this scraper so that users do not need to obtain an API key from Google to download multiple images. It uses **[Wget](https://www.gnu.org/software/wget/)** as I think it's more widely available than alternatives such as **[cURL](https://github.com/curl/curl)**.

Thumbnail gallery building can be disabled if not required. As a guide, I built from 380 images (totalling 70MB) and created a single gallery image file that is 191MB with dimensions of 8,004 x 7,676 (61.4MP). This took **montage** 10 minutes to render on my old Atom D510 CPU :)

When the gallery is being built, it will only create a thumbnail from the first image of a multi-image file (like an animated GIF).

Typically, downloads run quite fast and then get slower as the required number of images is reached due to less parallel Wgets running. Sometimes though, downloads will appear to stall, as all the download slots are being held up by servers that are not responding/slow to respond or are downloading very large files. New download slots won't open up until at least one of these completes, fails or times-out. If you download a large enough number of files, all the download slots can end up like this. This is perfectly normal behaviour and the problem will sort itself out. Please be patient. Grab yourself a coffee.

Another case that I have seen several times is when something like 24 out of 25 images have downloaded without issue. This leaves only one download slot available to use. However, this slot keeps hitting a series of problems (as mentioned above) and so it can take some time to get that last image as the script works it way through the links list. Please be patient. Grab a danish to go with that coffee. **:)**

This script will need to be updated from time-to-time as Google periodically change their search results page-code. The last functional check of this script by me was on 2016-06-12. 

The latest copy can be found **[here](https://github.com/teracow/googliser)**.  

Script icon has been used from **[here](http://www.iconarchive.com/show/social-inside-icons-by-icontexto/social-inside-google-icon.html)**. Please support the artist!

Suggestions / comments / bug reports / advice (are|is) most welcome. :) **[email me](mailto:teracow@gmail.com)**

---
**Usage:**

    $ ./googliser.sh [PARAMETERS] ...

Allowable parameters are indicated with a hyphen then a single character or the alternative form with 2 hypens and the full-text. Parameters can be specified as follows:

`-n` or `--number [INTEGER]`  
Number of images to download. Default is 25. Maximum is 1,000.  

`-p` or `--phrase [STRING]`  
**Required!** The search-phrase to look for. Enclose whitespace in quotes e.g. *"small brown cows"*  

`-f` or `--failures [INTEGER]`  
How many download failures before exiting? Default is 40. Enter 0 for unlimited (this may try to download all results - so only use if there are many failures). In rare circumstances, it is possible for the script to show more failures than this. Worst case would be reported as high as `((failures - 1) + parallel)`. The inevitable consequence of parallel downloads. :) 

`-p` or `--parallel [INTEGER]`  
How many parallel image downloads? Default is 8. Maximum is 40. **Larger is not necessarily faster!**

`-t` or `--timeout [INTEGER]`  
Number of seconds before Wget gives up. Default is 15. Maximum is 600 (10 minutes).

`-r` or `--retries [INTEGER]`  
Number of download retries for each image. Default is 3. Maximum is 100.

`-u` or `--upper-size [INTEGER]`  
Only download image files that are reported by the server to be smaller than this many bytes. Some servers do not report file-size, so these will be downloaded anyway and checked afterward. Enter 0 for unlimited size. Default is 0 (unlimited).

`-l` or `--lower-size [INTEGER]`  
Only download image files that are reported by the server to be larger than this many bytes. Some servers do not report file-size, so these will be downloaded anyway and checked afterward. Default is 1,000 bytes. I've found this setting useful for ignoring files sent by servers that give me HTML instead of the JPG I requested. :)

`-i` or `--title [STRING]`  
Specify a custom title for the gallery. Default is to use the search-phrase.

`-c` or `--colourised`  
Display with ANSI coloured text. Default is no colours. But definitely try it with colours. :)

`-g` or `--no-gallery`  
Don't create a thumbnail gallery.

`-k` or `--links`  
Put the URL results file into sub-directory. If selected, the URL list will be found in 'download.links.list' in the sub-directory. This file is always created in the temporary build directory.

`-q` or `--quiet`  
Suppress display output. Error messages are still shown.

`-h` or `--help`  
Display this help then exit.

`-v` or `--version`  
Show script version then exit.

`-d` or `--debug`  
Put the debug log file into sub-directory. If selected, debugging output is appended to 'debug.log' in the created sub-directory. This file is always created in the temporary build directory. Great for finding out what external commands and parameters were used!

**Usage Examples:**

    $ ./googliser.sh -p "cows"
This will download the first 25 available images for the search-phrase *"cows"*

    $ ./googliser.sh --number 250 --phrase "kittens" --parallel 10 --failures 0
This will download the first 250 available images for the search-phrase *"kittens"* and download up to 10 images at once and ignore the failures limit.

    $ ./googliser.sh --number 56 --phrase "fish and chips" --upper-size 50000 --lower-size 2000 --failures 0 --debug
This will download the first 56 available images for the search-phrase *"fish and chips"* but only if the image files are between 2KB and 50KB in size, ignore the failures limit and write a debug file.

---
**Samples:**

    $ ./googliser.sh --phrase "kittens" --upper-size 100000 --lower-size 2000 --failures 0
![kittens](http://i.imgur.com/vm1eisrh.jpg)

    $ ./googliser.sh -n 400 -p "cows" -u 200000 -l 2000 -f 0
![cows](http://i.imgur.com/SMV2BInh.jpg)  
For this sample, only 249 images were available out of the 381 search results returned. 132 images failed as they were unavailable or their file-size was outside the limits I set. The gallery image is built using however many images are downloaded.

---
**Return Values ($?):**  

0 : success!  
1 : required external program unavailable.  
2 : specified parameter incorrect - help shown.  
3 : unable to create sub-directory for 'search-phrase'.  
4 : could not get a list of search results from Google.  
5 : image download aborted as failure-limit was reached.  
6 : thumbnail gallery build failed.

---
**Known Issues:**

- (2016-06-11) - None.

---
**Work-in-Progress:**

- (2016-06-11) - Bit & pieces...
 
---
**To-Do List:**

- need way to cancel background procs when user cancels. Trap user cancel?
- ignore .php results in list?
- limit download results? 