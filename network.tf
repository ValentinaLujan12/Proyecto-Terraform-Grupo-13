# RED
# VPC y subred

resource "google_compute_network" "vpc" {
  name = "lb-vpc"
  auto_create_subnetworks = false
  description = "VPC dedicada al proyecto de load balancing con control de tráfico."

  depends_on = [google_project_service.compute]
}

resource "google_compute_subnetwork" "subnet" {
  name = "lb-subnet"
  ip_cidr_range = "10.10.0.0/24"
  region = var.region
  network = google_compute_network.vpc.id
  description = "Subred privada donde residen las VMs de backend (sin IPs externas)."
}
