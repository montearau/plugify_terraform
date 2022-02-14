terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }
}

provider "aws" {
  profile = "default"
  region  = "us-west-2"
}

module "vpc" {
  source = "./modules/vpc"

  resource_tag_name = var.resource_tag_name
  namespace         = var.namespace
  region            = var.region

  vpc_cidr = "172.0.0.0/16"

  route = [
    {
      cidr_block     = "0.0.0.0/0"
      gateway_id     = module.vpc.gateway_id
      instance_id    = null
      nat_gateway_id = null
    }
  ]

  subnet_ids = module.subnet_ec2.ids
}

module "ec2" {
  source = "./modules/ec2"

  resource_tag_name = var.resource_tag_name
  namespace         = var.namespace
  region            = var.region

  user_data =   <<-EOF
    #!/bin/bash
    set -ex
    sudo yum update -y
    sudo amazon-linux-extras install docker -y
    sudo service docker start
    sudo usermod -a -G docker ec2-user
    sudo curl -L https://github.com/docker/compose/releases/download/1.25.4/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
  EOF

  ami           = "ami-07ebfd5b3428b6f4d" 
  key_name      = "${local.resource_name_prefix}-ec2-key"
  instance_type = var.instance_type
  subnet_id     = module.subnet_ec2.ids[0]

  vpc_security_group_ids = [aws_security_group.ec2.id]

  vpc_id = module.vpc.id
}

module "rds" {
    source = ".modules/rds"

    # RDS vars
    rds_identifier        = "postgres"
    rds_engine            = "postgres12"
    rds_engine_version    = "12.2"
    rds_instance_class    = "db.t3.micro"
    rds_allocated_storage = 30
    rds_storage_encrypted = false     
    rds_name              = "prod-postgres-db"        
    rds_username          = "admin"   

    rds_port                    = 5432
    rds_maintenance_window      = "Mon:00:00-Mon:03:00"
    rds_backup_window           = "10:46-11:16"
    rds_backup_retention_period = 1
    rds_publicly_accessible     = false

    rds_final_snapshot_identifier = "prod-postgres-db-snapshot" 
    rds_snapshot_identifier       = null 

    rds_performance_insights_enabled  = true
}

module "s3" {
    source = "./modules/s3"
    name = "arn:aws:s3:::plugify"
    env = "prd"    
}