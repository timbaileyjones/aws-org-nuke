#!/bin/bash
export PARENT_ID=${PARENT_ID:-r-0gtj}

set -e
set -u
export PS4='Line ${LINENO}: '

PREFIX_TO_NUKE=${1:-nothing-at-all}

(for CHILD_ORG_ID in $(aws organizations list-children --parent-id "${PARENT_ID}" --child-type ORGANIZATIONAL_UNIT | jq -r ".Children[].Id")
do
    aws organizations list-children --parent-id "${CHILD_ORG_ID}" --child-type ORGANIZATIONAL_UNIT > .child-ous.json
    aws organizations list-children --parent-id "${CHILD_ORG_ID}" --child-type ACCOUNT > .child-accounts.json

    export SUB_ORG_COUNT=$(    jq -r '.Children | length' < .child-ous.json)
    export SUB_ACCOUNT_COUNT=$(jq -r '.Children | length' < .child-accounts.json)
    echo CHILD_ORG=${CHILD_ORG_ID} SUB_ORG_COUNT=$SUB_ORG_COUNT   SUB_ACCOUNT_COUNT=$SUB_ACCOUNT_COUNT
    if [ "${SUB_ORG_COUNT}" = 0 -a "${SUB_ACCOUNT_COUNT}" = 0 ];then
        ORG_UNIT_NAME=$(aws organizations describe-organizational-unit --organizational-unit-id "${CHILD_ORG_ID}" | jq -r .OrganizationalUnit.Name)
        echo deleting this organizational unit: "${CHILD_ORG_ID}" named "${ORG_UNIT_NAME}"
        aws organizations delete-organizational-unit --organizational-unit-id "${CHILD_ORG_ID}"
        echo
    #else
    #    echo leave this organizational unit alone: "${CHILD_ORG_ID}" - "${ORG_UNIT_NAME}"
    fi

done ) | tee remove-empty-organizations.$(date +%Y%m%d%H%M%S).out

