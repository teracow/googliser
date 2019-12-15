#!/usr/bin/env bash

Init()
    {

    readonly SOURCE_SCRIPT_PATHFILE=/tmp/googliser.sh
    readonly TARGET_SCRIPT_PATHFILE=/usr/local/bin/googliser
    readonly SOURCE_COMPLETION_PATHFILE=/tmp/googliser-completion
    BASH_COMPLETION_PACKAGE_PATHFILES=()
    BASH_COMPLETION_PACKAGE_PATHFILES+=(/usr/share/bash-completion/bash_completion)
    BASH_COMPLETION_PACKAGE_PATHFILES+=(/usr/local/etc/bash_completion)
    readonly BASH_COMPLETION_PACKAGE_PATHFILES
    TARGET_COMPLETION_PATHS=()
    TARGET_COMPLETION_PATHS+=(/etc/bash_completion.d)
    TARGET_COMPLETION_PATHS+=(/usr/local/etc/bash_completion.d)
    TARGET_COMPLETION_PATHS+=(/usr/share/bash-completion/completions)
    readonly TARGET_COMPLETION_PATHS

    SUDO='sudo -k '         # '-k' disables cached authentication, so a password will be required every time
    if [[ $EUID -eq 0 || $OSTYPE = "darwin"* ]]; then
        SUDO=''
    fi
    readonly SUDO

    echo " Installing googliser ..."

    FindPackageManager || return 1

    return 0

    }

InstallBrew()
    {

    if [[ $OSTYPE = "darwin"* ]]; then
        if ! (command -v brew >/dev/null); then
            ruby -e "$(curl -fsSL git.io/get-brew)"
        fi
        brew install coreutils ghostscript gnu-sed gnu-getopt
    fi

    return 0

    }

InstallImageMagick()
    {

    local cmd=''
    local cmd_result=0

    case $OSTYPE in
        darwin*)
            brew install imagemagick
            ;;
        linux*)
            if ! (command -v convert >/dev/null) || ! (command -v montage >/dev/null) || ! (command -v identify >/dev/null); then
                if [[ -e /etc/fedora-release ]]; then
                    cmd+='ImageMagick '
                else
                    cmd+='imagemagick '
                fi
            fi

            if [[ -n $cmd ]]; then
                if [[ $(basename "$PACKAGER_BIN") = pacman ]]; then       # pacman has its own syntax
                    cmd="${SUDO}$PACKAGER_BIN -Syu; ${SUDO}$PACKAGER_BIN -S $cmd"
                else
                    cmd="${SUDO}$PACKAGER_BIN install $cmd"
                fi
                [[ -n $SUDO ]] && echo " Executing: '$cmd'"
                eval "$cmd"; cmd_result=$?
            fi

            if [[ $cmd_result -gt 0 ]]; then
                echo " Unable to install additional packages"
                return 1
            fi
            ;;
    esac

    return 0

    }

InstallMain()
    {

    local cmd=''
    local cmd_result=0

    if [[ ! -e $SOURCE_SCRIPT_PATHFILE && -w $(dirname "$SOURCE_SCRIPT_PATHFILE") ]]; then
        if (command -v wget >/dev/null); then
            wget -q git.io/googliser.sh -O "$SOURCE_SCRIPT_PATHFILE"
        elif (command -v curl >/dev/null); then
            curl -skLo "$SOURCE_SCRIPT_PATHFILE" git.io/googliser.sh
        else
            echo " Unable to find a downloader for $(basename "$SOURCE_SCRIPT_PATHFILE")"
            return 1
        fi
    fi

    [[ ! -x $SOURCE_SCRIPT_PATHFILE ]] && chmod +x "$SOURCE_SCRIPT_PATHFILE"

    cmd="${SUDO}mv $SOURCE_SCRIPT_PATHFILE $TARGET_SCRIPT_PATHFILE"
    [[ -n $SUDO ]] && echo " Executing: '$cmd'"
    eval "$cmd"; cmd_result=$?

    if [[ $cmd_result -gt 0 ]]; then
        echo " Unable to move $SOURCE_SCRIPT_PATHFILE into target directory"
        return 1
    fi

    return 0

    }

InstallCompletion()
    {

    local cmd=''
    local cmd_result=0
    local target_completion_path=''
    local bash_completion_package_pathfile=''

    [[ $OSTYPE = "darwin"* ]] && brew install bash-completion

    for target_completion_path in "${TARGET_COMPLETION_PATHS[@]}"; do
        if [[ -d $target_completion_path ]]; then
            for bash_completion_package_pathfile in "${BASH_COMPLETION_PACKAGE_PATHFILES[@]}"; do
                if [[ -f $bash_completion_package_pathfile ]]; then
                    WriteCompletionScript

                    # move completion script into target path
                    cmd="${SUDO}mv $SOURCE_COMPLETION_PATHFILE $target_completion_path"
                    [[ -n $SUDO ]] && echo " Executing: '$cmd'"
                    eval "$cmd"; cmd_result=$?

                    if [[ $cmd_result -gt 0 ]]; then
                        echo " Unable to move $SOURCE_COMPLETION_PATHFILE into $target_completion_path"
                        return 1
                    fi

                    # now source completion script
                    case $OSTYPE in
                        darwin*)
                            SHELL=$(ps -p $$ -o ppid= | xargs ps -o comm= -p)
                            if [[ "$SHELL" == "zsh" ]]; then
                                echo "autoload -Uz compinit && compinit && autoload bashcompinit && bashcompinit" >> "$HOME/.zshrc"
                                LINE="source /usr/local/etc/bash_completion.d/googliser-completion"
                                CONFIG_FILE="$HOME/.zshrc"
                                #. "$HOME/.zshrc"
                            else
                                LINE="[ -f /usr/local/etc/bash_completion ] && . /usr/local/etc/bash_completion"
                                CONFIG_FILE="$HOME/.bash_profile"
                                # shellcheck disable=SC1090
                                . "$HOME/.bash_profile"
                            fi
                            grep -qF -- "$LINE" "$CONFIG_FILE" || echo "$LINE" >> "$CONFIG_FILE"
                            ;;
                        linux*)
                            # shellcheck disable=SC1090
                            . "$target_completion_path/googliser-completion"
                            ;;
                    esac
                    break 2
                fi
            done
        fi
    done

    return 0

    }

WriteCompletionScript()
    {

    [[ ! -e $SOURCE_COMPLETION_PATHFILE && -w $(dirname "$SOURCE_COMPLETION_PATHFILE") ]] && cat > "$SOURCE_COMPLETION_PATHFILE" << 'EOF'
#!/usr/bin/env bash
_GoogliserCompletion()
    {

    # Pointer to current completion word.
    # By convention, it's named "cur" but this isn't strictly necessary.
    local cur

    OPTS='-d -E -h -L -q -s -S -z -a -b -G -i -l -m -n -o -p -P -r -R -t -T -u --debug \
    --exact-search --help --lightning --links-only --no-colour --no-color --safesearch-off \
    --quiet --random --reindex-rename --save-links --skip-no-size --aspect-ratio \
    --border-pixels --colour --color --exclude-links --exclude-words --format --gallery \
    --input-links --input-phrases --lower-size --minimum-pixels --number --output --parallel \
    --phrase --recent --retries --sites --thumbnails --timeout --title --type --upper-size --usage-rights'

    COMPREPLY=()   # Array variable storing the possible completions.
    cur=${COMP_WORDS[COMP_CWORD]}
    prev=${COMP_WORDS[COMP_CWORD-1]}
    case "$cur" in
        -*)
        COMPREPLY=( $( compgen -W "${OPTS}" -- ${cur} ) );;
    esac

    # Display file completion for options that require files as arguments
    case "$prev" in
        --input-links|--exclude-links|-i|--input-phrases)
          _filedir ;;
        -a|--aspect-ratio)
          COMPREPLY=( $( compgen -W "tall square wide panoramic" -- ${cur} ) );;
        --colour|--color)
          COMPREPLY=( $( compgen -W "any full black-white bw transparent clear red \
                                    orange yellow green teal cyan blue purple magenta \
                                    pink white grey gray black brown" -- ${cur} ) );;
        --format)
          COMPREPLY=( $( compgen -W "jpg png gif bmp svg webp ico craw" -- ${cur} ) );;
        -m|--minimum-pixels)
          COMPREPLY=( $( compgen -W "qsvga vga svga xga 2mp 4mp 6mp 8mp 10mp 12mp 15mp\
                                    20mp 40mp 70mp large medium icon" -- ${cur} ) );;
        -R|--recent)
          COMPREPLY=( $( compgen -W "any hour day week month year" -- ${cur} ) );;
        --type)
          COMPREPLY=( $( compgen -W "face photo clipart lineart animated" -- ${cur} ) );;
        --usage-rights)
          COMPREPLY=( $( compgen -W "reuse reuse-with-mod noncomm-reuse noncomm-reuse-with-mod" -- ${cur} ) );;
    esac

    return 0

    }

complete -F _GoogliserCompletion -o filenames googliser
EOF

    }

FindPackageManager()
    {

    local managers=()
    local manager=''

    managers+=(brew)
    managers+=(apt)
    managers+=(yum)
    managers+=(pacman)
    managers+=(opkg)
    managers+=(ipkg)

    for manager in "${managers[@]}"; do
        PACKAGER_BIN=$(command -v "$manager") && break
    done

    if [[ -z $PACKAGER_BIN ]]; then
        echo " Unable to find local package manager"
        return 1
    fi

    readonly PACKAGER_BIN

    return 0

    }

FailedInstall()
    {

    echo " Installation failed"
    exit 1

    }

Init || FailedInstall
InstallBrew || FailedInstall
InstallImageMagick || FailedInstall
InstallMain || FailedInstall
InstallCompletion || FailedInstall

echo " Installation complete"
echo
echo " Type 'googliser -h' for help"
