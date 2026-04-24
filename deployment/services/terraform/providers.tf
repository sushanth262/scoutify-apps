provider "kubernetes" {
  config_path    = pathexpand(var.kubeconfig_path)
  config_context = trimspace(var.kubeconfig_context) == "" ? null : var.kubeconfig_context
}
