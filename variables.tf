variable "aws_access_key_id" {
  description = "The AWS access key"
  type        = string
  sensitive   = true
}
variable "aws_secret_access_key" {
  description = "The AWS secret key"
  type        = string
  sensitive   = true
}
variable "aws_session_token" {
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
variable "prj_name" {
  description = "project name"
  type        = string
}

