# Terraform Serverless API

## 1. Objetivo
API REST para gerenciar produtos (criar, listar, consultar e excluir), 100% provisionada com Terraform na AWS.
Inclui os extras: API Key, CORS, múltiplos ambientes e Lambda Layer.

## 2. Arquitetura
```text
Client --(x-api-key)--> API Gateway (REST API) --> Lambda (+ Layer) --> DynamoDB
                                                      |
                                                      +--> CloudWatch Logs
```

| Método | Rota             | Descrição         |
| ------ | ---------------- | ----------------- |
| POST   | `/products`      | Criar produto     |
| GET    | `/products`      | Listar produtos   |
| GET    | `/products/{id}` | Consultar produto |
| DELETE | `/products/{id}` | Excluir produto   |
| OPTIONS| `/products[/{id}]` | Preflight CORS (sem API Key) |

## 3. Pré-requisitos
AWS CLI, Terraform >= 1.5, Git, Python 3.12 (opcional).

## 4. Configuração AWS
```bash
aws configure          # ou: export AWS_PROFILE=meu-perfil
aws sts get-caller-identity
```
Nunca coloque credenciais no repositório.

## 5. Deploy
```bash
cp terraform.tfvars.example terraform.tfvars   # ajuste project_name para um nome único
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
```

### Ambientes (dev, staging, prod)
Use um workspace por ambiente para ter um state separado:
```bash
terraform workspace new staging
terraform apply -var="environment=staging"
```

## 6. Testes
```bash
export API_URL=$(terraform output -raw api_url)
export API_KEY=$(terraform output -raw api_key_value)

# Sem chave -> 403
curl -i "$API_URL/products"

# Com chave
curl -s -X POST "$API_URL/products" -H "x-api-key: $API_KEY" \
  -H "Content-Type: application/json" -d '{"name":"Notebook","price":4500}'
curl -s "$API_URL/products" -H "x-api-key: $API_KEY"
curl -s "$API_URL/products/ID" -H "x-api-key: $API_KEY"
curl -i -X DELETE "$API_URL/products/ID" -H "x-api-key: $API_KEY"
curl -i "$API_URL/products/ID" -H "x-api-key: $API_KEY"   # 404

# Preflight CORS
curl -i -X OPTIONS "$API_URL/products" \
  -H "Origin: http://localhost:3000" -H "Access-Control-Request-Method: POST"
```
Logs:
```bash
aws logs tail "$(terraform output -raw log_group_name)" --follow
```

## 7. Destroy
```bash
terraform destroy
```
