# deploy.ps1
$FUNCTION_NAME = "content-factory"
$ROLE_NAME     = "lambda-bedrock-role"
$REGION        = "us-east-1"
$DIR           = "C:\claude"

# ── Verification des fichiers ──────────────────────────────
Write-Host "Verification des fichiers..."
if (-not (Test-Path "$DIR\trust-policy.json")) {
    Write-Host "ERREUR : trust-policy.json introuvable dans $DIR" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path "$DIR\handler.py")) {
    Write-Host "ERREUR : handler.py introuvable dans $DIR" -ForegroundColor Red
    exit 1
}

# ── Creation du role IAM ───────────────────────────────────
Write-Host "Creation du role IAM..."
aws iam create-role `
    --role-name $ROLE_NAME `
    --assume-role-policy-document "file://$DIR/trust-policy.json"
if ($LASTEXITCODE -ne 0) { Write-Host "ERREUR role IAM" -ForegroundColor Red; exit 1 }

# ── Attachement des policies ───────────────────────────────
Write-Host "Attachement des policies..."
aws iam attach-role-policy `
    --role-name $ROLE_NAME `
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
if ($LASTEXITCODE -ne 0) { Write-Host "ERREUR policy 1" -ForegroundColor Red; exit 1 }

aws iam attach-role-policy `
    --role-name $ROLE_NAME `
    --policy-arn arn:aws:iam::aws:policy/AmazonBedrockFullAccess
if ($LASTEXITCODE -ne 0) { Write-Host "ERREUR policy 2" -ForegroundColor Red; exit 1 }

# ── Recuperation de l'ARN ──────────────────────────────────
Write-Host "Recuperation de l ARN du role..."
$ROLE_ARN = aws iam get-role `
    --role-name $ROLE_NAME `
    --query "Role.Arn" `
    --output text
Write-Host "ARN : $ROLE_ARN"

# ── Zip du code ────────────────────────────────────────────
Write-Host "Zip du code..."
Compress-Archive -Path "$DIR\handler.py" -DestinationPath "$DIR\function.zip" -Force

# ── Attendre que le role soit propagé (IAM ~10s) ───────────
Write-Host "Attente propagation IAM (10s)..."
Start-Sleep -Seconds 10

# ── Creation de la fonction Lambda ─────────────────────────
Write-Host "Creation de la fonction Lambda..."
aws lambda create-function `
    --function-name $FUNCTION_NAME `
    --runtime python3.12 `
    --role $ROLE_ARN `
    --handler handler.handler `
    --timeout 30 `
    --region $REGION `
    --zip-file "fileb://$DIR/function.zip"
if ($LASTEXITCODE -ne 0) { Write-Host "ERREUR creation Lambda" -ForegroundColor Red; exit 1 }

# ── Function URL avec streaming ────────────────────────────
Write-Host "Creation de la Function URL..."
aws lambda create-function-url-config `
    --function-name $FUNCTION_NAME `
    --auth-type NONE `
    --invoke-mode RESPONSE_STREAM `
    --cors '{\"AllowOrigins\":[\"*\"],\"AllowMethods\":[\"POST\"],\"AllowHeaders\":[\"content-type\"]}' `
    --region $REGION
if ($LASTEXITCODE -ne 0) { Write-Host "ERREUR Function URL" -ForegroundColor Red; exit 1 }

# ── Permission appel public ────────────────────────────────
Write-Host "Ajout permission publique..."
aws lambda add-permission `
    --function-name $FUNCTION_NAME `
    --statement-id FunctionURLAllowPublicAccess `
    --action lambda:InvokeFunctionUrl `
    --principal "*" `
    --function-url-auth-type NONE `
    --region $REGION
if ($LASTEXITCODE -ne 0) { Write-Host "ERREUR permission" -ForegroundColor Red; exit 1 }

# ── Affichage de la Function URL ───────────────────────────
Write-Host ""
Write-Host "Deploy termine !" -ForegroundColor Green
Write-Host "Votre Function URL :"
aws lambda get-function-url-config `
    --function-name $FUNCTION_NAME `
    --query "FunctionUrl" `
    --output text `
    --region $REGION
Write-Host ""
Write-Host "Copiez cette URL dans bedrock-content-factory.html (const API_URL)" -ForegroundColor Yellow