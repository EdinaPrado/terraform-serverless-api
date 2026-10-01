import json
import logging
import os
import uuid
from decimal import Decimal, InvalidOperation

import boto3
from botocore.exceptions import ClientError

# Vem do Lambda Layer (/opt/python/common_utils.py)
from common_utils import response

logger = logging.getLogger()
logger.setLevel(logging.INFO)

TABLE_NAME = os.environ["TABLE_NAME"]
table = boto3.resource("dynamodb").Table(TABLE_NAME)


def create_product(event):
    logger.info("Creating product")

    try:
        data = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        logger.warning("Invalid JSON body")
        return response(400, {"message": "Body deve ser um JSON válido"})

    name = data.get("name")
    price = data.get("price")

    if not isinstance(name, str) or not name.strip():
        return response(400, {"message": "Campo 'name' é obrigatório (string)"})

    if isinstance(price, bool) or not isinstance(price, (int, float)) or price < 0:
        return response(400, {"message": "Campo 'price' é obrigatório (número >= 0)"})

    try:
        price_decimal = Decimal(str(price))
    except InvalidOperation:
        return response(400, {"message": "Campo 'price' inválido"})

    item = {"id": str(uuid.uuid4()), "name": name.strip(), "price": price_decimal}
    table.put_item(Item=item)

    logger.info("Product created successfully: %s", item["id"])
    return response(201, item)


def list_products():
    logger.info("Listing products")

    result = table.scan()
    items = result.get("Items", [])
    while "LastEvaluatedKey" in result:
        result = table.scan(ExclusiveStartKey=result["LastEvaluatedKey"])
        items.extend(result.get("Items", []))

    logger.info("Found %d products", len(items))
    return response(200, items)


def get_product(product_id):
    logger.info("Getting product %s", product_id)

    item = table.get_item(Key={"id": product_id}).get("Item")
    if not item:
        logger.info("Product %s not found", product_id)
        return response(404, {"message": "Product not found"})

    return response(200, item)


def delete_product(product_id):
    logger.info("Deleting product %s", product_id)

    try:
        table.delete_item(
            Key={"id": product_id},
            ConditionExpression="attribute_exists(id)",
        )
    except ClientError as err:
        if err.response["Error"]["Code"] == "ConditionalCheckFailedException":
            logger.info("Product %s not found", product_id)
            return response(404, {"message": "Product not found"})
        raise

    logger.info("Product %s deleted successfully", product_id)
    return response(204)


def lambda_handler(event, context):
    logger.info("Request received")

    # REST API (payload v1) usa "httpMethod"; HTTP API (payload v2) usa requestContext.http
    method = event.get("httpMethod") or event["requestContext"]["http"]["method"]
    product_id = (event.get("pathParameters") or {}).get("id")
    logger.info("HTTP method: %s | product_id: %s", method, product_id)

    try:
        if method == "POST" and not product_id:
            return create_product(event)
        if method == "GET" and not product_id:
            return list_products()
        if method == "GET" and product_id:
            return get_product(product_id)
        if method == "DELETE" and product_id:
            return delete_product(product_id)

        return response(405, {"message": "Method not allowed"})

    except Exception:
        logger.exception("Unexpected error")
        return response(500, {"message": "Internal server error"})
