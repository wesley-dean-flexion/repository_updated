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
## The definition of "updated" in this sense depends on the type
## of query to perform:
##
## * commit : when a commit has been pushed to a branch
## * release: when a release is generated
##
## The default query used for commit queries is `main` while the
## default query used for release queries is `latest`.  Because
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

## @var DEFAULT_QUERY
## @brief default value for query (doesn't matter)
declare DEFAULT_QUERY
DEFAULT_QUERY="${DEFAULT_QUERY:-}"

## @var DEFAULT_COMMIT_QUERY
## @brief default commit query to perform
declare DEFAULT_COMMIT_QUERY
DEFAULT_COMMIT_QUERY="${DEFAULT_COMMIT_QUERY:-main}"

## @var DEFAULT_RELEASE_QUERY
## @brief default release query to perform
declare DEFAULT_RELEASE_QUERY
DEFAULT_RELEASE_QUERY="${DEFAULT_RELEASE_QUERY:-latest}"

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

## @var DEFAULT_QUERY_TYPE
## @brief the default type of query to perform
declare DEFAULT_QUERY_TYPE
DEFAULT_QUERY_TYPE="${DEFAULT_QUERY_TYPE:-release}"

## @var DEFAULT_AUTH_TOKEN
## @brief the defaul authentication token to use
declare DEFAULT_AUTH_TOKEN
DEFAULT_AUTH_TOKEN="${DEFAULT_AUTH_TOKEN:-}"

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

  declare -a headers

  headers=()

  repo="${repo:-${DEFAULT_REPO}}"
  query="${query:-${DEFAULT_QUERY}}"
  divisor="${divisor:-${DEFAULT_DIVISOR}}"
  api="${api:-${DEFAULT_API}}"
  query_type="${query_type:-${DEFAULT_QUERY_TYPE}}"
  auth_token="${auth_token:-${DEFAULT_AUTH_TOKEN}}"

  headers+=("-H" "Accept: application/vnd.github+json")
  headers+=("-H" "X-GitHub-Api-Version: 2022-11-28")

  if [ -n "${auth_token}" ]; then
    headers+=("-H" "Authorization: Bearer ${auth_token}")
  fi

  case "$query_type" in
    [Cc]*)
      url="https://${api}/repos/${repo}/commits/${query}"
      query=".commit.author.date"
      ;;

    [Rr]*)
      url="https://${api}/repos/${repo}/releases/${query}"
      query=".created_at"
      ;;

    *)
      echo "Invalid query type '$query_type' provided" 1>&2
      exit 1
      ;;
  esac

  # shellcheck disable=SC20866
  update_time="$(curl -s "${headers[@]}" "$url" | TZ=UTC jq -r "$query | fromdateiso8601 | trunc")"

  seconds=$((EPOCHSECONDS - update_time))

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

  query="${DEFAULT_QUERY}"
  repo="${DEFAULT_REPO}"
  api="${DEFAULT_API}"
  divisor="${DEFAULT_DIVISOR}"
  query_type="${DEFAULT_QUERY_TYPE}"
  auth_token="${DEFAULT_AUTH_TOKEN}"

  ###
  ### process long options here
  ###

  for arg in "$@"; do
    shift
    case "$arg" in
      '--authentication') set -- "$@" "-a" ;; ##- see -a
      '--api') set -- "$@" "-A" ;; ##- see -A
      '--repo') set -- "$@" "-r" ;; ##- see -r
      '--query') set -- "$@" "-q" ;; ##- see -q
      '--type') set -- "$@" "-t" ;; ##- see -t
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
  while getopts "SMHDWOYa:A:q:r:t:h" opt; do
    case "$opt" in
      'a') auth_token="$OPTARG" ;; ##- set the authentication token
      'A') api="$OPTARG" ;; ##- set the API to query
      'q') query="$OPTARG" ;; ##- set the query
      'r') repo="$OPTARG" ;; ##- set the repo to be queried
      't') query_type="$OPTARG" ;; ##- set the type of query to perform
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

  if [ -z "$query" ]; then
    case "$query_type" in
      [Cc]*)  query="$DEFAULT_COMMIT_QUERY" ;;
      [Rr]*)  query="$DEFAULT_RELEASE_QUERY" ;;
      *)
          echo "Invalid query type '$query_type' provided" 1>&2
                                                                  exit 1
                                                                         ;;
    esac
  fi

  ###
  ### program logic goes here
  ###

  time_since_repo_updated \
    repo="${repo}" \
    query="${query}" \
    divisor="${divisor}" \
    api="${api}" \
    query_type="${query_type}" \
    auth_token="${auth_token}"

}

# if we're not being sourced and there's a function named `main`, run it
(return 0 2> /dev/null) || ([ "$(type -t "main")" = "function" ] && main "$@" )
