"""
Finance Team - Daily Reports DAG
"""

from dagster import Definitions, asset


@asset
def daily_transactions():
    """Extract daily transactions from payment system"""
    return {"transactions": 500, "total_amount": 50000}


@asset
def revenue_summary(daily_transactions):
    """Calculate daily revenue summary"""
    return {
        "gross_revenue": daily_transactions["total_amount"],
        "fees": daily_transactions["total_amount"] * 0.03,
        "net_revenue": daily_transactions["total_amount"] * 0.97,
    }


@asset
def finance_report(revenue_summary):
    """Generate daily finance report"""
    return {"report_date": "2025-07-01", "revenue": revenue_summary["net_revenue"], "status": "completed"}


# Define the DAG (code location)
daily_reports_defs = Definitions(assets=[daily_transactions, revenue_summary, finance_report])
