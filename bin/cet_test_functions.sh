#!/bin/bash
########################################################################
# cet_test_functions.sh
################################
#
# Provide some functions used commonly by shell-script tests of CET
# code. This script must be sourced, not executed.
#
# N.B. Previously an option was accepted to change the behavior of the
# test functions between exit or return. Due to interactions with the
# existing environment, this mechanism has been replaced by the
# environment variable CET_TF_LEAVE, which has the acceptable values
# "exit" or "return."
#
# In addition, the variable ART_EXEC may be injected into the
# environment to influence the behavior of the run_art function to run a
# different Art exec than the default, "art."
#
# Available functions:
#
# check_command
#   Basic function to echo the command and execute it. This will rarely
# be called from user script directly but is used by other functions.
#
# check_exit
#   Run the provided command and check the exit code against $1 if it is
# numeric. If the first argument is not numeric the desired exit code
# is assumed to be 0.
#
# check_fail
#   Run the provided command and expect it to give a non-zero exit code.
#
# check_files
#   Ensure the provided arguments exist as files and are readable.
#
# run_art
#   Run the art executable (configurable via the environment variable
# ART_EXEC). A numeric first argument will be swallowed by check_exit
# and treated as the desired exit value. The first of the remaining
# arguments must be the configuration file and all other arguments are
# passed through verbatim.
#
# fail_art
#   As run_art, but with an expected non-zero exit value and no
# permitted numeric first argument.
#
# 2011/03/16 CG.
########################################################################

if [[ -n "${CET_TF_LEAVE}" ]]; then
  CET_TF_LEAVE=$(echo "${CET_TF_LEAVE}" | tr '[A-Z]' '[a-z]')
  CET_TF_LEAVE=${CET_TF_LEAVE%.}
  [[ "${CET_TF_LEAVE}" == exit ]] || [[ "${CET_TF_LEAVE}" == return ]] || \
    { echo \
      "Unrecognized value of CET_TF_LEAVE: \"${CET_TF_LEAVE}\": resetting." \
      1>&2
      unset CET_TF_LEAVE
    }
fi
[[ -n "${CET_TF_LEAVE}" ]] || \
  CET_TF_LEAVE=exit # Default behavior on check failure.

####################################
# check_command
function check_command() {
  echo "Invoking $@" 1>&2
  "$@"
  return $?
}

####################################
# check_exit
function check_exit() {
  local exit_code
  local status
  [[ -n "$1" ]] && [[ "$1" == [0-9]* ]] && { (( exit_code = $1 )); shift; }
  check_command "$@"
  (( status = $? ))
  (( status == ${exit_code:-0} )) || \
    { echo \
      "${1} failed check: expected code ${exit_code:-0}, got code ${status}." \
      1>&2
      ${CET_TF_LEAVE} ${status}
    }
}

####################################
# check_fail
function check_fail() {
  check_command "$@"
  (( $? == 0 )) && \
    { echo
      "${1} failed check: expected non-zero exit code; got 0." \
      1>&2
      ${CET_TF_LEAVE} 1
    }
  return 0
}

####################################
# check_files
function check_files() {
  local result
  local file
  (( result = 0 ))
  for file in "$@"; do
    [[ -r "$file" ]] || \
      { echo "Failed to find expected file \"$file\"" 1>&2
        (( ++result ))
      }
  done
  if (( $result == 0 )); then
    return
  else
    echo "Failed to find $result files." 1>&2
    ${CET_TF_LEAVE} 1
  fi
}

####################################
# run_art
function run_art() {
  local exit_code
  [[ -n "$1" ]] && [[ "$1" == [0-9]* ]] && { exit_code="$1 "; shift; }
  check_exit ${exit_code}${ART_EXEC:-art} -c "$@" || ${CET_TF_LEAVE} $?
}

####################################
# fail_art
function fail_art() {
  check_fail ${ART_EXEC:-art} -c "$@" || ${CET_TF_LEAVE} $?
}
