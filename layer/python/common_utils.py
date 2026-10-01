import json
import os
from decimal import Decimal


def json_default(obj):
    """DynamoDB devolve números como Decimal; converte para int/float."""
    if isinstance(obj, Decimal):
        return int(obj) if obj % 1 == 0 else float(obj)
    raise TypeError(f"Tipo não serializável: {type(obj)}")


def response(status, body=None):
    """Resposta HTTP no formato proxy, já com os headers de CORS."""
    return {
        "statusCode": status,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": os.environ.get("CORS_ALLOW_ORIGIN", "*"),
        },
        "body": json.dumps(body, default=json_default) if body is not None else "",
    }
