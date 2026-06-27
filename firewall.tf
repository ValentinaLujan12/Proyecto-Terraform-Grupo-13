# REGLAS DE FIREWALL

resource "google_compute_firewall" "allow_lb_and_health_check" {
  name = "allow-lb-and-health-check"
  network = google_compute_network.vpc.name
  description = "Permite que el LB y los health checkers de GCP accedan a los backends en el puerto 80."

  allow {
    protocol = "tcp"
    ports = ["80"]
  }

  # Rangos del Load Balancer y Health Checker de GCP
  source_ranges = [
    "130.211.0.0/22", # Google Cloud Load Balancing
    "35.191.0.0/16", # Google Cloud Health Checking
  ]

  target_tags = ["web-server"]
}
