project_id = "proyecto-terraform-500702"

region = "us-central1"
zone_main = "us-central1-a"
zone_contingency = "us-central1-b"
machine_type = "e2-micro"

# ESCENARIO ACTIVO: 
# Escenario 1 – Producción total: main=100, contingency=0
# Escenario 2 – Mantenimiento total: main=0, contingency=100
# Escenario 3 – Balanceo 50/50: main=50, contingency=50

main_traffic_weight = 100
contingency_traffic_weight = 0
