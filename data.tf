data "aws_caller_identity" "current" {}

# Empacota a pasta lambda/ em um .zip durante o plan/apply
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/build/lambda.zip"
}

# Empacota a pasta layer/ (contém python/common_utils.py) em um .zip
data "archive_file" "layer_zip" {
  type        = "zip"
  source_dir  = "${path.module}/layer"
  output_path = "${path.module}/build/layer.zip"
}
