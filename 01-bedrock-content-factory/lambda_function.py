import boto3
import json

bedrock  = boto3.client("bedrock-runtime", region_name="us-east-1")
MODEL_ID = "us.anthropic.claude-sonnet-4-5-20250929-v1:0"


def handler(event, context):
    # RESPONSE_STREAM : le body peut arriver directement ou encodé
    raw_body = event.get("body") or "{}"
    
    # Si le body est un dict (déjà parsé par Lambda)
    if isinstance(raw_body, dict):
        body = raw_body
    else:
        import base64
        # Parfois encodé en base64
        if event.get("isBase64Encoded"):
            raw_body = base64.b64decode(raw_body).decode("utf-8")
        body = json.loads(raw_body)
        
    body     = json.loads(event.get("body") or "{}")
    product  = body.get("product", "")
    desc     = body.get("description", "")
    audience = body.get("audience", "professionnels")
    tone     = body.get("tone", "Professionnel")

    prompt = f"""Tu es un expert en marketing et copywriting.

Génère du contenu marketing percutant pour le produit suivant :

Produit : {product}
Description : {desc}
Cible : {audience}
Ton souhaité : {tone}

Génère EXACTEMENT ce JSON (sans markdown, sans texte autour) :
{{
  "titre": "Un titre accrocheur de max 10 mots",
  "pitch_email": "Un pitch email d'accroche de 3 phrases max : une douleur, une solution, un appel à l'action",
  "linkedin": "Un post LinkedIn engageant de 4-6 lignes avec emojis, hashtags et un call-to-action"
}}"""

    response = bedrock.invoke_model(
        modelId=MODEL_ID,
        body=json.dumps({
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 1000,
            "messages": [{"role": "user", "content": prompt}]
        })
    )

    result = json.loads(response["body"].read())
    text   = result["content"][0]["text"]
    usage  = result.get("usage", {})
    parsed = json.loads(text.replace("```json", "").replace("```", "").strip())

    return {
        "statusCode": 200,
        "headers": { "Content-Type": "application/json" },
        "body": json.dumps({
            "titre":       parsed["titre"],
            "pitch_email": parsed["pitch_email"],
            "linkedin":    parsed["linkedin"],
            "tokens_in":   usage.get("input_tokens"),
            "tokens_out":  usage.get("output_tokens"),
        })
    }