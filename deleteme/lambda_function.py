import json
import os
import urllib3
from datetime import datetime

http = urllib3.PoolManager()

def lambda_handler(event, context):
    """
    Slack通知用Lambda関数

    イベントパラメータ:
    - ENV_NAME: 環境名 (例: pr-123)
    - PR_NUMBER: PR番号
    - BRANCH_NAME: ブランチ名
    - GENU_URL: GenUのURL
    - PR_URL: Pull RequestのURL
    - DEPLOY_STATUS: デプロイステータス
    - DEPLOY_TIMESTAMP: デプロイ日時 (オプション)
    """

    # Slack Webhook URLを環境変数から取得
    slack_webhook_url = os.environ.get('SLACK_WEBHOOK_URL')
    if not slack_webhook_url:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'SLACK_WEBHOOK_URL environment variable not set'})
        }

    # イベントからパラメータを取得
    env_name = event.get('ENV_NAME', 'unknown')
    pr_number = event.get('PR_NUMBER', 'unknown')
    branch_name = event.get('BRANCH_NAME', 'unknown')
    genu_url = event.get('GENU_URL', '')
    pr_url = event.get('PR_URL', '')
    deploy_status = event.get('DEPLOY_STATUS', '✅ 成功')
    deploy_timestamp = event.get('DEPLOY_TIMESTAMP', datetime.now().strftime('%Y-%m-%d %H:%M:%S JST'))

    # Slackに送信するペイロード
    payload = {
        "ENV_NAME": env_name,
        "PR_NUMBER": pr_number,
        "BRANCH_NAME": branch_name,
        "GENU_URL": genu_url,
        "PR_URL": pr_url,
        "DEPLOY_STATUS": deploy_status,
        "DEPLOY_TIMESTAMP": deploy_timestamp
    }

    try:
        # Slack Webhookに送信
        encoded_data = json.dumps(payload).encode('utf-8')
        response = http.request(
            'POST',
            slack_webhook_url,
            body=encoded_data,
            headers={'Content-Type': 'application/json'}
        )

        if response.status == 200:
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'Slack notification sent successfully',
                    'payload': payload
                })
            }
        else:
            return {
                'statusCode': response.status,
                'body': json.dumps({
                    'error': f'Slack API returned status {response.status}',
                    'response': response.data.decode('utf-8')
                })
            }

    except Exception as e:
        print(f"Error sending Slack notification: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': f'Failed to send Slack notification: {str(e)}'
            })
        }
