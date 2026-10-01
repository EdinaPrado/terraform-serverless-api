locals {
  name_prefix   = "${var.project_name}-${var.environment}"
  function_name = local.name_prefix
  table_name    = "${local.name_prefix}-products"

  # common_tags + Environment sempre refletindo a variável environment
  tags = merge(var.common_tags, {
    Environment = var.environment
  })
}

############################
# DynamoDB
############################
resource "aws_dynamodb_table" "products" {
  name         = local.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = local.tags
}

############################
# CloudWatch Log Group
############################
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = var.log_retention_days

  tags = local.tags
}

############################
# IAM (Role + Policy, least privilege)
############################
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${local.name_prefix}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = local.tags
}

data "aws_iam_policy_document" "lambda_permissions" {
  # CloudWatch Logs
  statement {
    sid    = "AllowCreateLogGroup"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
    ]
    resources = ["arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"]
  }

  statement {
    sid    = "AllowWriteLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.lambda.arn}:*"]
  }

  # DynamoDB: somente as 4 ações necessárias, somente nesta tabela
  statement {
    sid    = "AllowProductsTable"
    effect = "Allow"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:GetItem",
      "dynamodb:Scan",
      "dynamodb:DeleteItem",
    ]
    resources = [aws_dynamodb_table.products.arn]
  }
}

resource "aws_iam_policy" "lambda" {
  name        = "${local.name_prefix}-lambda-policy"
  description = "Logs + CRUD na tabela ${local.table_name}"
  policy      = data.aws_iam_policy_document.lambda_permissions.json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "lambda" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.lambda.arn
}

############################
# Lambda
############################
resource "aws_lambda_function" "api" {
  function_name = local.function_name
  role          = aws_iam_role.lambda.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = var.lambda_runtime
  memory_size   = var.lambda_memory
  timeout       = var.lambda_timeout
  layers        = [aws_lambda_layer_version.common.arn]

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      TABLE_NAME        = aws_dynamodb_table.products.name
      CORS_ALLOW_ORIGIN = var.cors_allow_origin
    }
  }

  # Garante que o Log Group gerenciado pelo Terraform exista antes da Lambda
  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy_attachment.lambda,
  ]

  tags = local.tags
}
