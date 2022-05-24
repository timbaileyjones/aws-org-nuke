#!/bin/bash
set -u
export PS4='Line ${LINENO}: '

PREFIX_TO_NUKE=${1:-nothing-at-all}
set +e
( aws organizations list-accounts > .accounts.json
cat .accounts.json | jq -r '.Accounts[] | "\(.Name) \(.Id) \(.Status) "' | grep "^${PREFIX_TO_NUKE}-" | sort | while read account_alias account status
do
    if [ $status = ACTIVE ]
    then
      echo aws organizations close-account --account-id "${account}"  \# account_alias=$account_alias
      aws organizations close-account --account-id "${account}"
    else
      echo $account_alias $account is in $status status, skipping....
    fi
done ) | tee close-accounts-with-prefix-${PREFIX_TO_NUKE}.`date +%Y%m%d%H%M%S`.out
