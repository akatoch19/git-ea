resource "aws_ecs_cluster" "gitea" {
  name = "gitea-cluster"
}

resource "aws_iam_role" "ecs_task_execution" {
  name = "ecsTaskExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role_policy.json
}

data "aws_iam_policy_document" "ecs_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecs_execution_policy" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_task_definition" "gitea" {
  family                   = "gitea-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "gitea"
      image     = "gitea/gitea:latest"
      essential = true
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
        },
        {
          containerPort = 22
          hostPort      = 22
        }
      ]
      environment = [
        { name = "USER_UID", value = "1000" },
        { name = "USER_GID", value = "1000" },
        { name = "DB_TYPE", value = "postgres" },
        { name = "DB_HOST", value = module.db.db_instance_address },
        { name = "DB_NAME", value = "giteadb" },
        { name = "DB_USER", value = "gitea" },
        { name = "DB_PASSWD", value = "giteapassword" }
      ]
/*      logConfiguration = {
       logDriver = "awslogs"
       options = {
         awslogs-group         = "/ecs/gitea"
         awslogs-region        = "us-east-1"
         awslogs-stream-prefix = "ecs"
       }
     } */
    }
  ])
}

resource "aws_ecs_service" "gitea" {
  name            = "gitea-service"
  cluster         = aws_ecs_cluster.gitea.id
  task_definition = aws_ecs_task_definition.gitea.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = module.vpc-gitea.public_subnets
    security_groups = [aws_security_group.gitea.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.gitea.arn
    container_name   = "gitea"
    container_port   = 3000
  }

  depends_on = [aws_lb_listener.gitea]
}
