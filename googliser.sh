#!/usr/bin/env bash

###############################################################################
# googliser.sh
#
# (C)opyright 2016-2019 Teracow Software
#
# If you find this script useful, please send me an email to let me know. :)
#   teracow@gmail.com
#
# The latest copy can be found here [https://github.com/teracow/googliser]
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see http://www.gnu.org/licenses/.
###############################################################################

# return values ($?):
#   0   completed successfully
#   1   required/alternative program unavailable (wget, curl, montage, convert, identify, brew, etc...)
#   2   required parameter unspecified or wrong
#   3   could not create output directory for 'phrase'
#   4   could not get a list of search results from Google
#   5   image download failure limit was reached or URL links list has been exhausted
#   6   thumbnail gallery building failed
#   7   unable to create a temporary build directory

# debug log first characters notation:
#   >>  child process forked
#   <<  child process ended
#   \\  function entry
#   //  function exit
#   VV  variable value
#   ??  other value
#   ==  execution
#   ~~  variable was reset within bounds
#   $$  success
#   xx  warning
#   !!  failure
#   TT  elapsed time
#   ##  comment

Init()
    {

    # script constants
    local SCRIPT_VERSION=191111
    SCRIPT_FILE=googliser.sh
    IMAGE_FILE_PREFIX=google-image
    GALLERY_FILE_PREFIX=googliser-gallery
    DEBUG_FILE=debug.log
    USERAGENT='--user-agent "Mozilla/5.0 (X11; Linux x86_64; rv:70.0) Gecko/20100101 Firefox/70.0"'
    local SCRIPT_VERSION_PID="v:$SCRIPT_VERSION PID:$$"
    SCRIPT_STARTSECONDS=$(date +%s)

    # parameter default constants
    FAIL_LIMIT_DEFAULT=32
    GALLERY_BORDER_PIXELS_DEFAULT=30
    IMAGES_REQUESTED_DEFAULT=16
    LOWER_SIZE_BYTES_DEFAULT=1000
    PARALLEL_LIMIT_DEFAULT=64
    THUMBNAIL_DIMENSIONS_DEFAULT=400x400
    TIMEOUT_SECONDS_DEFAULT=30
    UPPER_SIZE_BYTES_DEFAULT=0
    RETRIES_DEFAULT=3

    # limits
    GOOGLE_RESULTS_MAX=1000
    PARALLEL_MAX=512
    TIMEOUT_SECONDS_MAX=600
    RETRIES_MAX=100

    # script-variables
    fail_limit=$FAIL_LIMIT_DEFAULT
    gallery_images_required=$IMAGES_REQUESTED_DEFAULT   # number of images to build gallery with. This is ideally same as $user_images_requested except when performing random (single) image download.
    max_results_required=$((IMAGES_REQUESTED_DEFAULT+FAIL_LIMIT_DEFAULT))
    script_details_colour="$(ColourBackgroundBlack " $(ColourTextBrightWhite "$SCRIPT_FILE")")$(ColourBackgroundBlack " $SCRIPT_VERSION_PID ")"
    script_details_plain=" $SCRIPT_FILE $SCRIPT_VERSION_PID "
    imagelinks_file=download.links.list
    gallery_title=''
    current_path="$PWD"
    exitcode=0

    # script-variable flags
    target_path_created=false

    # user-variable parameters
    gallery_border_pixels=$GALLERY_BORDER_PIXELS_DEFAULT
    lower_size_bytes=$LOWER_SIZE_BYTES_DEFAULT
    parallel_limit=$PARALLEL_LIMIT_DEFAULT
    retries=$RETRIES_DEFAULT
    thumbnail_dimensions=$THUMBNAIL_DIMENSIONS_DEFAULT
    timeout_seconds=$TIMEOUT_SECONDS_DEFAULT
    upper_size_bytes=$UPPER_SIZE_BYTES_DEFAULT
    user_images_requested=$IMAGES_REQUESTED_DEFAULT
    user_fail_limit=$fail_limit

    # user-variable options
    always_download=false
    compact_gallery=false
    debug=false
    delete_after=false
    display_colour=true
    exact_search=false
    install_googliser=false
    lightning_mode=false
    links_only=false
    no_gallery=false
    race=false
    random_image=false
    reindex_rename=false
    safesearch=true
    save_links=false
    show_help=false
    skip_no_size=false
    verbose=true

    # user-variable strings
    aspect_ratio=''
    exclude_links_pathfile=''
    exclude_words=''
    image_colour=''
    image_format=''
    image_type=''
    input_links_pathfile=''
    input_phrases_pathfile=''
    min_pixels=''
    output_path=''
    recent=''
    usage_rights=''
    user_gallery_title=''
    user_phrase=''
    search_phrase=''
    sites=''

    BuildWorkPaths
    FindPackageManager

    DebugScriptEntry
    DebugScriptNow
    DebugScriptVal 'version' "$SCRIPT_VERSION"
    DebugScriptVal 'PID' "$$"

    }

InstallGoogliser()
    {

    echo -e " -> installing googliser ...\n"

    SUDO='sudo'
    if [[ $EUID -eq 0 ]]; then
        SUDO=''
    fi

    case "$OSTYPE" in
        "darwin"*)
            xcode-select --install
            ruby -e "$(curl -fsSL git.io/get-brew)"
            brew install coreutils ghostscript gnu-sed imagemagick gnu-getopt
            ;;
        "linux"*)
            if [[ $PACKAGER_BIN != unknown ]]; then
                $SUDO "$PACKAGER_BIN" install wget imagemagick
            else
                echo "Unsupported package manager. Please install the dependencies manually"
                exit 1
            fi
            ;;
        *)
            echo "Unidentified platform. Please create a new issue for this on GitHub: https://github.com/teracow/googliser/issues"
            exit 1
            ;;
    esac
    $SUDO ln -sf "$PWD/$SCRIPT_FILE" /usr/local/bin/googliser

    }

FindPackageManager()
    {

    case "$OSTYPE" in
        "darwin"*)
            PACKAGER_BIN=$(command -v brew)
            ;;
        "linux"*)
            if ! PACKAGER_BIN=$(command -v apt); then
                if ! PACKAGER_BIN=$(command -v yum); then
                    if ! PACKAGER_BIN=$(command -v opkg); then
                        PACKAGER_BIN=''
                    fi
                fi
            fi
            ;;
        *)
            echo "Unidentified platform. Please create a new issue for this on GitHub: https://github.com/teracow/googliser/issues"
            exit 1
            ;;
    esac

    [[ -z $PACKAGER_BIN ]] && PACKAGER_BIN=unknown

    }

BuildWorkPaths()
    {

    Flee()
        {

        echo "! Unable to create a temporary build directory! Exiting."; exit 7

        }

    local test_file=test-image          # used during image filesize testing

    TEMP_PATH=$(mktemp -d "/tmp/${SCRIPT_FILE%.*}.$$.XXX") || Flee

    results_run_count_path="$TEMP_PATH/results.running.count"
    mkdir -p "$results_run_count_path" || Flee

    results_success_count_path="$TEMP_PATH/results.success.count"
    mkdir -p "$results_success_count_path" || Flee

    results_fail_count_path="$TEMP_PATH/results.fail.count"
    mkdir -p "$results_fail_count_path" || Flee

    download_run_count_path="$TEMP_PATH/download.running.count"
    mkdir -p "$download_run_count_path" || Flee

    download_success_count_path="$TEMP_PATH/download.success.count"
    mkdir -p "$download_success_count_path" || Flee

    download_fail_count_path="$TEMP_PATH/download.fail.count"
    mkdir -p "$download_fail_count_path" || Flee

    testimage_pathfile="$TEMP_PATH/$test_file"
    searchresults_pathfile="$TEMP_PATH/search.results.page.html"
    gallery_title_pathfile="$TEMP_PATH/gallery.title.png"
    gallery_thumbnails_pathfile="$TEMP_PATH/gallery.thumbnails.png"
    gallery_background_pathfile="$TEMP_PATH/gallery.background.png"
    imagelinks_pathfile="$TEMP_PATH/$imagelinks_file"
    debug_pathfile="$TEMP_PATH/$DEBUG_FILE"

    unset -f Flee

    }

EnvironmentOK()
    {

    # checks and logs runtime environment
    # $? = 0 if OK, 1 if not

    DebugFuncEntry
    local func_startseconds=$(date +%s)

    WhatAreMyArgs

    if [[ $install_googliser = true ]]; then
        InstallGoogliser
        return 1
    fi

    if [[ $verbose = true ]]; then
        if [[ $display_colour = true ]]; then
            echo "$script_details_colour"
        else
            echo "$script_details_plain"
        fi
    fi

    if [[ $user_parameters_result -ne 0 || $user_parameters = ' --' ]]; then
        DisplayBasicHelp
        exitcode=2
        return 1
    fi

    if [[ $show_help = true ]]; then
        DisplayBasicHelp
        DisplayFullHelp
        return 1
    fi

    ValidateParams

    if [[ $exitcode -eq 0 ]]; then
        DebugFuncComment 'runtime parameters after validation and adjustment'
        DebugFuncVar always_download
        DebugFuncVar aspect_ratio
        DebugFuncVar compact_gallery
        DebugFuncVar debug
        DebugFuncVar delete_after
        DebugFuncVar display_colour
        DebugFuncVar exact_search
        DebugFuncVar exclude_links_pathfile
        DebugFuncVar exclude_words
        DebugFuncVar image_colour
        DebugFuncVar image_format
        DebugFuncVar image_type
        DebugFuncVar input_phrases_pathfile
        DebugFuncVar input_links_pathfile
        DebugFuncVar gallery_border_pixels
        DebugFuncVar gallery_images_required
        DebugFuncVar lightning_mode
        DebugFuncVar links_only
        DebugFuncVar lower_size_bytes
        DebugFuncVar min_pixels
        DebugFuncVar no_gallery
        DebugFuncVar output_path
        DebugFuncVar parallel_limit
        DebugFuncVar race
        DebugFuncVar random_image
        DebugFuncVar recent
        DebugFuncVar reindex_rename
        DebugFuncVar retries
        DebugFuncVar safesearch
        DebugFuncVar save_links
        DebugFuncVar sites
        DebugFuncVar skip_no_size
        DebugFuncVar thumbnail_dimensions
        DebugFuncVar timeout_seconds
        DebugFuncVar upper_size_bytes
        DebugFuncVar usage_rights
        DebugFuncVar user_fail_limit
        DebugFuncVar user_images_requested
        DebugFuncVar verbose
        DebugFuncComment 'internal parameters'
        DebugFuncVar ORIGIN
        DebugFuncVar OSTYPE
        DebugFuncVar GOOGLE_RESULTS_MAX
        DebugFuncVar PACKAGER_BIN
        DebugFuncVar TEMP_PATH
        DebugFuncVar max_results_required

        if ! DOWNLOADER_BIN=$(command -v wget); then
            if ! DOWNLOADER_BIN=$(command -v curl); then
                SuggestInstall wget
                exitcode=1
                return 1
            fi
        fi

        DebugFuncVar DOWNLOADER_BIN

        if [[ $no_gallery = false && $show_help = false ]]; then
            if ! MONTAGE_BIN=$(command -v montage); then
                SuggestInstall montage imagemagick
                exitcode=1
                return 1
            elif ! CONVERT_BIN=$(command -v convert); then
                SuggestInstall convert imagemagick
                exitcode=1
                return 1
            fi
        fi

        DebugFuncVar MONTAGE_BIN
        DebugFuncVar CONVERT_BIN

        ! IDENTIFY_BIN=$(command -v identify) && DebugScriptWarn "no recognised 'identify' binary was found"

        DebugFuncVar IDENTIFY_BIN

        trap CTRL_C_Captured INT
    fi

    DebugFuncElapsedTime "$func_startseconds"
    DebugFuncExit

    return 0

    }

WhatAreMyArgs()
    {

    DebugFuncVar user_parameters_raw

    eval set -- "$user_parameters"

    while true; do
        case $1 in
            --always-download|-A)
                always_download=true
                shift
                ;;
            --aspect-ratio|-a)
                aspect_ratio=$2
                shift 2
                ;;
            --border-thickness|-b)
                gallery_border_pixels=$2
                shift 2
                ;;
            --colour|--color)
                image_colour=$2
                shift 2
                ;;
            --condensed|-C)
                compact_gallery=true
                shift
                ;;
            --debug|-d)
                debug=true
                shift
                ;;
            --delete-after|-D)
                delete_after=true
                shift
                ;;
            --exact-search|-E)
                exact_search=true
                shift
                ;;
            --exclude-links)
                exclude_links_pathfile=$2
                shift 2
                ;;
            --exclude-words)
                exclude_words=$2
                shift 2
                ;;
            --failures|-f)
                user_fail_limit=$2
                shift 2
                ;;
            --format)
                image_format=$2
                shift 2
                ;;
            --help|-h)
                show_help=true
                exitcode=2
                return 1
                ;;
            --input-links)
                input_links_pathfile=$2
                shift 2
                ;;
            --input-phrases|-i)
                input_phrases_pathfile=$2
                shift 2
                ;;
            --install)
                install_googliser=true
                return 0
                ;;
            --lightning|-z)
                lightning_mode=true
                shift
                ;;
            --links-only|-L)
                links_only=true
                shift
                ;;
            --lower-size|-l)
                lower_size_bytes=$2
                shift 2
                ;;
            --minimum-pixels|-m)
                min_pixels=$2
                shift 2
                ;;
            --no-colour|--no-color)
                display_colour=false
                shift
                ;;
            --no-gallery|-N)
                no_gallery=true
                shift
                ;;
            --no-safesearch)
                safesearch=false
                shift
                ;;
            --number|-n)
                user_images_requested=$2
                shift 2
                ;;
            --output|-o)
                output_path=$2
                shift 2
                ;;
            --parallel|-P)
                parallel_limit=$2
                shift 2
                ;;
            --phrase|-p)
                user_phrase=$2
                shift 2
                ;;
            --quiet|-q)
                verbose=false
                shift
                ;;
            --race)
                race=true
                shift
                ;;
            --random)
                random_image=true
                shift
                ;;
            --recent|-R)
                recent=$2
                shift 2
                ;;
            --reindex-rename)
                reindex_rename=true
                shift
                ;;
            --retries|-r)
                retries=$2
                shift 2
                ;;
            --save-links|-s)
                save_links=true
                shift
                ;;
            --sites)
                sites=$2
                shift 2
                ;;
            --skip-no-size|-S)
                skip_no_size=true
                shift
                ;;
            --thumbnails)
                thumbnail_dimensions=$2
                shift 2
                ;;
            --timeout|-t)
                timeout_seconds=$2
                shift 2
                ;;
            --title|-T)
                if [[ $(Lowercase "$2") = false ]]; then
                    user_gallery_title='_false_'
                else
                    user_gallery_title=$2
                fi
                shift 2
                ;;
            --type)
                image_type=$2
                shift 2
                ;;
            --upper-size|-u)
                upper_size_bytes=$2
                shift 2
                ;;
            --usage-rights)
                usage_rights=$2
                shift 2
                ;;
            --)
                shift       # shift to next parameter in $1
                break
                ;;
            *)
                break       # there are no more matching parameters
                ;;
        esac
    done

    return 0

    }

DisplayBasicHelp()
    {

    echo
    if [[ $display_colour = true ]]; then
        message="$(ShowGoogle) $(ColourTextBrightBlue "images")"
    else
        message='Google images'
    fi

    echo " Search '$message' for a number of images matching a phrase, then compile them into a gallery."
    echo

    if [[ $display_colour = true ]]; then
        echo " Usage: $(ColourTextBrightWhite "./$SCRIPT_FILE") [PARAMETERS] ..."
    else
        echo " Usage: ./$SCRIPT_FILE [PARAMETERS] ..."
    fi

    }

DisplayFullHelp()
    {

    local SAMPLE_USER_PHRASE=cows

    echo
    echo " External requirements: Wget or cURL"
    echo " and optionally: identify, montage & convert (from ImageMagick)"
    echo
    echo " Questions or comments? teracow@gmail.com"
    echo
    echo " Mandatory arguments for long options are mandatory for short options too. Defaults values are shown as [n]."
    echo

    if [[ $display_colour = true ]]; then
        echo " $(ColourTextBrightOrange "* Required *")"
    else
        echo " * Required *"
    fi

    FormatHelpLine p phrase "Search for images Google identifies with this phrase. Enclose whitespace in quotes. A sub-directory will be created with this name, unless '--output' is specified."
    echo
    if [[ $display_colour = true ]]; then
        echo " $(ColourTextBrightOrange "* Optional *")"
    else
        echo " * Optional *"
    fi
    FormatHelpLine A always-download "Always download images, no matter what else happens. Unlimited failures!"
    FormatHelpLine a aspect-ratio "Image aspect ratio. Specify like '--aspect-ratio square'. Presets are:"
    FormatHelpLine '' '' "'tall'"
    FormatHelpLine '' '' "'square'"
    FormatHelpLine '' '' "'wide'"
    FormatHelpLine '' '' "'panoramic'"
    FormatHelpLine b border-thickness "Thickness of border surrounding gallery image in pixels [$GALLERY_BORDER_PIXELS_DEFAULT]. Use '0' for no border."
    FormatHelpLine C condensed "Create a condensed thumbnail gallery. All gallery images are square with no tile-padding."
    FormatHelpLine '' 'colour|color' "The dominant image colour [any]. Specify like '--colour green'. Presets are:"
    FormatHelpLine '' '' "'any'"
    FormatHelpLine '' '' "'full' (colour images only)"
    FormatHelpLine '' '' "'black-white' or 'bw'"
    FormatHelpLine '' '' "'transparent' or 'clear'"
    FormatHelpLine '' '' "'red'"
    FormatHelpLine '' '' "'orange'"
    FormatHelpLine '' '' "'yellow'"
    FormatHelpLine '' '' "'green'"
    FormatHelpLine '' '' "'teal' or 'cyan'"
    FormatHelpLine '' '' "'blue'"
    FormatHelpLine '' '' "'purple' or 'magenta'"
    FormatHelpLine '' '' "'pink'"
    FormatHelpLine '' '' "'white'"
    FormatHelpLine '' '' "'gray' or 'grey'"
    FormatHelpLine '' '' "'black'"
    FormatHelpLine '' '' "'brown'"
    FormatHelpLine d debug "Save the runtime debug log [$DEBUG_FILE] into output directory."
    FormatHelpLine D delete-after "Remove all downloaded images, after building thumbnail gallery."
    FormatHelpLine E exact-search "Perform an exact-phrase search only. Disregard Google suggestions and loose matches."
    FormatHelpLine '' exclude-links "The URLs for images successfully downloaded will be appended to this file (if specified). Specify this file again to ensure these URLs are not reused."
    FormatHelpLine '' exclude-words "A comma separated list (without spaces) of words that you want to exclude from the search."
    FormatHelpLine '' format "Only download images encoded in this file format. Specify like '--format svg'. Presets are:"
    FormatHelpLine '' '' "'jpg'"
    FormatHelpLine '' '' "'png'"
    FormatHelpLine '' '' "'gif'"
    FormatHelpLine '' '' "'bmp'"
    FormatHelpLine '' '' "'svg'"
    FormatHelpLine '' '' "'webp'"
    FormatHelpLine '' '' "'ico'"
    FormatHelpLine '' '' "'craw'"
    FormatHelpLine f failures "Total number of download failures allowed before aborting [$FAIL_LIMIT_DEFAULT]. Use '0' for unlimited ($GOOGLE_RESULTS_MAX)."
    FormatHelpLine h help "Display this help."
#    FormatHelpLine '' input-links "A text file containing a list of URLs to download, one URL per line. A Google search will not be performed."
    FormatHelpLine i input-phrases "A text file containing a list of phrases to download, one phrase per line."
    FormatHelpLine '' install "Install all googliser dependencies, and make googliser available globally on CLI."
    FormatHelpLine l lower-size "Only download images that are larger than this many bytes [$LOWER_SIZE_BYTES_DEFAULT]."
    FormatHelpLine L links-only "Compile a list of image URLs, but don't download any images."
    FormatHelpLine m minimum-pixels "Images must contain at least this many pixels. Specify like '-m 8mp'. Presets are:"
    FormatHelpLine '' '' "'qsvga' (400 x 300)"
    FormatHelpLine '' '' "'vga'   (640 x 480)"
    FormatHelpLine '' '' "'svga'  (800 x 600)"
    FormatHelpLine '' '' "'xga'   (1024 x 768)"
    FormatHelpLine '' '' "'2mp'   (1600 x 1200)"
    FormatHelpLine '' '' "'4mp'   (2272 x 1704)"
    FormatHelpLine '' '' "'6mp'   (2816 x 2112)"
    FormatHelpLine '' '' "'8mp'   (3264 x 2448)"
    FormatHelpLine '' '' "'10mp'  (3648 x 2736)"
    FormatHelpLine '' '' "'12mp'  (4096 x 3072)"
    FormatHelpLine '' '' "'15mp'  (4480 x 3360)"
    FormatHelpLine '' '' "'20mp'  (5120 x 3840)"
    FormatHelpLine '' '' "'40mp'  (7216 x 5412)"
    FormatHelpLine '' '' "'70mp'  (9600 x 7200)"
    FormatHelpLine '' '' "'large'"
    FormatHelpLine '' '' "'medium'"
    FormatHelpLine '' '' "'icon'"
    FormatHelpLine n number "Number of images to download [$IMAGES_REQUESTED_DEFAULT]. Maximum of $GOOGLE_RESULTS_MAX."
    FormatHelpLine '' 'no-colour|no-color' "Runtime display will be in boring, uncoloured text. :("
    FormatHelpLine N no-gallery "Don't create a thumbnail gallery after downloading images."
    FormatHelpLine '' no-safesearch "Disable Google's SafeSearch content-filtering. Default is enabled."
    FormatHelpLine o output "The image output directory [phrase]. Enclose whitespace in quotes."
    FormatHelpLine P parallel "How many parallel image downloads? [$PARALLEL_LIMIT_DEFAULT]. Maximum of $PARALLEL_MAX."
    FormatHelpLine q quiet "Suppress stdout. stderr is still shown."
    FormatHelpLine '' race "Race to the finish line! Maximum concurrent downloads (as per '--parallel') will be maintained until the requested number of images are received. Extras are then removed."
    FormatHelpLine '' random "Download a single, random image."
    FormatHelpLine R recent "Only get images published this far back in time [any]. Specify like '--recent month'. Presets are:"
    FormatHelpLine '' '' "'any'"
    FormatHelpLine '' '' "'hour'"
    FormatHelpLine '' '' "'day'"
    FormatHelpLine '' '' "'week'"
    FormatHelpLine '' '' "'month'"
    FormatHelpLine '' '' "'year'"
    FormatHelpLine '' reindex-rename "Reindex and rename downloaded image files into a contiguous block."
    FormatHelpLine r retries "Retry each image download this many times [$RETRIES_DEFAULT]. Maximum of $RETRIES_MAX."
    FormatHelpLine s save-links "Save image URL list to file [$imagelinks_file] into the output directory."
    FormatHelpLine '' sites "A comma separated list (without spaces) of sites or domains from which you want to search the images."
    FormatHelpLine S skip-no-size "Don't download any image if its size cannot be determined before fetching from server."
    FormatHelpLine '' thumbnails "Ensure each gallery thumbnail is not larger than: width x height [$THUMBNAIL_DIMENSIONS_DEFAULT]. Specify like '--thumbnails 200x100'."
    FormatHelpLine t timeout "Number of seconds before aborting each image download [$TIMEOUT_SECONDS_DEFAULT]. Maximum of $TIMEOUT_SECONDS_MAX."
    FormatHelpLine T title "Title for thumbnail gallery image [phrase]. Enclose whitespace in quotes. Use 'false' for no title."
    FormatHelpLine '' type "Image type. Specify like '--type clipart'. Presets are:"
    FormatHelpLine '' '' "'face'"
    FormatHelpLine '' '' "'photo'"
    FormatHelpLine '' '' "'clipart'"
    FormatHelpLine '' '' "'lineart'"
    FormatHelpLine '' '' "'animated'"
    FormatHelpLine u upper-size "Only download images that are smaller than this many bytes [$UPPER_SIZE_BYTES_DEFAULT]. Use '0' for unlimited."
    FormatHelpLine '' usage-rights "Original image usage rights. Specify like '--usage-rights reuse'. Presets are:"
    FormatHelpLine '' '' "'reuse'"
    FormatHelpLine '' '' "'reuse-with-mod'"
    FormatHelpLine '' '' "'noncomm-reuse'"
    FormatHelpLine '' '' "'noncomm-reuse-with-mod'"
    FormatHelpLine z lightning "Download images even faster by using an optimised set of parameters. For when you really can't wait!"
    echo
    echo " Example:"

    if [[ $display_colour = true ]]; then
        ColourTextBrightWhite " $ ./$SCRIPT_FILE -p '$SAMPLE_USER_PHRASE'"
    else
        echo " $ ./$SCRIPT_FILE -p '$SAMPLE_USER_PHRASE'"
    fi

    echo
    echo " This will download the first $IMAGES_REQUESTED_DEFAULT available images for the phrase '$SAMPLE_USER_PHRASE', and build them into a gallery image."
    }

ValidateParams()
    {

    DebugFuncEntry

    if [[ $no_gallery = true && $delete_after = true && $links_only = false ]]; then
        echo
        echo " Hmmm, so you've requested:"
        echo " 1. don't create a gallery,"
        echo " 2. delete the images after downloading,"
        echo " 3. don't save the links file."
        echo " Might be time to (R)ead-(T)he-(M)anual. ;)"
        exitcode=2
        return 1
    fi

    local aspect_ratio_type=''
    local aspect_ratio_search=''
    local image_colour_type=''
    local image_colour_search=''
    local image_type_search=''
    local image_format_search=''
    local min_pixels_type=''
    local min_pixels_search=''
    local recent_type=''
    local recent_search=''
    local usage_rights_type=''
    local usage_rights_search=''

    if [[ $always_download = true || $race = true ]]; then
        user_fail_limit=0
    fi

    if [[ $links_only = true ]]; then
        no_gallery=true
        save_links=true
        user_fail_limit=0
    fi

    if [[ $lightning_mode = true ]]; then
        # Yeah!
        timeout_seconds=1
        retries=0
        skip_no_size=true
        parallel_limit=$PARALLEL_MAX
        links_only=false
        compact_gallery=false
        no_gallery=true
        user_fail_limit=0
        race=true
    fi

    if [[ $compact_gallery = true ]]; then
        no_gallery=false
    fi

    case ${user_images_requested#[-+]} in
        *[!0-9]*)
            DebugScriptFail 'specified $user_images_requested is invalid'
            echo
            ShowFail ' !! number specified after (-n, --number) must be a valid integer'
            exitcode=2
            return 1
            ;;
        *)
            if [[ $user_images_requested -lt 1 ]]; then
                user_images_requested=1
                DebugFuncVarAdjust '$user_images_requested TOO LOW so set to a sensible minimum' "$user_images_requested"
            fi

            if [[ $user_images_requested -gt $GOOGLE_RESULTS_MAX ]]; then
                user_images_requested=$GOOGLE_RESULTS_MAX
                DebugFuncVarAdjust '$user_images_requested TOO HIGH so set as $GOOGLE_RESULTS_MAX' "$user_images_requested"
            fi
            ;;
    esac

    if [[ $random_image = true ]]; then
        gallery_images_required=1
    else
        gallery_images_required=$user_images_requested
    fi

    if [[ -n $input_links_pathfile ]]; then
        if [[ ! -e $input_links_pathfile ]]; then
            DebugScriptFail '$input_links_pathfile was not found'
            echo
            ShowFail ' !! input links file  (--input-links) was not found'
            exitcode=2
            return 1
        fi
    fi

    if [[ -n $input_phrases_pathfile ]]; then
        if [[ ! -e $input_phrases_pathfile ]]; then
            DebugScriptFail '$input_phrases_pathfile was not found'
            echo
            ShowFail ' !! input phrases file  (-i, --input-phrases) was not found'
            exitcode=2
            return 1
        fi
    fi

    if [[ -n $exclude_links_pathfile ]]; then
        [[ ! -e $exclude_links_pathfile ]] && touch "$exclude_links_pathfile"
    fi

    case ${user_fail_limit#[-+]} in
        *[!0-9]*)
            DebugScriptFail 'specified $user_fail_limit is invalid'
            echo
            ShowFail ' !! number specified after (-f, --failures) must be a valid integer'
            exitcode=2
            return 1
            ;;
        *)
            if [[ $user_fail_limit -le 0 ]]; then
                user_fail_limit=$GOOGLE_RESULTS_MAX
                DebugFuncVarAdjust '$user_fail_limit SET TO MAX' "$user_fail_limit"
            fi

            if [[ $user_fail_limit -gt $GOOGLE_RESULTS_MAX ]]; then
                user_fail_limit=$GOOGLE_RESULTS_MAX
                DebugFuncVarAdjust '$user_fail_limit TOO HIGH so set as $GOOGLE_RESULTS_MAX' "$user_fail_limit"
            fi
            ;;
    esac

    case ${parallel_limit#[-+]} in
        *[!0-9]*)
            DebugScriptFail 'specified $parallel_limit is invalid'
            echo
            ShowFail ' !! number specified after (-P, --parallel) must be a valid integer'
            exitcode=2
            return 1
            ;;
        *)
            if [[ $parallel_limit -lt 1 ]]; then
                parallel_limit=$PARALLEL_MAX
                DebugFuncVarAdjust '$parallel_limit SET TO MAX' "$parallel_limit"
            fi

            if [[ $parallel_limit -gt $PARALLEL_MAX ]]; then
                parallel_limit=$PARALLEL_MAX
                DebugFuncVarAdjust '$parallel_limit TOO HIGH so set as' "$parallel_limit"
            fi
            ;;
    esac

    case ${timeout_seconds#[-+]} in
        *[!0-9]*)
            DebugScriptFail 'specified $timeout_seconds is invalid'
            echo
            ShowFail ' !! number specified after (-t, --timeout) must be a valid integer'
            exitcode=2
            return 1
            ;;
        *)
            if [[ $timeout_seconds -lt 1 ]]; then
                timeout_seconds=1
                DebugFuncVarAdjust '$timeout_seconds TOO LOW so set as' "$timeout_seconds"
            fi

            if [[ $timeout_seconds -gt $TIMEOUT_SECONDS_MAX ]]; then
                timeout_seconds=$TIMEOUT_SECONDS_MAX
                DebugFuncVarAdjust '$timeout_seconds TOO HIGH so set as' "$timeout_seconds"
            fi
            ;;
    esac

    case ${retries#[-+]} in
        *[!0-9]*)
            DebugScriptFail 'specified $retries is invalid'
            echo
            ShowFail ' !! number specified after (-r, --retries) must be a valid integer'
            exitcode=2
            return 1
            ;;
        *)
            if [[ $retries -lt 0 ]]; then
                retries=0
                DebugFuncVarAdjust '$retries TOO LOW so set as' "$retries"
            fi

            if [[ $retries -gt $RETRIES_MAX ]]; then
                retries=$RETRIES_MAX
                DebugFuncVarAdjust '$retries TOO HIGH so set as' "$retries"
            fi
            ;;
    esac

    case ${upper_size_bytes#[-+]} in
        *[!0-9]*)
            DebugScriptFail 'specified $upper_size_bytes is invalid'
            echo
            ShowFail ' !! number specified after (-u, --upper-size) must be a valid integer'
            exitcode=2
            return 1
            ;;
        *)
            if [[ $upper_size_bytes -lt 0 ]]; then
                upper_size_bytes=0
                DebugFuncVarAdjust '$upper_size_bytes TOO LOW so set as' "$upper_size_bytes (unlimited)"
            fi
            ;;
    esac

    case ${lower_size_bytes#[-+]} in
        *[!0-9]*)
            DebugScriptFail 'specified $lower_size_bytes is invalid'
            echo
            ShowFail ' !! number specified after (-l, --lower-size) must be a valid integer'
            exitcode=2
            return 1
            ;;
        *)
            if [[ $lower_size_bytes -lt 0 ]]; then
                lower_size_bytes=0
                DebugFuncVarAdjust '$lower_size_bytes TOO LOW so set as' "$lower_size_bytes"
            fi

            if [[ $upper_size_bytes -gt 0 && $lower_size_bytes -gt $upper_size_bytes ]]; then
                lower_size_bytes=$((upper_size_bytes-1))
                DebugFuncVarAdjust "\$lower_size_bytes larger than \$upper_size_bytes ($upper_size_bytes) so set as" "$lower_size_bytes"
            fi
            ;;
    esac

    case ${gallery_border_pixels#[-+]} in
        *[!0-9]*)
            DebugScriptFail 'specified $gallery_border_pixels is invalid'
            echo
            ShowFail ' !! number specified after (-b, --border-thickness) must be a valid integer'
            exitcode=2
            return 1
            ;;
        *)
            if [[ $gallery_border_pixels -lt 0 ]]; then
                gallery_border_pixels=0
                DebugFuncVarAdjust '$gallery_border_pixels TOO LOW so set as' "$gallery_border_pixels"
            fi
            ;;
    esac

    if [[ $max_results_required -lt $((user_images_requested+user_fail_limit)) ]]; then
        max_results_required=$((user_images_requested+user_fail_limit))
        DebugFuncVarAdjust '$max_results_required TOO LOW so set as $user_images_requested + $user_fail_limit' "$max_results_required"
    fi

    if [[ -n $min_pixels ]]; then
        case "$min_pixels" in
            qsvga|vga|svga|xga|2mp|4mp|6mp|8mp|10mp|12mp|15mp|20mp|40mp|70mp)
                min_pixels_type="lt,islt:$min_pixels"
                ;;
            large)
                min_pixels_type='l'
                ;;
            medium)
                min_pixels_type='m'
                ;;
            icon)
                min_pixels_type='i'
                ;;
            *)
                DebugScriptFail 'specified $min_pixels is invalid'
                echo
                ShowFail ' !! (-m, --minimum-pixels) preset invalid'
                exitcode=2
                return 1
                ;;
        esac
        [[ -n $min_pixels_type ]] && min_pixels_search="isz:$min_pixels_type"

    fi

    if [[ -n $aspect_ratio ]]; then
        case "$aspect_ratio" in
            tall)
                aspect_ratio_type='t'
                ;;
            square)
                aspect_ratio_type='s'
                ;;
            wide)
                aspect_ratio_type='w'
                ;;
            panoramic)
                aspect_ratio_type='xw'
                ;;
            *)
                DebugScriptFail 'specified $aspect_ratio is invalid'
                echo
                ShowFail ' !! (-a, --aspect-ratio) preset invalid'
                exitcode=2
                return 1
                ;;
        esac
        [[ -n $aspect_ratio_type ]] && aspect_ratio_search="iar:$aspect_ratio_type"
    fi

    if [[ -n $image_type ]]; then
        case "$image_type" in
            face|photo|clipart|lineart|animated)
                image_type_search="itp:$image_type"
                ;;
            *)
                DebugScriptFail 'specified $image_type is invalid'
                echo
                ShowFail ' !! (--type) preset invalid'
                exitcode=2
                return 1
                ;;
        esac
    fi

    if [[ -n $image_format ]]; then
        case "$image_format" in
            png|jpg|gif|bmp|svg|ico|webp|craw)
                image_format_search="ift:$image_format"
                ;;
            *)
                DebugScriptFail 'specified $image_format is invalid'
                echo
                ShowFail ' !! (--format) preset invalid'
                exitcode=2
                return 1
                ;;
        esac
    fi

    if [[ -n $usage_rights ]]; then
        case "$usage_rights" in
            reuse-with-mod)
                usage_rights_type='fmc'
                ;;
            reuse)
                usage_rights_type='fc'
                ;;
            noncomm-reuse-with-mod)
                usage_rights_type='fm'
                ;;
            noncomm-reuse)
                usage_rights_type='f'
                ;;
            *)
                DebugScriptFail 'specified $usage_rights is invalid'
                echo
                ShowFail ' !! (--usage-rights) preset invalid'
                exitcode=2
                return 1
                ;;
        esac
        [[ -n $usage_rights_type ]] && usage_rights_search="sur:$usage_rights_type"
    fi

    if [[ -n $recent ]]; then
        case "$recent" in
            any)
                recent_type=''
                ;;
            hour)
                recent_type='h'
                ;;
            day)
                recent_type='d'
                ;;
            week)
                recent_type='w'
                ;;
            month)
                recent_type='m'
                ;;
            year)
                recent_type='y'
                ;;
            *)
                DebugScriptFail 'specified $recent is invalid'
                echo
                ShowFail ' !! (--recent) preset invalid'
                exitcode=2
                return 1
                ;;
        esac
        [[ -n $recent_type ]] && recent_search="qdr:$recent_type"
    fi

    if [[ -n $image_colour ]]; then
        case "$image_colour" in
            any)
                image_colour_type=''
                ;;
            full)
                image_colour_type='color'
                ;;
            black-white|bw)
                image_colour_type='gray'
                ;;
            transparent|clear)
                image_colour_type='trans'
                ;;
            red|orange|yellow|green|teal|blue|purple|pink|white|gray|black|brown)
                image_colour_type="specific,isc:$image_colour"
                ;;
            cyan)
                image_colour_type="specific,isc:teal"
                ;;
            magenta)
                image_colour_type="specific,isc:purple"
                ;;
            grey)
                image_colour_type="specific,isc:gray"
                ;;
            *)
                DebugScriptFail 'specified $image_colour is invalid'
                echo
                ShowFail ' !! (--colour, --color) preset invalid'
                exitcode=2
                return 1
                ;;
        esac
        [[ -n $image_colour_type ]] && image_colour_search="ic:$image_colour_type"
    fi

    if [[ -n $min_pixels_search || -n $aspect_ratio_search || -n $image_type_search || -n $image_format_search ||-n $usage_rights_search || -n $recent_search || -n $image_colour_search ]]; then
        advanced_search="&tbs=$min_pixels_search,$aspect_ratio_search,$image_type_search,$image_format_search,$usage_rights_search,$recent_search,$image_colour_search"
    fi

    DebugFuncExit
    return 0

    }

FinalizeSearchPhrase()
    {

    search_phrase=$1

    IFS=',' read -r -a array <<< "$exclude_words"
    for element in "${array[@]}"
    do
        search_phrase+=" -${element}"
    done

    if [[ -n "$sites" ]]
    then
        IFS=',' read -r -a array <<< "$sites"
        for element in "${array[@]}"
        do
        search_phrase+=" -site:${element} OR"
        done
        search_phrase=${search_phrase%???}
    fi

    }

ProcessPhrase()
    {

    # this function:
    #   searches Google for a phrase,
    #   creates a URL list,
    #   downloads each image from URL list,
    #   builds a gallery from these downloaded images if requested.

    # $1 = phrase to search Google Images for. Enclose whitespace in quotes.

    DebugFuncEntry

    local func_startseconds=$(date +%s)

    echo
    DebugFuncComment 'user phrase parameters'

    if [[ -z $1 ]]; then
        DebugFuncFail 'phrase' 'unspecified'
        ShowFail ' !! search phrase (-p, --phrase) was unspecified'
        exitcode=2
        return 1
    fi

    echo " -> requested phrase: \"$1\""

    FinalizeSearchPhrase "$1"
    safe_search_phrase="${search_phrase// /+}"  # replace whitepace with '+' to suit curl/wget
    DebugFuncVar safe_search_phrase

    if [[ -z $output_path ]]; then
        target_path="$current_path/$1"
    else
        if [[ -n $input_phrases_pathfile ]]; then
            target_path="$output_path/$1"
        else
            target_path="$output_path"
        fi
    fi

    DebugFuncVar target_path

    # ensure target path exists
    if [[ -e $target_path ]]; then
        DebugFuncSuccess 'target path already exists'
    else
        mkdir -p "$target_path"
        result=$?
        if [[ $result -gt 0 ]]; then
            DebugFuncFail 'create target path' "failed! mkdir returned: ($result)"
            echo
            ShowFail ' !! unable to create target path'
            exitcode=3
            return 1
        else
            DebugFuncSuccess 'create target path'
            target_path_created=true
        fi
    fi

    # set gallery title
    if [[ $exitcode -eq 0 && $no_gallery = false ]]; then
        if [[ -n $user_gallery_title ]]; then
            gallery_title="$user_gallery_title"
        else
            gallery_title="$1"
            DebugFuncVarAdjust 'gallery title unspecified so set as' "'$gallery_title'"
        fi
    fi

    # download search results
    GetResultPages || exitcode=4

    # download images
    if [[ $exitcode -eq 0 && $links_only = false ]]; then
        GetImages || exitcode=5
    fi

    # reindex and rename downloaded images if specified
    if [[ $exitcode -eq 0 || $exitcode -eq 5 ]] && [[ $reindex_rename = true ]]; then
        DebugFuncOpr 'reindexing and renaming downloaded files'
        local reindex=0
        for targetfile in "$target_path/"*; do
            ((reindex++))
            mv "$targetfile" "$target_path/$IMAGE_FILE_PREFIX($(printf "%04d" $reindex)).${targetfile##*.}"
        done
    fi

    # build thumbnail gallery even if fail_limit was reached
    if [[ $exitcode -eq 0 || $exitcode -eq 5 ]] && [[ $no_gallery = false ]]; then
        BuildGallery || exitcode=6
    fi

    # copy links file into target directory if possible. If not, then copy to current directory.
    if [[ $exitcode -eq 0 || $exitcode -eq 5 ]]; then
        if [[ $save_links = true ]]; then
            if [[ $target_path_created = true ]]; then
                cp -f "$imagelinks_pathfile" "$target_path/$imagelinks_file"
            else
                cp -f "$imagelinks_pathfile" "$current_path/$imagelinks_file"
            fi
        fi
    fi

    DebugFuncElapsedTime "$func_startseconds"
    DebugFuncExit

    return 0

    }

ProcessLinkList()
    {

    # This function:
    #   downloads each image from URL list,
    #   builds a gallery from these downloaded images if requested.

# This function is in-flux. Code-overlap between ProcessLinkList() and ProcessPhrase() will be removed when I can.
# Requires '-n', '-o' and '-T' to be specified while in development (not programatically enforced yet, so ensure you specify them).
# Later on, '-p' will be accepted too and can be used in-place of '-o' and '-T'.

    DebugFuncEntry

    local func_startseconds=$(date +%s)

    echo
#     DebugFuncComment 'user phrase parameters'

#     if [[ -z $1 ]]; then
#         DebugFuncFail 'phrase' 'unspecified'
#         ShowFail ' !! search phrase (-p, --phrase) was unspecified'
#         exitcode=2
#         return 1
#     fi

#     echo " -> requested phrase: \"$1\""

#     FinalizeSearchPhrase "$1"
#     safe_search_phrase="${search_phrase// /+}"  # replace whitepace with '+' to suit curl/wget
#     DebugFuncVar safe_search_phrase

#     if [[ -z $output_path ]]; then
#         target_path="$current_path/$1"
#     else
#         if [[ -n $input_phrases_pathfile ]]; then
#             target_path="$output_path/$1"
#         else
            target_path="$output_path"
#         fi
#     fi

    DebugFuncVar target_path

    # ensure target path exists
    if [[ -e $target_path ]]; then
        DebugFuncSuccess 'target path already exists'
    else
        mkdir -p "$target_path"
        result=$?
        if [[ $result -gt 0 ]]; then
            DebugFuncFail 'create target path' "failed! mkdir returned: ($result)"
            echo
            ShowFail ' !! unable to create target path'
            exitcode=3
            return 1
        else
            DebugFuncSuccess 'create target path'
            target_path_created=true
        fi
    fi

    # set gallery title
#     if [[ $exitcode -eq 0 && $no_gallery = false ]]; then
#         if [[ -n $user_gallery_title ]]; then
            gallery_title="$user_gallery_title"
#         else
#             gallery_title="$1"
#             DebugFuncVarAdjust 'gallery title unspecified so set as' "'$gallery_title'"
#         fi
#     fi

    if [[ -e $input_links_pathfile ]]; then
        imagelinks_pathfile=$input_links_pathfile
    else
        DebugFuncFail "input list file doesn't exist" "failed! mkdir returned: ($result)"
        echo
#       ShowFail ' !! unable to create target path'
        exitcode=3
        return 1
    fi

    # download images
    if [[ $exitcode -eq 0 && $links_only = false ]]; then
        GetImages || exitcode=5
    fi

    # reindex and rename downloaded images if specified
    if [[ $exitcode -eq 0 || $exitcode -eq 5 ]] && [[ $reindex_rename = true ]]; then
        DebugFuncOpr 'reindexing and renaming downloaded files'
        local reindex=0
        for targetfile in "$target_path/"*; do
            ((reindex++))
            mv "$targetfile" "$target_path/$IMAGE_FILE_PREFIX($(printf "%04d" $reindex)).${targetfile##*.}"
        done
    fi

    # build thumbnail gallery even if fail_limit was reached
    if [[ $exitcode -eq 0 || $exitcode -eq 5 ]] && [[ $no_gallery = false ]]; then
        BuildGallery || exitcode=6
    fi

    # copy links file into target directory if possible. If not, then copy to current directory.
    if [[ $exitcode -eq 0 || $exitcode -eq 5 ]]; then
        if [[ $save_links = true ]]; then
            if [[ $target_path_created = true ]]; then
                cp -f "$imagelinks_pathfile" "$target_path/$imagelinks_file"
            else
                cp -f "$imagelinks_pathfile" "$current_path/$imagelinks_file"
            fi
        fi
    fi

    DebugFuncElapsedTime "$func_startseconds"
    DebugFuncExit

    return 0

    }

GetResultPages()
    {

    DebugFuncEntry

    local func_startseconds=$(date +%s)
    local groups_max=$((GOOGLE_RESULTS_MAX/100))
    local run_count=0
    local success_count=0
    local fail_count=0
    local max_search_result_groups=$((max_results_required*2))
    [[ $max_search_result_groups -gt $GOOGLE_RESULTS_MAX ]] && max_search_result_groups=$GOOGLE_RESULTS_MAX
    local returncode=0

    InitProgress

    # clears the paths used to count the search result pages
    [[ -d $results_run_count_path ]] && rm -f "$results_run_count_path"/*
    [[ -d $results_success_count_path ]] && rm -f "$results_success_count_path"/*
    [[ -d $results_fail_count_path ]] && rm -f "$results_fail_count_path"/*

    if [[ $verbose = true ]]; then
        if [[ $display_colour = true ]]; then
            echo -n " -> searching $(ShowGoogle): "
        else
            echo -n " -> searching Google: "
        fi
    fi

    for ((group=1; group<=groups_max; group++)); do
        # wait here until a download slot becomes available
        while [[ $run_count -eq $parallel_limit ]]; do
            sleep 0.5

            RefreshResultsCounts
            ShowGetResultProgress
        done

        group_index=$(printf "%02d" $group)

        # create run file here as it takes too long to happen in background function
        touch "$results_run_count_path/$group_index"
        { _GetResultPage_ "$group" "$group_index" & } 2>/dev/null

        RefreshResultsCounts
        ShowGetResultProgress

        [[ $((group*100)) -ge $max_search_result_groups ]] && break
    done

    # wait here while all running downloads finish
    wait 2>/dev/null

    RefreshResultsCounts
    ShowGetResultProgress

    # build all groups into a single file
    cat "$searchresults_pathfile".* > "$searchresults_pathfile"

    ParseResults

    DebugFuncElapsedTime "$func_startseconds"
    DebugFuncExit

    return $returncode

    }

_GetResultPage_()
    {

    # * This function runs as a forked process *
    # $1 = page group to load           e.g. 0, 1, 2, 3, etc...
    # $2 = debug index identifier       e.g. (02)

    _GetResultsGroup_()
        {

        # $1 = page group to load           e.g. 0, 1, 2, 3, etc...
        # $2 = debug log link index         e.g. (02)
        # echo = downloader stdout & stderr
        # $? = downloader return code

        local page_group="$1"
        local group_index="$2"
        local search_group="&ijn=$((page_group-1))"
        local search_start="&start=$(((page_group-1)*100))"
        local SERVER='https://www.google.com'
        local safe_search_query="&q=$safe_search_phrase"
        local get_results_cmd=''

        # ------------- assumptions regarding Google's URL parameters ---------------------------------------------------
        local SEARCH_TYPE='&tbm=isch'       # search for images
        local SEARCH_LANGUAGE='&hl=en'      # language
        local SEARCH_STYLE='&site=imghp'    # result layout style
        local SEARCH_SIMILAR='&filter=0'    # don't omit similar results

        local search_match_type='&nfpr='    # exact or loose (suggested) search

        if [[ $exact_search = true ]]; then
            search_match_type+='1'
        else
            search_match_type+='0'
        fi

        local safesearch_flag='&safe='      # Google's SafeSearch content filter

        if [[ $safesearch = true ]]; then
            safesearch_flag+='active'
        else
            safesearch_flag+='inactive'
        fi

        # compiled search string
        local search_string="\"$SERVER/search?${SEARCH_TYPE}${search_match_type}${SEARCH_SIMILAR}${safe_search_query}${SEARCH_LANGUAGE}${SEARCH_STYLE}${search_group}${search_start}${advanced_search}${safesearch_flag}\""

        if [[ $(basename "$DOWNLOADER_BIN") = wget ]]; then
            get_results_cmd="$DOWNLOADER_BIN --quiet --timeout 5 --tries 3 $search_string $USERAGENT --output-document \"$searchresults_pathfile.$page_group\""
        elif [[ $(basename "$DOWNLOADER_BIN") = curl ]]; then
            get_results_cmd="$DOWNLOADER_BIN --max-time 30 $search_string $USERAGENT --output \"$searchresults_pathfile.$page_group\""
        else
            DebugFuncFail 'unknown downloader' 'out-of-ideas'
            return 1
        fi

        DebugChildExec "get search results" "$get_results_cmd"

        eval "$get_results_cmd" 2>&1

        }

    local page_group="$1"
    local group_index="$2"
    _forkname_="$(FormatFuncSearch "${FUNCNAME[0]}" "$group_index")"    # global: used by various debug logging functions
    local response=''
    local result=0
    local func_startseconds=$(date +%s)

    DebugChildForked

    local run_pathfile="$results_run_count_path/$group_index"
    local success_pathfile="$results_success_count_path/$group_index"
    local fail_pathfile="$results_fail_count_path/$group_index"

    response=$(_GetResultsGroup_ "$page_group" "$group_index")
    result=$?

    if [[ $result -eq 0 ]]; then
        mv "$run_pathfile" "$success_pathfile"
        DebugChildSuccess 'get search results'
    else
        mv "$run_pathfile" "$fail_pathfile"
        DebugChildFail "downloader returned \"$result: $(DownloaderReturnCodes "$result")\""
    fi

    DebugChildElapsedTime "$func_startseconds"
    DebugChildEnded

    return 0

    }

GetImages()
    {

    DebugFuncEntry

    local func_startseconds=$(date +%s)
    local result_index=0
    local message=''
    local result=0
    local run_count=0
    local success_count=0
    local fail_count=0
    local imagelink=''
    local download_bytes=0

    [[ $verbose = true ]] && echo -n " -> acquiring images: "

    InitProgress

    # clears the paths used to count the downloaded images
    [[ -d $download_run_count_path ]] && rm -f "$download_run_count_path"/*
    [[ -d $download_success_count_path ]] && rm -f "$download_success_count_path"/*
    [[ -d $download_fail_count_path ]] && rm -f "$download_fail_count_path"/*

    while read -r imagelink; do
        while true; do
            RefreshDownloadCounts; ShowGetImagesProgress

            [[ $success_count -ge $gallery_images_required ]] && break 2

            if [[ $fail_count -ge $fail_limit ]]; then
                wait 2>/dev/null            # wait here until all forked downloaders have completed
                result=1
                break 2
            fi

            # don't proceed until a download slot becomes available
            [[ $run_count -eq $parallel_limit ]] && continue

            if [[ $((success_count+run_count)) -lt $gallery_images_required ]] || [[ $race = true && $success_count -lt $gallery_images_required ]]; then
                # fork a new downloader
                ((result_index++))
                local link_index=$(printf "%04d" $result_index)

                # create the fork runfile here as it takes too long to happen in background function
                touch "$download_run_count_path/$link_index"
                { _GetImage_ "$imagelink" "$link_index" & } 2>/dev/null

                break
            fi
        done
    done < "$imagelinks_pathfile"

    while [[ $run_count -gt 0 ]]; do
        [[ $race = true && $success_count -ge $gallery_images_required ]] && KillActiveDownloads
        RefreshDownloadCounts; ShowGetImagesProgress
    done

    wait 2>/dev/null;                   # wait here until all forked download jobs have exited

    if [[ $success_count -gt $gallery_images_required ]]; then      # overrun can occur when race=true so trim back successful downloads to that required
        for existing_pathfile in $(ls "$download_success_count_path"/* | tail -n +$((gallery_images_required+1))); do
            existing_file="$(basename "$existing_pathfile")"
            mv "$existing_pathfile" "$download_fail_count_path"
            rm -f "$target_path/$IMAGE_FILE_PREFIX($existing_file)".*
        done
    fi

    RefreshDownloadCounts; ShowGetImagesProgress

    if [[ $fail_count -gt 0 ]]; then
        # derived from: http://stackoverflow.com/questions/24284460/calculating-rounded-percentage-in-shell-script-without-using-bc
        percent="$((200*(fail_count)/(success_count+fail_count) % 2 + 100*(fail_count)/(success_count+fail_count)))%"

        if [[ $display_colour = true ]]; then
            echo -n "($(ColourTextBrightRed "$percent")) "
        else
            echo -n "($percent) "
        fi
    fi

    if [[ $result -eq 1 ]]; then
        DebugFuncFail 'failure limit reached' "$fail_count/$fail_limit"
        echo; echo
        echo " Try your search again with additional options:"
        [[ $safesearch = true ]] && echo "    - disable SafeSearch: '--no-safesearch'"
        echo "    - consider raising the failure limit: '-f0'"
    else
        if [[ $result_index -eq $results_received && $always_download = false ]]; then
            DebugFuncFail 'links list exhausted' "$result_index/$results_received"

            if [[ $display_colour = true ]]; then
                ColourTextBrightRed 'Links list exhausted!'
            else
                echo "Links list exhausted!"
            fi

            result=1
        else
            [[ $verbose = true ]] && echo
        fi
    fi

    DebugFuncVal 'downloads OK' "$success_count"
    DebugFuncVal 'downloads failed' "$fail_count"

    if [[ $result -le 1 ]]; then
        download_bytes="$($DU_BIN "$target_path/$IMAGE_FILE_PREFIX"* -cb | tail -n1 | cut -f1)"
        DebugFuncVal 'downloaded bytes' "$(DisplayThousands "$download_bytes")"

        download_seconds="$(($(date +%s)-func_startseconds))"
        if [[ $download_seconds -lt 1 ]]; then
            download_seconds=1
            DebugFuncVarAdjust "\$download_seconds TOO LOW so set to a usable minimum" "$download_seconds"
        fi

        DebugFuncVal 'average download speed' "$(DisplayISO "$((download_bytes/download_seconds))")B/s"
    fi

    DebugFuncElapsedTime "$func_startseconds"
    DebugFuncExit

    return $result

    }

_GetImage_()
    {

    # * This function runs as a forked process *
    # $1 = URL to download
    # $2 = debug index identifier e.g. "0026"

    _GetHeader_()
        {

        # $1 = URL to check
        # $2 = temporary filename to download to (only used by Wget)
        # stdout = header string
        # $? = downloader return code

        local URL="$1"
        local output_pathfile="$2"
        local get_headers_cmd=''

        if [[ $(basename "$DOWNLOADER_BIN") = wget ]]; then
            get_headers_cmd="$DOWNLOADER_BIN --spider --server-response --max-redirect 0 --no-check-certificate --timeout $timeout_seconds --tries $((retries+1)) $USERAGENT --output-document \"$output_pathfile\" \"$URL\""
        elif [[ $(basename "$DOWNLOADER_BIN") = curl ]]; then
            get_headers_cmd="$DOWNLOADER_BIN --silent --head --insecure --max-time 30 $USERAGENT \"$URL\""
        else
            DebugFuncFail "$_forkname_" 'unknown downloader'
            return 1
        fi

        DebugChildExec "get image size" "$get_headers_cmd"

        eval "$get_headers_cmd" 2>&1

        }

    _GetFile_()
        {

        # $1 = URL to check
        # $2 = filename to download to
        # stdout = downloader stdout & stderr
        # $? = downloader return code

        local URL="$1"
        local output_pathfile="$2"
        local get_image_cmd=''

        if [[ $(basename "$DOWNLOADER_BIN") = wget ]]; then
            get_image_cmd="$DOWNLOADER_BIN --max-redirect 0 --no-check-certificate --timeout $timeout_seconds --tries $((retries+1)) $USERAGENT --output-document \"$output_pathfile\" \"$URL\""
        elif [[ $(basename "$DOWNLOADER_BIN") = curl ]]; then
            get_image_cmd="$DOWNLOADER_BIN --silent --max-time 30 $USERAGENT --output \"$output_pathfile\" \"$URL\""
        else
            DebugFuncFail 'unknown downloader' 'out-of-ideas'
            return 1
        fi

        DebugChildExec "get image" "$get_image_cmd"

        eval "$get_image_cmd" 2>&1

        }

    _MoveToSuccess_()
        {

        # move runfile to the successes directory

        [[ -e $run_pathfile ]] && mv "$run_pathfile" "$success_pathfile"

        }

    _MoveToFail_()
        {

        # move runfile to the failures directory

        [[ -e $run_pathfile ]] && mv "$run_pathfile" "$fail_pathfile"

        # delete temp file if one was created
        [[ -e $targetimage_pathfileext ]] && rm -f "$targetimage_pathfileext"

        }

    _UpdateRunLog_()
        {

        # $1 = section
        # $2 = action
        # $3 = stdout from function (optional)
        # $4 = resultcode
        # $5 = extended description of resultcode (optional)

        [[ -z $1 || -z $2 || -z $4 || -z $run_pathfile || ! -f $run_pathfile ]] && return 1

        printf "> section: %s\n= action: %s\n= stdout: '%s'\n= resultcode: %s\n= description: '%s'\n\n" "$1" "$2" "$3" "$4" "$5" >> "$run_pathfile"

        }

    local URL="$1"
    local link_index="$2"
    _forkname_="$(FormatFuncLink "${FUNCNAME[0]}" "$link_index")"   # global: used by various debug logging functions
    local pre_download_ok=''
    local size_ok=''
    local download_ok=''
    local response=''
    local result=0
    local download_speed=''
    local estimated_size=0
    local actual_size=0
    local func_startseconds=$(date +%s)
    local section=''
    local action=''
    local get_remote_size_result=0
    local get_image_result=0
    local get_type_result=0

    DebugChildForked

    local run_pathfile="$download_run_count_path/$link_index"
    local success_pathfile="$download_success_count_path/$link_index"
    local fail_pathfile="$download_fail_count_path/$link_index"

    # extract file extension by checking only last 5 characters of URL (to handle .jpeg as worst case)
    local ext=$(echo "${1:(-5)}" | $SED_BIN "s/.*\(\.[^\.]*\)$/\1/")

    [[ ! "$ext" =~ '.' ]] && ext='.jpg' # if URL did not have a file extension then choose jpg as default

    local targetimage_pathfileext="$target_path/$IMAGE_FILE_PREFIX($link_index)$ext"

    section='pre-download'

    if [[ $upper_size_bytes -gt 0 || $lower_size_bytes -gt 0 ]]; then
        action='ask for remote image file size'
        response=$(_GetHeader_ "$URL" "$testimage_pathfile($link_index)$ext")
        get_remote_size_result=$?
        _UpdateRunLog_ "$section" "$action" "$response" "$get_remote_size_result" "$(DownloaderReturnCodes "$get_remote_size_result")"

        if [[ $get_remote_size_result -eq 0 ]]; then
            action='check remote image file size'
            estimated_size="$(grep -i 'content-length:' <<< "$response" | $SED_BIN 's|^.*: ||;s|\r||')"
            [[ -z $estimated_size || $estimated_size = unspecified ]] && estimated_size=unknown

            DebugChildVal "$section" "$(DisplayThousands "$estimated_size") bytes"

            if [[ $estimated_size = unknown ]]; then
                pre_download_ok=$skip_no_size
                _UpdateRunLog_ "$section" "$action" "$(DisplayThousands "$estimated_size") bytes" '1' 'unknown'
            else
                if [[ $estimated_size -lt $lower_size_bytes ]]; then
                    pre_download_ok=false
                    _UpdateRunLog_ "$section" "$action" "$estimated_size" '1' 'too small'
                    DebugChildFail "$action < $(DisplayThousands "$lower_size_bytes") bytes"
                elif [[ $upper_size_bytes -gt 0 && $estimated_size -gt $upper_size_bytes ]]; then
                    pre_download_ok=false
                    _UpdateRunLog_ "$section" "$action" "$estimated_size" '1' 'too large'
                    DebugChildFail "$action > $(DisplayThousands "$upper_size_bytes") bytes"
                else
                    pre_download_ok=true
                    _UpdateRunLog_ "$section" "$action" "$estimated_size" '0' 'OK'
                    DebugChildSuccess "$action"
                fi
            fi
        else
            pre_download_ok=false
            _MoveToFail_
            DebugChildFail "$section returned: \"$get_remote_size_result: $(DownloaderReturnCodes "$get_remote_size_result")\""
        fi
    else
        pre_download_ok=true
    fi

    section='mid-download'

    if [[ $pre_download_ok = true ]]; then
        action='download image'
        response=$(_GetFile_ "$URL" "$targetimage_pathfileext")
        get_image_result=$?
        _UpdateRunLog_ "$section" "$action" "$response" "$get_image_result" "$(DownloaderReturnCodes "$get_image_result")"
        if [[ $get_image_result -eq 0 && -e $targetimage_pathfileext ]]; then
            download_ok=true
            DebugChildSuccess "$action"
        else
            download_ok=false
            _MoveToFail_
            DebugChildFail "$action"
        fi
    else
        download_ok=false
        _MoveToFail_
    fi

    section='post-download'

    if [[ $download_ok = true ]]; then
        action='check local image file size'
        actual_size=$(wc -c < "$targetimage_pathfileext"); actual_size=${actual_size##* }

        # http://stackoverflow.com/questions/36249714/parse-download-speed-from-wget-output-in-terminal
        download_speed=$(tail -n1 <<< "$response" | grep -o '\([0-9.]\+ [KM]B/s\)'); download_speed="${download_speed/K/k}"

        DebugChildVal "$section" "$(DisplayThousands "$actual_size") bytes"
        DebugChildVal 'average download speed' "$download_speed"

        if [[ $actual_size -lt $lower_size_bytes ]]; then
            _UpdateRunLog_ "$section" "$action" "$actual_size" '1' 'too small'
            size_ok=false
            _MoveToFail_
            DebugChildFail "$action < $lower_size_bytes"
        elif [[ $upper_size_bytes -gt 0 && $actual_size -gt $upper_size_bytes ]]; then
            _UpdateRunLog_ "$section" "$action" "$actual_size" '1' 'too large'
            size_ok=false
            _MoveToFail_
            DebugChildFail "$action > $upper_size_bytes"
        else
            _UpdateRunLog_ "$section" "$action" "$actual_size" '0' 'OK'
            size_ok=true
            DebugChildSuccess "$action"
        fi
    else
        size_ok=false
        _MoveToFail_
    fi

    if [[ $size_ok = true ]]; then
        response=$(RenameExtAsType "$targetimage_pathfileext")
        get_type_result=$?
        action='confirm local image file type'
        _UpdateRunLog_ "$section" "$action" "$response" "$get_type_result" ''

        if [[ $get_type_result -eq 0 ]]; then
            _MoveToSuccess_
            DebugChildSuccess "$action"
        else
            _MoveToFail_
            DebugChildFail "$action"
        fi
    fi

    [[ -n $exclude_links_pathfile ]] && echo "$URL" >> "$exclude_links_pathfile"

    DebugChildElapsedTime "$func_startseconds"
    DebugChildEnded

    return 0

    }

ParseResults()
    {

    _GetLinkCount_()
        {

        # get link count
        results_received=$(wc -l < "$imagelinks_pathfile"); results_received=${results_received##* }

        }

    DebugFuncEntry

    results_received=0
    local returncode=0

    ScrapeSearchResults

    if [[ -e $imagelinks_pathfile ]]; then
        _GetLinkCount_
        DebugFuncVar results_received

        # check against allowable file types
        while read -r imagelink; do
            AllowableFileType "$imagelink" && echo "$imagelink" >> "$imagelinks_pathfile.tmp"
        done < "$imagelinks_pathfile"
        [[ -e $imagelinks_pathfile.tmp ]] && mv "$imagelinks_pathfile.tmp" "$imagelinks_pathfile"
        _GetLinkCount_
        DebugFuncVarAdjust 'after removing disallowed image types' "$results_received"

        # remove duplicate URLs, but retain current order
        cat -n "$imagelinks_pathfile" | sort -uk2 | sort -nk1 | cut -f2 > "$imagelinks_pathfile.tmp"
        [[ -e $imagelinks_pathfile.tmp ]] && mv "$imagelinks_pathfile.tmp" "$imagelinks_pathfile"
        _GetLinkCount_
        DebugFuncVarAdjust 'after removing duplicate URLs' "$results_received"

        # remove previously downloaded URLs
        if [[ -n $exclude_links_pathfile ]]; then
            [[ -e $exclude_links_pathfile ]] && grep -axvFf "$exclude_links_pathfile" "$imagelinks_pathfile" > "$imagelinks_pathfile.tmp"
            [[ -e $imagelinks_pathfile.tmp ]] && mv "$imagelinks_pathfile.tmp" "$imagelinks_pathfile"
            _GetLinkCount_
            DebugFuncVarAdjust 'after removing previous URLs' "$results_received"
        fi

        # if too many results then trim
        if [[ $results_received -gt $max_results_required ]]; then
            head -n "$max_results_required" "$imagelinks_pathfile" > "$imagelinks_pathfile".tmp
            mv "$imagelinks_pathfile".tmp "$imagelinks_pathfile"
            results_received=$max_results_required
            DebugFuncVarAdjust 'after trimming to $max_results_required' "$results_received"
        fi
    fi

    if [[ $verbose = true ]]; then
        if [[ $display_colour = true ]]; then
            if [[ $results_received -ge $max_results_required ]]; then
                echo "($(ColourTextBrightGreen "$results_received") results)"
            elif [[ $results_received -lt $max_results_required && $results_received -ge $user_images_requested ]]; then
                echo "($(ColourTextBrightOrange "$results_received") results)"
            elif [[ $results_received -lt $user_images_requested ]]; then
                echo "($(ColourTextBrightRed "$results_received") results)"
            fi
        else
            echo "($results_received results)"
        fi

        if [[ $results_received -lt $user_images_requested ]]; then
            if [[ $always_download = false ]]; then
                echo
                echo " Try your search again with additional options:"
                [[ $safesearch = true ]] && echo "    - disable SafeSearch: '--no-safesearch'"
                echo "    - grab as many images as possible: '-A'"
                exitcode=4
            fi
        fi
    fi

    if [[ -e $imagelinks_pathfile && $random_image = true ]]; then
        local op='shuffle links'
        shuf "$imagelinks_pathfile" -o "$imagelinks_pathfile" && DebugFuncSuccess "$op" || DebugFuncFail "$op"
    fi

    if [[ $exitcode -eq 0 ]]; then
        fail_limit=$user_fail_limit
        if [[ $fail_limit -gt $results_received ]]; then
            fail_limit=$results_received
            DebugFuncVarAdjust '$fail_limit TOO HIGH so set as $results_received' "$fail_limit"
        fi

        if [[ $max_results_required -gt $results_received ]]; then
            max_results_required=$results_received
            DebugFuncVarAdjust '$max_results_required TOO HIGH so set as $results_received' "$results_received"
        fi

        if [[ $gallery_images_required -gt $results_received ]]; then
            gallery_images_required=$results_received
            DebugFuncVarAdjust '$gallery_images_required TOO HIGH so set as $results_received' "$results_received"
        fi
    fi

    if [[ $results_received -eq 0 ]]; then
        DebugFuncVal 'zero results returned?' 'Oops...'
        returncode=1
    fi

    DebugFuncExit
    return $returncode

    }

BuildGallery()
    {

    DebugFuncEntry

    local func_startseconds=$(date +%s)
    local reserve_for_border="-border $gallery_border_pixels"
    local title_height_pixels=100
    local stage_description=''
    local runmsg=''

    InitProgress

    # build thumbnails image overlay
    stage_description='compose thumbnails'
    if [[ $verbose = true ]]; then
        echo -n " -> building gallery: "

        if [[ $display_colour = true ]]; then
            progress_message="$(ColourTextBrightOrange 'stage 1/4')"
        else
            progress_message='stage 1/4'
        fi

        progress_message+=" ($stage_description)"
        ProgressUpdater "$progress_message"
    fi

    if [[ $gallery_title = '_false_' ]]; then
        reserve_for_title=''
    else
        reserve_for_title="-gravity north -splice 0x$((title_height_pixels+gallery_border_pixels+10))"
    fi

    if [[ $compact_gallery = true ]]; then
        build_foreground_cmd="$CONVERT_BIN \"$target_path/*[0]\" -define jpeg:size=$thumbnail_dimensions -thumbnail ${thumbnail_dimensions}^ -gravity center -extent $thumbnail_dimensions miff:- | montage - -background none -geometry +0+0 miff:- | convert - -background none $reserve_for_title -bordercolor none $reserve_for_border \"$gallery_thumbnails_pathfile\""
    else
        build_foreground_cmd="$MONTAGE_BIN \"$target_path/*[0]\" -background none -shadow -geometry $thumbnail_dimensions miff:- | convert - -background none $reserve_for_title -bordercolor none $reserve_for_border \"$gallery_thumbnails_pathfile\""
    fi

    DebugFuncExec "$stage_description" "$build_foreground_cmd"

    runmsg=$(eval "$build_foreground_cmd" 2>&1)
    result=$?

    if [[ $result -eq 0 ]]; then
        DebugFuncSuccess "$stage_description"
    else
        DebugFuncFail "$stage_description" "($result)"
        DebugFuncVar runmsg
    fi

    if [[ $result -eq 0 ]]; then
        # build background image
        stage_description='draw background'
        if [[ $verbose = true ]]; then
            if [[ $display_colour = true ]]; then
                progress_message="$(ColourTextBrightOrange 'stage 2/4')"
            else
                progress_message='stage 2/4'
            fi

            progress_message+=" ($stage_description)"
            ProgressUpdater "$progress_message"
        fi

        # get image dimensions
        read -r width height <<< "$($CONVERT_BIN -ping "$gallery_thumbnails_pathfile" -format "%w %h" info:)"

        # create a dark image with light sphere in centre
        build_background_cmd="$CONVERT_BIN -size ${width}x${height} radial-gradient:WhiteSmoke-gray10 \"$gallery_background_pathfile\""

        DebugFuncExec "$stage_description" "$build_background_cmd"

        runmsg=$(eval "$build_background_cmd" 2>&1)
        result=$?

        if [[ $result -eq 0 ]]; then
            DebugFuncSuccess "$stage_description"
        else
            DebugFuncFail "$stage_description" "($result)"
            DebugFuncVar runmsg
        fi
    fi

    if [[ $result -eq 0 ]]; then
        # build title image overlay
        stage_description='draw title'
        if [[ $verbose = true ]]; then
            if [[ $display_colour = true ]]; then
                progress_message="$(ColourTextBrightOrange 'stage 3/4')"
            else
                progress_message='stage 3/4'
            fi

            progress_message+=" ($stage_description)"
            ProgressUpdater "$progress_message"
        fi

        if [[ $gallery_title != '_false_' ]]; then
            # create title image
            # let's try a fixed height of 100 pixels
            build_title_cmd="$CONVERT_BIN -size x$title_height_pixels -font $(FirstPreferredFont) -background none -stroke black -strokewidth 10 label:\"\\ \\ $gallery_title\\ \" -blur 0x5 -fill goldenrod1 -stroke none label:\"\\ \\ $gallery_title\\ \" -flatten \"$gallery_title_pathfile\""

            DebugFuncExec "$stage_description" "$build_title_cmd"

            runmsg=$(eval "$build_title_cmd" 2>&1)
            result=$?

            if [[ $result -eq 0 ]]; then
                DebugFuncSuccess "$stage_description"
            else
                DebugFuncFail "$stage_description" "($result)"
                DebugFuncVar runmsg
            fi
        fi
    fi

    if [[ $result -eq 0 ]]; then
        # compose thumbnail and title images onto background image
        stage_description='compose images'
        if [[ $verbose = true ]]; then
            if [[ $display_colour = true ]]; then
                progress_message="$(ColourTextBrightOrange 'stage 4/4')"
            else
                progress_message='stage 4/4'
            fi

            progress_message+=" ($stage_description)"
            ProgressUpdater "$progress_message"
        fi

        if [[ $gallery_title = '_false_' ]]; then
            include_title=''
        else
            include_title="-composite \"$gallery_title_pathfile\" -gravity north -geometry +0+$((gallery_border_pixels+10))"
        fi

        # compose thumbnails image on background image, then title image on top
        build_compose_cmd="$CONVERT_BIN \"$gallery_background_pathfile\" \"$gallery_thumbnails_pathfile\" -gravity center $include_title -composite \"$target_path/$GALLERY_FILE_PREFIX-(${search_phrase// /_}).png\""

        DebugFuncExec "$stage_description" "$build_compose_cmd"

        runmsg=$(eval "$build_compose_cmd" 2>&1)
        result=$?

        if [[ $result -eq 0 ]]; then
            DebugFuncSuccess "$stage_description"
        else
            DebugFuncFail "$stage_description" "($result)"
            DebugFuncVar runmsg
        fi
    fi

    [[ -e $gallery_title_pathfile ]] && rm -f "$gallery_title_pathfile"
    [[ -e $gallery_thumbnails_pathfile ]] && rm -f "$gallery_thumbnails_pathfile"
    [[ -e $gallery_background_pathfile ]] && rm -f "$gallery_background_pathfile"

    if [[ $result -eq 0 ]]; then
        if [[ $verbose = true ]]; then
            if [[ $display_colour = true ]]; then
                ProgressUpdater "$(ColourTextBrightGreen 'done!')"
            else
                ProgressUpdater 'done!'
            fi
        fi
    else
        if [[ $display_colour = true ]]; then
            ProgressUpdater "$(ColourTextBrightRed 'failed!')"
        else
            ProgressUpdater 'failed!'
        fi
        echo
        ShowFail ' !! unable to build thumbnail gallery'
    fi

    [[ $result -eq 0 && $delete_after = true ]] && rm -f "$target_path/$IMAGE_FILE_PREFIX"*

    [[ $verbose = true ]] && echo

    DebugFuncElapsedTime "$func_startseconds"
    DebugFuncExit

    return $result

    }

Finish()
    {

    # display end
    if [[ $verbose = true ]]; then
        case $exitcode in
            0)
                echo
                echo " -> $(ShowSuccess 'done!')"
                ;;
            [1-2])
                if [[ $show_help != true ]]; then
                    echo
                    echo " use '-h' or '--help' to display the complete parameter list."
                fi
                ;;
            [3-6])
                echo
                echo " -> $(ShowFail 'done! (with errors)')"
                ;;
            *)
                ;;
        esac
    fi

    # write results into debug file
    DebugScriptNow
    DebugScriptElapsedTime "$SCRIPT_STARTSECONDS"
    DebugScriptExit

    # copy debug file into target directory if possible. If not, or searched for multiple terms, then copy to current directory.
    if [[ $debug = true ]]; then
        if [[ -n $input_phrases_pathfile || $target_path_created = false ]]; then
            [[ -e $current_path/$DEBUG_FILE ]] && echo "" >> "$current_path/$DEBUG_FILE"
            cat "$debug_pathfile" >> "$current_path/$DEBUG_FILE"
        else
            [[ -e $target_path/$DEBUG_FILE ]] && echo "" >> "$target_path/$DEBUG_FILE"
            cp -f "$debug_pathfile" "$target_path/$DEBUG_FILE"
        fi
    fi

    [[ $show_help = true ]] && exitcode=0

    exit $exitcode

    }

SuggestInstall()
    {

    # $1 = executable name missing
    # $2 (optional) = package to install. Only specify this if different to $1

    [[ -n $1 ]] && executable=$1 || return 1
    [[ -n $2 ]] && package=$2 || package=$executable

    DebugFuncFail "no recognised '$executable' executable found" 'unable to suggest'
    echo -e "\n '$executable' executable not found!"
    if [[ $PACKAGER_BIN != unknown ]]; then
        echo -e "\n try installing with:"
        echo " $ $(basename $PACKAGER_BIN) install $package"
    else
        echo " no local package manager found!"
        echo " well, I'm out of ideas..."
    fi

    }

InitProgress()
    {

    # needs to be called prior to first call of ProgressUpdater

    progress_message=''
    previous_length=0
    previous_msg=''

    }

ProgressUpdater()
    {

    # $1 = message to display

    if [[ $1 != "$previous_msg" ]]; then
        temp=$(RemoveColourCodes "$1")
        current_length=$((${#temp}+1))

        if [[ $current_length -lt $previous_length ]]; then
            appended_length=$((current_length-previous_length))
            # backspace to start of previous msg, print new msg, add additional spaces, then backspace to end of msg
            printf "%${previous_length}s" | tr ' ' '\b' ; echo -n "$1 " ; printf "%${appended_length}s" ; printf "%${appended_length}s" | tr ' ' '\b'
        else
            # backspace to start of previous msg, print new msg
            printf "%${previous_length}s" | tr ' ' '\b' ; echo -n "$1 "
        fi

        previous_length=$current_length
        previous_msg="$1"
    fi

    }

RefreshResultsCounts()
    {

    run_count=$(ls -1 "$results_run_count_path" | wc -l); run_count=${run_count##* }                    # remove leading space in 'wc' output on macOS
    success_count=$(ls -1 "$results_success_count_path" | wc -l); success_count=${success_count##* }    # remove leading space in 'wc' output on macOS
    fail_count=$(ls -1 "$results_fail_count_path" | wc -l); fail_count=${fail_count##* }                # remove leading space in 'wc' output on macOS

    }

ShowGetResultProgress()
    {

    if [[ $verbose = true ]]; then
        if [[ $display_colour = true ]]; then
            if [[ $success_count -eq $groups_max ]]; then
                progress_message="$(ColourTextBrightGreen "$(Display2to1 "$success_count" "$groups_max")")"
            else
                progress_message="$(ColourTextBrightOrange "$(Display2to1 "$success_count" "$groups_max")")"
            fi
        else
            progress_message="$(Display2to1 "$success_count" "$groups_max")"
        fi

        progress_message+=' result groups downloaded:'
        ProgressUpdater "$progress_message"
    fi

    }

RefreshDownloadCounts()
    {

    run_count=$(ls -1 "$download_run_count_path" | wc -l); run_count=${run_count##* }                   # remove leading space in 'wc' output on macOS
    success_count=$(ls -1 "$download_success_count_path" | wc -l); success_count=${success_count##* }   # remove leading space in 'wc' output on macOS
    fail_count=$(ls -1 "$download_fail_count_path" | wc -l); fail_count=${fail_count##* }               # remove leading space in 'wc' output on macOS

    }

ShowGetImagesProgress()
    {

    local gallery_images_required_adjusted=''
    local fail_limit_adjusted=''

    if [[ $verbose = true ]]; then
#        if [[ $always_download = true ]]; then
#            gallery_images_required_adjusted=$((gallery_images_required-fail_count))
#        else
            gallery_images_required_adjusted=$gallery_images_required
#        fi

        if [[ $display_colour = true ]]; then
            progress_message="$(ColourTextBrightGreen "$(Display2to1 "$success_count" "$gallery_images_required_adjusted")")"
        else
            progress_message="$(Display2to1 "$success_count" "$gallery_images_required_adjusted")"
        fi

        progress_message+=' downloaded'

        if [[ $run_count -gt 0 ]]; then
            progress_message+=', '

            if [[ $display_colour = true ]]; then
                progress_message+="$(ColourTextBrightOrange "$run_count/$parallel_limit")"
            else
                progress_message+="$run_count/$parallel_limit"
            fi

            progress_message+=' are in progress'
        fi

        if [[ $fail_count -gt 0 ]]; then
            progress_message+=' and '

#            if [[ $always_download = true ]]; then
#                fail_limit_adjusted=$((fail_limit-success_count))
#            else
#                fail_limit_adjusted=$fail_limit
#            fi

            if [[ $user_fail_limit -ge $results_received ]]; then
                fail_limit_adjusted=$fail_count
            else
                fail_limit_adjusted=$fail_limit
            fi

            if [[ $display_colour = true ]]; then
                progress_message+="$(ColourTextBrightRed "$(Display2to1 "$fail_count" "$fail_limit_adjusted")")"
            else
                progress_message+="$(Display2to1 "$fail_count" "$fail_limit_adjusted")"
            fi
            [[ $run_count -gt 0 ]] && progress_message+=' have'

            progress_message+=' failed'
        fi

        progress_message+=':'
        ProgressUpdater "$progress_message"
    fi

    }

Display2to1()
    {

    if [[ $1 -eq $2 ]]; then
        echo "$1"
    else
        echo "$1/$2"
    fi

    }

ShowGoogle()
    {

    echo -n "$(ColourTextBrightBlue 'G')$(ColourTextBrightRed 'o')$(ColourTextBrightOrange 'o')$(ColourTextBrightBlue 'g')$(ColourTextBrightGreen 'l')$(ColourTextBrightRed 'e')"

    }

FormatHelpLine()
    {

    # $1 = short parameter
    # $2 = long parameter
    # $3 = description

    if [[ -n $1 && -n $2 ]]; then
        printf "  -%-1s, --%-18s %s\n" "$1" "$2" "$3"
    elif [[ -z $1 && -n $2 ]]; then
        printf "   %-1s  --%-18s %s\n" '' "$2" "$3"
    else
        printf "   %-1s    %-18s %s\n" '' '' "$3"
    fi

    }

RenameExtAsType()
    {

    # checks output of 'identify -format "%m"' and ensures provided file extension matches
    # $1 = image filename. Is it really a valid image?
    # stdout = image type
    # $? = 0 if it IS an image, 1 if not an image

    local returncode=0

    if [[ -n $IDENTIFY_BIN ]]; then
        [[ -z $1 ]] && returncode=1
        [[ ! -e $1 ]] && returncode=1

        if [[ $returncode -eq 0 ]]; then
            rawtype=$($IDENTIFY_BIN -format "%m" "$1")
            returncode=$?
        fi

        if [[ $returncode -eq 0 ]]; then
            # only want first 4 chars
            imagetype="${rawtype:0:4}"

            # exception to handle identify's output for animated gifs i.e. "GIFGIFGIFGIFGIF"
            [[ $imagetype = 'GIFG' ]] && imagetype='GIF'

            # exception to handle identify's output for BMP i.e. "BMP3"
            [[ $imagetype = 'BMP3' ]] && imagetype='BMP'

            # exception to handle identify's output for RAW i.e. "CRAW"
            [[ $imagetype = 'CRAW' ]] && imagetype='RAW'

            case "$imagetype" in
                PNG|JPEG|GIF|BMP|SVG|ICO|WEBP|RAW)
                    # move file into temp file
                    mv "$1" "$1".tmp

                    # then back but with new extension created from $imagetype
                    mv "$1".tmp "${1%.*}.$(Lowercase "$imagetype")"
                    echo "$imagetype"
                    ;;
                *)
                    # not a valid image
                    returncode=1
                    ;;
            esac
        fi
    fi

    return $returncode

    }

AllowableFileType()
    {

    # only these image types are considered acceptable
    # $1 = string to check
    # $? = 0 if OK, 1 if not

    local lcase=$(Lowercase "$1")
    local ext=$(echo "${lcase:(-5)}" | $SED_BIN "s/.*\(\.[^\.]*\)$/\1/")

    # if string does not have a '.' then assume no extension present
    [[ ! "$ext" = *"."* ]] && ext=''

    case "${ext#.}" in
        png|jpg|jpeg|gif|bmp|svg|ico|webp|raw)
            # valid image type
            return 0
            ;;
        *)
            # not a valid image
            return 1
            ;;
    esac

    }

ScrapeSearchResults()
    {

    #-------------------------- "These are the regexes you're looking for" -------------------------------------
    # They turn a single, long file of Google HTML, CSS and Javascript into a nice, neat textfile,
    # one URL per row and each pointing to an original image address found by Google.
    #-----------------------------------------------------------------------------------------------------------
    #
    # sed   1. add 2 x newline chars before each occurence of '<div',
    #       2. remove ' notranslate' (if this is one of the odd times Google have added it),
    #
    # grep  3. only list lines with '<div class="rg_meta">',
    #
    # sed   4. remove lines with 'YouTube' (case insensitive),
    #       5. remove lines with 'Vimeo' (case insensitive),
    #       6. add newline char before first occurence of 'http',
    #       7. remove from '<div' to newline,
    #       8. remove from '","ow"' to end of line,
    #       9. remove from '?' to end of line.
    #
    #-----------------------------------------------------------------------------------------------------------

    cat "$searchresults_pathfile" \
    | $SED_BIN 's|<div|\n\n&|g;s| notranslate||g' \
    | grep '<div class="rg_meta">' \
    | $SED_BIN '/youtube/Id;/vimeo/Id;s|http|\n&|;s|<div.*\n||;s|","ow".*||;s|\?.*||' \
    > "$imagelinks_pathfile"

    }

CTRL_C_Captured()
    {

    DebugFuncEntry

    echo

    if [[ $display_colour = true ]]; then
        echo " -> $(ColourTextBrightRed '[SIGINT]') cleanup ..."
    else
        echo " -> [SIGINT] cleanup ..."
    fi

    KillActiveDownloads

    DebugFuncExit
    Finish

    }

KillActiveDownloads()
    {

    # remove any image files where processing by [_GetImage_] was incomplete

    local existing_pathfile=''
    local existing_file=''

    kill $(jobs -rp) 2>/dev/null
    wait 2>/dev/null

    for existing_pathfile in "$download_run_count_path"/*; do
        existing_file="$(basename "$existing_pathfile")"
        rm -f "$existing_pathfile"
        rm -f "$target_path/$IMAGE_FILE_PREFIX($existing_file)".*
        DebugFuncSuccess "$(FormatLink "$existing_file")"
    done

    }

DebugScriptEntry()
    {

    DebugEntry "$(FormatScript)"

    }

DebugScriptExit()
    {

    DebugExit "$(FormatScript)"

    }

DebugScriptNow()
    {

    DebugNow "$(FormatScript)"

    }

DebugScriptVal()
    {

    [[ -n $1 && -n $2 ]] && DebugVal "$(FormatScript)" "$1: $2"

    }

DebugScriptVar()
    {

    [[ -n $1 ]] && DebugVar "$(FormatScript)" "$1"

    }

DebugScriptElapsedTime()
    {

    [[ -n $1 ]] && DebugElapsedTime "$(FormatScript)" "$1"

    }

DebugScriptFail()
    {

    [[ -n $1 ]] && DebugFail "$(FormatScript)" "$1"

    }

DebugScriptWarn()
    {

    [[ -n $1 ]] && DebugWarn "$(FormatScript)" "$1"

    }

DebugFuncEntry()
    {

    DebugEntry "$(FormatFunc "${FUNCNAME[1]}")"

    }

DebugFuncExit()
    {

    DebugExit "$(FormatFunc "${FUNCNAME[1]}")"

    }

DebugFuncElapsedTime()
    {

    [[ -n $1 ]] && DebugElapsedTime "$(FormatFunc "${FUNCNAME[1]}")" "$1"

    }

DebugFuncVarAdjust()
    {

    [[ -n $1 && -n $2 ]] && DebugVarAdjust "$(FormatFunc "${FUNCNAME[1]}")" "$1" "$2"

    }

DebugFuncSuccess()
    {

    DebugSuccess "$(FormatFunc "${FUNCNAME[1]}")" "$1"

    }

DebugFuncFail()
    {

    DebugFail "$(FormatFunc "${FUNCNAME[1]}")" "$1" "$2"

    }

DebugFuncVar()
    {

    [[ -n $1 ]] && DebugVar "$(FormatFunc "${FUNCNAME[1]}")" "$1"

    }

DebugFuncExec()
    {

    [[ -n $1 && -n $2 ]] && DebugExec "$(FormatFunc "${FUNCNAME[1]}")" "$1" "$2"

    }

DebugFuncOpr()
    {

    [[ -n $1 ]] && DebugOpr "$(FormatFunc "${FUNCNAME[1]}")" "$1"

    }

DebugFuncVal()
    {

    [[ -n $1 && -n $2 ]] && DebugVal "$(FormatFunc "${FUNCNAME[1]}")" "$1" "$2"

    }

DebugFuncComment()
    {

    [[ -n $1 ]] && DebugComment "$(FormatFunc "${FUNCNAME[1]}")" "$1"

    }

DebugChildForked()
    {

    [[ -n $_forkname_ ]] && DebugThis '>' "$_forkname_" 'fork'

    }

DebugChildEnded()
    {

    [[ -n $_forkname_ ]] && DebugThis '<' "$_forkname_" 'exit'

    }

DebugChildExec()
    {

    [[ -n $_forkname_ && -n $1 && -n $2 ]] && DebugExec "$_forkname_" "$1" "$2"

    }

DebugChildSuccess()
    {

    [[ -n $_forkname_ && -n $1 ]] && DebugSuccess "$_forkname_" "$1"

    }

DebugChildFail()
    {

    [[ -n $_forkname_ && -n $1 ]] && DebugFail "$_forkname_" "$1"

    }

DebugChildVal()
    {

    [[ -n $_forkname_ && -n $1 && -n $2 ]] && DebugVal "$_forkname_" "$1" "$2"

    }

DebugChildElapsedTime()
    {

    [[ -n $_forkname_ && -n $1 ]] && DebugElapsedTime "$_forkname_" "$1"

    }

DebugEntry()
    {

    [[ -n $1 ]] && DebugThis '\' "$1" 'entry'

    }

DebugExit()
    {

    [[ -n $1 ]] && DebugThis '/' "$1" 'exit'

    }

DebugSuccess()
    {

    [[ -n $1 && -n $2 ]] && DebugThis '$' "$1" "$2" 'OK'

    }

DebugWarn()
    {

    # $1 = section
    # $2 = operation
    # $3 = optional reason

    [[ -z $1 ]] && return 1

    if [[ -n $3 ]]; then
        DebugThis 'x' "$1" "$2" "$3" 'warning'
    else
        DebugThis 'x' "$1" "$2" 'warning'
    fi

    }

DebugFail()
    {

    # $1 = section
    # $2 = operation
    # $3 = optional reason

    [[ -z $1 ]] && return 1

    if [[ -n $3 ]]; then
        DebugThis '!' "$1" "$2" "$3" 'failed'
    else
        DebugThis '!' "$1" "$2" 'failed'
    fi

    }

DebugExec()
    {

    # $1 = process name (function/child/link/search)
    # $2 = command description
    # $3 = command string to be executed

    [[ -n $1 && -n $2 && -n $3 ]] && DebugThis '=' "$1" "$2" "'$3'"

    }

DebugOpr()
    {

    # $1 = process name (function/child/link/search)
    # $2 = operation description

    [[ -n $1 && -n $2 ]] && DebugThis '-' "$1" "$2 ..."

    }

DebugNow()
    {

    [[ -n $1 ]] && DebugVal "$1" "it's now" "$(date)"

    }

DebugVar()
    {

    # Generally, values are output as provided.
    # if a value contains whitespace, surround it with single-quotes.
    # If it's a number from 1000 up, then insert commas as thousands group separators and surround it with double-quotes.

    # $1 = scope
    # $2 = variable name to log the value of

    local displayvalue=''

    if [[ -n ${!2} ]]; then
        value="${!2}"

        if [[ $value = *" "* ]]; then
            displayvalue="'$value'"
        elif [[ $value =~ ^[0-9]+$ ]]; then
            if [[ $value -ge 1000 ]]; then
                displayvalue="\"$(DisplayThousands "$value")\""
            else
                displayvalue="$value"
            fi
        else
            displayvalue="$value"
        fi

        DebugThis 'V' "$1" "\$$2" "$displayvalue"
    else
        DebugThis 'V' "$1" "\$$2" "''"
    fi

    }

DebugVarAdjust()
    {

    # make a record of name and value in debug log
    # $1 = section
    # $2 = name
    # $3 = value (optional)

    [[ -z $1 || -z $2 ]] && return 1

    if [[ -n $3 ]]; then
        DebugThis '~' "$1" "$2" "$3"
    else
        DebugThis '~' "$1" "$2"
    fi

    }

DebugVal()
    {

    # make a record of name and value in debug log
    # $1 = section
    # $2 = name
    # $3 = value (optional)

    [[ -z $1 || -z $2 ]] && return 1

    if [[ -n $3 ]]; then
        DebugThis '?' "$1" "$2" "$3"
    else
        DebugThis '?' "$1" "$2"
    fi

    }

DebugComment()
    {

    [[ -n $1 && -n $2 ]] && DebugThis '#' "$1" "*** $2 ***"

    }

DebugElapsedTime()
    {

    [[ -n $1 && -n $2 ]] && DebugThis 'T' "$1" "elapsed time" "$(ConvertSecs "$(($(date +%s)-$2))")"

    }

DebugThis()
    {

    # $1 = symbol
    # $2 = item
    # $3 = value
    # $4 = value (optional)
    # $5 = value (optional)

    [[ -z $1 || -z $2 || -z $3 ]] && return 1

    { if [[ -n $5 ]]; then
        echo "$1$1 $2: $3: $4: $5"
    elif [[ -n $4 ]]; then
        echo "$1$1 $2: $3: $4"
    else
        echo "$1$1 $2: $3"
    fi } >> "$debug_pathfile"

    }

FormatFuncSearch()
    {

    [[ -n $1 && -n $2 ]] && echo "$(FormatFunc "$1"): $(FormatSearch "$2")"

    }

FormatFuncLink()
    {

    [[ -n $1 && -n $2 ]] && echo "$(FormatFunc "$1"): $(FormatLink "$2")"

    }

FormatScript()
    {

    [[ -n $SCRIPT_FILE ]] && echo "($SCRIPT_FILE)"

    }

FormatFunc()
    {

    [[ -n $1 ]] && echo "($1)"

    }

FormatSearch()
    {

    [[ -n $1 ]] && echo "search ($1)"

    }

FormatLink()
    {

    [[ -n $1 ]] && echo "link ($1)"

    }

DownloaderReturnCodes()
    {

    # $1 = downloader return code
    # echo = return code description

    if [[ $(basename "$DOWNLOADER_BIN") = wget ]]; then
        WgetReturnCodes "$1"
    elif [[ $(basename "$DOWNLOADER_BIN") = curl ]]; then
        CurlReturnCodes "$1"
    else
        DebugFuncFail 'no return codes available for this downloader' 'unable to decode'
        return 1
    fi

    }

WgetReturnCodes()
    {

    # convert Wget return code into a description
    # https://gist.github.com/cosimo/5747881#file-wget-exit-codes-txt

    # $1 = Wget return code
    # echo = text string

    case "$1" in
        0)
            echo "No problems occurred"
            ;;
        2)
            echo "Parse error — for instance, when parsing command-line options, the .wgetrc or .netrc…"
            ;;
        3)
            echo "File I/O error"
            ;;
        4)
            echo "Network failure"
            ;;
        5)
            echo "SSL verification failure"
            ;;
        6)
            echo "Username/password authentication failure"
            ;;
        7)
            echo "Protocol errors"
            ;;
        8)
            echo "Server issued an error response"
            ;;
        *)
            echo "Generic error code"
            ;;
    esac

    }

CurlReturnCodes()
    {

    # convert cURL return code into a description
    # https://ec.haxx.se/usingcurl-returns.html

    # $1 = cURL return code
    # echo = text string

    case "$1" in
        0)
            echo "No problems occurred"
            ;;
        1)
            echo "Unsupported protocol"
            ;;
        2)
            echo "Failed to initialize"
            ;;
        3)
            echo "URL malformed"
            ;;
        4)
            echo "A feature or option that was needed to perform the desired request was not enabled or was explicitly disabled at build-time"
            ;;
        5)
            echo "Couldn't resolve proxy"
            ;;
        6)
            echo "Couldn't resolve host"
            ;;
        7)
            echo "Failed to connect to host"
            ;;
        8)
            echo "Unknown FTP server response"
            ;;
        9)
            echo "FTP access denied"
            ;;
        10)
            echo "FTP accept failed"
            ;;
        11)
            echo "FTP weird PASS reply"
            ;;
        12)
            echo "During an active FTP session (PORT is used) while waiting for the server to connect, the timeout expired"
            ;;
        13)
            echo "Unknown response to FTP PASV command, Curl could not parse the reply sent to the PASV request"
            ;;
        14)
            echo "Unknown FTP 227 format"
            ;;
        15)
            echo "FTP can't get host"
            ;;
        16)
            echo "HTTP/2 error"
            ;;
        17)
            echo "FTP couldn't set binary"
            ;;
        18)
            echo "Partial file"
            ;;
        19)
            echo "FTP couldn't download/access the given file"
            ;;
        21)
            echo "Quote error"
            ;;
        22)
            echo "HTTP page not retrieved"
            ;;
        23)
            echo "Write error"
            ;;
        25)
            echo "Upload failed"
            ;;
        26)
            echo "Read error"
            ;;
        27)
            echo "Out of memory"
            ;;
        28)
            echo "Operation timeout"
            ;;
        30)
            echo "FTP PORT failed"
            ;;
        31)
            echo "FTP couldn't use REST"
            ;;
        33)
            echo "HTTP range error"
            ;;
        34)
            echo "HTTP post error"
            ;;
        35)
            echo "A TLS/SSL connect error"
            ;;
        36)
            echo "Bad download resume"
            ;;
        37)
            echo "Couldn't read the given file when using the FILE:// scheme"
            ;;
        38)
            echo "LDAP cannot bind"
            ;;
        39)
            echo "LDAP search failed"
            ;;
        42)
            echo "Aborted by callback"
            ;;
        43)
            echo "Bad function argument"
            ;;
        45)
            echo "Interface error"
            ;;
        47)
            echo "Too many redirects"
            ;;
        48)
            echo "Unknown option specified to libcurl"
            ;;
        49)
            echo "Malformed telnet option"
            ;;
        51)
            echo "The server's SSL/TLS certificate or SSH fingerprint failed verification"
            ;;
        52)
            echo "The server did not reply anything, which in this context is considered an error"
            ;;
        53)
            echo "SSL crypto engine not found"
            ;;
        54)
            echo "Cannot set SSL crypto engine as default"
            ;;
        55)
            echo "Failed sending network data"
            ;;
        56)
            echo "Fail in receiving network data"
            ;;
        58)
            echo "Problem with the local certificate"
            ;;
        59)
            echo "Couldn't use the specified SSL cipher"
            ;;
        60)
            echo "Peer certificate cannot be authenticated with known CA certificates"
            ;;
        61)
            echo "Unrecognized transfer encoding"
            ;;
        62)
            echo "Invalid LDAP URL"
            ;;
        63)
            echo "Maximum file size exceeded"
            ;;
        64)
            echo "Requested FTP SSL level failed"
            ;;
        65)
            echo "Sending the data requires a rewind that failed"
            ;;
        66)
            echo "Failed to initialize SSL Engine"
            ;;
        67)
            echo "The user name, password, or similar was not accepted and curl failed to log in"
            ;;
        68)
            echo "File not found on TFTP server"
            ;;
        69)
            echo "Permission problem on TFTP server"
            ;;
        70)
            echo "Out of disk space on TFTP server"
            ;;
        71)
            echo "Illegal TFTP operation"
            ;;
        72)
            echo "Unknown TFTP transfer ID"
            ;;
        73)
            echo "File already exists (TFTP)"
            ;;
        74)
            echo "No such user (TFTP)"
            ;;
        75)
            echo "Character conversion failed"
            ;;
        76)
            echo "Character conversion functions required"
            ;;
        77)
            echo "Problem with reading the SSL CA cert"
            ;;
        78)
            echo "The resource referenced in the URL does not exist"
            ;;
        79)
            echo "An unspecified error occurred during the SSH session"
            ;;
        80)
            echo "Failed to shut down the SSL connection"
            ;;
        82)
            echo "Could not load CRL file, missing or wrong format"
            ;;
        83)
            echo "TLS certificate issuer check failed"
            ;;
        84)
            echo "The FTP PRET command failed"
            ;;
        85)
            echo "RTSP: mismatch of CSeq numbers"
            ;;
        86)
            echo "RTSP: mismatch of Session Identifiers"
            ;;
        87)
            echo "unable to parse FTP file list"
            ;;
        88)
            echo "FTP chunk callback reported error"
            ;;
        89)
            echo "No connection available, the session will be queued"
            ;;
        90)
            echo "SSL public key does not matched pinned public key"
            ;;
        91)
            echo "Invalid SSL certificate status"
            ;;
        92)
            echo "Stream error in HTTP/2 framing layer"
            ;;
        *)
            echo "Unknown error code"
            ;;
    esac

    }

ConvertSecs()
    {

    # http://stackoverflow.com/questions/12199631/convert-seconds-to-hours-minutes-seconds
    # $1 = a time in seconds to convert to 'hh:mm:ss'

    ((h=${1}/3600))
    ((m=(${1}%3600)/60))
    ((s=${1}%60))

    printf "%02dh:%02dm:%02ds\n" $h $m $s

    }

ColourBackgroundBlack()
    {

    echo -en '\033[40m'"$(PrintResetColours "$1")"

    }

ColourTextBrightWhite()
    {

    echo -en '\033[1;97m'"$(PrintResetColours "$1")"

    }

ColourTextBrightGreen()
    {

    echo -en '\033[1;32m'"$(PrintResetColours "$1")"

    }

ColourTextBrightOrange()
    {

    echo -en '\033[1;38;5;214m'"$(PrintResetColours "$1")"

    }

ColourTextBrightRed()
    {

    echo -en '\033[1;31m'"$(PrintResetColours "$1")"

    }

ColourTextBrightBlue()
    {

    echo -en '\033[1;94m'"$(PrintResetColours "$1")"

    }

PrintResetColours()
    {

    echo -en "$1"'\033[0m'

    }

RemoveColourCodes()
    {

    # http://www.commandlinefu.com/commands/view/3584/remove-color-codes-special-characters-with-sed
    echo -n "$1" | $SED_BIN "s,\x1B\[[0-9;]*[a-zA-Z],,g"

    }

ShowFail()
    {

    # $1 = message to show in colour if colour is set

    if [[ $display_colour = true ]]; then
        echo -n "$(ColourTextBrightRed "$1")"
    else
        echo -n "$1"
    fi

    }

ShowSuccess()
    {

    # $1 = message to show in colour if colour is set

    if [[ $display_colour = true ]]; then
        echo -n "$(ColourTextBrightGreen "$1")"
    else
        echo -n "$1"
    fi

    }

Lowercase()
    {

    # $1 = some text to convert to lowercase

    tr 'A-Z' 'a-z' <<< "$1"

    }

DisplayISO()
    {

    # show $1 formatted with 'k', 'M', 'G'

    echo "$1" | awk 'BEGIN{ u[0]=""; u[1]=" k"; u[2]=" M"; u[3]=" G"} { n = $1; i = 0; while(n > 1000) { i+=1; n= int((n/1000)+0.5) } print n u[i] } '

    }

DisplayThousands()
    {

    # show $1 formatted with thousands separator

    printf "%'.f\n" "$1"

    }

WantedFonts()
    {

    local font_list=''

    font_list+='Century-Schoolbook-L-Bold-Italic\n'
    font_list+='Droid-Serif-Bold-Italic\n'
    font_list+='FreeSerif-Bold-Italic\n'
    font_list+='Nimbus-Roman-No9-L-Medium-Italic\n'
    font_list+='Times-BoldItalic\n'
    font_list+='URW-Palladio-L-Bold-Italic\n'
    font_list+='Utopia-Bold-Italic\n'
    font_list+='Bitstream-Charter-Bold-Italic\n'

    echo -e "$font_list"

    }

FirstPreferredFont()
    {

    local preferred_fonts=$(WantedFonts)
    local available_fonts=$($CONVERT_BIN -list font | grep "Font:" | $SED_BIN 's| Font: ||')
    local first_available_font=''

    while read -r preferred_font; do
        while read -r available_font; do
            [[ $preferred_font = "$available_font" ]] && break 2
        done <<< "$available_fonts"
    done <<< "$preferred_fonts"

    if [[ -n $preferred_font ]]; then
        echo "$preferred_font"
    else
        # uncomment 2nd line down to return first installed font if no preferred fonts could be found.
        # for 'convert -font' this isn't needed as it will use a default font if specified font is "".

        #read first_available_font others <<< $available_fonts

        echo "$first_available_font"
    fi

    }

ORIGIN="$_"

Init

case "$OSTYPE" in
    "darwin"*)
        SED_BIN='gsed'
        DU_BIN='gdu'
        if [[ $(basename $PACKAGER_BIN) = brew ]]; then
            GETOPT_BIN="$(brew --prefix gnu-getopt)/bin/getopt" # based upon https://stackoverflow.com/a/47542834/6182835
        else
            DebugScriptFail "'brew' executable was not found"
            echo " 'brew' executable was not found!"
            echo -e "\n On this platform, try installing it with:"
            echo ' $ xcode-select --install && ruby -e "$(curl -fsSL git.io/get-brew)"'
            exit 1
        fi
        ;;
    *)
        SED_BIN='sed'
        DU_BIN='du'
        GETOPT_BIN='getopt'
        ;;
esac

user_parameters="$($GETOPT_BIN -o A,C,d,D,E,h,L,N,q,s,S,z,a:,b:,f:,i:,l:,m:,n:,o:,p:,P:,r:,R:,t:,T:,u: -l always-download,condensed,debug,delete-after,exact-search,help,install,lightning,links-only,no-colour,no-color,no-gallery,no-safesearch,quiet,race,random,reindex-rename,save-links,skip-no-size,aspect-ratio:,border-thickness:,colour:,color:,exclude-links:,exclude-words:,failures:,format:,input-links:,input-phrases:,lower-size:,minimum-pixels:,number:,output:,parallel:,phrase:,recent:,retries:,sites:,thumbnails:,timeout:,title:,type:,upper-size:,usage-rights: -n "$(basename "$ORIGIN")" -- "$@")"
user_parameters_result=$?
user_parameters_raw="$*"

if EnvironmentOK; then
    if [[ -n $input_phrases_pathfile ]]; then
        while read -r file_phrase; do
            [[ -n $file_phrase && $file_phrase != \#* ]] && ProcessPhrase "$file_phrase"
        done < "$input_phrases_pathfile"
    elif [[ -n $input_links_pathfile ]]; then
        ProcessLinkList
    else
        ProcessPhrase "$user_phrase"
    fi
fi

Finish
