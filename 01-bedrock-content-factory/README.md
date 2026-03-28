# 01 — Serverless AI Content Factory

A serverless web app that generates marketing content (title, description, LinkedIn post) from a product brief — powered by Claude Sonnet via AWS Bedrock.

> 📝 Behind the scenes: [What nobody tells you about AWS Bedrock](https://medium.com/@sistatress971/how-i-built-an-ai-content-factory-with-claude-and-aws-bedrock-and-everything-that-almost-broke-41a450b12590)

---

## What it does

You type a product brief. The app calls Claude Sonnet through AWS Bedrock and returns three pieces of marketing content in seconds:
- A product title
- A short description
- A LinkedIn post

---

## Architecture

```
Browser (HTML/JS)
      │
      │  POST JSON
      ▼
Lambda Function URL  ──────►  AWS Bedrock
(BUFFERED mode)               Claude Sonnet
      │                       us-east-1
      │  IAM Role
      ▼
AmazonBedrockFullAccess
```

**Why Lambda Function URL instead of API Gateway?**
API Gateway does not support streaming responses. Lambda Function URLs do — and they're simpler to configure, with no additional cost. Even though this version ships in BUFFERED mode, the architecture is already ready for streaming.

**Why BUFFERED and not RESPONSE_STREAM?**
Streaming with Lambda Function URLs requires specific response handling on both the Lambda side (generator body) and the frontend side (ReadableStream). The architecture supports it — the implementation is a work in progress. See [02-bedrock-streaming](../02-bedrock-streaming/) for the follow-up.

---

## Stack

| Layer | Service / Tool |
|---|---|
| Frontend | HTML · Vanilla JS · hosted on S3 |
| Compute | AWS Lambda · Python 3.12 · boto3 |
| AI Model | AWS Bedrock · Claude Sonnet |
| Auth | IAM Role with AmazonBedrockFullAccess |
| Endpoint | Lambda Function URL · BUFFERED mode |
| Region | us-east-1 |

---

## Key lessons learned

**1. Model activation is manual**
Before any API call works, you need to manually request access to Claude Sonnet in the Bedrock console under *Model access*. The error you get if you skip this step looks like an IAM issue — it's not.

**2. API Gateway doesn't support streaming**
This was the first architectural decision I had to make. Lambda Function URLs are the right replacement.

**3. Streaming fails silently**
When streaming doesn't work, there's no error — just a delayed full response. This makes it genuinely hard to debug. Full details in the Medium article linked above.

---

## How to deploy

### Prerequisites
- AWS account with Bedrock access enabled for Claude Sonnet in `us-east-1`
- AWS CLI configured (`aws configure`)
- Python 3.12

### 1. Enable model access
Go to AWS Console → Bedrock → Model access → Request access to Claude Sonnet.

### 2. Create the IAM Role
```bash
# Create role with Lambda trust policy
aws iam create-role \
  --role-name bedrock-lambda-role \
  --assume-role-policy-document file://trust-policy.json

# Attach Bedrock permissions
aws iam attach-role-policy \
  --role-name bedrock-lambda-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonBedrockFullAccess
```

### 3. Deploy the Lambda function
```bash
zip function.zip lambda_function.py

aws lambda create-function \
  --function-name content-factory \
  --runtime python3.12 \
  --handler lambda_function.handler \
  --role arn:aws:iam::YOUR_ACCOUNT_ID:role/bedrock-lambda-role \
  --zip-file fileb://function.zip \
  --timeout 30 \
  --region us-east-1
```

### 4. Create the Function URL
```bash
aws lambda create-function-url-config \
  --function-name content-factory \
  --auth-type NONE \
  --cors '{"AllowOrigins":["*"],"AllowMethods":["POST"],"AllowHeaders":["Content-Type"]}' \
  --region us-east-1
```

### 5. Update the frontend
In `index.html`, replace `LAMBDA_FUNCTION_URL` with your actual Function URL, then open the file in your browser or host it on S3.

---

## Estimated cost

| Service | Cost |
|---|---|
| Lambda | Free tier — 1M requests/month |
| Lambda Function URL | Free |
| Bedrock Claude Sonnet | ~$0.003–$0.01 per generation |
| S3 static hosting | A few cents/month |

---

## What's next

→ [02-bedrock-streaming](../02-bedrock-streaming/) — Making streaming actually work end-to-end