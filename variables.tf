variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment deve ser dev, staging ou prod."
  }
}

variable "project_name" {
  description = "Nome do projeto, usado como prefixo dos recursos"
  type        = string
  default     = "products-api"
}

variable "lambda_runtime" {
  description = "Runtime da Lambda"
  type        = string
  default     = "python3.12"
}

variable "lambda_memory" {
  description = "Memória da Lambda (MB)"
  type        = number
  default     = 256
}

variable "lambda_timeout" {
  description = "Timeout da Lambda (segundos)"
  type        = number
  default     = 10
}

variable "log_retention_days" {
  description = "Retenção dos logs no CloudWatch (dias)"
  type        = number
  default     = 7
}

variable "common_tags" {
  description = "Tags aplicadas aos recursos"
  type        = map(string)

  default = {
    Environment = "dev"
    ManagedBy   = "terraform"
    Project     = "products-api"
    Owner       = "devops"
  }
}

variable "cors_allow_origin" {
  description = "Origem permitida no CORS (use o domínio do frontend em produção)"
  type        = string
  default     = "*"
}
