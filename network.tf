resource "aws_vpc" "vpc-ecs-demo" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames    = true
  enable_dns_support      = true
  tags = {
    Name = "vpc-ecs-demo"
  }
}


##############################################
############## PUBLIC ########################
##############################################

resource "aws_subnet" "subnet_public_1a" {
  vpc_id            = aws_vpc.vpc-ecs-demo.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "subnet-public-ecs-demo-a"
  }
}

resource "aws_subnet" "subnet_public_1b" {
  vpc_id            = aws_vpc.vpc-ecs-demo.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "subnet-public-ecs-demo-b"
  }
}

resource "aws_internet_gateway" "igw-ecs-demo" {
  vpc_id = aws_vpc.vpc-ecs-demo.id
  tags = {
    Name = "igw-ecs-demo"
  }
}

resource "aws_route_table" "rtb-public-ecs-demo" {
  vpc_id = aws_vpc.vpc-ecs-demo.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw-ecs-demo.id
  }

  tags = {
    Name = "rtb-public-ecs-demo"
  }
}

resource "aws_route_table_association" "public_subnet_assoc_a" {
  subnet_id      = aws_subnet.subnet_public_1a.id
  route_table_id = aws_route_table.rtb-public-ecs-demo.id
}

resource "aws_route_table_association" "public_subnet_assoc_b" {
  subnet_id      = aws_subnet.subnet_public_1b.id
  route_table_id = aws_route_table.rtb-public-ecs-demo.id
}

##############################################
############## PRIVATE #######################
##############################################

resource "aws_subnet" "subnet_private_1a" {
  vpc_id            = aws_vpc.vpc-ecs-demo.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "subnet-private-ecs-demo"
  }
}

resource "aws_subnet" "subnet_private_1b" {
  vpc_id            = aws_vpc.vpc-ecs-demo.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "subnet-private-ecs-demo"
  }
}

resource "aws_eip" "eip-ngw-ecs-demo" {
  domain = "vpc"
  tags = {
    Name = "eip-ecs-demo"
  }
}

resource "aws_nat_gateway" "nat-ecs-demo" {
  allocation_id = aws_eip.eip-ngw-ecs-demo.id
  subnet_id     = aws_subnet.subnet_public_1a.id
  tags = {
    Name = "nat-ecs-demo"
  }

  depends_on = [aws_internet_gateway.igw-ecs-demo]
}

resource "aws_route_table" "rtb-private-ecs-demo" {
  vpc_id = aws_vpc.vpc-ecs-demo.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat-ecs-demo.id
  }

  tags = {
    Name = "rtb-private-ecs-demo"
  }
}


resource "aws_route_table_association" "private_subnet_1c_assoc" {
  subnet_id      = aws_subnet.subnet_private_1a.id
  route_table_id = aws_route_table.rtb-private-ecs-demo.id
}
resource "aws_route_table_association" "private_subnet_1d_assoc" {
  subnet_id      = aws_subnet.subnet_private_1b.id
  route_table_id = aws_route_table.rtb-private-ecs-demo.id
}
