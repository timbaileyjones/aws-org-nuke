#!/bin/bash -eu
for search_prefix in ${*}
do
  set +e
  echo search_prefix="${search_prefix}"

  role_names=$(aws iam list-roles | jq -r '.Roles[].RoleName' | grep "${search_prefix}-")
  if [ -z "${role_names}" ];then
    echo no roles matching prefix "${search_prefix}"
    continue
  fi

  for role_name in ${role_names}
  do
    echo pruning role $role_name
    policy_arns=$(aws iam list-attached-role-policies --role-name "${role_name}" | jq -r '.AttachedPolicies[].PolicyArn')
    for policy_arn in ${policy_arns}
    do
        echo detaching policy "${policy_arn}" from role "${role_name}"
        aws iam detach-role-policy --role-name "${role_name}" --policy-arn "${policy_arn}"
        echo deleting policy "${policy_arn}"
        aws iam delete-policy --policy-arn "${policy_arn}"
    done


    echo deleting role "${role_name}"
    aws iam delete-role --role-name "${role_name}"
    echo
  done

  #
  #  check for (and delete) policies matching prefixes that were not found by being attached to a role (above)
  #
  policy_arns=$(aws iam list-policies | jq -r '.Policies[].Arn' | grep "${search_prefix}")
  for policy_arn in ${policy_arns}
  do
    echo deleting unattached policy ARN "${policy_arn}"
    aws iam delete-policy --policy-arn "${policy_arn}"
  done
done
exit 0
