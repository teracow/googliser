#!/usr/bin/env bash

###############################################################################
# googliser.sh
#
# (C)opyright 2016-2018 Teracow Software
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
#   1   required program unavailable (wget, montage, convert)
#   2   required parameter unspecified or wrong
#   3   could not create output directory for 'phrase'
#   4   could not get a list of search results from Google
#   5   image download aborted as failure limit was reached or ran out of images
#   6   thumbnail gallery build failed
#   7   unable to create a temporary build directory

# debug log first character notation:
#   >   script entry
#   <   script exit
#   \   function entry
#   /   function exit
#   ?   variable value
#   =   evaluation
#   ~   variable had boundary issues so was set within bounds
#   $   success
#   !   failure
#   T   elapsed time

case "$OSTYPE" in
    "darwin"*)
        CMD_READLINK=greadlink
        CMD_HEAD=ghead
        CMD_SED=gsed
        CMD_DU=gdu
        CMD_LS=gls
        CMD_GETOPT="$(brew --prefix gnu-getopt)/bin/getopt" # based upon https://stackoverflow.com/a/47542834/6182835
        ;;
    *)
        CMD_READLINK=readlink
        CMD_HEAD=head
        CMD_SED=sed
        CMD_DU=du
        CMD_LS=ls
        CMD_GETOPT=getopt
        ;;
esac

user_parameters=$($CMD_GETOPT -o h,N,D,s,q,c,C,S,z,L,T:,a:,i:,l:,u:,m:,r:,t:,P:,f:,n:,p:,o: -l help,no-gallery,condensed,debug,delete-after,save-links,quiet,colour,skip-no-size,lightning,links-only,title:,input:,lower-size:,upper-size:,retries:,timeout:,parallel:,failures:,number:,phrase:,minimum-pixels:,aspect-ratio:,usage-rights:,type:,output:,dimensions: -n $($CMD_READLINK -f -- "$0") -- "$@")
user_parameters_result=$?
user_parameters_raw="$@"

Init()
    {

    local script_date=2018-10-17
    script_file=googliser.sh
    script_name="${script_file%.*}"
    local script_details_colour="$(ColourTextBrightWhite "$script_file") - $script_date PID:[$$]"
    local script_details_plain="$script_file - $script_date PID:[$$]"

    # parameter defaults
    images_required_default=25
    parallel_limit_default=10
    fail_limit_default=40
    upper_size_limit_default=0
    lower_size_limit_default=1000
    timeout_default=8
    retries_default=3
    max_results_required=$images_required_default
    fail_limit=$fail_limit_default

    # limits
    google_max=1000
    parallel_max=40
    timeout_max=600
    retries_max=100

    # internals
    local script_starttime=$(date)
    script_startseconds=$(date +%s)
    server=www.google.com
    useragent='Mozilla/5.0 (X11; Linux x86_64; rv:52.0) Gecko/20100101 Firefox/52.0'
    target_path_created=false
    show_help_only=false
    exitcode=0

    # user changable parameters
    user_query=''
    images_required=$images_required_default
    user_fail_limit=$fail_limit
    parallel_limit=$parallel_limit_default
    timeout=$timeout_default
    retries=$retries_default
    upper_size_limit=$upper_size_limit_default
    lower_size_limit=$lower_size_limit_default
    create_gallery=true
    gallery_title=''
    condensed_gallery=false
    save_links=false
    colour=false
    verbose=true
    debug=false
    skip_no_size=false
    remove_after=false
    lightning=false
    min_pixels=''
    aspect_ratio=''
    usage_rights=''
    image_type=''
    input_pathfile=''
    output_path=''
    links_only=false
    dimensions=''

    BuildWorkPaths
    WhatAreMyOptions

    DebugThis '> started' "$script_starttime"
    DebugThis '? $script_details' "$script_details_plain"
    DebugThis '? $user_parameters_raw' "$user_parameters_raw"

    if [[ $verbose = true ]]; then
        if [[ $colour = true ]]; then
            echo " $script_details_colour"
        else
            echo " $script_details_plain"
        fi
    fi

    if [[ $show_help_only = true ]]; then
        DisplayHelp
        return 1
    else
        ValidateParameters
    fi

    DebugThis '= environment' '*** parameters after validation and adjustment ***'
    DebugThis '? $user_query' "$user_query"
    DebugThis '? $images_required' "$images_required"
    DebugThis '? $fail_limit' "$fail_limit"
    DebugThis '? $parallel_limit' "$parallel_limit"
    DebugThis '? $timeout' "$timeout"
    DebugThis '? $retries' "$retries"
    DebugThis '? $upper_size_limit' "$upper_size_limit"
    DebugThis '? $lower_size_limit' "$lower_size_limit"
    DebugThis '? $create_gallery' "$create_gallery"
    DebugThis '? $gallery_title' "$gallery_title"
    DebugThis '? $condensed_gallery' "$condensed_gallery"
    DebugThis '? $save_links' "$save_links"
    DebugThis '? $colour' "$colour"
    DebugThis '? $verbose' "$verbose"
    DebugThis '? $debug' "$debug"
    DebugThis '? $skip_no_size' "$skip_no_size"
    DebugThis '? $remove_after' "$remove_after"
    DebugThis '? $lightning' "$lightning"
    DebugThis '? $min_pixels' "$min_pixels"
    DebugThis '? $aspect_ratio' "$aspect_ratio"
    DebugThis '? $image_type' "$image_type"
    DebugThis '? $usage_rights' "$usage_rights"
    DebugThis '? $input_pathfile' "$input_pathfile"
    DebugThis '? $output_path' "$output_path"
    DebugThis '? $links_only' "$links_only"
    DebugThis '? $dimensions' "$dimensions"
    DebugThis '= environment' '*** internal parameters ***'
    DebugThis '? $google_max' "$google_max"
    DebugThis '? $temp_path' "$temp_path"

    IsReqProgAvail 'wget' || { exitcode=1; return 1 ;}

    if [[ $create_gallery = true && $show_help_only = false ]]; then
        IsReqProgAvail montage || { exitcode=1; return 1 ;}
        IsReqProgAvail convert || { exitcode=1; return 1 ;}
    fi

    IsOptProgAvail identify && ident=true || ident=false

    trap CTRL_C_Captured INT

    return 0

    }

BuildWorkPaths()
    {

    Flee()
        {

        echo "! Unable to create a temporary build directory! Exiting."; exit 7

        }

    image_file_prefix=google-image
    test_file=test-image          # this is used during size testing
    imagelinks_file=download.links.list
    debug_file=debug.log
    gallery_name=googliser-gallery
    current_path="$PWD"

    temp_path=$(mktemp -d "/tmp/${script_name}.$$.XXX") || Flee

    results_run_count_path="${temp_path}/results.running.count"
    mkdir -p "$results_run_count_path" || Flee

    results_success_count_path="${temp_path}/results.success.count"
    mkdir -p "$results_success_count_path" || Flee

    results_fail_count_path="${temp_path}/results.fail.count"
    mkdir -p "$results_fail_count_path" || Flee

    download_run_count_path="${temp_path}/download.running.count"
    mkdir -p "$download_run_count_path" || Flee

    download_success_count_path="${temp_path}/download.success.count"
    mkdir -p "$download_success_count_path" || Flee

    download_fail_count_path="${temp_path}/download.fail.count"
    mkdir -p "$download_fail_count_path" || Flee

    testimage_pathfile="${temp_path}/${test_file}"
    results_pathfile="${temp_path}/results.page.html"
    gallery_title_pathfile="${temp_path}/gallery.title.png"
    gallery_thumbnails_pathfile="${temp_path}/gallery.thumbnails.png"
    gallery_background_pathfile="${temp_path}/gallery.background.png"
    imagelinks_pathfile="${temp_path}/${imagelinks_file}"
    debug_pathfile="${temp_path}/${debug_file}"

    unset -f Flee

    }

WhatAreMyOptions()
    {

    [[ $user_parameters_result -ne 0 ]] && { echo; exitcode=2; return 1 ;}
    [[ $user_parameters = ' --' ]] && { show_help_only=true; exitcode=2; return 1 ;}

    eval set -- "$user_parameters"

    while true; do
        case "$1" in
            -n|--number)
                images_required="$2"
                shift 2
                ;;
            -f|--failures)
                user_fail_limit="$2"
                shift 2
                ;;
            -p|--phrase)
                user_query="$2"
                shift 2
                ;;
            -P|--parallel)
                parallel_limit="$2"
                shift 2
                ;;
            -t|--timeout)
                timeout="$2"
                shift 2
                ;;
            -r|--retries)
                retries="$2"
                shift 2
                ;;
            -u|--upper-size)
                upper_size_limit="$2"
                shift 2
                ;;
            -l|--lower-size)
                lower_size_limit="$2"
                shift 2
                ;;
            -T|--title)
                gallery_title="$2"
                shift 2
                ;;
            -o|--output)
                output_path="$2"
                shift 2
                ;;
            -i|--input)
                input_pathfile="$2"
                shift 2
                ;;
            #--dimensions)
            #   dimensions="$2"
            #   shift 2
            #   ;;
            -S|--skip-no-size)
                skip_no_size=true
                shift
                ;;
            -s|--save-links)
                save_links=true
                shift
                ;;
            -D|--delete-after)
                remove_after=true
                shift
                ;;
            -z|--lightning)
                lightning=true
                shift
                ;;
            -h|--help)
                show_help_only=true
                exitcode=2
                return 1
                ;;
            -c|--colour)
                colour=true
                shift
                ;;
            -N|--no-gallery)
                create_gallery=false
                shift
                ;;
            -C|--condensed)
                condensed_gallery=true
                shift
                ;;
            -q|--quiet)
                verbose=false
                shift
                ;;
            --debug)
                debug=true
                shift
                ;;
            -L|--links-only)
                links_only=true
                shift
                ;;
            -m|--minimum-pixels)
                min_pixels="$2"
                shift 2
                ;;
            -a|--aspect-ratio)
                aspect_ratio="$2"
                shift 2
                ;;
            --type)
                image_type="$2"
                shift 2
                ;;
            --usage-rights)
                usage_rights="$2"
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

DisplayHelp()
    {

    DebugThis "\ [${FUNCNAME[0]}]" 'entry'

    local sample_user_query=cows

    echo
    if [[ $colour = true ]]; then
        echo " Usage: $(ColourTextBrightWhite "./$script_file") [PARAMETERS] ..."
        message="$(ShowGoogle) $(ColourTextBrightBlue "images")"
    else
        echo " Usage: ./$script_file [PARAMETERS] ..."
        message='Google images'
    fi

    echo
    echo " search '$message', download from each of the image URLs, then create a gallery image using ImageMagick."
    echo
    echo " External requirements: Wget"
    echo " and optionally: identify, montage & convert (from ImageMagick)"
    echo
    echo " Questions or comments? teracow@gmail.com"
    echo
    echo " Mandatory arguments for long options are mandatory for short options too. Defaults values are shown in [ ]"
    echo

    if [[ $colour = true ]]; then
        echo " $(ColourTextBrightOrange "* Required *")"
    else
        echo " * Required *"
    fi

    HelpParameterFormat "p" "phrase" "Phrase to search for. Enclose whitespace in quotes. A sub-directory is created with this name unless '--output' is specified."
    echo
    echo " Optional"
    HelpParameterFormat a aspect-ratio "Image aspect ratio. Specify like '-a square'. Presets are:"
    HelpParameterFormat '' '' "'tall'"
    HelpParameterFormat '' '' "'square'"
    HelpParameterFormat '' '' "'wide'"
    HelpParameterFormat '' '' "'panoramic'"
    HelpParameterFormat c colour "Display with ANSI coloured text."
    HelpParameterFormat C condensed "Create a condensed thumbnail gallery. All square images with no tile padding."
    HelpParameterFormat '' debug "Save the debug file [$debug_file] into the output directory."
    #HelpParameterFormat d dimensions "Specify exact image dimensions to download."
    HelpParameterFormat D delete-after "Remove all downloaded images afterwards."
    HelpParameterFormat f failures "Total number of download failures allowed before aborting. [$fail_limit_default] Use 0 for unlimited ($google_max)."
    HelpParameterFormat h help "Display this help then exit."
    HelpParameterFormat i input "A text file containing a list of phrases to download. One phrase per line."
    HelpParameterFormat l lower-size "Only download images that are larger than this many bytes. [$lower_size_limit_default]"
    HelpParameterFormat L links-only "Only get image file URLs. Don't download any images."
    HelpParameterFormat m minimum-pixels "Images must contain at least this many pixels. Specify like '-m 8mp'. Presets are:"
    HelpParameterFormat '' '' "'qsvga' (400 x 300)"
    HelpParameterFormat '' '' "'vga'   (640 x 480)"
    HelpParameterFormat '' '' "'svga'  (800 x 600)"
    HelpParameterFormat '' '' "'xga'   (1024 x 768)"
    HelpParameterFormat '' '' "'2mp'   (1600 x 1200)"
    HelpParameterFormat '' '' "'4mp'   (2272 x 1704)"
    HelpParameterFormat '' '' "'6mp'   (2816 x 2112)"
    HelpParameterFormat '' '' "'8mp'   (3264 x 2448)"
    HelpParameterFormat '' '' "'10mp'  (3648 x 2736)"
    HelpParameterFormat '' '' "'12mp'  (4096 x 3072)"
    HelpParameterFormat '' '' "'15mp'  (4480 x 3360)"
    HelpParameterFormat '' '' "'20mp'  (5120 x 3840)"
    HelpParameterFormat '' '' "'40mp'  (7216 x 5412)"
    HelpParameterFormat '' '' "'70mp'  (9600 x 7200)"
    HelpParameterFormat '' '' "'large'"
    HelpParameterFormat '' '' "'medium'"
    HelpParameterFormat '' '' "'icon'"
    HelpParameterFormat n number "Number of images to download. [$images_required_default] Maximum of $google_max."
    HelpParameterFormat N no-gallery "Don't create thumbnail gallery."
    HelpParameterFormat o output "The image output directory. [phrase]"
    HelpParameterFormat P parallel "How many parallel image downloads? [$parallel_limit_default] Maximum of $parallel_max. Use wisely!"
    HelpParameterFormat q quiet "Suppress standard output. Errors are still shown."
    HelpParameterFormat r retries "Retry image download this many times. [$retries_default] Maximum of $retries_max."
    HelpParameterFormat s save-links "Save URL list to file [$imagelinks_file] into the output directory."
    HelpParameterFormat S skip-no-size "Don't download any image if its size cannot be determined."
    HelpParameterFormat t timeout "Number of seconds before aborting each image download. [$timeout_default] Maximum of $timeout_max."
    HelpParameterFormat T title "Title for thumbnail gallery image. Enclose whitespace in quotes. [phrase]"
    HelpParameterFormat '' type "Image type. Specify like '--type clipart'. Presets are:"
    HelpParameterFormat '' '' "'face'"
    HelpParameterFormat '' '' "'photo'"
    HelpParameterFormat '' '' "'clipart'"
    HelpParameterFormat '' '' "'lineart'"
    HelpParameterFormat '' '' "'animated'"
    HelpParameterFormat u upper-size "Only download images that are smaller than this many bytes. [$upper_size_limit_default] Use 0 for unlimited."
    #HelpParameterFormat '?' random "Download a single random image only"
    HelpParameterFormat '' usage-rights "Usage rights. Specify like '--usage-rights reuse'. Presets are:"
    HelpParameterFormat '' '' "'reuse'"
    HelpParameterFormat '' '' "'reuse-with-mod'"
    HelpParameterFormat '' '' "'noncomm-reuse'"
    HelpParameterFormat '' '' "'noncomm-reuse-with-mod'"
    HelpParameterFormat z lightning "Download images even faster by using an optimized set of parameters. For those who really can't wait!"
    echo
    echo " Example:"

    if [[ $colour = true ]]; then
        echo "$(ColourTextBrightWhite " $ ./$script_file -p '$sample_user_query'")"
    else
        echo " $ ./$script_file -p '$sample_user_query'"
    fi

    echo
    echo " This will download the first $images_required_default available images for the phrase '$sample_user_query' and build them into a gallery image."

    DebugThis "/ [${FUNCNAME[0]}]" 'exit'

    }

ValidateParameters()
    {

    DebugThis "\ [${FUNCNAME[0]}]" "entry"

    if [[ $create_gallery = false && $remove_after = true && $links_only = false ]]; then
        echo
        echo " Hmmm, so you've requested:"
        echo " 1. don't create a gallery,"
        echo " 2. delete the images after downloading,"
        echo " 3. don't save the links file."
        echo " Might be time to (R)ead-(T)he-(M)anual. ;)"
        exitcode=2
        return 1
    fi

    if [[ $lightning = true ]]; then
        # Yeah!
        timeout=1
        retries=0
        skip_no_size=true
        parallel_limit=16
        links_only=false
        create_gallery=false
        user_fail_limit=0
    fi

    if [[ $links_only = true ]]; then
        create_gallery=false
        save_links=true
        user_fail_limit=0
    fi

    if [[ $condensed_gallery = true ]]; then
        create_gallery=true
    fi

    case ${images_required#[-+]} in
        *[!0-9]*)
            DebugThis '! specified $images_required' 'invalid'
            echo
            echo "$(ShowAsFailed " !! number specified after (-n, --number) must be a valid integer")"
            exitcode=2
            return 1
            ;;
        *)
            if [[ $images_required -lt 1 ]]; then
                images_required=1
                DebugThis '~ $images_required too low so set sensible minimum' "$images_required"
            fi

            if [[ $images_required -gt $google_max ]]; then
                images_required=$google_max
                DebugThis '~ $images_required too high so set as $google_max' "$images_required"
            fi
            ;;
    esac

    if [[ -n $input_pathfile ]]; then
        if [[ ! -e $input_pathfile ]]; then
            DebugThis '! $input_pathfile' 'not found'
            echo
            echo "$(ShowAsFailed ' !! input file  (-i, --input) was not found')"
            exitcode=2
            return 1
        fi
    fi

    case ${user_fail_limit#[-+]} in
        *[!0-9]*)
            DebugThis '! specified $user_fail_limit' 'invalid'
            echo
            echo "$(ShowAsFailed ' !! number specified after (-f, --failures) must be a valid integer')"
            exitcode=2
            return 1
            ;;
        *)
            if [[ $user_fail_limit -le 0 ]]; then
                user_fail_limit=$google_max
                DebugThis '~ $user_fail_limit too low so set as $google_max' "$user_fail_limit"
            fi

            if [[ $user_fail_limit -gt $google_max ]]; then
                user_fail_limit=$google_max
                DebugThis '~ $user_fail_limit too high so set as $google_max' "$user_fail_limit"
            fi
            ;;
    esac

    case ${parallel_limit#[-+]} in
        *[!0-9]*)
            DebugThis '! specified $parallel_limit' 'invalid'
            echo
            echo "$(ShowAsFailed ' !! number specified after (-P, --parallel) must be a valid integer')"
            exitcode=2
            return 1
            ;;
        *)
            if [[ $parallel_limit -lt 1 ]]; then
                parallel_limit=1
                DebugThis '~ $parallel_limit too low so set as' "$parallel_limit"
            fi

            if [[ $parallel_limit -gt $parallel_max ]]; then
                parallel_limit=$parallel_max
                DebugThis '~ $parallel_limit too high so set as' "$parallel_limit"
            fi
            ;;
    esac

    case ${timeout#[-+]} in
        *[!0-9]*)
            DebugThis '! specified $timeout' 'invalid'
            echo
            echo "$(ShowAsFailed ' !! number specified after (-t, --timeout) must be a valid integer')"
            exitcode=2
            return 1
            ;;
        *)
            if [[ $timeout -lt 1 ]]; then
                timeout=1
                DebugThis '~ $timeout too low so set as' "$timeout"
            fi

            if [[ $timeout -gt $timeout_max ]]; then
                timeout=$timeout_max
                DebugThis '~ $timeout too high so set as' "$timeout"
            fi
            ;;
    esac

    case ${retries#[-+]} in
        *[!0-9]*)
            DebugThis '! specified $retries' 'invalid'
            echo
            echo "$(ShowAsFailed ' !! number specified after (-r, --retries) must be a valid integer')"
            exitcode=2
            return 1
            ;;
        *)
            if [[ $retries -lt 1 ]]; then
                retries=1
                DebugThis '~ $retries too low so set as' "$retries"
            fi

            if [[ $retries -gt $retries_max ]]; then
                retries=$retries_max
                DebugThis '~ $retries too high so set as' "$retries"
            fi
            ;;
    esac

    case ${upper_size_limit#[-+]} in
        *[!0-9]*)
            DebugThis '! specified $upper_size_limit' 'invalid'
            echo
            echo "$(ShowAsFailed ' !! number specified after (-u, --upper-size) must be a valid integer')"
            exitcode=2
            return 1
            ;;
        *)
            if [[ $upper_size_limit -lt 0 ]]; then
                upper_size_limit=0
                DebugThis '~ $upper_size_limit too small so set as' "$upper_size_limit (unlimited)"
            fi
            ;;
    esac

    case ${lower_size_limit#[-+]} in
        *[!0-9]*)
            DebugThis '! specified $lower_size_limit' 'invalid'
            echo
            echo "$(ShowAsFailed ' !! number specified after (-l, --lower-size) must be a valid integer')"
            exitcode=2
            return 1
            ;;
        *)
            if [[ $lower_size_limit -lt 0 ]]; then
                lower_size_limit=0
                DebugThis '~ $lower_size_limit too small so set as' "$lower_size_limit"
            fi

            if [[ $upper_size_limit -gt 0 && $lower_size_limit -gt $upper_size_limit ]]; then
                lower_size_limit=$(($upper_size_limit-1))
                DebugThis "~ \$lower_size_limit larger than \$upper_size_limit ($upper_size_limit) so set as" "$lower_size_limit"
            fi
            ;;
    esac

    if [[ $max_results_required -lt $(($images_required+$user_fail_limit)) ]]; then
        max_results_required=$(($images_required+$user_fail_limit))
        DebugThis '~ $max_results_required too low so set as $images_required + $user_fail_limit' "$max_results_required"
    fi

    dimensions_search=''
    if [[ -n $dimensions ]]; then
        # parse dimensions strings like '1920x1080' or '1920' or 'x1080'
        echo "dimensions: [$dimensions]"

        if grep -q 'x' <<< $dimensions; then
            echo "found a separator"
            image_width=${dimensions%x*}
            image_height=${dimensions#*x}
        else
            image_width=$dimensions
        fi

        [[ $image_width =~ ^-?[0-9]+$ ]] && echo "image_width is a number" || echo "image_width is NOT a number"
        [[ $image_height =~ ^-?[0-9]+$ ]] && echo "image_height is a number" || echo "image_height is NOT a number"

        echo "image_width: [$image_width]"
        echo "image_height: [$image_height]"
        echo "dimensions_search: [$dimensions_search]"

        # only while debugging - remove for release
        exitcode=2
        return 1
    fi

    if [[ -n $dimensions && -n $min_pixels ]]; then
        min_pixels=''
        DebugThis '~ $dimensions was specified so cleared $min_pixels'
    fi

    min_pixels_search=''
    if [[ -n $min_pixels ]]; then
        case "$min_pixels" in
            qsvga|vga|svga|xga|2mp|4mp|6mp|8mp|10mp|12mp|15mp|20mp|40mp|70mp)
                min_pixels_search="isz:lt,islt:${min_pixels}"
                ;;
            large)
                min_pixels_search='isz:l'
                ;;
            medium)
                min_pixels_search='isz:m'
                ;;
            icon)
                min_pixels_search='isz:i'
                ;;
            *)
                echo
                echo "$(ShowAsFailed ' !! (-m, --minimum-pixels) preset invalid')"
                exitcode=2
                return 1
                ;;
        esac
    fi

    aspect_ratio_search=''
    if [[ -n $aspect_ratio ]]; then
        case "$aspect_ratio" in
            tall)
                ar_type='t'
                ;;
            square)
                ar_type='s'
                ;;
            wide)
                ar_type='w'
                ;;
            panoramic)
                ar_type='xw'
                ;;
            *)
                echo
                echo "$(ShowAsFailed ' !! (-a, --aspect-ratio) preset invalid')"
                exitcode=2
                return 1
                ;;
        esac
        [[ -n $ar_type ]] && aspect_ratio_search="iar:${ar_type}"
    fi

    image_type_search=''
    if [[ -n $image_type ]]; then
        case "$image_type" in
            face|photo|clipart|lineart|animated)
                image_type_search="itp:${image_type}"
                ;;
            *)
                echo
                echo "$(ShowAsFailed ' !! (--type) preset invalid')"
                exitcode=2
                return 1
                ;;
        esac
    fi

    usage_rights_search=''
    if [[ -n $usage_rights ]]; then
        case "$usage_rights" in
            reuse-with-mod)
                usage_rights_search='sur:fmc'
                ;;
            reuse)
                usage_rights_search='sur:fc'
                ;;
            noncomm-reuse-with-mod)
                usage_rights_search='sur:fm'
                ;;
            noncomm-reuse)
                usage_rights_search='sur:f'
                ;;
            *)
                echo
                echo "$(ShowAsFailed ' !! (--usage-rights) preset invalid')"
                exitcode=2
                return 1
                ;;
        esac
    fi

    if [[ -n $min_pixels_search || -n $aspect_ratio_search || -n $image_type_search || -n $usage_rights_search ]]; then
        advanced_search="&tbs=${min_pixels_search},${aspect_ratio_search},${image_type_search},${usage_rights_search}"
    fi

    DebugThis "/ [${FUNCNAME[0]}]" 'exit'

    return 0

    }

ProcessQuery()
    {

    echo

    # some last-minute parameter validation - needed when reading phrases from text file
    if [[ -z $user_query ]]; then
        DebugThis '! $user_query' 'unspecified'
        echo "$(ShowAsFailed ' !! search phrase (-p, --phrase) was unspecified')"
        exitcode=2
        return 1
    fi

    echo " -> processing query: \"$user_query\""
    search_phrase="&q=$(echo $user_query | tr ' ' '+')" # replace whitepace with '+' to suit curl/wget
    safe_query="$(echo $user_query | tr ' ' '_')"   # replace whitepace with '_' so less issues later on!
    DebugThis '? $safe_query' "$safe_query"

    if [[ -z $output_path ]]; then
        target_path="${current_path}/${safe_query}"
    else
        safe_path="$(echo $output_path | tr ' ' '_')"   # replace whitepace with '_' so less issues later on!
        DebugThis '? $safe_path' "$safe_path"
        if [[ -n $input_pathfile ]]; then
            target_path="${safe_path}/${safe_query}"
        else
            target_path="$safe_path"
        fi
    fi

    DebugThis '? $target_path' "$target_path"

    if [[ $exitcode -eq 0 && -z $gallery_title ]]; then
        gallery_title=$user_query
        DebugThis '~ $gallery_title was unspecified so set as' "$gallery_title"
    fi

    # create directory for search phrase
    if [[ -e $target_path ]]; then
        if [[ $($CMD_LS -1 $target_path | wc -l) -gt 0 ]]; then
            DebugThis "! create ouput directory [$target_path]" "failed! Directory already exists!"
            echo
            echo "$(ShowAsFailed " !! output directory [$target_path] already exists")"
            exitcode=3
            return 1
        fi
    else
        mkdir -p "$target_path"
        result=$?
        if [[ $result -gt 0 ]]; then
            DebugThis "! create output directory [$target_path]" "failed! mkdir returned: ($result)"
            echo
            echo "$(ShowAsFailed " !! couldn't create output directory [$target_path]")"
            exitcode=3
            return 1
        else
            DebugThis "$ create output directory [$target_path]" "success!"
            target_path_created=true
        fi
    fi

    # download search results pages
    DownloadResultGroups
    if [[ $? -gt 0 ]]; then
        echo "$(ShowAsFailed " !! couldn't download Google search results")"
        exitcode=4
        return 1
    else
        fail_limit=$user_fail_limit
        if [[ $fail_limit -gt $result_count ]]; then
            fail_limit=$result_count
            DebugThis '~ $fail_limit too high so set as $result_count' "$fail_limit"
        fi

        if [[ $images_required -gt $result_count ]]; then
            images_required=$result_count
            DebugThis '~ $images_required too high so set as $result_count' "$result_count"
        fi
    fi

    if [[ $result_count -eq 0 ]]; then
        DebugThis '= zero results returned?' 'Oops...'
        exitcode=4
        return 1
    fi

    # download images
    if [[ $exitcode -eq 0 ]]; then
        if [[ $links_only = false ]]; then
            DownloadImages
            [[ $? -gt 0 ]] && exitcode=5
        fi
    fi

    # build thumbnail gallery even if fail_limit was reached
    if [[ $exitcode -eq 0 || $exitcode -eq 5 ]]; then
        if [[ $create_gallery = true ]]; then
            BuildGallery
            if [[ $? -gt 0 ]]; then
                echo
                echo "$(ShowAsFailed ' !! unable to build thumbnail gallery')"
                exitcode=6
            else
                if [[ $remove_after = true ]]; then
                    rm -f "${target_path}/${image_file_prefix}"*
                    DebugThis '= remove all downloaded images from' "[$target_path]"
                fi
            fi
        fi
    fi

    # copy links file into target directory if possible. If not, then copy to current directory.
    if [[ $exitcode -eq 0 || $exitcode -eq 5 ]]; then
        if [[ $save_links = true ]]; then
            if [[ $target_path_created = true ]]; then
                cp -f "$imagelinks_pathfile" "${target_path}/${imagelinks_file}"
            else
                cp -f "$imagelinks_pathfile" "${current_path}/${imagelinks_file}"
            fi
        fi
    fi

    return 0

    }

DownloadResultGroups()
    {

    DebugThis "\ [${FUNCNAME[0]}]" 'entry'

    local func_startseconds=$(date +%s)
    local groups_max=$(($google_max/100))
    local pointer=0
    local parallel_count=0
    local success_count=0
    local fail_count=0

    InitProgress
    InitResultsCounts

    if [[ $verbose = true ]]; then
        if [[ $colour = true ]]; then
            echo -n " -> searching $(ShowGoogle): "
        else
            echo -n " -> searching Google: "
        fi
    fi

    for ((group=1; group<=$groups_max; group++)); do
        # wait here until a download slot becomes available
        while [[ $parallel_count -eq $parallel_limit ]]; do
            sleep 0.5

            RefreshResultsCounts
            ShowResultDownloadProgress
        done

        pointer=$((($group-1)*100))
        link_index=$(printf "%02d" $(($group-1)))

        # create run file here as it takes too long to happen in background function
        touch "$results_run_count_path/$link_index"
        { DownloadResultGroup_auto "$(($group-1))" "$pointer" "$link_index" & } 2>/dev/null

        RefreshResultsCounts
        ShowResultDownloadProgress

        [[ $(($group*100)) -gt $max_results_required ]] && break
    done

    # wait here while all running downloads finish
    wait 2>/dev/null

    RefreshResultsCounts
    ShowResultDownloadProgress

    # build all groups into a single file
    cat ${results_pathfile}.* > "$results_pathfile"

    ParseResults

    [[ $fail_count -gt 0 ]] && result=1 || result=0

    DebugThis "T [${FUNCNAME[0]}] elapsed time" "$(ConvertSecs "$(($(date +%s)-$func_startseconds))")"
    DebugThis "/ [${FUNCNAME[0]}]" 'exit'

    return $result

    }

DownloadResultGroup_auto()
    {

    # *** This function runs as a background process ***
    # $1 = page group to load:      (0, 1, 2, 3, etc...)
    # $2 = pointer starts at result:    (0, 100, 200, 300, etc...)
    # $3 = debug index identifier e.g. "02"

    local result=0
    local search_group="&ijn=$1"
    local search_start="&start=$2"
    local response=''
    local link_index="$3"

    # ------------- assumptions regarding Google's URL parameters ---------------------------------------------------
    local search_type='&tbm=isch'       # search for images
    local search_language='&hl=en'      # language
    local search_style='&site=imghp'    # result layout style
    local search_match_type='&nfpr=1'   # perform exact string search - does not show most likely match results or suggested search.

    local run_pathfile="$results_run_count_path/$link_index"
    local success_pathfile="$results_success_count_path/$link_index"
    local fail_pathfile="$results_fail_count_path/$link_index"

    DebugThis "- result group ($link_index) download" 'start'

    local downloader_results_get_cmd="wget --quiet --timeout=5 --tries=3 \"https://${server}/search?${search_type}${search_match_type}${search_phrase}${search_language}${search_style}${search_group}${search_start}${advanced_search}\" --user-agent '$useragent' --output-document \"${results_pathfile}.$1\""

    DebugThis "? result group ($link_index) \$downloader_results_get_cmd" "$downloader_results_get_cmd"

    response=$(eval "$downloader_results_get_cmd")
    result=$?

    if [[ $result -eq 0 ]]; then
        DebugThis "$ result group ($link_index) download" 'success!'
        mv "$run_pathfile" "$success_pathfile"
    else
        DebugThis "! result group ($link_index) download" "failed! downloader returned: ($result - $(WgetReturnCodes "$result"))"
        mv "$run_pathfile" "$fail_pathfile"
    fi

    return 0

    }

DownloadImages()
    {

    DebugThis "\ [${FUNCNAME[0]}]" 'entry'

    local func_startseconds=$(date +%s)
    local result_index=0
    local message=''
    local result=0
    local parallel_count=0
    local success_count=0
    local fail_count=0
    local imagelink=''

    [[ $verbose = true ]] && echo -n " -> acquiring images: "

    InitProgress
    InitDownloadsCounts

    while read imagelink; do
        while true; do
            RefreshDownloadCounts
            ShowImageDownloadProgress

            # abort downloading if too many failures
            if [[ $fail_count -ge $fail_limit ]]; then
                result=1

                wait 2>/dev/null

                break 2
            fi

            # wait here until a download slot becomes available
            while [[ $parallel_count -eq $parallel_limit ]]; do
                sleep 0.5

                RefreshDownloadCounts
            done

            # have enough images now so exit loop
            [[ $success_count -eq $images_required ]] &&    break 2

            if [[ $(($success_count+$parallel_count)) -lt $images_required ]]; then
                ((result_index++))
                local link_index=$(printf "%04d" $result_index)

                # create run file here as it takes too long to happen in background function
                touch "${download_run_count_path}/${link_index}"
                { DownloadImage_auto "$imagelink" "$link_index" & } 2>/dev/null

                break
            fi
        done
    done < "$imagelinks_pathfile"

    wait 2>/dev/null

    RefreshDownloadCounts
    ShowImageDownloadProgress

    if [[ $fail_count -gt 0 ]]; then
        # derived from: http://stackoverflow.com/questions/24284460/calculating-rounded-percentage-in-shell-script-without-using-bc
        percent="$((200*($fail_count)/($success_count+$fail_count) % 2 + 100*($fail_count)/($success_count+$fail_count)))%"

        if [[ $colour = true ]]; then
            echo -n "($(ColourTextBrightRed "$percent")) "
        else
            echo -n "($percent) "
        fi
    fi

    if [[ $result -eq 1 ]]; then
        DebugThis "! failure limit reached" "${fail_count}/${fail_limit}"

        if [[ $colour = true ]]; then
            echo "$(ColourTextBrightRed 'Too many failures!')"
        else
            echo "Too many failures!"
        fi
    else
        if [[ $result_index -eq $result_count ]]; then
            DebugThis "! ran out of images to download!" "${result_index}/${result_count}"

            if [[ $colour = true ]]; then
                echo "$(ColourTextBrightRed 'Ran out of images to download!')"
            else
                echo "Ran out of images to download!"
            fi

            result=1
        else
            [[ $verbose = true ]] && echo
        fi
    fi

    if [[ $result -ne 1 ]]; then
        download_bytes="$($CMD_DU "${target_path}/${image_file_prefix}"* -cb | tail -n1 | cut -f1)"
        DebugThis '= downloaded bytes' "$(DisplayThousands "$download_bytes")"

        download_seconds="$(($(date +%s)-$func_startseconds))"
        DebugThis '= download seconds' "$(DisplayThousands "$download_seconds")"

        avg_download_speed="$(DisplayISO "$(($download_bytes/$download_seconds))")"
        DebugThis '= average download speed' "${avg_download_speed}B/s"
    fi

    DebugThis '? $success_count' "$success_count"
    DebugThis '? $fail_count' "$fail_count"
    DebugThis "T [${FUNCNAME[0]}] elapsed time" "$(ConvertSecs "$(($(date +%s)-$func_startseconds))")"
    DebugThis "/ [${FUNCNAME[0]}]" 'exit'

    return $result

    }

DownloadImage_auto()
    {

    # *** This function runs as a background process ***
    # $1 = URL to download
    # $2 = debug index identifier e.g. "0026"

    local result=0
    local size_ok=true
    local get_download=true
    local response=''
    local link_index="$2"

    local run_pathfile="$download_run_count_path/$link_index"
    local success_pathfile="$download_success_count_path/$link_index"
    local fail_pathfile="$download_fail_count_path/$link_index"

    DebugThis "- link ($link_index) download" 'start'

    # extract file extension by checking only last 5 characters of URL (to handle .jpeg as worst case)
    local ext=$(echo ${1:(-5)} | $CMD_SED "s/.*\(\.[^\.]*\)$/\1/")

    [[ ! "$ext" =~ '.' ]] && ext='.jpg' # if URL did not have a file extension then choose jpg as default

    local testimage_pathfileext="${testimage_pathfile}($link_index)${ext}"
    local targetimage_pathfile="${target_path}/${image_file_prefix}"
    local targetimage_pathfileext="${targetimage_pathfile}($link_index)${ext}"

    # are file size limits going to be applied before download?
    if [[ $upper_size_limit -gt 0 || $lower_size_limit -gt 0 ]]; then
        # try to get file size from server
        local downloader_server_response_cmd="wget --spider --server-response --max-redirect 0 --timeout=$timeout --tries=$retries --user-agent \"$useragent\" --output-document \"$testimage_pathfileext\" \"$1\" 2>&1"
        DebugThis "? link ($link_index) \$downloader_server_response_cmd" "$downloader_server_response_cmd"

        response=$(eval "$downloader_server_response_cmd")
        result=$?

        if [[ $result -eq 0 ]]; then
            estimated_size=$(grep 'Content-Length:' <<< "$response" | $CMD_SED 's|^.*: ||' )

            if [[ -z $estimated_size || $estimated_size = unspecified ]]; then
                estimated_size='unknown'
            fi

            DebugThis "? link ($link_index) \$estimated_size" "$estimated_size bytes"

            if [[ $estimated_size != unknown ]]; then
                if [[ $estimated_size -lt $lower_size_limit ]]; then
                    DebugThis "! link ($link_index) (before download) is too small!" "$estimated_size bytes < $lower_size_limit bytes"
                    size_ok=false
                    get_download=false
                fi

                if [[ $upper_size_limit -gt 0 && $estimated_size -gt $upper_size_limit ]]; then
                    DebugThis "! link ($link_index) (before download) is too large!" "$estimated_size bytes > $upper_size_limit bytes"
                    size_ok=false
                    get_download=false
                fi
            else
                if [[ $skip_no_size = true ]]; then
                    DebugThis "! link ($link_index) unknown image size so" 'failed!'
                    get_download=false
                fi
            fi
        else
            DebugThis "! link ($link_index) (before download) server-response" 'failed!'
            estimated_size='unknown'
        fi
    fi

    # perform actual image download
    if [[ $get_download = true ]]; then
        local downloader_get_cmd="wget --max-redirect 0 --timeout=$timeout --tries=$retries --user-agent \"$useragent\" --output-document \"$targetimage_pathfileext\" \"$1\" 2>&1"
        DebugThis "? link ($link_index) \$downloader_get_cmd" "$downloader_get_cmd"

        response=$(eval "$downloader_get_cmd")
        result=$?

        if [[ $result -eq 0 ]]; then
            # http://stackoverflow.com/questions/36249714/parse-download-speed-from-wget-output-in-terminal
            download_speed=$(grep -o '\([0-9.]\+ [KM]B/s\)' <<< "$response")

            if [[ -e $targetimage_pathfileext ]]; then
                actual_size=$(wc -c < "$targetimage_pathfileext")

                if [[ $actual_size = $estimated_size ]]; then
                    DebugThis "? link ($link_index) \$actual_size" "$actual_size bytes (estimate was correct)"
                else
                    DebugThis "? link ($link_index) \$actual_size" "$actual_size bytes (estimate of $estimated_size bytes was incorrect)"
                fi

                if [[ $actual_size -lt $lower_size_limit ]]; then
                    DebugThis "! link ($link_index) \$actual_size (after download) is too small!" "$actual_size bytes < $lower_size_limit bytes"
                    rm -f "$targetimage_pathfileext"
                    size_ok=false
                fi

                if [[ $upper_size_limit -gt 0 && $actual_size -gt $upper_size_limit ]]; then
                    DebugThis "! link ($link_index) \$actual_size (after download) is too large!" "$actual_size bytes > $upper_size_limit bytes"
                    rm -f "$targetimage_pathfileext"
                    size_ok=false
                fi
            else
                # file does not exist
                size_ok=false
            fi

            if [[ $size_ok = true ]]; then
                RenameExtAsType "$targetimage_pathfileext"

                if [[ $? -eq 0 ]]; then
                    mv "$run_pathfile" "$success_pathfile"
                    DebugThis "$ link ($link_index) image type validation" 'success!'
                    DebugThis "$ link ($link_index) download" 'success!'
                    DebugThis "? link ($link_index) \$download_speed" "$download_speed"
                else
                    DebugThis "! link ($link_index) image type validation" 'failed!'
                fi
            else
                # files that were outside size limits still count as failures
                mv "$run_pathfile" "$fail_pathfile"
            fi
        else
            mv "$run_pathfile" "$fail_pathfile"
            DebugThis "! link ($link_index) download" "failed! downloader returned $result ($(WgetReturnCodes "$result"))"

            # delete temp file if one was created
            [[ -e $targetimage_pathfileext ]] && rm -f "$targetimage_pathfileext"
        fi
    else
        mv "$run_pathfile" "$fail_pathfile"
    fi

    return 0

    }

ParseResults()
    {

    DebugThis "\ [${FUNCNAME[0]}]" 'entry'

    result_count=0

    PageScraper

    if [[ -e $imagelinks_pathfile ]]; then
        # check against allowable file types
        while read imagelink; do
            AllowableFileType "$imagelink"
            [[ $? -eq 0 ]] && echo "$imagelink" >> ${imagelinks_pathfile}.tmp
        done < "$imagelinks_pathfile"

        [[ -e ${imagelinks_pathfile}.tmp ]] && mv ${imagelinks_pathfile}.tmp "$imagelinks_pathfile"

        # get link count
        result_count=$(wc -l < "$imagelinks_pathfile")

        # if too many results then trim
        if [[ $result_count -gt $max_results_required ]]; then
            DebugThis '! received more results than required' "$result_count/$max_results_required"

            $CMD_HEAD --lines "$max_results_required" --quiet "$imagelinks_pathfile" > "$imagelinks_pathfile".tmp
            mv "$imagelinks_pathfile".tmp "$imagelinks_pathfile"
            result_count=$max_results_required

            DebugThis '~ trimmed results back to $max_results_required' "$max_results_required"
        fi
    fi

    if [[ $verbose = true ]]; then
        if [[ $result_count -gt 0 ]]; then
            if [[ $colour = true ]]; then
                if [[ $result_count -ge $(($max_results_required)) ]]; then
                    echo "$(ColourTextBrightGreen "$result_count") results!"
                fi

                if [[ $result_count -ge $images_required && $result_count -lt $(($max_results_required)) ]]; then
                    echo "$(ColourTextBrightOrange "$result_count") results!"
                fi

                if [[ $result_count -lt $images_required ]]; then
                    echo "$(ColourTextBrightRed "$result_count") results!"
                fi
            else
                echo "$result_count results!"
            fi
        else
            if [[ $colour = true ]]; then
                echo "$(ColourTextBrightRed 'No results!')"
            else
                echo "No results!"
            fi
        fi
    fi

    DebugThis '? $result_count' "$result_count"
    DebugThis "/ [${FUNCNAME[0]}]" 'exit'

    }

BuildGallery()
    {

    DebugThis "\ [${FUNCNAME[0]}]" 'entry'

    local thumbnail_dimensions='400x400'
    local func_startseconds=$(date +%s)

    InitProgress

    if [[ $verbose = true ]]; then
        echo -n " -> building gallery: "

        if [[ $colour = true ]]; then
            progress_message="$(ColourTextBrightOrange 'stage 1/4')"
        else
            progress_message='stage 1/4'
        fi

        progress_message+=' (construct thumbnails)'
        ProgressUpdater "$progress_message"
    fi

    if [[ $condensed_gallery = true ]]; then
        build_foreground_cmd="convert \"${target_path}/*[0]\" -define jpeg:size=$thumbnail_dimensions -thumbnail ${thumbnail_dimensions}^ -gravity center -extent $thumbnail_dimensions miff:- | montage - -background none -geometry +0+0 miff:- | convert - -background none -gravity north -splice 0x140 -bordercolor none -border 30 \"$gallery_thumbnails_pathfile\""
    else
        build_foreground_cmd="montage \"${target_path}/*[0]\" -background none -shadow -geometry $thumbnail_dimensions miff:- | convert - -background none -gravity north -splice 0x140 -bordercolor none -border 30 \"$gallery_thumbnails_pathfile\""
    fi

    DebugThis '? $build_foreground_cmd' "$build_foreground_cmd"

    eval $build_foreground_cmd 2>/dev/null
    result=$?

    if [[ $result -eq 0 ]]; then
        DebugThis '$ $build_foreground_cmd' 'success!'
    else
        DebugThis '! $build_foreground_cmd' "failed! montage returned: ($result)"
    fi

    if [[ $result -eq 0 ]]; then
        if [[ $verbose = true ]]; then
            if [[ $colour = true ]]; then
                progress_message="$(ColourTextBrightOrange 'stage 2/4')"
            else
                progress_message='stage 2/4'
            fi

            progress_message+=' (draw background pattern)'
            ProgressUpdater "$progress_message"
        fi

        # get image dimensions
        read -r width height <<< $(convert -ping "$gallery_thumbnails_pathfile" -format "%w %h" info:)

        # create a dark image with light sphere in centre
        build_background_cmd="convert -size ${width}x${height} radial-gradient:WhiteSmoke-gray10 \"$gallery_background_pathfile\""

        DebugThis '? $build_background_cmd' "$build_background_cmd"

        eval $build_background_cmd 2>/dev/null
        result=$?

        if [[ $result -eq 0 ]]; then
            DebugThis '$ $build_background_cmd' 'success!'
        else
            DebugThis '! $build_background_cmd' "failed! convert returned: ($result)"
        fi
    fi

    if [[ $result -eq 0 ]]; then
        if [[ $verbose = true ]]; then
            if [[ $colour = true ]]; then
                progress_message="$(ColourTextBrightOrange 'stage 3/4')"
            else
                progress_message='stage 3/4'
            fi

            progress_message+=' (draw title text image)'
            ProgressUpdater "$progress_message"
        fi

        # create title image
        # let's try a fixed height of 100 pixels
        build_title_cmd="convert -size x100 -font $(FirstPreferredFont) -background none -stroke black -strokewidth 10 label:\"\\ \\ $gallery_title\\ \" -blur 0x5 -fill goldenrod1 -stroke none label:\"\\ \\ $gallery_title\\ \" -flatten \"$gallery_title_pathfile\""

        DebugThis '? $build_title_cmd' "$build_title_cmd"

        eval $build_title_cmd 2>/dev/null
        result=$?

        if [[ $result -eq 0 ]]; then
            DebugThis '$ $build_title_cmd' 'success!'
        else
            DebugThis '! $build_title_cmd' "failed! convert returned: ($result)"
        fi
    fi

    if [[ $result -eq 0 ]]; then
        if [[ $verbose = true ]]; then
            if [[ $colour = true ]]; then
                progress_message="$(ColourTextBrightOrange 'stage 4/4')"
            else
                progress_message='stage 4/4'
            fi

            progress_message+=' (compile all images)'
            ProgressUpdater "$progress_message"
        fi

        # compose thumbnails image on background image, then title image on top
        build_compose_cmd="convert \"$gallery_background_pathfile\" \"$gallery_thumbnails_pathfile\" -gravity center -composite \"$gallery_title_pathfile\" -gravity north -geometry +0+40 -composite \"${target_path}/${gallery_name}-($safe_query).png\""

        DebugThis '? $build_compose_cmd' "$build_compose_cmd"

        eval $build_compose_cmd 2>/dev/null
        result=$?

        if [[ $result -eq 0 ]]; then
            DebugThis '$ $build_compose_cmd' 'success!'
        else
            DebugThis '! $build_compose_cmd' "failed! convert returned: ($result)"
        fi
    fi

    [[ -e $gallery_title_pathfile ]] && rm -f "$gallery_title_pathfile"
    [[ -e $gallery_thumbnails_pathfile ]] && rm -f "$gallery_thumbnails_pathfile"
    [[ -e $gallery_background_pathfile ]] && rm -f "$gallery_background_pathfile"

    if [[ $result -eq 0 ]]; then
        DebugThis "$ [${FUNCNAME[0]}]" 'success!'
        if [[ $verbose = true ]]; then
            if [[ $colour = true ]]; then
                ProgressUpdater "$(ColourTextBrightGreen 'done!')"
            else
                ProgressUpdater 'done!'
            fi
        fi
    else
        DebugThis "! [${FUNCNAME[0]}]" "failed! See previous!"

        if [[ $colour = true ]]; then
            ProgressUpdater "$(ColourTextBrightRed 'failed!')"
        else
            ProgressUpdater 'failed!'
        fi
    fi

    [[ $verbose = true ]] && echo

    DebugThis "T [${FUNCNAME[0]}] elapsed time" "$(ConvertSecs "$(($(date +%s)-$func_startseconds))")"
    DebugThis "/ [${FUNCNAME[0]}]" 'exit'

    return $result

    }

Finish()
    {

    # write results into debug file
    DebugThis "T [$script_file] elapsed time" "$(ConvertSecs "$(($(date +%s)-$script_startseconds))")"
    DebugThis "< finished" "$(date)"

    # copy debug file into target directory if possible. If not, then copy to current directory.
    if [[ $debug = true ]]; then
        if [[ $target_path_created = true ]]; then
            [[ -e ${target_path}/${debug_file} ]] && echo "" >> "${target_path}/${debug_file}"
            cp -f "$debug_pathfile" "${target_path}/${debug_file}"
        else
            # append to current path debug file (if it exists)
            [[ -e ${current_path}/${debug_file} ]] && echo "" >> "${current_path}/${debug_file}"
            cat "$debug_pathfile" >> "${current_path}/${debug_file}"
        fi
    fi

    # display end
    if [[ $verbose = true ]]; then
        case $exitcode in
            0)
                echo
                echo " -> $(ShowAsSucceed 'All done!')"
                ;;
            [1-2])
                if [[ $show_help_only != true ]]; then
                    echo
                    echo " use '-h' or '--help' to display parameter list."
                fi
                ;;
            [3-6])
                echo
                echo " -> $(ShowAsFailed 'All done! (with errors)')"
                ;;
            *)
                ;;
        esac
    fi

    [[ $show_help_only = true ]] && exitcode=0

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

    if [[ $1 != $previous_msg ]]; then
        temp=$(RemoveColourCodes "$1")
        current_length=$((${#temp}+1))

        if [[ $current_length -lt $previous_length ]]; then
            appended_length=$(($current_length-$previous_length))
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

InitResultsCounts()
    {

    # clears the paths used to count the search result pages

    [[ -d $results_run_count_path ]] && rm -f ${results_run_count_path}/*
    [[ -d $results_success_count_path ]] && rm -f ${results_success_count_path}/*
    [[ -d $results_fail_count_path ]] && rm -f ${results_fail_count_path}/*

    }

InitDownloadsCounts()
    {

    # clears the paths used to count the downloaded images

    [[ -d $download_run_count_path ]] && rm -f ${download_run_count_path}/*
    [[ -d $download_success_count_path ]] && rm -f ${download_success_count_path}/*
    [[ -d $dowload_fail_count_path ]] && rm -f ${download_fail_count_path}/*

    }

RefreshResultsCounts()
    {

    parallel_count=$($CMD_LS -1 "$results_run_count_path" | wc -l)
    success_count=$($CMD_LS -1 "$results_success_count_path" | wc -l)
    fail_count=$($CMD_LS -1 "$results_fail_count_path" | wc -l)

    }

ShowResultDownloadProgress()
    {

    if [[ $verbose = true ]]; then
        if [[ $colour = true ]]; then
            if [[ $success_count -eq $groups_max ]]; then
                progress_message="$(ColourTextBrightGreen "${success_count}/${groups_max}")"
            else
                progress_message="$(ColourTextBrightOrange "${success_count}/${groups_max}")"
            fi
        else
            progress_message="${success_count}/${groups_max}"
        fi

        progress_message+=' result groups downloaded.'
        ProgressUpdater "$progress_message"
    fi

    }

RefreshDownloadCounts()
    {

    parallel_count=$($CMD_LS -1 "$download_run_count_path" | wc -l)
    success_count=$($CMD_LS -1 "$download_success_count_path" | wc -l)
    fail_count=$($CMD_LS -1 "$download_fail_count_path" | wc -l)

    }

ShowImageDownloadProgress()
    {

    if [[ $verbose = true ]]; then
        # number of image downloads that are OK
        if [[ $colour = true ]]; then
            progress_message="$(ColourTextBrightGreen "${success_count}/${images_required}")"
        else
            progress_message="${success_count}/${images_required}"
        fi

        progress_message+=' downloaded'

        # show the number of files currently downloading (if any)
        if [[ $parallel_count -gt 0 ]]; then
            progress_message+=', '

            if [[ $colour = true ]]; then
                progress_message+="$(ColourTextBrightOrange "${parallel_count}/${parallel_limit}")"
            else
                progress_message+="${parallel_count}/${parallel_limit}"
            fi

            progress_message+=' are in progress'
        fi

        # include failures (if any)
        if [[ $fail_count -gt 0 ]]; then
            progress_message+=' and '

            if [[ $colour = true ]]; then
                progress_message+="$(ColourTextBrightRed "${fail_count}/${fail_limit}")"
            else
                progress_message+="${fail_count}/${fail_limit}"
            fi

            progress_message+=' failed'
        fi

        progress_message+='.'
        ProgressUpdater "$progress_message"
    fi

    }

IsReqProgAvail()
    {

    # $1 = search $PATH for this binary with 'which'
    # $? = 0 if found, 1 if not found

    if (which "$1" > /dev/null 2>&1); then
        DebugThis '$ required program is available' "$1"
    else
        echo " !! required program [$1] is unavailable"
        DebugThis '! required program is unavailable' "$1"
        return 1
    fi

    }

IsOptProgAvail()
    {

    # $1 = search $PATH for this binary with 'which'
    # $? = 0 if found, 1 if not found

    if (which "$1" >/dev/null 2>&1); then
        DebugThis '$ optional program is available' "$1"
    else
        DebugThis '! optional program is unavailable' "$1"
        return 1
    fi

    }

ShowGoogle()
    {

    echo -n "$(ColourTextBrightBlue 'G')$(ColourTextBrightRed 'o')$(ColourTextBrightOrange 'o')$(ColourTextBrightBlue 'g')$(ColourTextBrightGreen 'l')$(ColourTextBrightRed 'e')"

    }

HelpParameterFormat()
    {

    # $1 = short parameter
    # $2 = long parameter
    # $3 = description

    if [[ -n $1 && -n $2 ]]; then
        printf "  -%-1s, --%-15s %s\n" "$1" "$2" "$3"
    elif [[ -z $1 && -n $2 ]]; then
        printf "   %-1s  --%-15s %s\n" '' "$2" "$3"
    else
        printf "   %-1s    %-15s %s\n" '' '' "$3"
    fi

    }

RenameExtAsType()
    {

    # checks output of 'identify -format "%m"' and ensures provided file extension matches
    # $1 = image filename. Is it actually a valid image?
    # $? = 0 if it IS an image, 1 if not an image

    local returncode=0

    if [[ $ident = true ]]; then
        [[ -z $1 ]] && returncode=1
        [[ ! -e $1 ]] && returncode=1

        if [[ $returncode -eq 0 ]]; then
            rawtype=$(identify -format "%m" "$1")
            returncode=$?
        fi

        if [[ $returncode -eq 0 ]]; then
            # only want first 4 chars
            imagetype="${rawtype:0:4}"

            # exception to handle identify's output for animated gifs i.e. "GIFGIFGIFGIFGIF"
            [[ $imagetype = 'GIFG' ]] && imagetype='GIF'

            # exception to handle identify's output for BMP i.e. "BMP3"
            [[ $imagetype = 'BMP3' ]] && imagetype='BMP'

            case "$imagetype" in
                JPEG|GIF|PNG|BMP|ICO)
                    # move file into temp file
                    mv "$1" "$1".tmp

                    # then back but with new extension created from $imagetype
                    mv "$1".tmp "${1%.*}.$(Lowercase "$imagetype")"
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
    local ext=$(echo ${lcase:(-5)} | $CMD_SED "s/.*\(\.[^\.]*\)$/\1/")

    # if string does not have a '.' then assume no extension present
    [[ ! "$ext" =~ '.' ]] && ext=''

    case "$ext" in
        .jpg|.jpeg|.gif|.png|.bmp|.ico)
            # valid image type
            return 0
            ;;
        *)
            # not a valid image
            return 1
            ;;
    esac

    }

PageScraper()
    {

    #------------- when Google change their web-code again, these regexes will need to be changed too --------------
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
    #---------------------------------------------------------------------------------------------------------------

    cat "$results_pathfile" \
    | $CMD_SED 's|<div|\n\n&|g;s| notranslate||g' \
    | grep '<div class="rg_meta">' \
    | $CMD_SED '/youtube/Id;/vimeo/Id;s|http|\n&|;s|<div.*\n||;s|","ow".*||;s|\?.*||' \
    > "$imagelinks_pathfile"

    }

CTRL_C_Captured()
    {

    DebugThis "! [SIGINT]" "detected"

    echo

    if [[ $colour = true ]]; then
        echo " -> $(ColourTextBrightRed '[SIGINT]') - let's cleanup now ..."
    else
        echo " -> [SIGINT] - let's cleanup now ..."
    fi

    # http://stackoverflow.com/questions/81520/how-to-suppress-terminated-message-after-killing-in-bash
    kill $(jobs -p) 2>/dev/null
    wait $(jobs -p) 2>/dev/null

    RefreshDownloadCounts

    if [[ $parallel_count -gt 0 ]]; then
        # remove any image files where processing by [DownloadImage_auto] was incomplete
        for currentfile in $($CMD_LS -1 "$download_run_count_path"); do
            rm -f "${target_path}/${image_file_prefix}($currentfile)".*
            DebugThis "= link ($currentfile) was partially processed" 'deleted!'
        done
    fi

    DebugThis "< finished" "$(date)"

    echo
    echo " -> And ... we're done."

    exit

    }

DebugThis()
    {

    # $1 = item
    # $2 = value

    echo "$1: '$2'" >> "$debug_pathfile"

    }

WgetReturnCodes()
    {

    # convert wget return code into a description
    # https://gist.github.com/cosimo/5747881#file-wget-exit-codes-txt

    # $1 = wget return code
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

ConvertSecs()
    {

    # http://stackoverflow.com/questions/12199631/convert-seconds-to-hours-minutes-seconds
    # $1 = a time in seconds to convert to 'hh:mm:ss'

    ((h=${1}/3600))
    ((m=(${1}%3600)/60))
    ((s=${1}%60))

    printf "%02dh:%02dm:%02ds\n" $h $m $s

    }

ColourTextBrightWhite()
    {

    echo -en '\E[1;97m'"$(PrintResetColours "$1")"

    }

ColourTextBrightGreen()
    {

    echo -en '\E[1;32m'"$(PrintResetColours "$1")"

    }

ColourTextBrightOrange()
    {

    echo -en '\E[1;38;5;214m'"$(PrintResetColours "$1")"

    }

ColourTextBrightRed()
    {

    echo -en '\E[1;31m'"$(PrintResetColours "$1")"

    }

ColourTextBrightBlue()
    {

    echo -en '\E[1;94m'"$(PrintResetColours "$1")"

    }

PrintResetColours()
    {

    echo -en "$1"'\E[0m'

    }

RemoveColourCodes()
    {

    # http://www.commandlinefu.com/commands/view/3584/remove-color-codes-special-characters-with-sed
    echo -n "$1" | $CMD_SED "s,\x1B\[[0-9;]*[a-zA-Z],,g"

    }

ShowAsFailed()
    {

    # $1 = message to show in colour if colour is set

    if [[ $colour = true ]]; then
        echo -n "$(ColourTextBrightRed "$1")"
    else
        echo -n "$1"
    fi

    }

ShowAsSucceed()
    {

    # $1 = message to show in colour if colour is set

    if [[ $colour = true ]]; then
        echo -n "$(ColourTextBrightGreen "$1")"
    else
        echo -n "$1"
    fi

    }

Uppercase()
    {

    # $1 = some text to convert to uppercase

    echo "$1" | tr "[a-z]" "[A-Z]"

    }

Lowercase()
    {

    # $1 = some text to convert to lowercase

    echo "$1" | tr "[A-Z]" "[a-z]"

    }

DisplayISO()
    {

    # show $1 formatted with 'k', 'M', 'G'

    echo $1 | awk 'BEGIN{ u[0]=""; u[1]=" k"; u[2]=" M"; u[3]=" G"} { n = $1; i = 0; while(n > 1000) { i+=1; n= int((n/1000)+0.5) } print n u[i] } '

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
    local available_fonts=$(convert -list font | grep "Font:" | $CMD_SED 's| Font: ||')
    local first_available_font=''

    while read preferred_font; do
        while read available_font; do
            [[ $preferred_font = $available_font ]] && break 2
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

Init

if [[ $exitcode -eq 0 ]]; then
    if [[ -n $input_pathfile ]]; then
        while read -r file_query; do
            if [[ -n $file_query ]]; then
                if [[ $file_query != \#* ]]; then
                    user_query="$file_query"
                    ProcessQuery
                else
                    DebugThis '! ignoring $file_query' 'comment'
                fi
            else
                DebugThis '! ignoring $file_query' 'null'
            fi
        done < "$input_pathfile"
    else
        ProcessQuery
    fi
fi

Finish

exit $exitcode
