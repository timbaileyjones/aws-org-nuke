#!/bin/bash -eux
export PAGER=cat
bucket_prefix=${1}

buckets=$(aws s3api list-buckets | jq -r .Buckets[].Name | grep "${bucket_prefix}-")
#echo buckets=$buckets
for bucket in ${buckets}
do
  #echo ---------------------
  #echo bucket=$bucket

  #aws s3api list-objects --bucket tbj4-cf-base-u62e-use1-prod-s3-replica
  #continue

  #aws s3 rm --recursive "s3://${bucket}/*"

if [ 1 = 1 ] ;then
  aws s3api list-object-versions --bucket ${bucket} |\
       jq -r '.Versions[] | "\(.Key) \(.VersionId)"' |\
  while read key version
  do
    aws s3api delete-objects --bucket $bucket --delete "
        {
            \"Objects\": [
              {
                \"Key\": \"${key}\",
                \"VersionId\": \"${version}\"
              }
            ],
            \"Quiet\": false
          }"
  done
fi
  aws s3api delete-bucket --bucket $bucket
done
