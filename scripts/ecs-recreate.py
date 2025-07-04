#!/usr/bin/env python3
"""
ECS Cluster Recreation Script

This script recreates the ECS cluster and related resources.
Prerequisites:
- Infrastructure must already exist (VPC, RDS, S3, EFS, etc.)
- Docker images must be pushed to ECR
"""

import json
import os
import subprocess
import sys
import time

from rich.console import Console
from rich.panel import Panel
from rich.progress import BarColumn, Progress, SpinnerColumn, TaskProgressColumn, TextColumn
from rich.prompt import Confirm
from rich.table import Table

console = Console()


class ECSRecreate:
    def __init__(self):
        self.console = console
        self.aws_region = self._get_aws_region()
        self.cluster_name = "dagster-ecs-fargate-cluster"
        self.plan_file = "infrastructure/ecs-recreate.tfplan"

    def _run_command(self, command: list[str], check: bool = True, cwd: str | None = None) -> str | None:
        """Run a command and return output"""
        try:
            result = subprocess.run(command, capture_output=True, text=True, check=check, cwd=cwd)
            return result.stdout.strip()
        except subprocess.CalledProcessError as e:
            if check:
                self.console.print(f"[red]Error running command: {' '.join(command)}[/red]")
                self.console.print(f"[red]{e.stderr}[/red]")
            return None

    def _get_aws_region(self) -> str:
        """Get AWS region from terraform output"""
        output = self._run_command(["tofu", "output", "-raw", "aws_region"], check=False, cwd="infrastructure")
        return output or "ap-southeast-2"

    def _check_aws_credentials(self) -> bool:
        """Check if AWS CLI is configured"""
        result = self._run_command(["aws", "sts", "get-caller-identity"], check=False)
        return result is not None

    def _check_terraform_init(self) -> bool:
        """Check if terraform is initialized"""
        return os.path.exists("infrastructure/.terraform")

    def initialize_terraform(self):
        """Initialize Terraform if needed"""
        if not self._check_terraform_init():
            with Progress(
                SpinnerColumn(), TextColumn("[progress.description]{task.description}"), console=self.console
            ) as progress:
                task = progress.add_task("Initializing Terraform...", total=None)

                self._run_command(["tofu", "init", "-backend-config=backend.hcl"], cwd="infrastructure")

                progress.update(task, completed=True)

    def plan_infrastructure(self) -> bool:
        """Create targeted plan for ECS resources"""
        targets = [
            "aws_ecs_cluster.dagster_fargate",
            "aws_ecs_task_definition.dagster_fargate",
            "aws_ecs_task_definition.dagster_daemon_fargate",
            "aws_ecs_service.dagster_fargate",
            "aws_ecs_service.dagster_daemon_fargate",
            "aws_appautoscaling_target.dagster_fargate",
            "aws_appautoscaling_policy.dagster_fargate_cpu",
            "aws_appautoscaling_policy.dagster_fargate_memory",
            "aws_cloudwatch_log_group.dagster_fargate",
            "aws_cloudwatch_log_group.dagster_daemon_fargate",
        ]

        command = ["tofu", "plan", "-out=ecs-recreate.tfplan"]
        for target in targets:
            command.extend(["-target", target])

        self.console.print("\n[yellow]Creating infrastructure plan...[/yellow]")

        # Run the plan command and capture output
        result = subprocess.run(command, cwd="infrastructure", capture_output=True, text=True, check=False)

        if result.returncode != 0:
            self.console.print("[red]Failed to create plan:[/red]")
            self.console.print(result.stderr)
            return False

        # Display plan summary
        self.console.print("\n[green]Plan created successfully![/green]")

        # Parse plan output for summary
        plan_output = result.stdout
        if "Plan:" in plan_output:
            for line in plan_output.split("\n"):
                if "Plan:" in line:
                    self.console.print(f"\n[bold]{line.strip()}[/bold]")
                    break

        return True

    def show_plan_summary(self):
        """Show summary of resources to be created"""
        table = Table(title="Resources to be Created", show_header=True)
        table.add_column("Resource Type", style="cyan")
        table.add_column("Resource Name", style="green")

        resources = [
            ("ECS Cluster", "dagster-ecs-fargate-cluster"),
            ("Task Definition", "dagster-webserver-fargate"),
            ("Task Definition", "dagster-daemon-fargate"),
            ("ECS Service", "dagster-ecs-fargate-service"),
            ("ECS Service", "dagster-ecs-daemon-service"),
            ("Auto Scaling Target", "dagster-fargate"),
            ("Auto Scaling Policy", "CPU-based scaling"),
            ("Auto Scaling Policy", "Memory-based scaling"),
            ("CloudWatch Log Group", "/ecs/dagster-ecs-fargate"),
            ("CloudWatch Log Group", "/ecs/dagster-daemon-fargate"),
        ]

        for resource_type, resource_name in resources:
            table.add_row(resource_type, resource_name)

        self.console.print("\n")
        self.console.print(table)

    def apply_infrastructure(self) -> bool:
        """Apply the infrastructure plan"""
        self.console.print("\n[yellow]Applying infrastructure changes...[/yellow]")

        with Progress(
            SpinnerColumn(), TextColumn("[progress.description]{task.description}"), console=self.console
        ) as progress:
            task = progress.add_task("Creating ECS resources...", total=None)

            result = self._run_command(["tofu", "apply", "ecs-recreate.tfplan"], cwd="infrastructure", check=False)

            progress.update(task, completed=True)

            # Clean up plan file
            if os.path.exists(self.plan_file):
                os.remove(self.plan_file)

            return result is not None

    def check_service_health(self, service_name: str) -> tuple[bool, str]:
        """Check if a service is healthy"""
        output = self._run_command(
            [
                "aws",
                "ecs",
                "describe-services",
                "--cluster",
                self.cluster_name,
                "--services",
                service_name,
                "--region",
                self.aws_region,
                "--output",
                "json",
            ],
            check=False,
        )

        if not output:
            return False, "UNKNOWN"

        data = json.loads(output)
        if data.get("services"):
            service = data["services"][0]
            deployments = service.get("deployments", [])
            if deployments:
                status = deployments[0].get("rolloutState", "UNKNOWN")
                return status == "COMPLETED", status

        return False, "UNKNOWN"

    def wait_for_services(self):
        """Wait for services to become healthy"""
        services = [("dagster-ecs-fargate-service", "Webserver"), ("dagster-ecs-daemon-service", "Daemon")]

        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            BarColumn(),
            TaskProgressColumn(),
            console=self.console,
        ) as progress:
            for service_name, display_name in services:
                task = progress.add_task(
                    f"Waiting for {display_name} to become healthy...",
                    total=60,  # 10 minutes max
                )

                for _i in range(60):
                    is_healthy, status = self.check_service_health(service_name)

                    if is_healthy:
                        progress.update(task, completed=60)
                        self.console.print(f"[green]✓ {display_name} is healthy[/green]")
                        break
                    elif status == "FAILED":
                        progress.update(task, completed=60)
                        self.console.print(f"[red]✗ {display_name} deployment failed![/red]")
                        break

                    progress.update(task, advance=1)
                    time.sleep(10)
                else:
                    self.console.print(f"[yellow]⚠ {display_name} health check timed out[/yellow]")

    def get_deployment_info(self) -> tuple[str | None, str | None]:
        """Get deployment information"""
        alb_url = self._run_command(["tofu", "output", "-raw", "alb_dns_name"], check=False, cwd="infrastructure")

        auth_user = self._run_command(
            ["tofu", "output", "-raw", "dagster_auth_user"], check=False, cwd="infrastructure"
        )

        return alb_url, auth_user

    def show_deployment_summary(self):
        """Show deployment summary"""
        alb_url, auth_user = self.get_deployment_info()

        if alb_url:
            info_panel = Panel.fit(
                f"[bold green]Dagster is now available at:[/bold green]\n"
                f"[cyan]http://{alb_url}[/cyan]\n\n"
                f"It may take a few minutes for the load balancer to become fully healthy.\n",
                border_style="green",
                title="Deployment Complete",
            )
            self.console.print(info_panel)

            if auth_user:
                self.console.print("\n[yellow]Authentication is enabled.[/yellow]")
                self.console.print(f"Username: [cyan]{auth_user}[/cyan]")
                self.console.print("Password is stored in Terraform variables.")
        else:
            self.console.print("\n[green]ECS cluster and services have been recreated.[/green]")
            self.console.print("Run 'make aws-url' to get the Dagster URL once the load balancer is ready.")

        # Additional commands
        self.console.print("\n[bold]Useful commands:[/bold]")
        commands_table = Table(show_header=False, box=None)
        commands_table.add_column("Command", style="cyan")
        commands_table.add_column("Description")

        commands = [
            ("make ecs-logs", "View ECS logs"),
            ("make ecs-status", "Check service status"),
            (
                f"aws ecs describe-services --cluster {self.cluster_name} --services dagster-ecs-fargate-service --region {self.aws_region}",
                "Detailed service status",
            ),
        ]

        for cmd, desc in commands:
            commands_table.add_row(cmd, desc)

        self.console.print(commands_table)

    def run(self):
        """Main execution function"""
        # Show banner
        self.console.print(
            Panel.fit(
                "[bold yellow]ECS Cluster Recreation Script[/bold yellow]\n\n"
                "This script will recreate the ECS cluster and related resources.\n\n"
                "[bold]Prerequisites:[/bold]\n"
                "• Infrastructure must already exist (VPC, RDS, S3, EFS, etc.)\n"
                "• Docker images must be pushed to ECR",
                border_style="yellow",
            )
        )

        # Confirm with user
        if not Confirm.ask("\n[yellow]Are you sure you want to recreate the ECS cluster?[/yellow]"):
            self.console.print("Operation cancelled.")
            sys.exit(0)

        # Check AWS credentials
        if not self._check_aws_credentials():
            self.console.print("[red]Error: AWS CLI not configured or no valid credentials[/red]")
            sys.exit(1)

        self.console.print(f"\n[green]Using AWS Region: {self.aws_region}[/green]")

        # Execute recreation steps
        self.console.rule("\n[bold yellow]Step 1: Initializing Terraform[/bold yellow]")
        self.initialize_terraform()

        self.console.rule("\n[bold yellow]Step 2: Planning ECS infrastructure[/bold yellow]")
        if not self.plan_infrastructure():
            self.console.print("[red]Failed to create infrastructure plan[/red]")
            sys.exit(1)

        self.show_plan_summary()

        if not Confirm.ask("\n[yellow]Do you want to apply this plan?[/yellow]"):
            self.console.print("Operation cancelled.")
            if os.path.exists(self.plan_file):
                os.remove(self.plan_file)
            sys.exit(0)

        self.console.rule("\n[bold yellow]Step 3: Applying ECS infrastructure[/bold yellow]")
        if not self.apply_infrastructure():
            self.console.print("[red]Failed to apply infrastructure[/red]")
            sys.exit(1)

        self.console.rule("\n[bold yellow]Step 4: Waiting for services to become healthy[/bold yellow]")
        self.wait_for_services()

        self.console.rule("\n[bold yellow]Step 5: Verifying deployment[/bold yellow]")
        self.show_deployment_summary()

        self.console.rule("\n[bold green]ECS Cluster Recreation Complete[/bold green]")


if __name__ == "__main__":
    recreate = ECSRecreate()
    recreate.run()
