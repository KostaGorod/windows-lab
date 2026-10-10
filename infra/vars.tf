#Set your public SSH key here
variable "ssh_key" {
  default = "roci_develop"
}
#Establish which Proxmox host you'd like to spin a VM up on
variable "proxmox_node" {
    default = "pve"
}
#Specify which template name you'd like to use
variable "template_name" {
    default = "ubuntu-2204-template"
}
#Establish which nic you would like to utilize
variable "nic_name" {
    default = "vmbr0"
}
#Establish the VLAN you'd like to use
variable "vlan_num" {
    default = "30"
}
#Provide the url of the host you would like the API to communicate on.
#It is safe to default to setting this as the URL for what you used
#as your `proxmox_node`, although they can be different
variable "endpoint_url" {
    default = "https://pve.myth-rudd.ts.net:8006/"
}
#Blank var for use by terraform.tfvars
variable "token_secret" {
  sensitive   = true

}
#Blank var for use by terraform.tfvars
variable "token_id" {
}

variable "virtual_environment_node_name" {
  default = "default_node_name"
}
