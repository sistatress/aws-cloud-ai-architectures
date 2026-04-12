# Commandes utiles — 01-bedrock-content-factory

## Déploiement

```powershell
# Zipper et déployer le code
Compress-Archive -Path lambda_function.py -DestinationPath function.zip -Force
aws lambda update-function-code `
  --function-name content-factory `
  --zip-file fileb://function.zip `
  --region us-east-1

# Mettre à jour le handler
aws lambda update-function-configuration `
  --function-name content-factory `
  --handler lambda_function.handler `
  --region us-east-1

# Lancer le serveur local
python -m http.server 8080 --bind 127.0.0.1
# → Ouvrir http://localhost:8080
```

---

## Function URL

```powershell
# Récupérer l'URL
aws lambda get-function-url-config `
  --function-name content-factory `
  --region us-east-1 `
  --query "FunctionUrl" --output text

# Vérifier la config complète
aws lambda get-function-url-config `
  --function-name content-factory `
  --region us-east-1

# Passer en BUFFERED (avec invoke_model classique)
aws lambda update-function-url-config `
  --function-name content-factory `
  --region us-east-1 `
  --invoke-mode BUFFERED `
  --cors '{\"AllowOrigins\":[\"*\"],\"AllowMethods\":[\"POST\"],\"AllowHeaders\":[\"content-type\"]}'

# Passer en RESPONSE_STREAM (avec invoke_model_with_response_stream)
aws lambda update-function-url-config `
  --function-name content-factory `
  --region us-east-1 `
  --invoke-mode RESPONSE_STREAM `
  --cors '{\"AllowOrigins\":[\"*\"],\"AllowMethods\":[\"POST\"],\"AllowHeaders\":[\"content-type\"]}'
```

---

## Permissions

> ⚠️ **Root cause du 403** : les deux permissions sont obligatoires.  
> `lambda:InvokeFunctionUrl` seul ne suffit pas.

```powershell
# Permission 1 — accès à la Function URL
aws lambda add-permission `
  --function-name content-factory `
  --statement-id FunctionURLAllowPublicAccess `
  --action lambda:InvokeFunctionUrl `
  --principal "*" `
  --function-url-auth-type NONE `
  --region us-east-1

# Permission 2 — invocation de la fonction (OBLIGATOIRE)
aws lambda add-permission `
  --function-name content-factory `
  --statement-id UrlPolicyInvokeFunction `
  --action lambda:InvokeFunction `
  --principal "*" `
  --region us-east-1

# Vérifier les permissions
aws lambda get-policy `
  --function-name content-factory `
  --region us-east-1

# Supprimer les permissions
aws lambda remove-permission `
  --function-name content-factory `
  --statement-id FunctionURLAllowPublicAccess `
  --region us-east-1

aws lambda remove-permission `
  --function-name content-factory `
  --statement-id UrlPolicyInvokeFunction `
  --region us-east-1
```

---

## Diagnostic

```powershell
# État de la fonction
aws lambda get-function-configuration `
  --function-name content-factory `
  --region us-east-1 `
  --query "[Handler,State,LastUpdateStatus,Runtime]"

# Derniers logs CloudWatch
$stream = $(aws logs describe-log-streams `
  --log-group-name "/aws/lambda/content-factory" `
  --order-by LastEventTime --descending `
  --region us-east-1 `
  --query "logStreams[0].logStreamName" --output text)

aws logs get-log-events `
  --log-group-name "/aws/lambda/content-factory" `
  --log-stream-name $stream `
  --region us-east-1 --limit 20

# Invoquer Lambda directement (bypasse la Function URL)
$payload = '{"body":"{\"product\":\"Test\",\"description\":\"Test\",\"audience\":\"pro\",\"tone\":\"Professionnel\"}"}'
$payload | Out-File -FilePath "$env:TEMP\payload.json" -Encoding utf8 -NoNewline
aws lambda invoke `
  --function-name content-factory `
  --region us-east-1 `
  --payload fileb://$env:TEMP\payload.json `
  --cli-binary-format raw-in-base64-out `
  "$env:TEMP\response.json"
Get-Content "$env:TEMP\response.json"

# Tester la Function URL avec curl
curl.exe -4 -X POST `
  -H "Content-Type: application/json" `
  -d "{\"product\":\"Test\",\"description\":\"Test\",\"audience\":\"pro\",\"tone\":\"Professionnel\"}" `
  "https://VOTRE_URL.lambda-url.us-east-1.on.aws/"

# Identité AWS active
aws sts get-caller-identity

# Région par défaut
aws configure list
```

---

## Modèles Bedrock

```powershell
# Lister les modèles Claude disponibles
aws bedrock list-foundation-models `
  --by-provider Anthropic `
  --region us-east-1 `
  --query "modelSummaries[*].[modelName,modelId,modelLifecycle.status]" `
  --output table
```

> Model ID à utiliser (inference profile obligatoire pour Claude 4.x) :  
> `us.anthropic.claude-sonnet-4-5-20250929-v1:0`