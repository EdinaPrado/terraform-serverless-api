############################
# API Gateway (REST API)
############################
resource "aws_api_gateway_rest_api" "api" {
  name        = "${local.name_prefix}-rest-api"
  description = "API de produtos (${var.environment})"

  tags = local.tags
}

resource "aws_api_gateway_resource" "products" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "products"
}

resource "aws_api_gateway_resource" "product_id" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.products.id
  path_part   = "{id}"
}

locals {
  methods = {
    create = { resource_id = aws_api_gateway_resource.products.id, http_method = "POST" }
    list   = { resource_id = aws_api_gateway_resource.products.id, http_method = "GET" }
    get    = { resource_id = aws_api_gateway_resource.product_id.id, http_method = "GET" }
    delete = { resource_id = aws_api_gateway_resource.product_id.id, http_method = "DELETE" }
  }

  cors_resources = {
    products   = aws_api_gateway_resource.products.id
    product_id = aws_api_gateway_resource.product_id.id
  }
}

# Métodos que exigem a API Key (header x-api-key)
resource "aws_api_gateway_method" "methods" {
  for_each = local.methods

  rest_api_id      = aws_api_gateway_rest_api.api.id
  resource_id      = each.value.resource_id
  http_method      = each.value.http_method
  authorization    = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_integration" "lambda" {
  for_each = local.methods

  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = each.value.resource_id
  http_method             = aws_api_gateway_method.methods[each.key].http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api.invoke_arn
}

############################
# Extra 2: CORS (preflight OPTIONS sem API Key)
############################
resource "aws_api_gateway_method" "options" {
  for_each = local.cors_resources

  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = each.value
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options" {
  for_each = local.cors_resources

  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = each.value
  http_method = aws_api_gateway_method.options[each.key].http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = jsonencode({ statusCode = 200 })
  }
}

resource "aws_api_gateway_method_response" "options" {
  for_each = local.cors_resources

  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = each.value
  http_method = aws_api_gateway_method.options[each.key].http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Headers" = true
  }
}

resource "aws_api_gateway_integration_response" "options" {
  for_each = local.cors_resources

  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = each.value
  http_method = aws_api_gateway_method.options[each.key].http_method
  status_code = aws_api_gateway_method_response.options[each.key].status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = "'${var.cors_allow_origin}'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,DELETE,OPTIONS'"
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,x-api-key'"
  }

  depends_on = [aws_api_gateway_integration.options]
}

############################
# Extra 1: API Key + Usage Plan
############################
resource "aws_api_gateway_api_key" "key" {
  name    = "${local.name_prefix}-key"
  enabled = true

  tags = local.tags
}

resource "aws_api_gateway_usage_plan" "plan" {
  name = "${local.name_prefix}-plan"

  api_stages {
    api_id = aws_api_gateway_rest_api.api.id
    stage  = aws_api_gateway_stage.stage.stage_name
  }

  throttle_settings {
    rate_limit  = 10
    burst_limit = 20
  }

  tags = local.tags

  # ESTA LINHA É ESSENCIAL: força o Stage a ser criado ANTES do Usage Plan
  depends_on = [aws_api_gateway_stage.stage]
}

resource "aws_api_gateway_usage_plan_key" "plan_key" {
  key_id        = aws_api_gateway_api_key.key.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.plan.id
}

############################
# Deployment + Stage (stage = ambiente)
############################
resource "aws_api_gateway_deployment" "api" {
  rest_api_id = aws_api_gateway_rest_api.api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.products.id,
      aws_api_gateway_resource.product_id.id,
      aws_api_gateway_method.methods,
      aws_api_gateway_integration.lambda,
      aws_api_gateway_method.options,
      aws_api_gateway_integration.options,
      aws_api_gateway_integration_response.options,
    ]))
  }

  depends_on = [
    aws_api_gateway_method.methods,
    aws_api_gateway_integration.lambda
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "stage" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  deployment_id = aws_api_gateway_deployment.api.id
  stage_name    = var.environment

  tags = local.tags

  lifecycle {
    create_before_destroy = true
  }
}

############################
# Lambda Permission (API Gateway -> Lambda)
############################
resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*/*"
}
