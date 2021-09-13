output "ip" {
  value = google_compute_instance.demo.network_interface.0.access_config.0.nat_ip
}

// output "subnets" {
//   value = module.vpc.subnets["${var.region}/subnet-04"].name
// }

