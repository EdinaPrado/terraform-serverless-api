# Extra 4: Lambda Layer com código compartilhado (respostas HTTP e serialização JSON)
resource "aws_lambda_layer_version" "common" {
  layer_name          = "${local.name_prefix}-common"
  description         = "Funções utilitárias compartilhadas (response, json)"
  filename            = data.archive_file.layer_zip.output_path
  source_code_hash    = data.archive_file.layer_zip.output_base64sha256
  compatible_runtimes = [var.lambda_runtime]
}
