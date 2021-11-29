provider "aws" {
    region  = var.region
    access_key =  var.access_key
    secret_key = var.secret_key
}

# 11. Create ALB and point it to ASG from #10
resource "aws_lb" "prod-lb" {
  name = "prod-alb"
  internal = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.allow_web.id]
  subnets = [aws_subnet.subnet-1.id, aws_subnet.subnet-2.id]
  tags = {
    Name = "prod-alb"
    Project = "terraform-web-server"
  }
}

resource "aws_lb_target_group" "lb-tg" {
  name     = "alb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.prod-vpc.id
}

resource "aws_lb_listener" "lb_listener" {
  load_balancer_arn = aws_lb.prod-lb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb-tg.arn
  }
}

# Create a new ALB Target Group attachment
resource "aws_autoscaling_attachment" "asg_attach" {
  autoscaling_group_name = aws_autoscaling_group.server_asg.id
  alb_target_group_arn   = aws_lb_target_group.lb-tg.arn
}

# 13. Configure CloudFront for ELB from #11

# 14. Send CloudFront logs to Kinesis Firehose

# 15. Send Kinesis Firehouse logs to S3