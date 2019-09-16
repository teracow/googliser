#!/usr/bin/env bash

shellcheck --shell=bash --exclude=SC2016,SC2005,SC2209,SC2012,SC1003,SC2076,SC2181,SC1117,SC2002,SC2155,SC2015 googliser.sh
#shellcheck --shell=bash googliser.sh
