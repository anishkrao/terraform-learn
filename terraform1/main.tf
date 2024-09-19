provider "aws" {
    region = "ap-south-1"                        ///AWS infrastructure for our Demo project
}

variable vpc_cidr_block {}
variable subnet_cidr_block {}
variable avail_zone {}
variable env_prefix {}
variable my_ip {}
variable instance_type {}
variable public_key_location {}

resource "aws_vpc" "myapp_vpc" {
  cidr_block = var.vpc_cidr_block
  tags = {
    Name: "${var.env_prefix}_vpc"
  }
}

resource "aws_subnet" "myapp_subnet_1" {
  vpc_id = aws_vpc.myapp_vpc.id
  cidr_block = var.subnet_cidr_block
  availability_zone = var.avail_zone
  tags = {
    Name: "${var.env_prefix}_subnet_1"
  }
}

resource "aws_internet_gateway" "myapp_internet_gateway" {
    vpc_id = aws_vpc.myapp_vpc.id
    tags = {
      Name: "${var.env_prefix}_internet_gateway"
  }
}

resource "aws_route_table" "myapp_routetable" {
    vpc_id = aws_vpc.myapp_vpc.id

    route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.myapp_internet_gateway.id
    }

    tags = {
      Name: "${var.env_prefix}_route_table"
  }
}

resource "aws_route_table_association" "a_rtb_subnet" {
  subnet_id = aws_subnet.myapp_subnet_1.id
  route_table_id = aws_route_table.myapp_routetable.id
}

resource "aws_default_security_group" "myapp_sg" {  //configuring rules (outbound/inbound rules for my app) for our firewall
  
  vpc_id = aws_vpc.myapp_vpc.id

  ingress {            //incoming rules
    from_port = 22 //allow ssh connection to our vpc
    to_port = 22 //specifying range, in our case we just need port 22
    protocol = "tcp"
    cidr_blocks = [var.my_ip] //who is allowd to access resource on port 22 | in our case it's our own pc
  }

  ingress {
    from_port = 8080 //allow any ip connection to our vpc on the port 8080
    to_port = 8080 //specifying range, in our case we just need port 8080
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"] //who is allowd to access resource on port 22 | in our case it's our own pc
  }

  egress {            //outgoing rules , in our case allowing any traffic to leave our vpc
    from_port = 0 //any
    to_port = 0 //any
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    prefix_list_ids = []
  }

  tags = {
    Name: "${var.env_prefix}_default_sg"
  }

}

data "aws_ami" "latest_amazon_linux_image" {  //getting amazon machine image id 
  most_recent = true
  owners = ["amazon"]
  filter {                                     //filtering the ami based on its name
      name = "name"
      values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {                                     //filtering the ami based on its virtualization type
    name = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_key_pair" "ssh_key" {           //configuring our own key
    key_name = "server_key"
    public_key = file(var.public_key_location)
}

resource "aws_instance" "myapp_server" {        //configuring the ami 
  ami = data.aws_ami.latest_amazon_linux_image.id
  instance_type = var.instance_type
  subnet_id = aws_subnet.myapp_subnet_1.id
  vpc_security_group_ids = [aws_default_security_group.myapp_sg.id]
  availability_zone = var.avail_zone

  associate_public_ip_address = true
  key_name = aws_key_pair.ssh_key.key_name

  user_data = file("entry-script.sh")          //automating the deployment of container to the ec2 server

  tags = {
    Name: "${var.env_prefix}_server"
  }
}