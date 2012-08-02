#!/bin/zsh

rm cov_out.file

lcov -c -d . -o cov_out.file
genhtml cov_out.file -o cov_html

open ./cov_html/Airship/Library/PushLib/UAPush.m.gcov.html -a safari
