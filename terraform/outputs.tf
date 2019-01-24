



output "Compute Instance Shapes " {
value = <<END

Bastion Node Shape: ${var.instance_shape}
Tableau Primary Node Shape: ${var.tableau_server_shape}
Tableau Worker Node Shape: ${var.tableau_worker_shape}

END
}


output "Tableau Server version: " {
value = <<END
 ${var.tableau_version}

END
}


output "Bastion server  SSH login " {
value = <<END
        ssh -i ~/.ssh/id_rsa ${var.ssh_user}@${oci_core_instance.bastion.*.public_ip[0]}

END
}


output "Tableau Server Primary  SSH login " {
value = <<END
        ssh -i ${var.ssh_private_key_path}  -o BatchMode=yes -o StrictHostkeyChecking=no  -o ProxyCommand="ssh -i /home/${var.ssh_user}/.ssh/id_rsa  -o BatchMode=yes -o StrictHostkeyChecking=no ${var.ssh_user}@${oci_core_instance.bastion.*.public_ip[0]} -W %h:%p %r" ${var.ssh_user}@${oci_core_instance.tableau_server.*.private_ip[0]}

END
}


output "tableau-worker-1  SSH login " {
value = <<END
        ${var.tableau_worker_count >= 1 ? "ssh -i ${var.ssh_private_key_path}  -o BatchMode=yes -o StrictHostkeyChecking=no  -o ProxyCommand=\"ssh -i /home/${var.ssh_user}/.ssh/id_rsa  -o BatchMode=yes -o StrictHostkeyChecking=no ${var.ssh_user}@${oci_core_instance.bastion.*.public_ip[0]} -W %h:%p %r\" ${var.ssh_user}@${element(concat(oci_core_instance.tableau_worker.*.private_ip, list("")), 0)}"  : "Not Applicable (for cluster of less than 3 nodes"}

END
}


output "tableau_worker-2  SSH login " {
value = <<END
        ${var.tableau_worker_count >= 2 ? "ssh -i ${var.ssh_private_key_path}  -o BatchMode=yes -o StrictHostkeyChecking=no  -o ProxyCommand=\"ssh -i /home/${var.ssh_user}/.ssh/id_rsa  -o BatchMode=yes -o StrictHostkeyChecking=no ${var.ssh_user}@${oci_core_instance.bastion.*.public_ip[0]} -W %h:%p %r\"  ${var.ssh_user}@${element(concat(oci_core_instance.tableau_worker.*.private_ip, list("")), 1)}"  : "Not Applicable (for cluster of less than 3 nodes"}    

END
}

output "Tableau UI " { 
value = <<END
        http://${oci_load_balancer.tableau_lb.ip_addresses[0]}/
Credentials - username: ${var.tableau_server_admin_user} / password: ${var.tableau_server_admin_password}

END
}



output "Tableau Services Manager UI " { 
value = <<END
        https://${oci_core_instance.tableau_server.*.private_ip[0]}:8850/
Credentials - username: ${var.username} / password: ${var.password} 

END
}



