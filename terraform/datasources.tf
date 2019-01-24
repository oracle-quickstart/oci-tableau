# Gets a list of Availability Domains
data "oci_identity_availability_domains" "ADs" {
  compartment_id = "${var.tenancy_ocid}"
}

data "template_file" "boot_script" {
  template =  "${file("../scripts/boot.sh.tpl")}"
  vars {
    tableau_version = "${var.tableau_version}"
    Username = "${var.username}"
    Password = "${var.password}"
    TableauServerAdminUser = "${var.tableau_server_admin_user}"
    TableauServerAdminPassword = "${var.tableau_server_admin_password}"
    reg_first_name = "${var.reg_first_name}"
    reg_last_name = "${var.reg_last_name}"
    reg_email = "${var.reg_email}"
    reg_company = "${var.reg_company}"
    reg_title = "${var.reg_title}"
    reg_department = "${var.reg_department}"
    reg_industry = "${var.reg_industry}"
    reg_phone = "${var.reg_phone}"
    reg_city = "${var.reg_city}"
    reg_state = "${var.reg_state}"
    reg_zip = "${var.reg_zip}"
    reg_country = "${var.reg_country}"
    AcceptEULA = "${var.accept_eula}"
    TableauServerLicenseKey = "${var.tableau_server_license_key}"
    PrivateSubnetsFQDN = "${oci_core_virtual_network.tmp_tableau_vcn.dns_label}.oraclevcn.com ${oci_core_subnet.private.*.dns_label[0]}.${oci_core_virtual_network.tmp_tableau_vcn.dns_label}.oraclevcn.com ${oci_core_subnet.private.*.dns_label[1]}.${oci_core_virtual_network.tmp_tableau_vcn.dns_label}.oraclevcn.com ${oci_core_subnet.private.*.dns_label[2]}.${oci_core_virtual_network.tmp_tableau_vcn.dns_label}.oraclevcn.com"
  }
}

data "template_file" "worker_boot_script" {
  template =  "${file("../scripts/worker_boot.sh.tpl")}"
  vars {
    tableau_version = "${var.tableau_version}"
    Username = "${var.username}"
    Password = "${var.password}"
    TableauServerAdminUser = "${var.tableau_server_admin_user}"
    TableauServerAdminPassword = "${var.tableau_server_admin_password}"
    TableauPrimaryNodePrivateIP = "${oci_core_instance.tableau_server.*.private_ip[0]}"
    PrivateSubnetsFQDN = "${oci_core_virtual_network.tmp_tableau_vcn.dns_label}.oraclevcn.com ${oci_core_subnet.private.*.dns_label[0]}.${oci_core_virtual_network.tmp_tableau_vcn.dns_label}.oraclevcn.com ${oci_core_subnet.private.*.dns_label[1]}.${oci_core_virtual_network.tmp_tableau_vcn.dns_label}.oraclevcn.com ${oci_core_subnet.private.*.dns_label[2]}.${oci_core_virtual_network.tmp_tableau_vcn.dns_label}.oraclevcn.com"
  }
}


data "oci_core_vnic" "bastion_vnic" {
  vnic_id = "${lookup(data.oci_core_vnic_attachments.bastion_vnics.vnic_attachments[0],"vnic_id")}"
}


data "oci_core_vnic_attachments" "bastion_vnics" {
  compartment_id      = "${var.compartment_ocid}"
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[0],"name")}"
  instance_id         = "${oci_core_instance.bastion.*.id[0]}"
}

