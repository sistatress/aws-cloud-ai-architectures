# deploy.ps1
$FUNCTION_NAME = "content-factory"
$ROLE_NAME     = "lambda-bedrock-role"
$REGION        = "us-east-1"
$DIR           = Split-Path -Parent $MyInvocation.MyCommand.Path

# ── Verification des fichiers ──────────────────────────────
Write-Host "Verification des fichiers..." -ForegroundColor Cyan
if (-not (Test-Path "$DIR\trust-policy.json")) {
    Write-Host "ERREUR : trust-policy.json introuvable dans $DIR" -ForegroundColor Red; exit 1
}
if (-not (Test-Path "$DIR\lambda_function.py")) {
    Write-Host "ERREUR : lambda_function.py introuvable dans $DIR" -ForegroundColor Red; exit 1
}

# ── Creation du role IAM ───────────────────────────────────
Write-Host "Creation du role IAM..." -ForegroundColor Cyan
aws iam create-role `
    --role-name $ROLE_NAME `
    --assume-role-policy-document "file://$DIR/trust-policy.json"
if ($LASTEXITCODE -ne 0) { Write-Host "ERREUR role IAM" -ForegroundColor Red; exit 1 }

# ── Attachement des policies ───────────────────────────────
Write-Host "Attachement des policies..." -ForegroundColor Cyan
aws iam attach-role-policy `
    --role-name $ROLE_NAME `
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
if ($LASTEXITCODE -ne 0) { Write-Host "ERREUR policy 1" -ForegroundColor Red; exit 1 }

aws iam attach-role-policy `
    --role-name $ROLE_NAME `
    --policy-arn arn:aws:iam::aws:policy/AmazonBedrockFullAccess
if ($LASTEXITCODE -ne 0) { Write-Host "ERREUR policy 2" -ForegroundColor Red; exit 1 }

# ── Recuperation de l'ARN ──────────────────────────────────
Write-Host "Recuperation de l ARN du role..." -ForegroundColor Cyan
$ROLE_ARN = aws iam get-role `
    --role-name $ROLE_NAME `
    --query "Role.Arn" `
    --output text
Write-Host "ARN : $ROLE_ARN"

# ── Zip du code ────────────────────────────────────────────
Write-Host "Zip du code..." -ForegroundColor Cyan
Compress-Archive -Path "$DIR\lambda_function.py" -DestinationPath "$DIR\function.zip" -Force

# ── Attendre que le role soit propagé (IAM ~10s) ───────────
Write-Host "Attente propagation IAM (10s)..." -ForegroundColor Cyan
Start-Sleep -Seconds 10

# ── Creation de la fonction Lambda ─────────────────────────
Write-Host "Creation de la fonction Lambda..." -ForegroundColor Cyan
aws lambda create-function `
    --function-name $FUNCTION_NAME `
    --runtime python3.12 `
    --role $ROLE_ARN `
    --handler lambda_function.handler `
    --timeout 30 `
    --region $REGION `
    --zip-file "fileb://$DIR/function.zip"
if ($LASTEXITCODE -ne 0) { Write-Host "ERREUR creation Lambda" -ForegroundColor Red; exit 1 }

# ── Function URL en mode BUFFERED ──────────────────────────
Write-Host "Creation de la Function URL (BUFFERED)..." -ForegroundColor Cyan
aws lambda create-function-url-config `
    --function-name $FUNCTION_NAME `
    --auth-type NONE `
    --invoke-mode BUFFERED `
    --cors '{\"AllowOrigins\":[\"*\"],\"AllowMethods\":[\"POST\"],\"AllowHeaders\":[\"content-type\"]}' `
    --region $REGION
if ($LASTEXITCODE -ne 0) { Write-Host "ERREUR Function URL" -ForegroundColor Red; exit 1 }

# ── Permission 1 : InvokeFunctionUrl ──────────────────────
# Permet l'accès à la Function URL publiquement
Write-Host "Ajout permission InvokeFunctionUrl..." -ForegroundColor Cyan
aws lambda add-permission `
    --function-name $FUNCTION_NAME `
    --statement-id FunctionURLAllowPublicAccess `
    --action lambda:InvokeFunctionUrl `
    --principal "*" `
    --function-url-auth-type NONE `
    --region $REGION
if ($LASTEXITCODE -ne 0) { Write-Host "ERREUR permission InvokeFunctionUrl" -ForegroundColor Red; exit 1 }

# ── Permission 2 : InvokeFunction ─────────────────────────
# OBLIGATOIRE avec Function URL — souvent oublié, cause des 403
Write-Host "Ajout permission InvokeFunction..." -ForegroundColor Cyan
aws lambda add-permission `
    --function-name $FUNCTION_NAME `
    --statement-id UrlPolicyInvokeFunction `
    --action lambda:InvokeFunction `
    --principal "*" `
    --region $REGION
if ($LASTEXITCODE -ne 0) { Write-Host "ERREUR permission InvokeFunction" -ForegroundColor Red; exit 1 }

# ── Affichage de la Function URL ───────────────────────────
Write-Host ""
Write-Host "Deploy termine !" -ForegroundColor Green
Write-Host "Votre Function URL :" -ForegroundColor Yellow
$FUNCTION_URL = aws lambda get-function-url-config `
    --function-name $FUNCTION_NAME `
    --query "FunctionUrl" `
    --output text `
    --region $REGION
Write-Host $FUNCTION_URL -ForegroundColor White
Write-Host ""
Write-Host "Mettez a jour API_URL dans index.html avec cette URL" -ForegroundColor Yellow