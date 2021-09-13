provider "google" {
  project     = var.project_id
  region      = var.region
}

module "vpc" {
    source  = "terraform-google-modules/network/google"
    version = "~> 3.0"

    project_id   = var.project_id
    network_name = "terraform-gcp-sample-network"
    routing_mode = "GLOBAL"

    subnets = [
        {
            subnet_name           = "subnet-01"
            subnet_ip             = "10.10.10.0/24"
            subnet_region         = "us-west1"
        },
        {
            subnet_name           = "subnet-02"
            subnet_ip             = "10.10.20.0/24"
            subnet_region         = "us-west1"
            subnet_private_access = "true"
            subnet_flow_logs      = "true"
            description           = "This subnet has a description"
        },
        {
            subnet_name               = "subnet-03"
            subnet_ip                 = "10.10.30.0/24"
            subnet_region             = "us-west1"
            subnet_flow_logs          = "true"
            subnet_flow_logs_interval = "INTERVAL_10_MIN"
            subnet_flow_logs_sampling = 0.7
            subnet_flow_logs_metadata = "INCLUDE_ALL_METADATA"
        },
        {
            subnet_name           = "subnet-04"
            subnet_ip             = "10.10.40.0/24"
            subnet_region         = var.region
        }
    ]    

    routes = [
        {
            name                   = "egress-internet"
            description            = "route through IGW to access internet"
            destination_range      = "0.0.0.0/0"
            tags                   = "egress-inet"
            next_hop_internet      = "true"
        }
    ]
}

resource "google_compute_firewall" "iap_firewall_rule" {
      priority = 900
      name = "allow-ingress-from-iap"
      source_ranges = [ "35.235.240.0/20"]
      network = module.vpc.network_id
      allow {
        protocol = "tcp"
        ports = ["22"]
      }
      target_tags = ["iap-rule"]
      depends_on = [module.vpc]
}

resource "google_compute_firewall" "web_firewall_rule" {
  priority = 900
  name = "allow-ingress-from-web"
  source_ranges = [ "0.0.0.0/0"]
  network = module.vpc.network_id
  allow {
    protocol = "tcp"
    ports = ["80"]
  }
  target_tags = ["web"]
  depends_on = [module.vpc]
}

resource "google_compute_instance" "demo" {
  name         = "demo-instance"
  zone         = var.zone
  machine_type = "f1-micro"
  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1804-lts"
    }
  }

  network_interface {
    subnetwork = module.vpc.subnets["${var.region}/subnet-04"].name
    access_config {}
  }

  tags = ["iap-rule", "web"]

  metadata_startup_script = <<SCRIPT
  #!/bin/bash
  sudo apt-get update -y
  sudo apt-get install nginx -y
  sudo systemctl enable nginx
  sudo systemctl start nginx
  SCRIPT

  depends_on = [
    google_compute_firewall.iap_firewall_rule,
    google_compute_firewall.web_firewall_rule,
    module.vpc
  ]
}
