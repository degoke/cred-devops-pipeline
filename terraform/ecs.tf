resource "aws_ecs_cluster" "this" {
  name = "${var.project_name}-${local.environment}-cluster"
}

resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.project_name}-${local.environment}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.project_name}-${local.environment}-app"
  retention_in_days = 7
}

resource "aws_ecs_task_definition" "app" {
  family                   = "${var.project_name}-${local.environment}-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "app",
      image     = "${var.image_name}:${var.image_tag}",
      essential = true,
      portMappings = [
        {
          containerPort = 3000,
          protocol      = "tcp"
        }
      ],
      environment = [
        {
          name  = "PORT",
          value = "3000"
        }
      ],
      secrets = [
        {
          name      = "DATABASE_URL",
          valueFrom = aws_secretsmanager_secret.db_connection.arn
        }
      ],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = aws_cloudwatch_log_group.app.name,
          awslogs-region        = var.aws_region,
          awslogs-stream-prefix = "app"
        }
      },
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:3000/health || exit 1"],
        interval    = 30,
        timeout     = 5,
        retries     = 3,
        startPeriod = 30
      }
    }
  ])
}

resource "aws_ecs_service" "app" {
  name            = "${var.project_name}-${local.environment}-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.app.arn
  launch_type     = "FARGATE"
  desired_count   = 2

  network_configuration {
    subnets         = aws_subnet.private[*].id
    security_groups = [aws_security_group.ecs.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = 3000
  }

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  depends_on = [aws_lb_listener.https]
}
