terraform {
    backend "s3" {
      bucket = ""
      key    = "default-vpc-delete/terraform.tfstate"
      region = ""
      access_key     = ""
      secret_key     = ""
  
    }
  }
