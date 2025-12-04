# =============================================================================
# KMS Key for EKS Secrets Encryption
# =============================================================================
# Creates a KMS key for envelope encryption of Kubernetes secrets
# Per ADR-013: Encryption at rest for sensitive data
# =============================================================================

resource "aws_kms_key" "eks_secrets" {
  count = var.enable_secrets_encryption ? 1 : 0

  description             = "KMS key for EKS secrets encryption - ${local.cluster_name}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  # Policy allowing EKS to use the key
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccountFullAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:${local.partition}:iam::${local.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowEKSToUseKey"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:CallerAccount" = local.account_id
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-secrets-key"
  })
}

resource "aws_kms_alias" "eks_secrets" {
  count = var.enable_secrets_encryption ? 1 : 0

  name          = "alias/eks/${local.cluster_name}-secrets"
  target_key_id = aws_kms_key.eks_secrets[0].key_id
}
