"""
Databricks Workflow Trigger DAG with Multiple Job Examples

SCHEDULE EXAMPLES:
==================

1. WITH ASSETS (Data-driven scheduling):
   schedule=(posts_asset & users_asset)  # Runs when BOTH assets are updated

2. WITHOUT ASSETS (Time-based scheduling):
   - Daily:           schedule="0 2 * * *"              # Every day at 2 AM
   - Hourly:          schedule="0 * * * *"              # Every hour
   - Every 6 hours:   schedule="0 */6 * * *"            # At 0, 6, 12, 18
   - Weekly Monday:   schedule="0 2 * * 1"              # Every Monday at 2 AM
   - Monthly 1st:     schedule="0 2 1 * *"              # 1st of month at 2 AM
   - Last Thursday:   schedule="0 2 22-28 * 4"          # Last Thursday (22-28 + day 4)
   - Quarterly:       schedule="0 2 1 1,4,7,10 *"       # Jan, Apr, Jul, Oct
   - No schedule:     schedule=None                     # Manual trigger only

MULTIPLE JOBS PATTERNS:
=======================

A. PARALLEL (All start at once):
   job_1 = DatabricksRunNowOperator(...)
   job_2 = DatabricksRunNowOperator(...)
   job_3 = DatabricksRunNowOperator(...)
   # No dependencies

B. SEQUENTIAL (One after another):
   job_1 >> job_2 >> job_3

C. FAN-OUT (One to many):
   job_1 >> [job_2, job_3, job_4]

D. FAN-IN (Many to one):
   [job_1, job_2, job_3] >> job_4

E. COMPLEX:
   job_1 >> [job_2, job_3] >> job_4
"""

from datetime import datetime, timedelta
from airflow.sdk import DAG
from airflow.providers.databricks.operators.databricks import DatabricksRunNowOperator
from produce_data_assets import posts_asset, users_asset


# ========================================
# EXAMPLE 1: With Assets (Current)
# ========================================
dag_asset_triggered = DAG(
    dag_id="trigger_databricks_workflow_dag",
    description="Run when both posts and users assets are ready",
    schedule=(posts_asset & users_asset),  # Runs when BOTH assets update
    start_date=datetime(2025, 1, 1),
    catchup=False,
)

run_databricks_workflow = DatabricksRunNowOperator(
    task_id="run_databricks_workflow",
    databricks_conn_id="databricks_conn",
    job_id=1054308664529427,  # Example Databricks job
    dag=dag_asset_triggered,
)


# Scheduled Every Sunday at 9 AM

dag_weekly = DAG(
    dag_id="Talent_Experience_Tagging_Incremental_Loading",
    description="Run Databricks job every Sunday at 9 AM",
    schedule="0 9 * * 0",  # Sunday 09:00 (0=Sunday)
    start_date=datetime(2025, 1, 1),
    catchup=False,
)

job_bronze = DatabricksRunNowOperator(
    task_id="Talent_experience_tagging",
    databricks_conn_id="databricks_conn",
    job_id=695583825615209,
    dag=dag_weekly,
)

# ========================================
# EXAMPLE 2: Multiple Jobs - Sequential
# ========================================
# with DAG(
#     dag_id="databricks_sequential_jobs",
#     schedule="0 2 * * *",  # Daily at 2 AM
# ):
#     job_bronze = DatabricksRunNowOperator(
#         task_id="process_bronze_layer",
#         databricks_conn_id="databricks_conn",
#         job_id="1054308664529427"
#     )
#
#     job_silver = DatabricksRunNowOperator(
#         task_id="process_silver_layer",
#         databricks_conn_id="databricks_conn",
#         job_id="1054308664529428"
#     )
#
#     job_gold = DatabricksRunNowOperator(
#         task_id="process_gold_layer",
#         databricks_conn_id="databricks_conn",
#         job_id="1054308664529429"
#     )
#
#     # Sequential: bronze → silver → gold
#     job_bronze >> job_silver >> job_gold


# ========================================
# EXAMPLE 3: Multiple Jobs - Parallel
# ========================================
# with DAG(
#     dag_id="databricks_parallel_jobs",
#     schedule="0 */6 * * *",  # Every 6 hours
# ):
#     job_users = DatabricksRunNowOperator(
#         task_id="process_users",
#         databricks_conn_id="databricks_conn",
#         job_id="1054308664529427"
#     )
#
#     job_posts = DatabricksRunNowOperator(
#         task_id="process_posts",
#         databricks_conn_id="databricks_conn",
#         job_id="1054308664529428"
#     )
#
#     job_comments = DatabricksRunNowOperator(
#         task_id="process_comments",
#         databricks_conn_id="databricks_conn",
#         job_id="1054308664529429"
#     )
#
#     # All run in parallel (no dependencies)


# ========================================
# EXAMPLE 4: Fan-Out Pattern
# ========================================
# with DAG(
#     dag_id="databricks_fanout_pattern",
#     schedule="0 2 * * 1",  # Every Monday at 2 AM
# ):
#     ingest_data = DatabricksRunNowOperator(
#         task_id="ingest_raw_data",
#         databricks_conn_id="databricks_conn",
#         job_id="1054308664529427"
#     )
#
#     transform_users = DatabricksRunNowOperator(
#         task_id="transform_users",
#         databricks_conn_id="databricks_conn",
#         job_id="1054308664529428"
#     )
#
#     transform_posts = DatabricksRunNowOperator(
#         task_id="transform_posts",
#         databricks_conn_id="databricks_conn",
#         job_id="1054308664529429"
#     )
#
#     transform_analytics = DatabricksRunNowOperator(
#         task_id="transform_analytics",
#         databricks_conn_id="databricks_conn",
#         job_id="1054308664529430"
#     )
#
#     # One to many: ingest → [users, posts, analytics]
#     ingest_data >> [transform_users, transform_posts, transform_analytics]


# ========================================
# EXAMPLE 5: Last Thursday of Month
# ========================================
# with DAG(
#     dag_id="databricks_monthly_report",
#     schedule="0 2 22-28 * 4",  # Last Thursday (days 22-28 + Thursday)
# ):
#     generate_monthly_report = DatabricksRunNowOperator(
#         task_id="generate_monthly_report",
#         databricks_conn_id="databricks_conn",
#         job_id="1054308664529427",
#         notebook_params={
#             "report_type": "monthly_summary",
#             "report_date": "{{ ds }}"
#         }
#     )


# ========================================
# EXAMPLE 6: Quarterly Report (No Assets)
# ========================================
# with DAG(
#     dag_id="databricks_quarterly_report",
#     schedule="0 2 1 1,4,7,10 *",  # Jan 1, Apr 1, Jul 1, Oct 1 at 2 AM
# ):
#     run_quarterly_job = DatabricksRunNowOperator(
#         task_id="run_quarterly_analysis",
#         databricks_conn_id="databricks_conn",
#         job_id="1054308664529427"
#     )


# ========================================
# EXAMPLE 7: Manual Trigger Only
# ========================================
# with DAG(
#     dag_id="databricks_manual_trigger",
#     schedule=None,  # No automatic schedule - manual only
# ):
#     run_adhoc_job = DatabricksRunNowOperator(
#         task_id="run_adhoc_analysis",
#         databricks_conn_id="databricks_conn",
#         job_id="1054308664529427"
#     )


# ========================================
# EXAMPLE 8: Complex Workflow
# ========================================
# with DAG(
#     dag_id="databricks_complex_workflow",
#     schedule="0 2 * * *",  # Daily at 2 AM
# ):
#     # Step 1: Ingestion
#     ingest = DatabricksRunNowOperator(
#         task_id="ingest_data",
#         databricks_conn_id="databricks_conn",
#         job_id="1054308664529427"
#     )
#
#     # Step 2: Parallel transformations
#     transform_1 = DatabricksRunNowOperator(
#         task_id="transform_dataset_1",
#         databricks_conn_id="databricks_conn",
#         job_id="1054308664529428"
#     )
#
#     transform_2 = DatabricksRunNowOperator(
#         task_id="transform_dataset_2",
#         databricks_conn_id="databricks_conn",
#         job_id="1054308664529429"
#     )
#
#     # Step 3: Quality checks
#     quality_check = DatabricksRunNowOperator(
#         task_id="data_quality_check",
#         databricks_conn_id="databricks_conn",
#         job_id="1054308664529430"
#     )
#
#     # Step 4: Final aggregation
#     aggregate = DatabricksRunNowOperator(
#         task_id="aggregate_results",
#         databricks_conn_id="databricks_conn",
#         job_id="1054308664529431"
#     )
#
#     # Workflow: ingest → [transform_1, transform_2] → quality_check → aggregate
#     ingest >> [transform_1, transform_2] >> quality_check >> aggregate


# ========================================
# CRON SCHEDULE QUICK REFERENCE
# ========================================
# Format: "minute hour day month day_of_week"
#
# minute:       0-59
# hour:         0-23
# day:          1-31
# month:        1-12
# day_of_week:  0-6 (0=Sunday, 1=Monday, ..., 6=Saturday)
#
# Special:
# *     = every
# */n   = every n
# n-m   = range from n to m
# n,m   = specific values n and m
#
# Examples:
# "0 2 * * *"        = Every day at 2:00 AM
# "0 */6 * * *"      = Every 6 hours
# "0 2 * * 1"        = Every Monday at 2 AM
# "0 2 1 * *"        = First day of month at 2 AM
# "0 2 22-28 * 4"    = Last Thursday (days 22-28 + Thursday)
# "0 2 1 1,4,7,10 *" = Quarterly (Jan, Apr, Jul, Oct)
# "30 14 * * 5"      = Every Friday at 2:30 PM
# "0 0 15 * *"       = 15th of every month at midnight
# "0 9-17 * * 1-5"   = Every hour from 9 AM to 5 PM, Mon-Fri
