#!/usr/bin/env bash

Init()
    {

    readonly TARGET_SCRIPT_FILE=googliser.sh

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
        brew install coreutils ghostscript gnu-sed gnu-getopt bash-completion
    fi

    return 0

    }

InstallImageMagick()
    {

    cmd=''
    cmd_result=0

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
                cmd="${SUDO}$PACKAGER_BIN install $cmd"

                echo " Executing: '$cmd'"
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

    cmd=''
    cmd_result=0

    if [[ ! -e $TARGET_SCRIPT_FILE ]]; then
        if (command -v wget >/dev/null); then
            wget -q git.io/googliser.sh
        elif (command -v curl >/dev/null); then
            curl -skLO git.io/googliser.sh
        else
            echo " Unable to find a downloader for googliser.sh"
            return 1
        fi
    fi

    [[ ! -x $TARGET_SCRIPT_FILE ]] && chmod +x "$TARGET_SCRIPT_FILE"

    cmd="${SUDO}mv $TARGET_SCRIPT_FILE /usr/local/bin/googliser"
    echo " Executing: '$cmd'"
    eval "$cmd"; cmd_result=$?

    if [[ $cmd_result -gt 0 ]]; then
        echo " Unable to move googliser.sh into target directory"
        return 1
    fi

    return 0

    }

InstallCompletion()
    {

    cmd=''
    cmd_result=0

    cat > googliser-completion << 'EOF'
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
    esac

    return 0

    }

complete -F _GoogliserCompletion -o filenames googliser
EOF

    case $OSTYPE in
        darwin*)
            mv googliser-completion /usr/local/etc/bash_completion.d/
            SHELL=$(ps -p $$ -o ppid= | xargs ps -o comm= -p)
            if [[ "$SHELL" == "zsh" ]]; then
                echo "autoload -Uz compinit && compinit && autoload bashcompinit && bashcompinit" >> "$HOME/.zshrc"
                echo "source /usr/local/etc/bash_completion.d/googliser-completion" >> "$HOME/.zshrc"
                #. "$HOME/.zshrc"
            else
                echo "[ -f /usr/local/etc/bash_completion ] && . /usr/local/etc/bash_completion" >> "$HOME/.bash_profile"
                # shellcheck disable=SC1090
                . "$HOME/.bash_profile"
            fi
            ;;
        linux*)
            if [[ -e /etc/manjaro-release ]]; then
                cmd="${SUDO}mv googliser-completion /usr/share/bash-completion/completions/"
            else
                cmd="${SUDO}mv googliser-completion /etc/bash_completion.d/"
            fi
            echo " Executing: '$cmd'"
            eval "$cmd"; cmd_result=$?

            if [[ $cmd_result -gt 0 ]]; then
                echo " Unable to move completion script into target directory"
                return 1
            fi

            if [[ -e /etc/manjaro-release ]]; then
                # shellcheck disable=SC1091
                . /usr/share/bash-completion/completions/googliser-completion
            else
                # shellcheck disable=SC1091
                . /etc/bash_completion.d/googliser-completion
            fi
            ;;
    esac

    return 0

    }

FindPackageManager()
    {

    local managers=()
    local manager=''

    managers+=(apt)
    managers+=(yum)
    managers+=(pacman)
    managers+=(brew)
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
