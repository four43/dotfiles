#!/bin/zsh
set -e 
# Basic startup time
time zsh -i -c exit

mv ~/.zshrc ~/.zshrc.pre-profile
echo 'zmodload zsh/zprof' > ~/.zshrc
cat ~/.zshrc.pre-profile >> ~/.zshrc
echo 'zprof' >> ~/.zshrc
time zsh -i -c exit
# mv ~/.zshrc.pre-profile ~/.zshrc
