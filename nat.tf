# CLOUD NAT 
# Para que las VMs sin IP externa descarguen paquetes (nginx)

resource "google_compute_router" "nat_router" {
  name = "lb-nat-router"
  region = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat_config" {
  name = "lb-nat-config"
  router = google_compute_router.nat_router.name
  region = var.region
  nat_ip_allocate_option = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = false
    filter = "ERRORS_ONLY"
  }
}
