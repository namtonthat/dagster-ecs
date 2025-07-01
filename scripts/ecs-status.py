#!/usr/bin/env python3

"""
ECS Status Script
Displays ECS cluster and service status using rich formatting
"""

import json
import subprocess
import sys
from typing import Any

from rich.console import Console
from rich.panel import Panel
from rich.table import Table
from rich.text import Text


def run_aws_command(command: list[str]) -> dict[str, Any]:
    """Run AWS CLI command and return JSON result"""
    try:
        result = subprocess.run(command, capture_output=True, text=True, check=True)
        return json.loads(result.stdout)
    except subprocess.CalledProcessError as e:
        Console().print(f"[red]Error running AWS command: {e}[/red]")
        sys.exit(1)
    except json.JSONDecodeError as e:
        Console().print(f"[red]Error parsing AWS response: {e}[/red]")
        sys.exit(1)
    return {}


def get_cluster_status(cluster_name: str) -> dict:
    """Get ECS cluster status"""
    command = [
        "aws",
        "ecs",
        "describe-clusters",
        "--clusters",
        cluster_name,
        "--query",
        "clusters[0]",
        "--output",
        "json",
    ]
    return run_aws_command(command)


def get_service_status(cluster_name: str, service_name: str) -> dict:
    """Get ECS service status"""
    command = [
        "aws",
        "ecs",
        "describe-services",
        "--cluster",
        cluster_name,
        "--services",
        service_name,
        "--query",
        "services[0]",
        "--output",
        "json",
    ]
    return run_aws_command(command)


def create_cluster_table(cluster_data: dict) -> Table:
    """Create cluster status table"""
    table = Table(title="Cluster Status")
    table.add_column("Name", style="cyan")
    table.add_column("Status", style="green")
    table.add_column("Active Tasks", style="yellow")
    table.add_column("Pending Tasks", style="yellow")
    table.add_column("Services", style="blue")

    table.add_row(
        cluster_data.get("clusterName", "N/A"),
        cluster_data.get("status", "N/A"),
        str(cluster_data.get("runningTasksCount", 0)),
        str(cluster_data.get("pendingTasksCount", 0)),
        str(cluster_data.get("activeServicesCount", 0)),
    )

    return table


def create_service_table(service_data: dict) -> Table:
    """Create service status table"""
    table = Table(title="Service Status")
    table.add_column("Name", style="cyan")
    table.add_column("Status", style="green")
    table.add_column("Desired", style="yellow")
    table.add_column("Running", style="yellow")
    table.add_column("Pending", style="yellow")
    table.add_column("Task Definition", style="blue")

    task_def = service_data.get("taskDefinition", "N/A")
    # Extract just the task definition name from the full ARN
    if "/" in task_def:
        task_def = task_def.split("/")[-1]

    table.add_row(
        service_data.get("serviceName", "N/A"),
        service_data.get("status", "N/A"),
        str(service_data.get("desiredCount", 0)),
        str(service_data.get("runningCount", 0)),
        str(service_data.get("pendingCount", 0)),
        task_def,
    )

    return table


def get_stability_status(service_data: dict) -> tuple[str, str]:
    """Determine service stability status and message"""
    status = service_data.get("status", "")
    desired = service_data.get("desiredCount", 0)
    running = service_data.get("runningCount", 0)
    pending = service_data.get("pendingCount", 0)

    if status == "ACTIVE" and running == desired and pending == 0:
        return "STABLE", f"✓ Service is STABLE - All {desired} desired tasks are running"
    elif status == "ACTIVE" and pending > 0:
        return "UPDATING", f"⚠ Service is UPDATING - {pending} task(s) pending"
    elif status == "ACTIVE" and running < desired:
        return "UNSTABLE", f"⚠ Service is UNSTABLE - Only {running}/{desired} tasks running"
    else:
        return "ERROR", f"✗ Service is NOT STABLE - Status: {status}, Running: {running}/{desired}, Pending: {pending}"


def main():
    """Main function"""
    console = Console()

    cluster_name = "dagster-ecs-fargate-cluster"
    service_name = "dagster-ecs-fargate-service"

    try:
        # Get cluster status
        cluster_data = get_cluster_status(cluster_name)
        cluster_table = create_cluster_table(cluster_data)
        console.print(cluster_table)
        console.print()

        # Get service status
        service_data = get_service_status(cluster_name, service_name)
        service_table = create_service_table(service_data)
        console.print(service_table)
        console.print()

        # Get stability status
        stability_type, stability_message = get_stability_status(service_data)

        # Color the panel based on stability
        if stability_type == "STABLE":
            panel_style = "green"
        elif stability_type in ["UPDATING", "UNSTABLE"]:
            panel_style = "yellow"
        else:
            panel_style = "red"

        stability_panel = Panel(
            Text(stability_message, justify="center"), title="Service Stability Check", style=panel_style
        )
        console.print(stability_panel)

    except Exception as e:
        console.print(f"[red]Unexpected error: {e}[/red]")
        sys.exit(1)


if __name__ == "__main__":
    main()
