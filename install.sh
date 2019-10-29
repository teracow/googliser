#!/bin/bash


OSTYPE=`uname`
echo $OSTYPE

if [ "$OSTYPE" == "Darwin" ];
then
    xcode-select --install
    ruby -e "$(curl -fsSL git.io/get-brew)"
    brew install coreutils ghostscript gnu-sed imagemagick gnu-getopt
elif [ "$OSTYPE" == "Linux" ];
then
     LINUX_DIST=$(cat /etc/os-release | grep "^NAME=" | cut -d '=' -f2 | tr -d '"')
     if [[ $LINUX_DIST =~ "Debian" ]] || [[ $LINUX_DIST =~ "Ubuntu" ]]
     then 
         sudo apt install wget imagemagick
     fi  
fi

mkdir googliser
cd googliser

# Check whether wget or curl is available 
if command -v wget ;
then
    echo "Install googliser through wget"
    wget -qN git.io/googliser.sh && chmod +x googliser.sh
elif command -v curl ;
then 
    echo "Install googliser through curl"
    curl -skLO git.io/googliser.sh && chmod +x googliser.sh
else
    echo "cURL and wget missing. Install one of them and restart"
fi

echo "export PATH=$PATH:$PWD" >> ~/.bash_profile
echo "alias googliser='googliser.sh'" >> ~/.bash_profile
source ~/.bash_profile
