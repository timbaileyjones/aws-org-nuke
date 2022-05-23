#!/bin/bash
set -e
set -u
export PS4='Line ${LINENO}: '

PREFIX_TO_NUKE=${1:-nothing-at-all}
( aws organizations list-accounts > .accounts.json
set +e
cat .accounts.json | jq -r '.Accounts[] | "\(.Name) \(.Id)"' | grep "^${PREFIX_TO_NUKE}-" | sort | while read account_alias account
do
  echo setting up for deleting account=$account, $account_alias
  unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

  account_alias=$(echo "${account_alias}" | sed -e's/-prod/-deleted/g')

  #
  # assuming role for target account
  #
  role=arn:aws:iam::$account:role/OrganizationAccountAccessRole
  session_name="${account_alias}"
  temp_role=$(aws sts assume-role --role-arn "$role" --role-session-name "$session_name")
  if [ -z "${temp_role}" ];then
    echo "couldn't assume role, continuing ..."
    continue
  fi

  AWS_ACCESS_KEY_ID=$(echo "$temp_role" | jq -r .Credentials.AccessKeyId)
  AWS_SECRET_ACCESS_KEY=$(echo "$temp_role" | jq -r .Credentials.SecretAccessKey)
  AWS_SESSION_TOKEN=$(echo "$temp_role" | jq -r .Credentials.SessionToken)
  aws configure --profile "bootstrap-${session_name}" set aws_access_key_id "${AWS_ACCESS_KEY_ID}"
  aws configure --profile "bootstrap-${session_name}" set aws_secret_access_key "${AWS_SECRET_ACCESS_KEY}"
  aws configure --profile "bootstrap-${session_name}" set aws_session_token "${AWS_SESSION_TOKEN}"
  export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
  aws sts get-caller-identity

  set +e
  aws iam create-account-alias --account-alias "${account_alias}"
  #echo subshell at $LINENO ; $SHELL
  #aws iam delete-account-alias --account-alias "${account_alias}"
  set -e
cat > aws-nuke-config.yaml << EOF
regions:
- ${AWS_REGION}
- global

account-blocklist:
- "055073553869" # production

accounts:
  "${account}":
    filters:
      IAMRole:
         - type: "glob"
           value: "*"

resource-types:
  # don't nuke IAM users or roles
  excludes:
  - IAMUser
  - IAMROle
  - IAMRolePolicyAttachment

EOF
   aws-nuke \
      --no-dry-run \
      --force \
      --force-sleep 3 \
      -c aws-nuke-config.yaml 2>&1 |\
       egrep -v -i 'cannot.delete|Access.Denied'
#
    unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
    echo aws organizations close-account --account-id "${account}"
    set +e
    echo aws organizations close-account --account-id "${account}"
    set -e
done ) | tee nuke-wrapper-${PREFIX_TO_NUKE}.`date +%Y%m%d%H%M%S`.out
