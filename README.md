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

The definition of "updated" in this sense is when a commit has
been pushed to a particular branch of a particular repository.
The default branch name used by this script is `main`.  Because
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

## Usage

```text
--api    : see -a
-a       : set the API to query
--branch : see -b
-b       : set the branch to be queried
--days   : see -D
-D       : respond with days
--hours  : see -H
-H       : respond with hours
--minutes: see -M
--months : see -O
-M       : respond with minutes
-O       : respond with months
--repo   : see -r
-r       : set the repo to be queried
--seconds: see -S
-S       : respond with seconds
--weeks  : see -W
-W       : respond with weeks
--years  : see -Y
-Y       : respond with years
```
