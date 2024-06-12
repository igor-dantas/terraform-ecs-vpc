terraform {
  backend "s3" {
    bucket = "ecs-demo-tf" 
    key    = "dev/terraform.tfstate" 
    region = "us-east-1"
  }
}
