# EFS (Elastic File System) for shared workspace storage across ECS tasks
# This allows multiple repositories to deploy their code to a shared filesystem

resource "aws_efs_file_system" "dagster_workspace" {
  creation_token = "${local.name_prefix}-workspace-efs"

  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  encrypted = true

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-workspace-efs"
  })
}

# Mount targets for each public subnet (matching ECS tasks)
resource "aws_efs_mount_target" "dagster_workspace" {
  count = length(aws_subnet.public)

  file_system_id  = aws_efs_file_system.dagster_workspace.id
  subnet_id       = aws_subnet.public[count.index].id
  security_groups = [aws_security_group.efs_workspace.id]
}

# Security group for workspace EFS
resource "aws_security_group" "efs_workspace" {
  name        = "${local.name_prefix}-efs-workspace-sg"
  description = "Security group for workspace EFS mount targets"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "NFS from ECS tasks"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks_fargate.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-efs-workspace-sg"
  })
}

# Access point for workspace projects
resource "aws_efs_access_point" "workspace_projects" {
  file_system_id = aws_efs_file_system.dagster_workspace.id

  posix_user {
    gid = 1000
    uid = 1000
  }

  root_directory {
    path = "/projects"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "755"
    }
  }

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-workspace-projects-ap"
  })
}

# Access point for workspace configuration
resource "aws_efs_access_point" "workspace_config" {
  file_system_id = aws_efs_file_system.dagster_workspace.id

  posix_user {
    gid = 1000
    uid = 1000
  }

  root_directory {
    path = "/config"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "755"
    }
  }

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-workspace-config-ap"
  })
}