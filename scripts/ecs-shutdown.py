#!/usr/bin/env python3
"""
ECS Cluster Shutdown Script

This script shuts down the ECS cluster and related resources while preserving:
- RDS Database
- S3 Buckets
- EFS Filesystem
- VPC and Networking
- ECR Repository
"""

import json
import subprocess
import sys
import time

from rich.console import Console
from rich.panel import Panel
from rich.progress import Progress, SpinnerColumn, TextColumn
from rich.prompt import Confirm
from rich.table import Table

console = Console()


class ECSShutdown:
    def __init__(self):
        self.console = console
        self.aws_region = self._get_aws_region()
        self.cluster_name = "dagster-ecs-fargate-cluster"

    def _run_command(self, command: list[str], check: bool = True) -> str | None:
        """Run a command and return output"""
        try:
            result = subprocess.run(command, capture_output=True, text=True, check=check)
            return result.stdout.strip()
        except subprocess.CalledProcessError as e:
            if check:
                self.console.print(f"[red]Error running command: {' '.join(command)}[/red]")
                self.console.print(f"[red]{e.stderr}[/red]")
            return None

    def _get_aws_region(self) -> str:
        """Get AWS region from terraform output"""
        output = self._run_command(["tofu", "-chdir=infrastructure", "output", "-raw", "aws_region"], check=False)
        return output or "ap-southeast-2"

    def _check_aws_credentials(self) -> bool:
        """Check if AWS CLI is configured"""
        result = self._run_command(["aws", "sts", "get-caller-identity"], check=False)
        return result is not None

    def _resource_exists(self, resource_type: str, resource_name: str) -> bool:
        """Check if a resource exists"""
        if resource_type == "ecs-service":
            output = self._run_command(
                [
                    "aws",
                    "ecs",
                    "describe-services",
                    "--cluster",
                    self.cluster_name,
                    "--services",
                    resource_name,
                    "--region",
                    self.aws_region,
                ],
                check=False,
            )

            if output:
                data = json.loads(output)
                if data.get("services"):
                    return data["services"][0].get("status") != "INACTIVE"
            return False

        elif resource_type == "ecs-cluster":
            output = self._run_command(
                ["aws", "ecs", "describe-clusters", "--clusters", resource_name, "--region", self.aws_region],
                check=False,
            )

            if output:
                data = json.loads(output)
                if data.get("clusters"):
                    return data["clusters"][0].get("status") == "ACTIVE"
            return False

        return False

    def _wait_for_service_inactive(self, service_name: str, progress) -> bool:
        """Wait for service to become inactive"""
        task = progress.add_task(f"Waiting for {service_name} to become inactive", total=30)

        for _i in range(30):
            if not self._resource_exists("ecs-service", service_name):
                progress.update(task, completed=30)
                return True

            progress.update(task, advance=1)
            time.sleep(10)

        return False

    def scale_down_services(self):
        """Scale down ECS services to 0"""
        services = ["dagster-ecs-fargate-service", "dagster-ecs-daemon-service"]

        with Progress(
            SpinnerColumn(), TextColumn("[progress.description]{task.description}"), console=self.console
        ) as progress:
            for service in services:
                if self._resource_exists("ecs-service", service):
                    task = progress.add_task(f"Scaling down {service}...", total=None)

                    self._run_command(
                        [
                            "aws",
                            "ecs",
                            "update-service",
                            "--cluster",
                            self.cluster_name,
                            "--service",
                            service,
                            "--desired-count",
                            "0",
                            "--region",
                            self.aws_region,
                            "--no-cli-pager",
                        ]
                    )

                    progress.update(task, completed=True)
                else:
                    self.console.print(f"[yellow]{service} not found or already inactive[/yellow]")

    def delete_services(self):
        """Delete ECS services"""
        services = ["dagster-ecs-fargate-service", "dagster-ecs-daemon-service"]

        with Progress(
            SpinnerColumn(), TextColumn("[progress.description]{task.description}"), console=self.console
        ) as progress:
            for service in services:
                if self._resource_exists("ecs-service", service):
                    task = progress.add_task(f"Deleting {service}...", total=None)

                    self._run_command(
                        [
                            "aws",
                            "ecs",
                            "delete-service",
                            "--cluster",
                            self.cluster_name,
                            "--service",
                            service,
                            "--force",
                            "--region",
                            self.aws_region,
                            "--no-cli-pager",
                        ]
                    )

                    progress.update(task, completed=True)

                    # Wait for service to be inactive
                    self._wait_for_service_inactive(service, progress)
                else:
                    self.console.print(f"[yellow]{service} already deleted[/yellow]")

    def deregister_task_definitions(self):
        """Deregister all task definitions"""
        # Get all task definition families
        output = self._run_command(
            [
                "aws",
                "ecs",
                "list-task-definition-families",
                "--family-prefix",
                "dagster-",
                "--region",
                self.aws_region,
                "--output",
                "json",
            ],
            check=False,
        )

        if not output:
            self.console.print("[yellow]No task definitions found to deregister[/yellow]")
            return

        families = json.loads(output).get("families", [])

        with Progress(
            SpinnerColumn(), TextColumn("[progress.description]{task.description}"), console=self.console
        ) as progress:
            for family in families:
                task = progress.add_task(f"Deregistering {family}...", total=None)

                # Get all revisions
                revisions_output = self._run_command(
                    [
                        "aws",
                        "ecs",
                        "list-task-definitions",
                        "--family-prefix",
                        family,
                        "--region",
                        self.aws_region,
                        "--output",
                        "json",
                    ],
                    check=False,
                )

                if revisions_output:
                    revisions = json.loads(revisions_output).get("taskDefinitionArns", [])

                    for revision in revisions:
                        self._run_command(
                            [
                                "aws",
                                "ecs",
                                "deregister-task-definition",
                                "--task-definition",
                                revision,
                                "--region",
                                self.aws_region,
                                "--no-cli-pager",
                            ],
                            check=False,
                        )

                progress.update(task, completed=True)

    def delete_cluster(self):
        """Delete ECS cluster"""
        if self._resource_exists("ecs-cluster", self.cluster_name):
            with Progress(
                SpinnerColumn(), TextColumn("[progress.description]{task.description}"), console=self.console
            ) as progress:
                task = progress.add_task("Deleting ECS cluster...", total=None)

                self._run_command(
                    [
                        "aws",
                        "ecs",
                        "delete-cluster",
                        "--cluster",
                        self.cluster_name,
                        "--region",
                        self.aws_region,
                        "--no-cli-pager",
                    ]
                )

                progress.update(task, completed=True)
                self.console.print("[green]ECS cluster deleted successfully[/green]")
        else:
            self.console.print("[yellow]ECS cluster already deleted[/yellow]")

    def remove_terraform_state(self):
        """Remove ECS resources from Terraform state"""
        resources = [
            "aws_ecs_cluster.dagster_fargate",
            "aws_ecs_service.dagster_fargate",
            "aws_ecs_service.dagster_daemon_fargate",
            "aws_ecs_task_definition.dagster_fargate",
            "aws_ecs_task_definition.dagster_daemon_fargate",
            "aws_appautoscaling_target.dagster_fargate",
            "aws_appautoscaling_policy.dagster_fargate_cpu",
            "aws_appautoscaling_policy.dagster_fargate_memory",
            "aws_cloudwatch_log_group.dagster_fargate",
            "aws_cloudwatch_log_group.dagster_daemon_fargate",
        ]

        with Progress(
            SpinnerColumn(), TextColumn("[progress.description]{task.description}"), console=self.console
        ) as progress:
            task = progress.add_task("Removing resources from Terraform state...", total=len(resources))

            for resource in resources:
                self._run_command(["tofu", "-chdir=infrastructure", "state", "rm", resource], check=False)
                progress.update(task, advance=1)

    def show_summary(self):
        """Show summary of what was done"""
        # Shutdown summary
        shutdown_table = Table(title="Resources Shut Down", show_header=False)
        shutdown_table.add_column("Resource", style="red")
        shutdown_items = [
            "ECS Cluster and Services",
            "Task Definitions",
            "Auto Scaling Policies",
            "CloudWatch Log Groups (removed from state)",
        ]
        for item in shutdown_items:
            shutdown_table.add_row(f"✗ {item}")

        # Preserved summary
        preserved_table = Table(title="Resources Preserved", show_header=False)
        preserved_table.add_column("Resource", style="green")
        preserved_items = [
            "RDS Database",
            "S3 Buckets",
            "EFS Filesystem",
            "VPC and Networking",
            "ECR Repository with Docker images",
            "Load Balancer (will show unhealthy targets)",
            "Security Groups",
            "IAM Roles",
        ]
        for item in preserved_items:
            preserved_table.add_row(f"✓ {item}")

        self.console.print("\n")
        self.console.print(shutdown_table)
        self.console.print("\n")
        self.console.print(preserved_table)
        self.console.print("\n")
        self.console.print("[yellow]To recreate the ECS cluster, run:[/yellow] make ecs-recreate")

    def run(self):
        """Main execution function"""
        # Show banner
        self.console.print(
            Panel.fit(
                "[bold yellow]ECS Cluster Shutdown Script[/bold yellow]\n\n"
                "This script will shut down the ECS cluster and related resources while preserving:\n"
                "• RDS Database\n"
                "• S3 Buckets\n"
                "• EFS Filesystem\n"
                "• VPC and Networking\n"
                "• ECR Repository",
                border_style="yellow",
            )
        )

        # Confirm with user
        if not Confirm.ask("\n[yellow]Are you sure you want to shut down the ECS cluster?[/yellow]"):
            self.console.print("Operation cancelled.")
            sys.exit(0)

        # Check AWS credentials
        if not self._check_aws_credentials():
            self.console.print("[red]Error: AWS CLI not configured or no valid credentials[/red]")
            sys.exit(1)

        self.console.print(f"\n[green]Using AWS Region: {self.aws_region}[/green]\n")

        # Execute shutdown steps
        self.console.rule("[bold yellow]Step 1: Scaling down ECS services to 0[/bold yellow]")
        self.scale_down_services()

        self.console.rule("\n[bold yellow]Step 2: Deleting ECS services[/bold yellow]")
        self.delete_services()

        self.console.rule("\n[bold yellow]Step 3: Deregistering task definitions[/bold yellow]")
        self.deregister_task_definitions()

        self.console.rule("\n[bold yellow]Step 4: Deleting ECS cluster[/bold yellow]")
        self.delete_cluster()

        self.console.rule("\n[bold yellow]Step 5: Removing ECS-specific resources via Terraform[/bold yellow]")
        self.remove_terraform_state()

        # Show summary
        self.console.rule("\n[bold green]ECS Cluster Shutdown Complete[/bold green]")
        self.show_summary()


if __name__ == "__main__":
    shutdown = ECSShutdown()
    shutdown.run()
