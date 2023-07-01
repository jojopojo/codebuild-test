variable "aws_access_key" {
  description = "The AWS access key"
  type        = string
  sensitive   = true
}
variable "aws_secret_key" {
  description = "The AWS secret key"
  type        = string
  sensitive   = true
}
variable "aws_token" {
  description = "The AWS token"
  type        = string
  sensitive   = true
}
variable "github_user" {
  description = "github user"
  type        = string
}
variable "github_repo" {
  description = "github repo"
  type        = string
}
variable "github_token" {
  description = "github token"
  type        = string
  sensitive   = true
}
variable "github_branch" {
  description = "Name for output bucket"
  type        = string
}
variable "codepipeline_name" {
  description = "Name for Codepipeline"
  type        = string
}
variable "bucket_name" {
  description = "Name for output bucket"
  type        = string
}
variable "codestar_arn" {
  description = "Codestar arn (connection to GitHub)"
  type        = string
}
variable "codestar_id" {
  description = "Codestar id"
  type        = string
}