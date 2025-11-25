# Overview - Permission Sets

## Why They're Needed

A Permission Set is a template that you create and maintain which defines a collection of one or more IAM policies. Permission sets simplify the assignment of AWS account access for users and groups in your organization. AWS Think of them as a centralized way to define "roles" that can be assigned across multiple AWS accounts without having to manage IAM roles individually in each account.

In your multi-account setup, Permission Sets solve a critical problem: when IAM Identity Center assigns a permission set to a user or group in one or more AWS accounts, IAM Identity Center creates corresponding IAM Identity Center-controlled IAM roles in each account and attaches the policies specified in the permission set to those roles. This means you define permissions once in your Management account and they're automatically provisioned across Development, Staging, and Production.

For your specific use case, Permission Sets are essential because:

They centralize access management across all 3 sub-accounts, reducing inconsistency and operational overhead. You can assign permissions based on job functions (human operators, Terraform automation), and users/service accounts automatically get the right IAM roles in each account. Following the best practice of applying least-privilege permissions, after you create an administrative permission set, you create a more restrictive permission set and assign it to one or more users. This aligns perfectly with having separate permission sets for human users and your Terraform service account.
