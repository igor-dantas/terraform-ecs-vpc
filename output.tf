output "dns_load_balancer" {
  value = aws_lb.alb.dns_name
}