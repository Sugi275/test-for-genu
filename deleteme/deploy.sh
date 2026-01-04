#!/bin/bash

set -e

# 設定
FUNCTION_NAME="GenUSlackNotification"
ROLE_NAME="GenUSlackNotificationRole"
SLACK_WEBHOOK_URL="https://hooks.slack.com/triggers/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"
REGION="ap-northeast-1"

echo "=== GenU Slack Notification Lambda デプロイ ==="

# 1. Lambda関数をzipで固める
echo "1. Lambda関数をzipで固める..."
zip -r lambda_function.zip lambda_function.py

# 2. IAMロールが存在するか確認
echo "2. IAMロールを確認..."
if aws iam get-role --role-name ${ROLE_NAME} 2>/dev/null; then
    echo "IAMロール ${ROLE_NAME} は既に存在します"
    ROLE_ARN=$(aws iam get-role --role-name ${ROLE_NAME} --query 'Role.Arn' --output text)
else
    echo "IAMロール ${ROLE_NAME} を作成します..."

    # Trust Policy (Lambda実行ロール用)
    cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

    # IAMロールを作成
    ROLE_ARN=$(aws iam create-role \
        --role-name ${ROLE_NAME} \
        --assume-role-policy-document file://trust-policy.json \
        --query 'Role.Arn' \
        --output text)

    echo "IAMロール作成完了: ${ROLE_ARN}"

    # 基本的なLambda実行ポリシーをアタッチ
    aws iam attach-role-policy \
        --role-name ${ROLE_NAME} \
        --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

    echo "ロール作成後、反映を待ちます（10秒）..."
    sleep 10
fi

# 3. Lambda関数が存在するか確認
echo "3. Lambda関数を確認..."
if aws lambda get-function --function-name ${FUNCTION_NAME} --region ${REGION} 2>/dev/null; then
    echo "Lambda関数 ${FUNCTION_NAME} を更新します..."
    aws lambda update-function-code \
        --function-name ${FUNCTION_NAME} \
        --zip-file fileb://lambda_function.zip \
        --region ${REGION}

    # 環境変数を更新
    aws lambda update-function-configuration \
        --function-name ${FUNCTION_NAME} \
        --environment "Variables={SLACK_WEBHOOK_URL=${SLACK_WEBHOOK_URL}}" \
        --region ${REGION}
else
    echo "Lambda関数 ${FUNCTION_NAME} を作成します..."
    aws lambda create-function \
        --function-name ${FUNCTION_NAME} \
        --runtime python3.12 \
        --role ${ROLE_ARN} \
        --handler lambda_function.lambda_handler \
        --zip-file fileb://lambda_function.zip \
        --timeout 30 \
        --memory-size 128 \
        --environment "Variables={SLACK_WEBHOOK_URL=${SLACK_WEBHOOK_URL}}" \
        --region ${REGION}
fi

echo ""
echo "=== デプロイ完了 ==="
echo "Lambda関数名: ${FUNCTION_NAME}"
echo "リージョン: ${REGION}"
echo ""
echo "テスト実行コマンド:"
echo "aws lambda invoke --function-name ${FUNCTION_NAME} --region ${REGION} --payload '{\"ENV_NAME\":\"pr-123\",\"PR_NUMBER\":\"123\",\"BRANCH_NAME\":\"test\",\"GENU_URL\":\"https://example.com\",\"PR_URL\":\"https://github.com/test/pull/123\",\"DEPLOY_STATUS\":\"✅ 成功\"}' response.json"
