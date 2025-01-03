variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1" # CloudFront and ACM require us-east-1
}

variable "bucket_name" {
  description = "Name of the S3 bucket for the static site"
  type        = string
  default     = "tonysottile.com"
}

variable "domain_name" {
  description = "Primary domain name for the static site"
  type        = string
  default     = "tonysottile.com"
}

variable "alternate_domain_names" {
  description = "Alternate domain names for the site"
  type        = list(string)
  default     = ["www.tonysottile.com"]
}

variable "route53_zone_id" {
  description = "Route 53 hosted zone ID for the domain"
  type        = string
  default     = "Z07298413KQ8VW0EP40CQ"
}

variable "table_name" {
  description = "Name of DynamoDB Table"
  type        = string
  default     = "VisitorCounter"
}

variable "lambda_zip" {
  description = "Name of zipped lambda file"
  type        = string
  default     = "lambda_function_payload.zip"
}

variable "lambda_name" {
  description = "Name of lambda function"
  type        = string
  default     = "VisitorCounterFunction"
}

variable "lambda_handler" {
  description = "Lambda function entrypoint in your code"
  type        = string
  default     = "lambda_function.lambda_handler"
}

variable "lambda_runtime" {
  description = "Runtime for the Lambda function"
  type        = string
  default     = "python3.8"
}

variable "lambda_filename" {
  description = "Path to the zip file containing the Lambda function code"
  type        = string
  default     = "lambda_function_payload.zip"
}

variable "lambda_iam_role_name" {
  description = "Role for lambda function"
  type        = string
  default     = "visitor_counter_lambda_role"
}

variable "lambda_role_policy_name" {
  description = "Name of policy for lambda role"
  type        = string
  default     = "visitor_counter_lambda_dynamodb_policy"
}

variable "api_gateway_name" {
  description = "The name of the API Gateway"
  type        = string
  default     = "visitor-counter-api"
}

variable "api_gateway_description" {
  description = "Description for the API Gateway"
  type        = string
  default     = "API for visitor counter"
}

variable "api_resource_path" {
  description = "The path part for the API resource"
  type        = string
  default     = "counter"
}

variable "api_method" {
  description = "HTTP method for the API endpoint"
  type        = string
  default     = "GET"
}

variable "api_stage_name" {
  default     = "Name of API Gateway stage"
  type        = string
  description = "main"
}