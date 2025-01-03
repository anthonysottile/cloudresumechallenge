provider "aws" {
  region = var.region
}

# S3 Bucket for Static Website
resource "aws_s3_bucket" "static_site" {
  bucket = var.bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_acl" "static_site_acl" {
  bucket = aws_s3_bucket.static_site.id
  acl    = "public-read"

  depends_on = [aws_s3_bucket_public_access_block.static_site_public_block]
}

resource "aws_s3_bucket_public_access_block" "static_site_public_block" {
  bucket = aws_s3_bucket.static_site.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_ownership_controls" "s3_bucket_owner" {
  bucket = aws_s3_bucket.static_site.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_policy" "static_site_policy" {
  bucket = aws_s3_bucket.static_site.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.static_site.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.static_site_public_block]
}

# ACM Certificate for Custom Domain
resource "aws_acm_certificate" "cert" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  subject_alternative_names = var.alternate_domain_names
}

# DNS Validation Records
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }

  zone_id = var.route53_zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.value]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "cert_validation" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "cdn" {
  origin {
    domain_name = aws_s3_bucket.static_site.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.static_site.id}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }

  enabled             = true
  default_root_object = "resume.html"

  default_cache_behavior {
    target_origin_id       = "S3-${aws_s3_bucket.static_site.id}"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]
    compress        = true
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate_validation.cert_validation.certificate_arn
    ssl_support_method  = "sni-only"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  aliases = concat([var.domain_name], var.alternate_domain_names)
}

# Route 53 Records for CloudFront
resource "aws_route53_record" "cdn_alias" {
  zone_id = var.route53_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.cdn.domain_name
    zone_id                = aws_cloudfront_distribution.cdn.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "cdn_alias_www" {
  zone_id = var.route53_zone_id
  name    = var.alternate_domain_names[0]
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.cdn.domain_name
    zone_id                = aws_cloudfront_distribution.cdn.hosted_zone_id
    evaluate_target_health = false
  }
}

# CloudFront OAI
resource "aws_cloudfront_origin_access_identity" "oai" {
  comment = "OAI for ${var.bucket_name}"
}

# DynamoDB
resource "aws_dynamodb_table" "visitor_counter_table" {
  name         = var.table_name
  hash_key     = "id"
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "id"
    type = "S"
  }
}

resource "aws_dynamodb_table_item" "dynamodb_views_item" {
  table_name = aws_dynamodb_table.visitor_counter_table.name
  hash_key   = aws_dynamodb_table.visitor_counter_table.hash_key

  item = <<ITEM
{
  "id": {"S": "1"},
  "views": {"N": "200"}
}
ITEM
}

# Lambda Function
resource "aws_lambda_function" "visitor_counter_lambda" {
  filename      = var.lambda_zip # Replace with your zip file containing Python code
  function_name = var.lambda_name
  role          = aws_iam_role.lambda_exec.arn
  handler       = var.lambda_handler # Adjust based on your Python file and function name
  runtime       = var.lambda_runtime # Choose an appropriate Python version

  source_code_hash = filebase64sha256("lambda_function_payload.zip") # Ensures updates if source changes
}

# IAM Role for Lambda function to allow execution
resource "aws_iam_role" "lambda_exec" {
  name = var.lambda_iam_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# IAM Policy for Lambda to interact with DynamoDB
resource "aws_iam_role_policy" "lambda_dynamodb_policy" {
  name = var.lambda_role_policy_name
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:BatchGetItem",
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchWriteItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ]
        Resource = "${aws_dynamodb_table.visitor_counter_table.arn}"
      }
    ]
  })
}

# Attaching basic execution policy for Lambda
resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# API Gateway
resource "aws_api_gateway_rest_api" "visitor_counter_api" {
  name        = var.api_gateway_name
  description = var.api_gateway_description
}

resource "aws_api_gateway_resource" "visitor_counter_resource" {
  rest_api_id = aws_api_gateway_rest_api.visitor_counter_api.id
  parent_id   = aws_api_gateway_rest_api.visitor_counter_api.root_resource_id
  path_part   = var.api_resource_path
}

resource "aws_api_gateway_method" "visitor_counter_method" {
  rest_api_id   = aws_api_gateway_rest_api.visitor_counter_api.id
  resource_id   = aws_api_gateway_resource.visitor_counter_resource.id
  http_method   = var.api_method
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.visitor_counter_api.id
  resource_id             = aws_api_gateway_resource.visitor_counter_resource.id
  http_method             = aws_api_gateway_method.visitor_counter_method.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = aws_lambda_function.visitor_counter_lambda.invoke_arn
  passthrough_behavior    = "WHEN_NO_MATCH"
}

resource "aws_api_gateway_integration_response" "api_int_response" {
  rest_api_id = aws_api_gateway_rest_api.visitor_counter_api.id
  resource_id = aws_api_gateway_resource.visitor_counter_resource.id
  http_method = aws_api_gateway_method_response.api_method_response.http_method
  status_code = 200

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }
}

resource "aws_api_gateway_method_response" "api_method_response" {
  rest_api_id = aws_api_gateway_rest_api.visitor_counter_api.id
  resource_id = aws_api_gateway_resource.visitor_counter_resource.id
  http_method = aws_api_gateway_integration.lambda_integration.http_method
  status_code = 200

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

# API Gateway permissions for Lambda
resource "aws_lambda_permission" "api_gateway_lambda" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.visitor_counter_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.visitor_counter_api.execution_arn}/*/*"
}

# Deploy API
resource "aws_api_gateway_deployment" "visitor_counter_deployment" {
  rest_api_id = aws_api_gateway_rest_api.visitor_counter_api.id

  depends_on = [ aws_api_gateway_method_response.api_method_response ]
}

resource "aws_api_gateway_stage" "visitor_counter_stage" {
  deployment_id = aws_api_gateway_deployment.visitor_counter_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.visitor_counter_api.id
  stage_name    = "main"
}