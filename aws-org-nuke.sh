#!/bin/bash
export DEST_ORG_ID="ou-0gtj-9dcyha66"
set -e
set -u
export PS4='Line ${LINENO}: '

PREFIX_TO_NUKE=${1:-nothing-at-all}
( aws organizations list-accounts > .accounts.json
set +e
cat .accounts.json | jq -r '.Accounts[] | "\(.Name) \(.Status) \(.Id)"' | grep "^${PREFIX_TO_NUKE}-" | sort | while read account_alias status account
do
  echo ; echo setting up for deleting account=$account, $account_alias
  unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

  account_alias=$(echo "${account_alias}" | sed -e's/-prod/-deleted/g')

  if [ $status != ACTIVE ]
  then
      echo Account $account is in $status status, continuing
  else

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
    #aws iam delete-account-alias --account-alias "${account_alias}"
    set -e
cat > aws-nuke-config.yaml << EOF
regions:
  - ${AWS_REGION}
  - global

account-blocklist:
  - "055073553869" # dof/root
  - "903876013112" #cbm-cf-base-networking-prod
  - "218565165464" #cbm-cf-base-logging-prod
  - "981772098476" #cbm-cf-base-ss-prod
  - "121103356385" #cbm-cf-base-backstage-prod
  - "988575203198" #cbm-cf-base-security-prod
  - "776023817471" #cbm-cf-base-mcs-prod
  - "359731104774" #cbm-cf-base-sharedservices-prod
  - "511306004885" #cbm-cf-base-networking-prod
  - "289591525709" #cbm-cf-base-logging-prod
  - "135350223673" #cbm-cf-base-gitlab-prod

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
  - IAMRole
  - IAMPolicy
  - IAMRolePolicy
  - IAMRolePolicyAttachment

EOF
     aws-nuke \
        --no-dry-run \
        --force \
        --force-sleep 3 \
        -c aws-nuke-config.yaml 2>&1 |\
         egrep -v -i 'cannot.delete|Access.Denied'

  fi
    unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
    echo aws organizations close-account --account-id "${account}"
    set +e
    aws organizations close-account --account-id "${account}"

    SOURCE_ORG_ID=$(aws organizations list-parents --child-id "${account}" | jq -r .Parents[0].Id)
    if [ $SOURCE_ORG_ID != $DEST_ORG_ID ]
    then
        echo moving account $account to ${DEST_ORG_ID}
        aws organizations move-account \
               --account-id "${account}" \
               --source-parent-id "${SOURCE_ORG_ID}" \
               --destination-parent-id "${DEST_ORG_ID}"
    else
        echo account $account is already moved to ${DEST_ORG_ID}
    fi


done ) | tee nuke-wrapper-${PREFIX_TO_NUKE}.`date +%Y%m%d%H%M%S`.out
