#!/bin/bash

set -e

echo ">>> [localstack-init] Creating SQS queue: solidary-donations"
awslocal sqs create-queue \
  --queue-name solidary-donations \
  --attributes VisibilityTimeout=30

echo ">>> [localstack-init] Creating DynamoDB table: SolidaryTechVolunteers"
awslocal dynamodb create-table \
  --table-name SolidaryTechVolunteers \
  --attribute-definitions AttributeName=volunteer_id,AttributeType=S \
  --key-schema AttributeName=volunteer_id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST

echo ">>> [localstack-init] All AWS resources created successfully."
