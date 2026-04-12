# undeploy.ps1
$FUNCTION_NAME = "content-factory"
$ROLE_NAME     = "lambda-bedrock-role"
$REGION        = "us-east-1"

Write-Host "Suppression de la Function URL..." -ForegroundColor Yellow
aws lambda delete-function-url-config `
    --function-name $FUNCTION_NAME `
    --region $REGION 2>$null
if ($LASTEXITCODE -eq 0) { Write-Host "  OK" -ForegroundColor Green } else { Write-Host "  Deja supprimee" -ForegroundColor Gray }

Write-Host "Suppression des permissions..." -ForegroundColor Yellow
aws lambda remove-permission `
    --function-name $FUNCTION_NAME `
    --statement-id FunctionURLAllowPublicAccess `
    --region $REGION 2>$null

# Permission ajoutée suite au fix 403
aws lambda remove-permission `
    --function-name $FUNCTION_NAME `
    --statement-id UrlPolicyInvokeFunction `
    --region $REGION 2>$null

Write-Host "  OK" -ForegroundColor Green

Write-Host "Suppression de la fonction Lambda..." -ForegroundColor Yellow
aws lambda delete-function `
    --function-name $FUNCTION_NAME `
    --region $REGION 2>$null
if ($LASTEXITCODE -eq 0) { Write-Host "  OK" -ForegroundColor Green } else { Write-Host "  Deja supprimee" -ForegroundColor Gray }

Write-Host "Detachement des policies IAM..." -ForegroundColor Yellow
aws iam detach-role-policy `
    --role-name $ROLE_NAME `
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole 2>$null

aws iam detach-role-policy `
    --role-name $ROLE_NAME `
    --policy-arn arn:aws:iam::aws:policy/AmazonBedrockFullAccess 2>$null
Write-Host "  OK" -ForegroundColor Green

Write-Host "Suppression du role IAM..." -ForegroundColor Yellow
aws iam delete-role `
    --role-name $ROLE_NAME 2>$null
if ($LASTEXITCODE -eq 0) { Write-Host "  OK" -ForegroundColor Green } else { Write-Host "  Deja supprime" -ForegroundColor Gray }

Write-Host ""
Write-Host "Undeploy termine !" -ForegroundColor Green