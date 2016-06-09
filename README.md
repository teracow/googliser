### googliser.sh
---
This is a BASH script to perform fast bulk image downloads sourced from **[Google Images](https://www.google.com/imghp?hl=en)** based upon a user-specified search phrase. In short - it's a web-page scraper that feeds a list of image URLs to **[Wget](https://www.gnu.org/software/wget/)** to download images concurrently. 

(This is an expansion upon a solution provided by ShellFish [here](https://stackoverflow.com/questions/27909521/download-images-from-google-with-command-line) and has been updated to handle Google page-code that was changed in April 2016.)

*This script has now replaced* ***bulk-google-image-downloader.sh***

A sub-directory is created below the current directory with the name of the user-specified search-phrase. All image links from this search are saved to a file. The script then iterates through this file and downloads the first [n]umber (user-specified) of available images into this sub-directory. Up to 400 images can be downloaded. If an image is unavailable, the script skips it and continues until it has downloaded the requested amount or its failure-limit is reached (optionally specified). A single thumbnail gallery image is then built using [ImageMagick](http://www.imagemagick.org)'s **montage**.

Thumbnail gallery building is now optional as not everyone will want to do this. As a guide, I built from 380 images (totalling 70MB) and created a single gallery image file that is 191MB with dimensions of 8,004 x 7,676 (61.4MP). This took **montage** 10 minutes to render on my old Atom D510 CPU :)

Any links for **YouTube** and **Vimeo** are removed.

I wrote this so that users do not have to obtain an API key from Google to download multiple images. It also uses **[Wget](https://www.gnu.org/software/wget/)** as I think it's more widely available than alternatives such as [cURL](https://github.com/curl/curl).

**Note:** this script will need to be updated from time-to-time as Google periodically change their search results page-code. The last functional check of this script by me was on 2016-06-08. 

The latest copy of this script can be found [here](https://github.com/teracow/googliser).  

Suggestions / comments / advice (are|is) most welcome. :) [email me](mailto:teracow@gmail.com)

---
**Usage:**

    $ ./googliser.sh [PARAMETERS] ...

Allowable parameters are indicated with a hyphen then a single character or the alternative form with 2 hypens and the full-text:

`-n` or `--number INTEGER`

Number of images to download. Default is 25. Maximum is 400.  

`-p` or `--phrase STRING (required)`

Search phrase to look for. Enclose whitespace in quotes e.g. *"small brown cows"*

`-f` or `--failures INTEGER`

How many download failures before exiting? Default is 10. Enter 0 for unlimited (this may try to download all results - so only use if there are many failures).

`-c` or `--concurrency INTEGER`

How many concurrent image downloads? Default is 8. Maximum is 40. **A higher number will not necessarily download faster!**

`-t` or `--timeout INTEGER`

Number of seconds before retrying download. Default is 15. Maximum is 600 (10 minutes).

`-r` or `--retries INTEGER`

Retry download of each image this many times. Default is 3. Maximum is 100.

`-u` or `--upper-size INTEGER`

Only download image files that are reported by the server to be smaller than this many bytes. Some servers do not report file size, so these will be downloaded anyway and checked afterward. Enter 0 for unlimited size. Default is 0 (unlimited).

`-l` or `--lower-size INTEGER`

Only download image files that are reported by the server to be larger than this many bytes. Some servers do not report file size, so these will be downloaded anyway and checked afterward. Default is 1000 bytes. I've found this useful for ignoring files sent by servers that send HTML instead of the JPG I requested. :)

`-g` or `--no-gallery`

Don't create thumbnail gallery. Default is that script always creates a thumbnail gallery after downloading images.

`-h` or `--help`

Display this help then exit.

`-v` or `--version`

Show script version then exit.

`-q` or `--quiet`

Suppress display output. Error messages are still shown.

`-d` or `--debug`

Append debug info to file. Default is no debug file output. If selected, debugging output is appended to 'googliser-debug.log' in working directory. Great for finding out what commands and parameters were run! :)

**Examples:**

`$ ./googliser.sh -p "cows"`

This will download the first 25 available images for the search phrase *"cows"*

`$ ./googliser.sh --number 250 --phrase "kittens" --concurrency 10 --failures 0`

This will download the first 250 available images for the search phrase *"kittens"* and download up to 10 images at once and ignore the failures limit.

`$ ./googliser.sh --number 56 --phrase "fish and chips" --upper-size 50000 --lower-size 2000 --failures 0 --debug`

This will download the first 56 available images for the search phrase *"fish and chips"* but only if the image files are between 2KB and 50KB in size, ignore the failures limit and write a debug file.

---
**Samples:**

`$ ./googliser.sh --phrase "kittens" --upper-size 100000 --lower-size 2000 --failures 0`

generates this image:

![kittens](http://i.imgur.com/PXcuwkMh.jpg)

---
**Return Values ($?):**  

0 : successful download(s).  
1 : required external program unavailable.  
2 : required parameter incorrect - help / version shown.  
3 : could not create sub-directory for 'search phrase'.  
4 : could not get a list of search results from Google.  
5 : image download aborted as failure-limit was reached.  
6 : thumbnail gallery build failed.

---
**Known Issues:**

- (2016-06-08) None AFAIK.

---
**Work-in-Progress:**

- (2016-06-08) - Gallery titling and background.
 
---
**To-Do List:**

- Check if target directory already has .list file present. Prompt to remove or overwrite?
- Move debug file into target directory?
- Increase results_max to 800 ~ 1200? Need to get next results page.
- Add search phrase as thumbnail gallery title?
