# repository_updated

This is a shell script to return the number of seconds since
an upstream repository has been updated

## Overview

GitHub doesn't *natively* provide functionality to run an action
in one repository when another repository is updated, especially
when one isn't able to update the other repository.  For example,
if one wants to build a Docker image based on `jq`; since they
(presumably) aren't Stephen Dolan and don't have the ability to
create webhooks in the `stedolan/jq` repository on GitHub, one
can poll the upstream repository on a cron job and only trigger
a fresh build when the `jq` repository has been update.

The definition of "updated" in this sense depends on the type
of query to perform:

* commit : when a commit has been pushed to a branch
* release: when a release is generated

The default query used for commit queries is `main` while the
default query used for release queries is `latest`.  Because
the script calls GitHub's API, we aren't able to pass regular
expressions like `(main|master)`

By default, the script will return the number of seconds since
the repository was last updated.  This value is returned via
STDOUT.  The units may be overridden by passing --seconds
(the default), ## --minutes, --hours, --days, --weeks, --months,
or --years via the CLI.  NOTE: integer division is used; as a
result, any remainder is effectively truncated.  For example,
6 days is truncated to 0 weeks.  Also, because the script is
limited to integer division, "months" are defined as 30 days
and "years" are defined as 365 days.  That is, it doesn't
account for months with other than 30 days (the average month
is 30.25 days), nor does it account for leap years (the average
year is 365.25 days long).

Note: this requires `curl` and `jq` to function properly

## Usage

```text
--authentication : set the authentication token
-a               : see -a
--api            : see -A
-A               : set the API to query
--query          : see -q
-q               : set the query to perform
--days           : see -D
-D               : respond with days
--hours          : see -H
-H               : respond with hours
--minutes        : see -M
--months         : see -O
-M               : respond with minutes
-O               : respond with months
--repo           : see -r
-r               : set the repo to be queried
--seconds        : see -S
-S               : respond with seconds
--type           : see -t
-t               : type of query to perform
--weeks          : see -W
-W               : respond with weeks
--years          : see -Y
-Y               : respond with years
```

### Use in a shell condition

The intended purpose for this script is to be used in conjunction
with periodic polling (e.g., via cron task) and function differently
if the target repository has been updated in the given time frame
vs if the most recent commit is outside of that time frame.  For
example, consider the following:

```bash

if [ $(./repository_updated --hours --repo owner/repo) -le 1 ] ; then
  echo "The repository was updated in the last hour"
fi
```

Code like that could be run hourly (e.g., `@hourly` or `0 * * * *`
via cron) and do something when a commit is "noticed" on the main
branch.

Similarly, one may pull the script directly from GitHub and pipe it
through Bash, such when using as a test as to whether or not to run
a GitHub Action.

```bash
[ $(curl -s https://raw.githubusercontent.com/wesley-dean-flexion/repository_updated/main/repository_updated.bash | bash -s -- --repo stedolan/jq --type release --days) -le 1 ]
```
