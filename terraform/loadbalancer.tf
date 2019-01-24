


/* Load Balancer */

resource "oci_load_balancer" "tableau_lb" {
  shape          = "100Mbps"
  compartment_id = "${var.compartment_ocid}"

  subnet_ids = [
    "${oci_core_subnet.public.*.id[0]}",
    "${oci_core_subnet.public.*.id[1]}",
  ]

  display_name = "tableau_lb"
}

resource "oci_load_balancer_backend_set" "lb_bes1" {
  name             = "lb_bes1"
  load_balancer_id = "${oci_load_balancer.tableau_lb.id}"
  policy           = "ROUND_ROBIN"

  health_checker {
    port                = "80"
    protocol            = "HTTP"
    response_body_regex = ".*"
    url_path            = "/"
  }
}



resource "oci_load_balancer_listener" "lb_listener1" {
  load_balancer_id         = "${oci_load_balancer.tableau_lb.id}"
  name                     = "http"
  default_backend_set_name = "${oci_load_balancer_backend_set.lb_bes1.name}"
  port                     = 80
  protocol                 = "HTTP"

  connection_configuration {
    idle_timeout_in_seconds = "2"
  }
}


resource "oci_load_balancer_backend" "lb_be1" {
  load_balancer_id = "${oci_load_balancer.tableau_lb.id}"
  backendset_name  = "${oci_load_balancer_backend_set.lb_bes1.name}"
  ip_address       = "${oci_core_instance.tableau_server.0.private_ip}"
  
  port             = 80
  backup           = false
  drain            = false
  offline          = false
  weight           = 1
}


resource "oci_load_balancer_backend" "lb_be2" {
  count = "${var.tableau_worker_count >= 1 ? 1 : 0}"
  load_balancer_id = "${oci_load_balancer.tableau_lb.id}"
  backendset_name  = "${oci_load_balancer_backend_set.lb_bes1.name}"
  ip_address       = "${element(concat(oci_core_instance.tableau_worker.*.private_ip, list("")), 0)}"

  port             = 80
  backup           = false
  drain            = false
  offline          = false
  weight           = 1
}

resource "oci_load_balancer_backend" "lb_be3" {
  count = "${var.tableau_worker_count >= 2 ? 1 : 0}"
  load_balancer_id = "${oci_load_balancer.tableau_lb.id}"
  backendset_name  = "${oci_load_balancer_backend_set.lb_bes1.name}"
  ip_address       = "${element(concat(oci_core_instance.tableau_worker.*.private_ip, list("")), 1)}"

  port             = 80
  backup           = false
  drain            = false
  offline          = false
  weight           = 1
}

/*
output "lb_public_ip" {
  value = ["${oci_load_balancer.tableau_lb.ip_addresses}"]
}
*/



