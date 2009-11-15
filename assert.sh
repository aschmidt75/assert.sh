#!/bin/bash
# Copyright (C) 2009 Robert Lehmann

args="$(getopt -n "$0" -l verbose,help,stop,discover vhxd $*)" || exit -1
for arg in $args; do
    case "$arg" in
        -h)
            echo "usage: $0 [-vxd] [--verbose] [--stop] [--discover]"
            echo "       `sed 's/./ /g' <<< "$0"` [-h] [--help]"
            exit 0;;
        --help)
            cat <<EOF
Usage: $0 [options]
Language-agnostic unit tests for subprocesses.

Options:
  -v, --verbose    generate output for every individual test
  -x, --stop       stop running tests after the first failure
  -d, --discover   collect test suites only, don't run any tests
  -h               show brief usage information and exit
  --help           show this help message and exit
EOF
            exit 0;;
        -v|--verbose)
            DEBUG=1;;
        -x|--stop)
            STOP=1;;
        -d|--discover)
            DISCOVERONLY=1;;
    esac
done

printf -v _indent "\n\t" # local format helper

_assert_reset() {
    tests_ran=0
    tests_failed=0
    declare -a tests_errors
    tests_starttime="$(date +%s.%N)" # seconds_since_epoch.nanoseconds
}

assert_end() {
    # assert_end [suite ..]
    tests_endtime="$(date +%s.%N)"
    tests="$tests_ran ${*:+$* }tests"
    [[ -n "$DISCOVERONLY" ]] && echo "collected $tests." && return
    [[ -n "$DEBUG" ]] && echo
    report_time="$(bc <<< "$tests_endtime - $tests_starttime" \
        | sed -e 's/\.\([0-9]\{0,3\}\)[0-9]*/.\1s/' -e 's/^\./0./')"
    if [[ "$tests_failed" -eq 0 ]]; then
        echo "all $tests passed in $report_time."
    else
        for error in "${tests_errors[@]}"; do echo "$error"; done
        echo "$tests_failed of $tests failed in $report_time."
    fi
    tests_failed_previous=$tests_failed
    _assert_reset
    return $tests_failed_previous
}

assert() {
    # assert <command> <expected stdout> [stdin] [expected status code]
    (( tests_ran++ ))
    [[ -n "$DISCOVERONLY" ]] && return
    printf -v expected "x$2" # required to overwrite older results
    result="$($1 <<< $3)"
    status=$?
    if [[ -n "$4" && "$status" -ne "$4" ]]; then
        failure="program terminated with code $status instead of $4"
    # Note: $expected is already decorated
    elif [[ "x$result" != "$expected" ]]; then
        result="$(sed -e :a -e '$!N;s/\n/\\n/;ta' <<< "$result")"
        [[ -z "$result" ]] && result="nothing" || result="\"$result\""
        [[ -z "$2" ]] && expected="nothing" || expected="\"$2\""
        failure="expected $expected${_indent}got $result"
    else
        [[ -n "$DEBUG" ]] && echo -n .
        return
    fi
    [[ -n "$DEBUG" ]] && echo -n X
    report="test #$tests_ran \"$1${3:+ <<< $3}\" failed:${_indent}$failure"
    if [[ -n "$STOP" ]]; then
        [[ -n "$DEBUG" ]] && echo
        echo "$report"
        exit 1
    fi
    tests_errors[$tests_failed]="$report"
    (( tests_failed++ ))
}

_assert_reset
