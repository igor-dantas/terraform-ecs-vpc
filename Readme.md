## Sistema operacional
O sistema operacional usado para este tutorial é linux, caso você não use linux, considere pesquisar comandos equivalentes para o seu sistema operacional.

Pré-requisitos
- terraform
- awscli
- conta na aws

## Criando diretório de trabalho
```shell
mkdir terraform-ecs-vpc/
cd terraform-ecs-vpc
```

## Configurando AWS-CLI
- Instalação
            nessa documentação você consegue instalar o aws cli para diferentes plataformas
            https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
- Criando usuário
    - Crie um usuário na aws, com permissão de administrador
    - Crie as chaves programáticas dele para poder ter acesso ao aws cli
depois rode o seguinte comando:
```shell
aws configure --profile terraform-profile 
```
-> o nome do profile pode ser qualquer um da sua escolha, após rodar este comando ele vai te pedir:
- Access Key Id
- Secret Acess Key
- Region -> para o nosso caso us-east1
- Default output format -> json

logo após rode este comando para verificar se realmente você está usando o perfil criado
```shell
aws sts get-caller-identity
```
## Criando provider.tf
Use o comando abaixo para criar o arquivo para o provider
```shell
touch provider.tf
```
https://registry.terraform.io/providers/hashicorp/aws/latest


```
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.53.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
  profile = "terraform-profile"
}
```

## Crie um bucket s3 na aws
https://docs.aws.amazon.com/pt_br/AmazonS3/latest/userguide/create-bucket-overview.html

nesse momento pode criar um bucket simples, não precisa configurar permissões nele

## Configurando Backend para salvar estados do terraform
```shell
touch backend.tf
```
Iniciando backend:

```
terraform {
  backend "s3" {
    bucket = "mybucket" # nome do bucket
    key    = "path/to/my/key" # pode ter o mesmo s3 armazenando tudo basta colocar um diretório especifico para cada tfstate
    region = "us-east-1"
  }
}
```
https://developer.hashicorp.com/terraform/language/settings/backends/s3

para o nosso caso, para seguirmos boas práticas, na variavel key vamos criar um diretório de dev portanto, vai ficar assim:

```
terraform {
  backend "s3" {
    bucket = "mybucket" 
    key    = "dev/" 
    region = "us-east-1"
  }
}
```

Depois que você criou o arquivo de provider e backend, rode o seguinte comando:

```
terraform init
```

esse comando vai baixar tudo que você configurou no seu provider e iniciar o seu backend que é onde vai ficar salvo o tfstate

## Configurando AWS VPC
Rode o comando abaixo para criar o arquivo que irá conter configurações de rede do nosso projeto
```shell
touch network.tf
```

É muito importante, que durante essa jornada com terraform você aprenda a se locomover na documentação dele, nosso caso agora, se você pesquisar por terraform aws vpc resource no google, você irá encontrar uma documentação com o recurso que queremos configurar que é a vpc, nos trará o seguinte trecho de código

```
resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "main"
  }
}
```
para o nosso caso, o trecho ficará assim:
```
resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"

  tags = {
    Name = "vpc-ecs-demo"
  }
}
```

Uma coisa que muitos arquitetos pecam as vezes na hora de fazer a arquitetura de nuvem é na escolha do range da vpc, é necessário escolher um range que não seja tão comum para que em casos que você precise comunicar sua infraestrutura com a de outro cliente não aconteça o overlapping de ip, que é basicamente quando dois dispositivos possuem o mesmo endereço de rede.

para realizar os cálculos de range de ip, recomendo esse site:
https://www.vultr.com/resources/subnet-calculator/
com ele vamos conseguir calcular os nossos ranges de ip

## Criando Subnet
Para nossa arquitetura, como é para fins de demonstração, iremos criar 2 subnets, 1 pública e 1 privada, "ah Igor mas o que caracteriza uma subnet ser publica ou privada?", subnet publica é toda subnet que possui rotas para io nternet gateway, ou seja, por meio do IGW meu serviço consegue se comunicar com a internet, e a subnet privada por sua vez é uma subnet isolada da internet, e não possui rotas diretas para o internet gateway, subnets privadas só possuem comunicação com a internet por meio de um NAT gateway que reside em uma subnet publica, permitindo requisições de saída da subnet mas não de entrada

para o nosso caso, podemos criar o recurso de subnet duas vezes para simbolizar a subnet publica e a privada, logo após configuraremos o route table para que elas façam jus ao nome privada ou publica
```
resource "aws_subnet" "subnet_public" {
  vpc_id     = aws_vpc.vpc-ecs-demo.id
  cidr_block = "10.0.0.0/24"

  tags = {
    Name = "subnet-publica-ecs-demo"
  }
}
```

```
resource "aws_subnet" "subnet_public" {
  vpc_id     = aws_vpc.vpc-ecs-demo.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "subnet-publica-ecs-demo"
  }
}
```

```
resource "aws_subnet" "subnet_private" {
  vpc_id     = aws_vpc.vpc-ecs-demo.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "subnet-privada-ecs-demo"
  }
}
```

```
resource "aws_subnet" "subnet_private" {
  vpc_id     = aws_vpc.vpc-ecs-demo.id
  cidr_block = "10.0.3.0/24"

  tags = {
    Name = "subnet-privada-ecs-demo"
  }
}
```

https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet

## Criando Internet Gateway
Agora faremos a criação do internet gateway, que vai ser o responsável por ligar a nossa arquitetura de rede ao mundo externo

```
resource "aws_internet_gateway" "igw-ecs-demo" {
  vpc_id = aws_vpc.vpc-ecs-demo.id

  tags = {
    Name = "internet-gateway-ecs-demo"
  }
}
```

o internet gateway ele fica atrelado a vpc, portanto a ligação dele é pelo Id da vpc, mas para que a gente consiga realizar essa conexão precisamos usar um outro recurso do terraform:

```
resource "aws_internet_gateway_attachment" "igw-attach-ecs-demo" {
  internet_gateway_id = aws_internet_gateway.example.id
  vpc_id              = aws_vpc.example.id
}
```

## Criando Nat Gateway

https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway

Teremos que criar um elastic Ip para colocar no Nat gateway, pois ele será o nosso ponto de saída da rede e logo após fazemos a criação do recurso

```
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
```

## IAM
Nós iremos utilizar uma policy que ja vem por padrão em toda conta da aws para atribuir a Role de execution task

```
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs_task_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
```

## Cluster ECS

Vamos fazer a criação do cluster ecs, nesse momento iremos ter algumas etapas para a criação até o container ficar acessível de fato


-> Criando cluster

```
resource "aws_ecs_cluster" "ecs-cluster-demo" {
  name = "ecs-cluster-demo"
}
```

https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster

-> Criando Capacity Provider

Nessa etapa, vamos usar um resource do terraform para informar para o nosso cluster que iremos usar o tipo de computação Fargate.

```
resource "aws_ecs_cluster_capacity_providers" "ecs-capacity_provider-demo" {
  cluster_name = aws_ecs_cluster.ecs-cluster-demo.name

  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}
```

https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster_capacity_providers

-> Criando Task Definition

Iremos criar um resource que basicamente informa para o ECS, todos os detalhes sobre o container, porta, imagem, quantidade de recurso, é aqui que caso sua aplicação tenha variaveis de ambiente você irá colocar e aqui também será informada a task execution role

```
resource "aws_ecs_task_definition" "task-definition-demo" {
  family                   = "task-definition-demo"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  container_definitions = jsonencode([
    {
      name      = "task-definition-demo"
      image     = "nginx"
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
    }
  ])
}
```

https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition


-> Criando Service

Este será o recurso do ECS que irá direcionar o tráfego para o container e gerenciar a execução de tarefas 

```
resource "aws_ecs_service" "service-ecs-demo" {
  name            = "service-ecs-demo"
  cluster         = aws_ecs_cluster.ecs-cluster-demo.id
  task_definition = aws_ecs_task_definition.task-definition-demo.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs-tg-demo.arn
    container_name   = "task-definition-demo"
    container_port   = 80
  }

  network_configuration {
    subnets         = [aws_subnet.subnet_private_1a.id, aws_subnet.subnet_private_1b.id]
    security_groups = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }


  depends_on = [
    aws_lb.alb,
    aws_lb_target_group.ecs-tg-demo,
    aws_lb_listener.http
  ]
}
```

## Application Load Balancer

Para que nós possamos acessar a nossa aplicação, iremos utilizar um ALB para ser a ponte entre uma subnet publica e uma subnet privada


```
resource "aws_lb" "alb" {
  name               = "alb-demo"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.subnet_public_1a.id, aws_subnet.subnet_public_1b.id]

  enable_deletion_protection = false
}

resource "aws_lb_target_group" "ecs-tg-demo" {
  name        = "ecs-tg-demo"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.vpc-ecs-demo.id
  target_type = "ip"
  health_check {
      path                  = "/"
      protocol              = "HTTP"
      matcher               = "200"
      port                  = "traffic-port"
      healthy_threshold     = 2
      unhealthy_threshold   = 2
      timeout               = 10
      interval              = 30
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs-tg-demo.arn
  }
}

resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.vpc-ecs-demo.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```