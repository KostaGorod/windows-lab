terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.116.0"
    }
    # bitwarden-secrets = {
    #   source = "registry.terraform.io/bitwarden/bitwarden-secrets"
    # }
  }
}

provider "proxmox" {
  endpoint = var.endpoint_url
  api_token = "${var.token_id}=${var.token_secret}"
  insecure = true

}

# resource "proxmox_download_file" "win2025_image" {
#   content_type = "iso"
#   datastore_id = "local"
#   node_name    = var.proxmox_node
#   url          = "https://go.microsoft.com/fwlink/?linkid=2345730&clcid=0x409&culture=en-us&country=us"
# }

resource "proxmox_virtual_environment_vm" "example" {
  name      = "SCCM01"
  vm_id = 2001
  node_name = var.proxmox_node
  description = "Managed by Terraform"
  machine     = "q35"
  bios        = "ovmf"
  started     = true

  # Always set stop_on_destroy when started = true,
  # otherwise Terraform will attempt a graceful ACPI shutdown
  # that may hang if the guest agent is not installed.
  stop_on_destroy = true

  agent {
      enabled = true
    }

  operating_system {
   type = "win11"
  }
  cpu {
    cores = 8
    type  = "host"
  }

  memory {
    dedicated = 8192
  }

  efi_disk {
    datastore_id = "nvme-thin" #var.datastore_id
    type         = "4m"
    pre_enrolled_keys = true
  }

  tpm_state {
      version = "v2.0"
    }

  serial_device {}

  cdrom {
    file_id = "local:iso/26100.32230.260111-0550.lt_release_svc_refresh_SERVER_EVAL_x64FRE_en-us.iso"
  }

  cdrom {
    file_id = "local:iso/virtio-win.iso"
  }

  disk {
    datastore_id = "nvme-thin" # var.datastore_id
    # file_id      = proxmox_download_file.win2025_image.id
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = 100
  }

  network_device {
    bridge = "vmbr0"
    vlan_id = "30"
    model = "virtio"
  }

  rng {
    source = "/dev/urandom"
    max_bytes = "2048"

  }
}
