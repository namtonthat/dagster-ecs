# ECS Fargate deployment with EFS for DAGs storage

resource "aws_ecs_cluster" "dagster_fargate" {
  name = "${local.name_prefix}-fargate-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.tags
}

# EFS for DAGs storage (since Fargate doesn't support EBS)
resource "aws_efs_file_system" "dagster_dags" {
  creation_token = "${local.name_prefix}-dags"
  
  performance_mode = "generalPurpose"
  throughput_mode  = "provisioned"
  provisioned_throughput_in_mibps = 100

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-dags-efs"
  })
}

resource "aws_efs_mount_target" "dagster_dags" {
  count = length(aws_subnet.private)

  file_system_id  = aws_efs_file_system.dagster_dags.id
  subnet_id       = aws_subnet.private[count.index].id
  security_groups = [aws_security_group.efs.id]
}

resource "aws_security_group" "efs" {
  name_prefix = "${local.name_prefix}-efs-"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks_fargate.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-efs-sg"
  })
}

resource "aws_security_group" "ecs_tasks_fargate" {
  name_prefix = "${local.name_prefix}-ecs-tasks-fargate-"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-ecs-tasks-fargate-sg"
  })
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution_fargate" {
  name = "${local.name_prefix}-ecs-task-execution-fargate"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_fargate" {
  role       = aws_iam_role.ecs_task_execution_fargate.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# IAM Role for ECS Task
resource "aws_iam_role" "ecs_task_fargate" {
  name = "${local.name_prefix}-ecs-task-fargate"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = local.tags
}

# Policy to allow EFS access
resource "aws_iam_role_policy" "ecs_task_fargate_efs" {
  name = "${local.name_prefix}-ecs-task-fargate-efs"
  role = aws_iam_role.ecs_task_fargate.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite",
          "elasticfilesystem:ClientRootAccess"
        ]
        Resource = aws_efs_file_system.dagster_dags.arn
      }
    ]
  })
}

# ECS Task Definition
resource "aws_ecs_task_definition" "dagster_fargate" {
  family                   = "${local.name_prefix}-webserver-fargate"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 1024
  memory                   = 2048
  execution_role_arn       = aws_iam_role.ecs_task_execution_fargate.arn
  task_role_arn           = aws_iam_role.ecs_task_fargate.arn

  volume {
    name = "dagster-dags"

    efs_volume_configuration {
      file_system_id = aws_efs_file_system.dagster_dags.id
      root_directory = "/"
      transit_encryption = "ENABLED"
    }
  }

  container_definitions = jsonencode([
    {
      name  = "dagster-webserver"
      image = "${aws_ecr_repository.dagster.repository_url}:latest"
      
      portMappings = [
        {
          containerPort = 3000
          protocol      = "tcp"
        }
      ]

      mountPoints = [
        {
          sourceVolume  = "dagster-dags"
          containerPath = "/app/dags"
          readOnly      = false
        }
      ]

      environment = [
        {
          name  = "DAGSTER_POSTGRES_USER"
          value = var.db_username
        },
        {
          name  = "DAGSTER_POSTGRES_DB"
          value = "dagster"
        },
        {
          name  = "DAGSTER_POSTGRES_HOST"
          value = aws_db_instance.dagster.address
        },
        {
          name  = "DAGSTER_POSTGRES_PORT"
          value = "5432"
        },
        {
          name  = "DAGSTER_POSTGRES_PASSWORD"
          value = var.db_password
        },
        {
          name  = "DAGSTER_S3_BUCKET"
          value = aws_s3_bucket.dagster.bucket
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.dagster_fargate.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      essential = true
    }
  ])

  tags = local.tags
}

# ECS Service
resource "aws_ecs_service" "dagster_fargate" {
  name            = "${local.name_prefix}-service-fargate"
  cluster         = aws_ecs_cluster.dagster_fargate.id
  task_definition = aws_ecs_task_definition.dagster_fargate.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [aws_security_group.ecs_tasks_fargate.id]
    subnets         = aws_subnet.private[*].id
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.dagster.arn
    container_name   = "dagster-webserver"
    container_port   = 3000
  }

  depends_on = [aws_lb_listener.dagster]

  tags = local.tags
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "dagster_fargate" {
  name              = "/ecs/${local.name_prefix}-fargate"
  retention_in_days = 7

  tags = local.tags
}

# Outputs
output "efs_file_system_id" {
  description = "EFS file system ID for DAGs"
  value       = aws_efs_file_system.dagster_dags.id
}

output "ecs_cluster_name" {
  description = "ECS Fargate cluster name"
  value       = aws_ecs_cluster.dagster_fargate.name
}

output "ecs_service_name" {
  description = "ECS Fargate service name"
  value       = aws_ecs_service.dagster_fargate.name
}