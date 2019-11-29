#!/usr/bin/env bash

cmd=''
cmd_result=0

echo " -> installing:"

SUDO='sudo -k '         # '-k' disables cached authentication, so a password will be required every time
if [[ $EUID -eq 0 ]]; then
    SUDO=''
fi

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

case "$OSTYPE" in
    darwin*)
        if ! (command -v brew >/dev/null); then
            ruby -e "$(curl -fsSL git.io/get-brew)"
        fi
        brew install coreutils ghostscript gnu-sed imagemagick gnu-getopt bash-completion
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
        if [[ $PACKAGER_BIN != unknown ]]; then
            ! (command -v wget>/dev/null) && cmd+=' wget'
            { ! (command -v convert >/dev/null) || ! (command -v montage >/dev/null) || ! (command -v identify >/dev/null) ;} && cmd+=' imagemagick'
            if [[ -n $cmd ]]; then
                cmd="${SUDO}$PACKAGER_BIN install${cmd}"

                echo " -> executing: '$cmd'"
                eval "$cmd"; cmd_result=$?
            fi

            if [[ $cmd_result -eq 0 ]]; then
                cmd="${SUDO}mv googliser-completion /etc/bash_completion.d/"
                echo " -> executing: '$cmd'"
                if (eval "$cmd"); then
                    # shellcheck disable=SC1091
                    . /etc/bash_completion.d/googliser-completion
                fi
            fi
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

if [[ ! -e $SCRIPT_FILE ]]; then
    if (command -v wget >/dev/null); then
        wget -q git.io/googliser.sh
    elif (command -v curl >/dev/null); then
        curl -skL git.io/googliser.sh
    else
        echo "! unable to find a way to download script."
        errorcode=1
        exit 1
    fi
fi

[[ ! -x $SCRIPT_FILE ]] && chmod +x "$SCRIPT_FILE"

cmd="${SUDO}mv "$PWD/$SCRIPT_FILE" /usr/local/bin/googliser"
echo " -> executing: '$cmd'"
eval "$cmd"
