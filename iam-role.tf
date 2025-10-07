data "aws_iam_policy_document" "podidentity" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }
}

# Create IAM role with trust policy
resource "aws_iam_role" "externaldns_iam_role" {
  name               = "external-dns-controller"
  assume_role_policy = data.aws_iam_policy_document.podidentity.json
}

# Associate Identity allowing serviceAccount external-dns-controller in NS external-dns
resource "aws_eks_pod_identity_association" "externaldns" {
  cluster_name    = module.eks.cluster_name
  namespace       = "external-dns"
  service_account = "external-dns-controller"
  role_arn        = aws_iam_role.externaldns_iam_role.arn
}

# IAM policy to allow Route53 zone updates
resource "aws_iam_policy" "external_dns_iam_policy" {
  name = "ExternalDNSControllerIAMPolicy"
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "route53:ChangeResourceRecordSets"
          ],
          "Resource" : [
            "arn:aws:route53:::hostedzone/*"
          ]
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "route53:ListHostedZones",
            "route53:ListResourceRecordSets"
          ],
          "Resource" : [
            "*"
          ]
        }
      ]
    }
  )
}

# Attach policy to IAM role.
resource "aws_iam_role_policy_attachment" "externaldns_policy_attachement" {
  role       = aws_iam_role.externaldns_iam_role.name
  policy_arn = aws_iam_policy.external_dns_iam_policy.arn
}
