#Specifying IAM User
provider "aws" {
  profile  =  "tanya1"
  region  = "ap-south-1"
}
#Creating VPC
resource "aws_vpc" "main" {
  cidr_block = "192.168.0.0/16"
    enable_dns_hostnames = "true"
   tags = {
    Name = "terra-vpc"
  }
}
#Public Subnet
resource "aws_subnet" "subnet1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "192.168.0.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = "true"

  tags = {
    Name = "terra-public"
  }
}
#Private Subnet
resource "aws_subnet" "subnet2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "192.168.1.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "terra-private"
  }
}
#Public facing Internet gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "terra-gw"
  }
}
#Routing Table
resource "aws_route_table" "r" {
  vpc_id = aws_vpc.main.id

route {
    cidr_block = "0.0.0.0/0"
     gateway_id = aws_internet_gateway.gw.id
}
   
 tags = {
    Name = "main"
  }
}
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.r.id
}

resource "aws_eip" "lb" {
   vpc      = true
}
resource "aws_nat_gateway" "nat-gw" {
  allocation_id = aws_eip.lb.id
  subnet_id     = aws_subnet.subnet1.id

  tags = {
    Name = "gw-NAT"
  }
}
resource "aws_route_table" "privte" {
  vpc_id = aws_vpc.main.id

route {
    cidr_block = "0.0.0.0/0"
     gateway_id = aws_nat_gateway.nat-gw.id
}
   
 tags = {
    Name = "main"
  }
}
resource "aws_route_table_association" "ab" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.privte.id
}
#Bastion Host security group
resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow ssh"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "TCP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks=["0.0.0.0/0"]
  }
    egress {
    description = "TCP"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Security Group for WordPress
resource "aws_security_group" "allowssh" {
  name        = "allowssh"
  description = "Allow TLS inbound traffic"
  vpc_id      =  aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

 ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "ICMP"
    from_port = -1
    to_port = -1
    protocol = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "public"
  }
}
#MYSQL SERVER BASTION SECURITY GROUP
resource "aws_security_group" "mariadb_private_bastion_sec" {
  name = "mariadb-private-bastion-sec"
  description = "Allow only Bastion Host traffic inbound via SSH protocol"
  vpc_id = aws_vpc.main.id 
  tags = {
    Name = "Bastion"
  }


  ingress {
    description = "Allow Bastion Hosts"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    security_groups = [aws_security_group.allow_ssh.id]
  }


  egress {
    description = "Allow Bastion Host outbound"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    security_groups = [aws_security_group.allow_ssh.id]
  }
}
#Security Group for MySQL
resource "aws_security_group" "allowsql" {
  name        = "allowsql"
  description = "Allow TLS inbound traffic"
  vpc_id      =  aws_vpc.main.id


 ingress {
    description = "mysql-rule"
    from_port   = 3306
    to_port     = 3306                                            ## to allow port of mysql
    protocol    = "tcp"
    security_groups = [aws_security_group.allowssh.id]
  }
  ingress {
    description = "SSH"
    from_port   = 22                                                    ## to allow ssh from bastion host only
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.mariadb_private_bastion_sec.id]

  }
 ingress {
    description = "Allow Bastion Host traffic"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    security_groups = [aws_security_group.allow_ssh.id]
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "private"
  }
}
#Instance WordPress
resource "aws_instance" "wp" {
  ami           = "ami-03899a29119b8194f"
  instance_type = "t2.micro"
  subnet_id  =  aws_subnet.subnet1.id
  vpc_security_group_ids  =  ["${aws_security_group.allowssh.id}"]
  key_name  = "new1"
  

  tags = {
    Name = "terra-wp"
  }
}
#Instance MySQL
resource "aws_instance" "sql" {
  ami           = "ami-00141549964d49703"
  instance_type = "t2.micro"
  subnet_id  =  aws_subnet.subnet2.id
  vpc_security_group_ids  =  ["${aws_security_group.allowsql.id}"]
  key_name  = "new1"

  

  tags = {
    Name = "terra-sql"
  }
}



resource "aws_instance" "ec2_bastion"{
 
  ami= "ami-09052aa9bc337c78d"
  instance_type="t2.micro"
  vpc_security_group_ids =["${aws_security_group.allow_ssh.id}"]
  key_name= "new1"
  subnet_id= aws_subnet.subnet1.id
  tags={
      Name="ec2_bastion"
  }
  
}
#Printing WordPress public_ip
output "task_done" {
  value = aws_instance.wp.public_ip
}

