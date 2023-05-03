#!/usr/bin/env bash

## @file repository_updated.bash
## @brief script to determine how for long ago a repo was updated
## @details
## GitHub doesn't *natively* provide functionality to run an action
## in one repository when another repository is updated, especially
## when one isn't able to update the other repository.  For example,
## if one wants to build a Docker image based on `jq`; since they
## (presumably) aren't Stephen Dolan and don't have the ability to
## create webhooks in the `stedolan/jq` repository on GitHub, one
## can poll the upstream repository on a cron job and only trigger
## a fresh build when the `jq` repository has been update.
##
## The definition of "updated" in this sense is when a commit has
## been pushed to a particular branch of a particular repository.
## The default branch name used by this script is `main`.  Because
## the script calls GitHub's API, we aren't able to pass regular
## expressions like `(main|master)`
##
## By default, the script will return the number of seconds since
## the repository was last updated.  This value is returned via
## STDOUT.  The units may be overridden by passing --seconds
## (the default), ## --minutes, --hours, --days, --weeks, --months,
## or --years via the CLI.  NOTE: integer division is used; as a
## result, any remainder is effectively truncated.  For example,
## 6 days is truncated to 0 weeks.  Also, because the script is
## limited to integer division, "months" are defined as 30 days
## and "years" are defined as 365 days.  That is, it doesn't
## account for months with other than 30 days (the average month
## is 30.25 days), nor does it account for leap years (the average
## year is 365.25 days long).
##
## @note: this requires `curl` and `jq` to function properly
## @author Wes Dean

set -euo pipefail

## @var SCRIPT_PATH
## @brief path to where the script lives
declare SCRIPT_PATH
# shellcheck disable=SC2034
SCRIPT_PATH="${SCRIPT_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)}"

## @var LIBRARY_PATH
## @brief location where libraries to be included reside
declare LIBRARY_PATH
LIBRARY_PATH="${LIBRARY_PATH:-${SCRIPT_PATH}/lib/}"

## @var DEFAULT_BRANCH
## @brief default branch to query
declare DEFAULT_BRANCH
DEFAULT_BRANCH="${DEFAULT_BRANCU:-main}"

## @var DEFAULT_REPO
## @brief default repositoy to query
declare DEFAULT_REPO
DEFAULT_REPO="${DEFAULT_REPO:-wesley-dean-flexion/repository_updated}"

## @var DEFAULT_DIVISOR
## @brief default value by which to divide the result
declare DEFAULT_DIVISOR
DEFAULT_DIVISOR="${DEFAULT_DIVISOR:-1}"

## @var DEFAULT_API
## @brief default url to the API to query
declare DEFAULT_API
DEFAULT_API="${DEFAULT_API:-api.github.com}"


## @fn time_since_repo_updated()
## @brief return how long it's been since a repo was updated
## @details
## This will return how long it's been since a repository
## was updated via STDOUT.  By default, it queries the GitHub
## API and returns values in seconds.
## @retval 0 something went wrong
## @retval 1 always returns failure
## @par Example
## @code
## printf "It's been %s days since the repo was updated" \
##   "$(time_since_repo_updated divisor=weeks)"
## @endcode
time_since_repo_updated() {
  local "$@"

  repo="${repo:-${DEFAULT_REPO}}"
  branch="${branch:-${DEFAULT_BRANCH}}"
  divisor="${divisor:-${DEFAULT_DIVISOR}}"
  api="${api:-${DEFAULT_API}}"

  url="https://${api}/repos/${repo}/commits/${branch}"

  seconds="$(curl -s "$url" \
    | jq -r "(now - (.commit.author.date | fromdateiso8601) | trunc)")"

  echo "$((seconds / divisor))"

}

## @fn die
## @brief receive a trapped error and display helpful debugging details
## @details
## When called -- presumably by a trap -- die() will provide details
## about what happened, including the filename, the line in the source
## where it happened, and a stack dump showing how we got there.  It
## will then exit with a result code of 1 (failure)
## @retval 1 always returns failure
## @par Example
## @code
## trap die ERR
## @endcode
die() {
  printf "ERROR %s in %s AT LINE %s\n" "$?" "${BASH_SOURCE[0]}" "${BASH_LINENO[0]}" 1>&2

  local i=0
  local FRAMES=${#BASH_LINENO[@]}

  # FRAMES-2 skips main, the last one in arrays
  for ((i = FRAMES - 2; i >= 0; i--)); do
    printf "  File \"%s\", line %s, in %s\n" "${BASH_SOURCE[i + 1]}" "${BASH_LINENO[i]}" "${FUNCNAME[i + 1]}"
    # Grab the source code of the line
    sed -n "${BASH_LINENO[i]}{s/^/    /;p}" "${BASH_SOURCE[i + 1]}"
  done
  exit 1
}

## @fn display_usage
## @brief display some auto-generated usage information
## @details
## This will take two passes over the script -- one to generate
## an overview based on everything between the @file tag and the
## first blank line and another to scan through getopts options
## to extract some hints about how to use the tool.
## @retval 0 if the extraction was successful
## @retval 1 if there was a problem running the extraction
## @par Example
## @code
## for arg in "$@" ; do
##   shift
##   case "$arg" in
##     '--word') set -- "$@" "-w" ;;   ##- see -w
##     '--help') set -- "$@" "-h" ;;   ##- see -h
##     *)        set -- "$@" "$arg" ;;
##   esac
## done
##
## # process short options
## OPTIND=1
###
##
## while getopts "w:h" option ; do
##   case "$option" in
##     w ) word="$OPTARG" ;; ##- set the word value
##     h ) display_usage ; exit 0 ;;
##     * ) printf "Invalid option '%s'" "$option" 2>&1 ; display_usage 1>&2 ; exit 1 ;;
##   esac
## done
## @endcode
display_usage() {
  local overview
  overview="$(sed -Ene '
  /^[[:space:]]*##[[:space:]]*@file/,${/^[[:space:]]*$/q}
  s/[[:space:]]*@(author|copyright|version)/\1:/
  s/[[:space:]]*@(note|remarks?|since|test|todo|version|warning)/\1:\n/
  s/[[:space:]]*@(pre|post)/\1 condition:\n/
  s/^[[:space:]]*##([[:space:]]*@[^[[:space:]]*[[:space:]]*)*//p' < "$0")"

  local usage
  usage="$(
    ( 
      sed -Ene "s/^[[:space:]]*(['\"])([[:alnum:]]*)\1[[:space:]]*\).*##-[[:space:]]*(.*)/\-\2\t\t: \3/p" < "$0"
      sed -Ene "s/^[[:space:]]*(['\"])([-[:alnum:]]*)*\1[[:space:]]*\)[[:space:]]*set[[:space:]]*--[[:space:]]*(['\"])[@$]*\3[[:space:]]*(['\"])(-[[:alnum:]])\4.*##-[[:space:]]*(.*)/\2\t\t: \6/p" < "$0"
    ) | sort --ignore-case
  )"

  if [ -n "$overview" ]; then
    printf "Overview\n%s\n" "$overview"
  fi

  if [ -n "$usage" ]; then
    printf "\nUsage:\n%s\n" "$usage"
  fi
}

###
### If there is a library directory (lib/) relative to the
### script's location by default), then attempt to source
### the *.bash files located there.
###

if [ -n "${LIBRARY_PATH}" ] \
                            && [ -d "${LIBRARY_PATH}" ]; then
  for library in "${LIBRARY_PATH}"*.bash; do
    if [ -e "${library}" ]; then
      # shellcheck disable=SC1090
      . "${library}"
    fi
  done
fi

## @fn main()
## @brief This is the main program loop.
## @details
## This is where the logic for the program lives; it's
## called when the script is run as a script (i.e., not
## when it's sourced or included).
main() {

  trap die ERR

  ###
  ### set values from their defaults here
  ###

  branch="${DEFAULT_BRANCH}"
  repo="${DEFAULT_REPO}"
  api="${DEFAULT_API}"
  divisor="${DEFAULT_DIVISOR}"

  ###
  ### process long options here
  ###

  for arg in "$@"; do
    shift
    case "$arg" in
      '--api') set -- "$@" "-a" ;; ##- see -a
      '--branch') set -- "$@" "-b" ;; ##- see -b
      '--repo') set -- "$@" "-r" ;; ##- see -r
      '--seconds') set -- "$@" "-S" ;; ##- see -S
      '--minutes') set -- "$@" "-M" ;; ##- see -M
      '--hours') set -- "$@" "-H" ;; ##- see -H
      '--days') set -- "$@" "-D" ;; ##- see -D
      '--weeks') set -- "$@" "-W" ;; ##- see -W
      '--months') set -- "$@" "-O" ;; ##- see -O
      '--years') set -- "$@" "-Y" ;; ##- see -Y
      *) set -- "$@" "$arg" ;;
    esac
  done

  ###
  ### process short options here
  ###

  OPTIND=1
  while getopts "SMHDWOYab:r:h" opt; do
    case "$opt" in
      'a') api="$OPTARG" ;; ##- set the API to query
      'b') branch="$OPTARG" ;; ##- set the branch to be queried
      'r') repo="$OPTARG" ;; ##- set the repo to be queried
      'S') divisor=1 ;; ##- respond with seconds
      'M') divisor=60 ;; ##- respond with minutes
      'H') divisor=$((60 * 60)) ;; ##- respond with hours
      'D') divisor=$((24 * 60 * 60)) ;; ##- respond with days
      'W') divisor=$((7 * 24 * 60 * 60)) ;; ##- respond with weeks
      'O') divisor=$((30 * 24 * 60 * 60)) ;; ##- respond with months
      'Y') divisor=$((365 * 24 * 60 * 60)) ;; ##- respond with years
      'h')
        display_usage
        exit 0
        ;; ##- view the help documentation
      *)
        printf "Invalid option '%s'" "$opt" 1>&2
        display_usage 1>&2
        exit 1
        ;;
    esac
  done

  shift "$((OPTIND - 1))"

  ###
  ### program logic goes here
  ###

  time_since_repo_updated \
    repo="${repo}" \
    branch="${branch}" \
    divisor="${divisor}" \
    api="${api}"

}

# if we're not being sourced and there's a function named `main`, run it
[[ "$0" == "${BASH_SOURCE[0]}" ]] && [ "$(type -t "main")" = "function" ] && main "$@"
