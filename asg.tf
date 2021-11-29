# 9. Create launch configuration for Auto Scaling Group

resource "aws_key_pair" "publickey"{
  key_name = "mykey"
  public_key = file(var.public_key_path)
}
resource "aws_launch_configuration" "launch_config" {
  name = "web_config"
  image_id = "ami-04902260ca3d33422" #Amaxon Linux 2 AMI id
  instance_type = "t2.micro"
  key_name = aws_key_pair.publickey.key_name
  security_groups = [aws_security_group.allow_web.id]
  user_data = <<-EOF
  #! /bin/bash
  yum update -y
  yum install -y httpd
  systemctl start httpd
  systemctl enable httpd
  echo "<h1>Hello from $(hostname -f)!</h1>" > /var/www/html/index.html
  EOF
}

# 10. Create Autoscaling Group with AMI from #9
resource "aws_autoscaling_group" "server_asg" {
  name                      = "server_asg"
  max_size                  = 4
  min_size                  = 1
  health_check_grace_period = 300
  health_check_type         = "ELB"
  desired_capacity          = 2
  force_delete              = true
  launch_configuration      = aws_launch_configuration.launch_config.id
  vpc_zone_identifier       = [aws_subnet.subnet-1.id,aws_subnet.subnet-2.id]

  tags = concat(
    [
      {
        "key" = "Name"
        "value"  = "server-asg"
        "propagate_at_launch" = true
      },
     {
        "key" = "Project"
        "value"  = "terraform-web-server"
        "propagate_at_launch" = true
      }
    ]
  )
}

# Define ASG Config policy
resource "aws_autoscaling_policy" "server_asg_up" {
  name                   = "server_asg_up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 100
  autoscaling_group_name = aws_autoscaling_group.server_asg.name
  policy_type = "SimpleScaling"
}

# Define CloudWatch monitoring for scale up

resource "aws_cloudwatch_metric_alarm" "cw_asg_up" {
  alarm_name          = "cw_asg_up"
  alarm_description = "This metric monitors ec2 cpu utilization"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "80"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.server_asg.name
  }
  alarm_actions     = [aws_autoscaling_policy.server_asg_up.arn]
}

# Define descaling policy

resource "aws_autoscaling_policy" "server_asg_down" {
  name                   = "server_asg_down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 100
  autoscaling_group_name = aws_autoscaling_group.server_asg.name
  policy_type = "SimpleScaling"
}

# Define CloudWatch monitoring for scaling down
resource "aws_cloudwatch_metric_alarm" "cw_asg_down" {
  alarm_name          = "cw_asg_down"
  alarm_description = "This metric monitors ec2 cpu utilization"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "10"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.server_asg.name
  }
  alarm_actions     = [aws_autoscaling_policy.server_asg_down.arn]
}
