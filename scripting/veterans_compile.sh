#!/bin/sh
set -x
rm ./compiled/veterans.smx;
yes | ./compile.sh ./veterans.sp; cp ./compiled/veterans.smx ../plugins

