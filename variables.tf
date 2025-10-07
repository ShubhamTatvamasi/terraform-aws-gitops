variable "tags" {
  description = "A map of tags to assign to resources."
  type        = map(string)
  default = {
    Environment = "mckinseydevops"
    Client      = "McKinsey"
    Terraform   = "true"
  }
}
