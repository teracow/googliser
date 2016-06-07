### googliser.sh
---
This is a BASH script to perform fast bulk image downloads sourced from Google Images based upon a user-specified search phrase. In short - it's a web-page scraper that feeds a list of image URLs to **Wget** to download images concurrently. 

(This is an expansion upon a solution provided by ShellFish [here](https://stackoverflow.com/questions/27909521/download-images-from-google-with-command-line) and has been updated to handle Google page-code that was changed in April 2016.)

*This script has now replaced* ***bulk-google-image-downloader.sh***

A sub-directory is created below the current directory with the name of the user-specified search-phrase. All image links from this search are saved to a file. The script then iterates through this file and downloads the first [n]umber (user-specified) of available images into this sub-directory. Up to 400 images can be downloaded. If an image is unavailable, the script skips it and continues until it has downloaded the requested amount or its failure-limit is reached (optionally specified). A single thumbnail gallery image is then built using ImageMagick's **montage**.

Thumbnail gallery building is now optional as not everyone will want to do this. As a guide, I built from 380 images (totalling 70MB) and created a single gallery image file that is 191MB with dimensions of 8,004 x 7,676 (61.4MP). This took **montage** 10 minutes to render on my old Atom D510 CPU :)

Any links for **YouTube** and **Vimeo** are removed.

I wrote this so that users do not have to obtain an API key from Google to download multiple images. It also uses Wget as I think it's more widely available than alternatives such as cURL.

**Note:** this script will need to be updated from time-to-time as Google periodically change their search results page-code. The last functional check of this script by me was on 2016-06-08. 

The latest copy of this script can be found [here](https://github.com/teracow/googliser).  

Suggestions / comments / advice (are|is) most welcome. :)

---
**Usage:**

    $ ./googliser.sh [PARAMETERS] ...

where allowable parameters are indicated with a hyphen then a single character or the alternative form with 2 hypens and the full-text:

`-n` or `--number INTEGER`

Number of images to download. Maximum of 400.  

`-p` or `--phrase STRING (required)`

Search phrase to look for. Enclose whitespace in quotes e.g. "small brown cows"

`-l` or `--limit INTEGER`

How many download failures before exiting? 0 for unlimited (400)."

`-c` or `--concurrency INTEGER`

How many concurrent image downloads? Maximum of 40. Use wisely. More will not necessarily download faster!

`-t` or `--timeout INTEGER`

Number of seconds before retrying download. Maximum of 600 (10 minutes).

`-r` or `--retries INTEGER`

Try to download each image this many times. Maximum of 100.

`-g` or `--no-gallery`

Don't create thumbnail gallery.

`-h` or `--help`

Display this help then exit.

`-v` or `--version`

Show script version then exit.

`-q` or `--quiet`

Suppress display output. (non-functional in this version)

`-d` or `--debug`

Output debug info to file.

**Examples:**

`$ ./googliser.sh -n 20 -p "cows"`

This will download the first 20 available images for the search phrase "cows"

`$ ./googliser.sh --number 250 --phrase "kittens" --concurrency 10`

This will download the first 250 available images for the search phrase "kittens" and download up to 10 images at once.

---
**Return Values ($?):**  

0 : successful download(s).  
1 : required program unavailable (wget, perl or montage).  
2 : required parameter incorrect - help /version shown.  
3 : could not create sub-directory for 'search phrase'.  
4 : could not get a list of search results from Google.  
5 : image download aborted as failure-limit was reached.  
6 : thumbnail gallery build failed.

---
**Known Issues:**

- (2016-06-08) Script is ignoring the set failure-limit due to the new concurrency code inserted yesterday. Hoping to fix that today.
- 'quiet' mode has not been enabled yet. This will supress display output. Low on my list but I'll correct this soon.

---
**Work-in-Progress:**

- (2016-06-08) - Fixing that failure-limit issue ...
 
---
**To-Do List:**

- Check if target directory already has .html and .list files present. Prompt to remove or overwrite these?
- Move debug file into target directory?
- Increase results_max to 800 ~ 1200? Need to get next results page.
- Add search phrase as thumbnail gallery title?
