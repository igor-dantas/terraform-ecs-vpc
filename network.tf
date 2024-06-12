resource "aws_vpc" "vpc-ecs-demo" {
  cidr_block       = "10.0.0.0/16"

  tags = {
    Name = "vpc-ecs-demo"
  }
}

#######################################
############ PUBLIC ###################
#######################################

resource "aws_subnet" "subnet_public" {
  vpc_id     = aws_vpc.vpc-ecs-demo.id
  cidr_block = "10.0.0.0/24"

  tags = {
    Name = "subnet-publica-ecs-demo"
  }
}

resource "aws_internet_gateway" "igw-ecs-demo" {
  vpc_id = aws_vpc.vpc-ecs-demo.id

  tags = {
    Name = "internet-gateway-ecs-demo"
  }
}


resource "aws_route_table" "rtb-public-ecs-demo" {
  vpc_id = aws_vpc.vpc-ecs-demo.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw-ecs-demo.id
  }

  tags = {
    Name = "route-table-public-ecs-demo"
  }
}

#######################################
############ PRIVATE ##################
#######################################


resource "aws_subnet" "subnet_private" {
  vpc_id     = aws_vpc.vpc-ecs-demo.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "subnet-privada-ecs-demo"
  }
}



resource "aws_eip" "eip-ngw-ecs-demo" {
  domain   = "vpc"
  tags = {
      Name = "eip-ecs-demo"
    }
}

resource "aws_nat_gateway" "nat-ecs-demo" {
  allocation_id = aws_eip.eip-ngw-ecs-demo.id
  subnet_id     = aws_subnet.subnet_private.id

  tags = {
    Name = "nat-gateway-ecs-demo"
  }

  depends_on = [aws_internet_gateway.igw-ecs-demo]
}


resource "aws_route_table" "rtb-private-ecs-demo" {
  vpc_id = aws_vpc.vpc-ecs-demo.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat-ecs-demo.id
  }

  tags = {
    Name = "route-table-private-ecs-demo"
  }
}