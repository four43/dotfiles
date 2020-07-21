#!/bin/bash
function trace_line(){
  caller
}
trap trace_line debug

zsh -x -i -c exit

