i## Sistema operacional
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
resource "aws_subnet" "subnet_private" {
  vpc_id     = aws_vpc.vpc-ecs-demo.id
  cidr_block = "10.0.1.0/24"

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

