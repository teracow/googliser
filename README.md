### googliser.sh
---
This is a BASH script to perform fast bulk image downloads sourced from Google Images based upon a user-specified search phrase. In short - it's a web-page scraper that feeds a list of image URLs to **wget** one-by-one. 

(This is an expansion upon a solution provided by ShellFish [here](https://stackoverflow.com/questions/27909521/download-images-from-google-with-command-line) and has been updated to handle Google page-code that was changed in April 2016.)

This script will replace **bulk-google-image-downloader.sh**

A sub-directory is created below the current directory with the name of the user-specified search-phrase. All image links from this search are saved to a file. The script then iterates through this file and downloads the first [n]umber (user-specified) of available images into this sub-directory. Up to 400 images can be downloaded. If an image is unavailable, the script skips it and continues until it has downloaded the requested amount or its failure-limit is reached (optionally specified). A single gallery image is then built using ImageMagick's **montage**.

As a guide, I built from 380 images (totalling 70MB) and created a single gallery image file that is 191MB with dimensions of 8,004 x 7,676 (61.4MP). This took **montage** 10 minutes to render on my old Atom D510 CPU :) So, I've included an option to disable the gallery build.

Any links for **YouTube** and **Vimeo** are removed.

**Note:** this script will need to be updated from time-to-time as Google periodically change their search results page-code. The last functional check of this script by me was on 2016-06-07. 

The latest copy of this script can be found [here](https://github.com/teracow/googliser).  

Suggestions / comments / advice (are|is) most welcome. :)

---
**Return Values ($?):**  

0 : successful download(s).  
1 : required program unavailable (wget, curl, perl or montage).  
2 : required parameter unspecified or wrong - help shown or version requested.  
3 : could not create sub-directory for 'search phrase'.  
4 : could not get a list of search results from Google.  
5 : image download aborted as failure-limit was reached.  
6 : thumbnail gallery build failed.

---
**Known Issues**

- File naming is non-sequential when different file types have been downloaded. If 'file(3).jpg' exists and next type is a .png, the next file will be named as 'file(3).png' instead of 'file(4).png'. Outcome is that montage may not build gallery in the exact file order required. I'll correct this eventually. :)
 
---
**Work-in-Progress**

- (2016-06-07) - Working on concurrent downloads. This is going quite well. I built [this](https://github.com/teracow/pstracker) this morning so I would have a better understanding of the problems involved in concurrent processes. I'm now working on a version that uses wget. Currently has a tendancy to 'overshoot' the required amount of images. When I solve this, I'll integrate this code into googliser. Best guess is a day or two from now.

---
**To-Do List**

- Parallel downloads? Oh yes, please!
- Check if target directory already has .html and .list files present. Prompt to remove or overwrite these?
- Move debug file into target directory?
- Increase results_max to 800 ~ 1200? Need to get next results page.
