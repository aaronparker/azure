variable "location" {
    type = string
    default = "AustraliaEast"
}

variable "environment" {
    type = string
    default = "TerraformTest"
}

variable "address_space" {
    type = string
    default = "10.100.0.0/16"
}

variable "subnet1" {
    type = string
    default = "10.100.1.0/24"
}

variable "vmname" {
    type = string
    default = "tflinux01"
}

variable "vmsize" {
    type = string
    default = "Standard_DS1_v2"
}

variable "admin_username" {
    type        = string
    default     = "rmuser"
    description = "Administrator user name for virtual machine"
}

variable "admin_password" {
    type        = string
    description = "Password must meet Azure complexity requirements"
}

variable "tags" {
    type = map
    default = {
            Environment = "Development"
            Function    = "Terraform"
            CreatedDate = "23-01-2020"
            CreatedBy   = "aaronparker@cloud.stealthpuppy.com"
            Owner       = "stealthpuppy"
    }
}

variable "sku" {
    default = {
        AustraliaEast     = "18.04-LTS"
        AustraliaSouthast = "18.04-LTS"
    }
}
