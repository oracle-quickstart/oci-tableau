/*
 * Primary or Master Tableau Server
*/
resource "oci_core_instance" "tableau_server" {
  count		      = "${var.tableau_server_count}"
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[count.index%3],"name")}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "Tableau Server ${format("%01d", count.index+1)}"
  hostname_label      = "Tableau-Server-${format("%01d", count.index+1)}"
  shape               = "${var.tableau_server_shape}"
  subnet_id           = "${oci_core_subnet.private.*.id[count.index%3]}"

  source_details {
    source_type = "image"
    source_id = "${var.InstanceImageOCID[var.region]}"
    #boot_volume_size_in_gbs = "${var.boot_volume_size}"
  }

  metadata {
    ssh_authorized_keys = "${var.ssh_public_key}"
    user_data = "${base64encode(data.template_file.boot_script.rendered)}"
  }

  timeouts {
    create = "60m"
  }

}

/*
 * Worker or Additional Tableau nodes
*/
resource "oci_core_instance" "tableau_worker" {
  depends_on = ["oci_core_instance.tableau_server", "null_resource.tableau-primary-setup-complete-status"]
  count               = "${var.tableau_worker_count}"
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[(count.index%3)+1],"name")}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "Tableau Worker ${format("%01d", count.index+1)}"
  hostname_label      = "Tableau-Worker-${format("%01d", count.index+1)}"
  shape               = "${var.tableau_worker_shape}"
  subnet_id           = "${oci_core_subnet.private.*.id[(count.index%3)+1]}"

  source_details {
    source_type = "image"
    source_id = "${var.InstanceImageOCID[var.region]}"
    #boot_volume_size_in_gbs = "${var.boot_volume_size}"
  }

  metadata {
    ssh_authorized_keys = "${var.ssh_public_key}"
    user_data = "${base64encode(data.template_file.worker_boot_script.rendered)}"
  }

  timeouts {
    create = "60m"
  }

}


###
### Block Volumes for Master & Worker Nodes - used to store Tableau Data & extracts, etc. 
###

resource "oci_core_volume" "tableau_server_volume1" {
  count="${var.tableau_server_count}"
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[count.index%3],"name")}"
  compartment_id = "${var.compartment_ocid}"
  display_name = "Tableau Server ${format("%01d", count.index+1)} Volume 1"
  size_in_gbs = "${var.data_volume_size}"
}

resource "oci_core_volume_attachment" "tableau_server_attachment1" {
  count="${var.tableau_server_count}"
  attachment_type = "iscsi"
  compartment_id = "${var.compartment_ocid}"
  instance_id = "${oci_core_instance.tableau_server.*.id[count.index]}"
  volume_id = "${oci_core_volume.tableau_server_volume1.*.id[count.index]}"
}



resource "oci_core_volume" "tableau_worker_volume1" {
  count="${var.tableau_worker_count}"
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[(count.index%3)+1],"name")}"
  compartment_id = "${var.compartment_ocid}"
  display_name = "Tableau Worker ${format("%01d", count.index+1)} Volume 1"
  size_in_gbs = "${var.data_volume_size}"
}

resource "oci_core_volume_attachment" "tableau_worker_attachment1" {
  count="${var.tableau_worker_count}"
  attachment_type = "iscsi"
  compartment_id = "${var.compartment_ocid}"
  instance_id = "${oci_core_instance.tableau_worker.*.id[count.index]}"
  volume_id = "${oci_core_volume.tableau_worker_volume1.*.id[count.index]}"
}


/*
Resource to check if the user_data/cloud-init script on tableau-server-1 was successfully completed. 
*/
resource "null_resource" "tableau-primary-setup-complete-status" {
    depends_on = ["oci_core_instance.tableau_server" ]
    
    triggers {
      cluster_instance_ids = "${join(",", oci_core_instance.tableau_server.*.id)}"
    }

    provisioner "file" {
      source = "${var.ssh_private_key_path}"
      destination = "/home/${var.ssh_user}/.ssh/id_rsa"
      connection {
        agent = false
        timeout = "10m"
        host = "${data.oci_core_vnic.bastion_vnic.public_ip_address}"
        user = "${var.ssh_user}"
        private_key = "${var.ssh_private_key}"
      }
    }

    provisioner "file" {
      source = "../scripts/tableau-nodes-setup-complete-status-check.sh"
      destination = "/tmp/tableau-nodes-setup-complete-status-check.sh"
      connection {
        agent = false
        timeout = "10m"
        host = "${data.oci_core_vnic.bastion_vnic.public_ip_address}"
        user = "${var.ssh_user}"
        private_key = "${var.ssh_private_key}"
      }
    } 

    provisioner "remote-exec" {
      connection {
        agent = false
        timeout = "10m"
        host = "${data.oci_core_vnic.bastion_vnic.public_ip_address}"
        user = "${var.ssh_user}"
        private_key = "${var.ssh_private_key}"
      }
      inline = [
        "set -x",        
        "chown ${var.ssh_user}:${var.ssh_user} /home/${var.ssh_user}/.ssh/id_rsa",
        "chmod 0600 /home/${var.ssh_user}/.ssh/id_rsa",
        "sleep 90s",
        "scp -o BatchMode=yes -o StrictHostkeyChecking=no -i /home/${var.ssh_user}/.ssh/id_rsa /tmp/tableau-nodes-setup-complete-status-check.sh ${var.ssh_user}@${oci_core_instance.tableau_server.*.private_ip[0]}:/tmp/tableau-nodes-setup-complete-status-check.sh",
        "ssh -i /home/${var.ssh_user}/.ssh/id_rsa -o BatchMode=yes -o StrictHostKeyChecking=no ${var.ssh_user}@${oci_core_instance.tableau_server.*.private_ip[0]} sudo chmod 777 /tmp/tableau-nodes-setup-complete-status-check.sh",
        "ssh -i /home/${var.ssh_user}/.ssh/id_rsa -o BatchMode=yes -o StrictHostKeyChecking=no ${var.ssh_user}@${oci_core_instance.tableau_server.*.private_ip[0]} sudo su -l root -c \"/tmp/tableau-nodes-setup-complete-status-check.sh\" "
      ]
    }
}


/*
Resource to check if the user_data/cloud-init script on tableau-worker-1 was successfully completed.
*/
resource "null_resource" "tableau-worker-1-setup-complete-status" {
    depends_on = ["oci_core_instance.tableau_worker" ]
    count = "${var.tableau_worker_count >= 1 ? 1 : 0}"
    triggers {
      worker_1_instance_ids = "${element(concat(oci_core_instance.tableau_worker.*.id, list("")), 0)}"
    }

    provisioner "remote-exec" {
      connection {
        agent = false
        timeout = "10m"
        host = "${data.oci_core_vnic.bastion_vnic.public_ip_address}"
        user = "${var.ssh_user}"
        private_key = "${var.ssh_private_key}"
      }
      inline = [
        "set -x",
        "chown ${var.ssh_user}:${var.ssh_user} /home/${var.ssh_user}/.ssh/id_rsa",
        "chmod 0600 /home/${var.ssh_user}/.ssh/id_rsa",
        "sleep 90s",
        "scp -o BatchMode=yes -o StrictHostkeyChecking=no -i /home/${var.ssh_user}/.ssh/id_rsa /tmp/tableau-nodes-setup-complete-status-check.sh ${var.ssh_user}@${element(concat(oci_core_instance.tableau_worker.*.private_ip, list("")), 0)}:/tmp/tableau-nodes-setup-complete-status-check.sh",
        "ssh -i /home/${var.ssh_user}/.ssh/id_rsa -o BatchMode=yes -o StrictHostKeyChecking=no ${var.ssh_user}@${element(concat(oci_core_instance.tableau_worker.*.private_ip, list("")), 0)} sudo chmod 777 /tmp/tableau-nodes-setup-complete-status-check.sh",
        "ssh -i /home/${var.ssh_user}/.ssh/id_rsa -o BatchMode=yes -o StrictHostKeyChecking=no ${var.ssh_user}@${element(concat(oci_core_instance.tableau_worker.*.private_ip, list("")), 0)} sudo su -l root -c \"/tmp/tableau-nodes-setup-complete-status-check.sh\" "
      ]
    }
}


/*
Resource to check if the cloud-init script on tableau-worker-2 was successfully completed.
*/
resource "null_resource" "tableau-worker-2-setup-complete-status" {
    depends_on = ["oci_core_instance.tableau_worker","null_resource.tableau-worker-1-setup-complete-status" ]
    count = "${var.tableau_worker_count >=2 ? 1 : 0}"
    triggers {
      worker_2_instance_ids = "${element(concat(oci_core_instance.tableau_worker.*.id, list("")), 1)}"
    }

    provisioner "remote-exec" {
      connection {
        agent = false
        timeout = "10m"
        host = "${data.oci_core_vnic.bastion_vnic.public_ip_address}"
        user = "${var.ssh_user}"
        private_key = "${var.ssh_private_key}"
      }
      inline = [
        "set -x",
        "chown ${var.ssh_user}:${var.ssh_user} /home/${var.ssh_user}/.ssh/id_rsa",
        "chmod 0600 /home/${var.ssh_user}/.ssh/id_rsa",
        "sleep 90s",
        "scp -o BatchMode=yes -o StrictHostkeyChecking=no -i /home/${var.ssh_user}/.ssh/id_rsa /tmp/tableau-nodes-setup-complete-status-check.sh ${var.ssh_user}@${element(concat(oci_core_instance.tableau_worker.*.private_ip, list("")), 1)}:/tmp/tableau-nodes-setup-complete-status-check.sh",
        "ssh -i /home/${var.ssh_user}/.ssh/id_rsa -o BatchMode=yes -o StrictHostKeyChecking=no ${var.ssh_user}@${element(concat(oci_core_instance.tableau_worker.*.private_ip, list("")), 1)} sudo chmod 777 /tmp/tableau-nodes-setup-complete-status-check.sh",
        "ssh -i /home/${var.ssh_user}/.ssh/id_rsa -o BatchMode=yes -o StrictHostKeyChecking=no ${var.ssh_user}@${element(concat(oci_core_instance.tableau_worker.*.private_ip, list("")), 1)} sudo su -l root -c \"/tmp/tableau-nodes-setup-complete-status-check.sh\" "
      ]
    }
}



/*
Resource will execute after all workers nodes user_data/cloud init scripts execution is confirmed to be complete. 
*/
resource "null_resource" "tableau-start-services" {
    depends_on = ["null_resource.tableau-worker-2-setup-complete-status", "null_resource.tableau-worker-1-setup-complete-status", "null_resource.tableau-primary-setup-complete-status" ]

    # Changes to any instance of the cluster requires re-provisioning
    triggers {
      tableau_instance_ids = "${join(",", concat(oci_core_instance.tableau_worker.*.id,oci_core_instance.tableau_server.*.id))}"
    }

    provisioner "file" {
      source = "../scripts/workers.sh"
      destination = "/tmp/workers.sh"
      connection {
        agent = false
        timeout = "10m"
        host = "${data.oci_core_vnic.bastion_vnic.public_ip_address}"
        user = "${var.ssh_user}"
        private_key = "${var.ssh_private_key}"
      }
    }

    

    provisioner "remote-exec" {
      connection {
        agent = false
        timeout = "10m"
        host = "${data.oci_core_vnic.bastion_vnic.public_ip_address}"
        user = "${var.ssh_user}"
        private_key = "${var.ssh_private_key}"
      }
      inline = [
        "scp -o BatchMode=yes -o StrictHostkeyChecking=no -i /home/${var.ssh_user}/.ssh/id_rsa /tmp/workers.sh ${var.ssh_user}@${oci_core_instance.tableau_server.*.private_ip[0]}:/tmp/workers.sh",
        "ssh -o BatchMode=yes -o StrictHostKeyChecking=no -i /home/${var.ssh_user}/.ssh/id_rsa ${var.ssh_user}@${oci_core_instance.tableau_server.*.private_ip[0]} sudo chmod +x /tmp/workers.sh",
        "ssh -o BatchMode=yes -o StrictHostKeyChecking=no -i /home/${var.ssh_user}/.ssh/id_rsa ${var.ssh_user}@${oci_core_instance.tableau_server.*.private_ip[0]} sudo su -l root -c \"/tmp/workers.sh\"; "
      ]
    }
}


/*
Install drivers for various data sources on primary node. Will execute after tableau services have been started.
*/
resource "null_resource" "install_drivers_primary_node" {
    depends_on = ["null_resource.tableau-start-services"]
    count = "${var.tableau_server_count}"

    triggers {
      tableau_instance_ids = "${join(",", concat(oci_core_instance.tableau_worker.*.id,oci_core_instance.tableau_server.*.id))}"
    }

    provisioner "file" {
      source = "../scripts/install_drivers.sh"
      destination = "/tmp/install_drivers.sh"
      connection {
        agent = false
        timeout = "10m"
        host = "${data.oci_core_vnic.bastion_vnic.public_ip_address}"
        user = "${var.ssh_user}"
        private_key = "${var.ssh_private_key}"
      }
    }
    provisioner "file" {
      source = "${var.oracle_credentials_wallet_zip_path}"
      destination = "/tmp/oracle_credentials_wallet.zip"
      connection {
        agent = false
        timeout = "10m"
        host = "${data.oci_core_vnic.bastion_vnic.public_ip_address}"
        user = "${var.ssh_user}"
        private_key = "${var.ssh_private_key}"
      }
    }
    provisioner "remote-exec" {
      connection {
        agent = false
        timeout = "10m"
        host = "${data.oci_core_vnic.bastion_vnic.public_ip_address}"
        user = "${var.ssh_user}"
        private_key = "${var.ssh_private_key}"
      }
      inline = [
        "echo server-${count.index+1}",
        "scp -o BatchMode=yes -o StrictHostkeyChecking=no -i /home/${var.ssh_user}/.ssh/id_rsa /tmp/install_drivers.sh ${var.ssh_user}@${oci_core_instance.tableau_server.*.private_ip[0]}:/tmp/install_drivers.sh",
        "ssh -o BatchMode=yes -o StrictHostKeyChecking=no -i /home/${var.ssh_user}/.ssh/id_rsa ${var.ssh_user}@${oci_core_instance.tableau_server.*.private_ip[0]} sudo chmod +x /tmp/install_drivers.sh",
        "scp -o BatchMode=yes -o StrictHostkeyChecking=no -i /home/${var.ssh_user}/.ssh/id_rsa /tmp/oracle_credentials_wallet.zip ${var.ssh_user}@${oci_core_instance.tableau_server.*.private_ip[0]}:/tmp/oracle_credentials_wallet.zip",
        "ssh -o BatchMode=yes -o StrictHostKeyChecking=no -i /home/${var.ssh_user}/.ssh/id_rsa ${var.ssh_user}@${oci_core_instance.tableau_server.*.private_ip[0]} sudo su -l root -c \"/tmp/install_drivers.sh\"; "
      ]
    }
}

/*
Install drivers for various data sources on worker nodes. Will execute after tableau services have been started.
*/
resource "null_resource" "install_drivers_worker_nodes" {
    depends_on = ["null_resource.tableau-start-services", "null_resource.install_drivers_primary_node"]
    count = "${var.tableau_worker_count}"
    
    triggers {
      tableau_instance_ids = "${join(",", concat(oci_core_instance.tableau_worker.*.id,oci_core_instance.tableau_server.*.id))}"
    }

    provisioner "file" {
      source = "../scripts/install_drivers.sh"
      destination = "/tmp/install_drivers.sh"
      connection {
        agent = false
        timeout = "10m"
        host = "${data.oci_core_vnic.bastion_vnic.public_ip_address}"
        user = "${var.ssh_user}"
        private_key = "${var.ssh_private_key}"
      }
    }
    provisioner "file" {
      source = "${var.oracle_credentials_wallet_zip_path}"
      destination = "/tmp/oracle_credentials_wallet.zip"
      connection {
        agent = false
        timeout = "10m"
        host = "${data.oci_core_vnic.bastion_vnic.public_ip_address}"
        user = "${var.ssh_user}"
        private_key = "${var.ssh_private_key}"
      }
    }
    provisioner "remote-exec" {
      connection {
        agent = false
        timeout = "10m"
        host = "${data.oci_core_vnic.bastion_vnic.public_ip_address}"
        user = "${var.ssh_user}"
        private_key = "${var.ssh_private_key}"
      }
      inline = [
        "echo worker-${count.index+1}",
        "scp -o BatchMode=yes -o StrictHostkeyChecking=no -i /home/${var.ssh_user}/.ssh/id_rsa /tmp/install_drivers.sh ${var.ssh_user}@${element(concat(oci_core_instance.tableau_worker.*.private_ip, list("")), count.index)}:/tmp/install_drivers.sh",
        "ssh -o BatchMode=yes -o StrictHostKeyChecking=no -i /home/${var.ssh_user}/.ssh/id_rsa ${var.ssh_user}@${element(concat(oci_core_instance.tableau_worker.*.private_ip, list("")), count.index)} sudo chmod +x /tmp/install_drivers.sh",
        "scp -o BatchMode=yes -o StrictHostkeyChecking=no -i /home/${var.ssh_user}/.ssh/id_rsa /tmp/oracle_credentials_wallet.zip ${var.ssh_user}@${element(concat(oci_core_instance.tableau_worker.*.private_ip, list("")), count.index)}:/tmp/oracle_credentials_wallet.zip",
        "ssh -o BatchMode=yes -o StrictHostKeyChecking=no -i /home/${var.ssh_user}/.ssh/id_rsa ${var.ssh_user}@${element(concat(oci_core_instance.tableau_worker.*.private_ip, list("")), count.index)} sudo su -l root -c \"/tmp/install_drivers.sh\" "
      ]
    }
}


/* bastion instances */

resource "oci_core_instance" "bastion" {
  count = "${var.bastion_server_count}"
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[count.index%3],"name")}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "bastion ${format("%01d", count.index+1)}"
  shape               = "${var.bastion_server_shape}"
  hostname_label      = "bastion-${format("%01d", count.index+1)}"

  create_vnic_details {
    subnet_id              = "${oci_core_subnet.public.*.id[count.index%3]}"
    skip_source_dest_check = true
  }

  metadata {
    ssh_authorized_keys = "${var.ssh_public_key}"
  }


  source_details {
    source_type = "image"
    source_id   = "${var.InstanceImageOCID[var.region]}"
  }
}



