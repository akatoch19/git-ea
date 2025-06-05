resource "aws_lb" "gitea" {
  name               = "gitea-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb.id]
  subnets            = module.vpc-gitea.public_subnets
}

resource "aws_lb_target_group" "gitea" {
  name     = "gitea-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = module.vpc-gitea.vpc_id
  target_type = "ip"
  health_check {
    path = "/"
  }
}

resource "aws_lb_listener" "gitea" {
  load_balancer_arn = aws_lb.gitea.arn
  port              = 80
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gitea.arn
  }
}
