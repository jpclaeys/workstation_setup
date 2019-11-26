#!/usr/bin/bash
# Removing nohup.out files
find $HOME -type f -name nohup.out -exec rm {} \;
