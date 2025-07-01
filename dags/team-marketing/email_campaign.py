"""
Marketing Team - Email Campaign DAG
"""

from dagster import Definitions, asset


@asset
def email_subscribers():
    """Load email subscribers from database"""
    return {"subscribers": 1000, "segments": ["premium", "basic"]}


@asset
def campaign_content(email_subscribers):
    """Generate personalized email content"""
    return {
        "campaigns": [
            {"segment": "premium", "subject": "Exclusive Offer Just for You!"},
            {"segment": "basic", "subject": "Don't Miss Out - Special Deal Inside"},
        ]
    }


@asset
def send_campaigns(campaign_content):
    """Send email campaigns"""
    return {"emails_sent": 1000, "open_rate": 0.25}


# Define the DAG (code location)
email_campaign_defs = Definitions(assets=[email_subscribers, campaign_content, send_campaigns])
