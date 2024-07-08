variable "azure_subscription_id" {
    description = "The subscription ID for Azure"
    type        = string
}

variable "azure_client_id" {
    description = "The client ID for Azure"
    type        = string
}

variable "azure_client_secret" {
    description = "The client secret for Azure"
    type        = string
}

variable "aws_region" {
    description = "The resources region in AWS"
    type        = string
}

variable "aws_access_key" {
    description = "The access key for AWS"
    type        = string
}

variable "aws_secret_key" {
    description = "The secret key for AWS"
    type        = string
}

variable "aws_route53_record_zone_id" {
    description = "The zone id for the AWS Route 53"
    type        = string
}

variable "aws_route53_record_domain_name" {
    description = "The domain name for the application"
    type        = string
}

variable "azure_vm_ssh_username" {
    description = "The ssh user name for the Azure VM"
    type        = string
}

variable "azure_vm_ssh_password" {
    description = "The ssh password for the Azure VM"
    type        = string
}

variable "kibana_username" {
    description = "The user name for Kibana"
    type        = string
}

variable "kibana_password" {
    description = "The password for Kibana"
    type        = string
}

variable "elastic_index" {
    description = "The elasticsearch index"
    type        = string
}