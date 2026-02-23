resource "aws_vpc" "myvpc" {
  cidr_block = var.cidr
}

resource "aws_subnet" "sub1" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "sub2" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.myvpc.id
}

resource "aws_route_table" "RT" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "RTA1" {
  subnet_id      = aws_subnet.sub1.id
  route_table_id = aws_route_table.RT.id
}

resource "aws_route_table_association" "RTA2" {
  subnet_id      = aws_subnet.sub2.id
  route_table_id = aws_route_table.RT.id
}

resource "aws_security_group" "SG1" {
  name        = "websg"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Web-SG"
  }
}

resource "aws_s3_bucket" "example" {
  bucket = "asp-terr-proj-38"
}

resource "aws_instance" "instance-demo1" {
  ami                    = "ami-0b6c6ebed2801a5cb"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.SG1.id]
  subnet_id              = aws_subnet.sub1.id
  user_data_base64       = base64encode(file("userdata.sh"))

  tags = {
    Name = "int-terr-proj1"
  }
}

resource "aws_instance" "instance-demo2" {
  ami                    = "ami-0b6c6ebed2801a5cb"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.SG1.id]
  subnet_id              = aws_subnet.sub2.id
  user_data_base64       = base64encode(file("userdata_asp.sh"))

  tags = {
    Name = "int-terr-proj2"
  }
}

#Create application load balancer
resource "aws_lb" "ALB" {
  name               = "ALB-Terr-Project"
  internal           = false
  load_balancer_type = "application"

  security_groups = [aws_security_group.SG1.id]
  subnets         = [aws_subnet.sub1.id, aws_subnet.sub2.id]

  tags = {
    name = "application-load-balancer"
  }
}

resource "aws_lb_target_group" "TG1" {
  name     = "LB-TG1"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.myvpc.id

  health_check {
    path = "/"
    port = "traffic-port"
  }
}

resource "aws_lb_target_group_attachment" "attachment1" {
  target_group_arn = aws_lb_target_group.TG1.arn
  target_id        = aws_instance.instance-demo1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "attachment2" {
  target_group_arn = aws_lb_target_group.TG1.arn
  target_id        = aws_instance.instance-demo2.id
  port             = 80
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.ALB.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.TG1.arn
    type             = "forward"
  }

}

output "lbdns" {
  value = aws_lb.ALB.dns_name
}