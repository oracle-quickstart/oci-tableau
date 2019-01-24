###
## Variables.tf for Terraform
###

variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key_path" {}
variable "region" { default = "us-phoenix-1" }

variable "compartment_ocid" {}
variable "ssh_public_key" {}
variable "ssh_private_key" {}

variable "ssh_private_key_path" {}

# For instances created using Oracle Linux and CentOS images, the user name opc is created automatically.
# For instances created using the Ubuntu image, the user name ubuntu is created automatically.
# The ubuntu user has sudo privileges and is configured for remote access over the SSH v2 protocol using RSA keys. The SSH public keys that you specify while creating instances are added to the /home/ubuntu/.ssh/authorized_keys file.
# For more details: https://docs.cloud.oracle.com/iaas/Content/Compute/References/images.htm#one
variable "ssh_user" { default = "opc" }
# For Ubuntu images,  set to ubuntu. 
# variable "ssh_user" { default = "ubuntu" }


variable "VPC-CIDR" { default = "10.0.0.0/16" }

/*
variable "InstanceImageOCID" {
    type = "map"
    default = {
        // See https://docs.us-phoenix-1.oraclecloud.com/images/ or https://docs.cloud.oracle.com/iaas/images/
        // Oracle-provided image "Canonical-Ubuntu-18.04-2018.12.10-0"
        eu-frankfurt-1 = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaaqmvdglh5hmonugj5i6w754r3hxbrsxk4luwe6u5ulyyyn4aha2gq"
        us-ashburn-1 = "ocid1.image.oc1.iad.aaaaaaaahh6wjs5qp2sieliieujdnih7eyxt32ets3nuiifzjjfkqnbelcra"
        uk-london-1 = "ocid1.image.oc1.uk-london-1.aaaaaaaasmb4dxiv4p6mpfohuiijs3gxkgtafbng7octzvj7aaebiayx5fca"
        us-phoenix-1 = "ocid1.image.oc1.phx.aaaaaaaahuvwlhrckaqyjgntvbjhlunzbv4zwsy6zvczknkstwa4tj3pzmuq"
    }
}
*/

variable "InstanceImageOCID" {
    type = "map"
    default = {
        // See https://docs.us-phoenix-1.oraclecloud.com/images/ or https://docs.cloud.oracle.com/iaas/images/
        // Oracle-provided image "CentOS-7-2018.08.15-0"
	eu-frankfurt-1 = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaatz6zixwltzswnmzi2qxdjcab6nw47xne4tco34kn6hltzdppmada" 
	us-ashburn-1 = "ocid1.image.oc1.iad.aaaaaaaah6ui3hcaq7d43esyrfmyqb3mwuzn4uoxjlbbdwoiicdmntlvwpda"
	uk-london-1 = "ocid1.image.oc1.uk-london-1.aaaaaaaai3czrt22cbu5uytpci55rcy4mpi4j7wm46iy5wdieqkestxve4yq"
	us-phoenix-1 = "ocid1.image.oc1.phx.aaaaaaaarbacra7juwrie5idcadtgbj3llxcu7p26rj4t3xujyqwwopy2wva"
    }
}


# Compute Instance counts
# Bastion server count.  1 should be enough
variable "bastion_server_count" { default = "1" }
# Tableau primary server count. Should be 1 only
variable "tableau_server_count" { default = "1" }
# Tableau worker server count (additional nodes). For High availability, this should be set to 2, so there is total of 3 nodes.   If set to 0, a single node Tableau will be deployed.   
variable "tableau_worker_count" { default = "0" }

# instance shapes
variable "bastion_server_shape" { default = "VM.Standard2.1" }
# Tableau primary server shape
variable "tableau_server_shape" { default = "VM.Standard2.8" }
# Tableau worker server shape
variable "tableau_worker_shape" { default = "VM.Standard2.8" }
# To use faster local NVMe,  use one of the VM.DenseIO2.x, BM.DenseIO2.x shapes, example: VM.DenseIO2.8 }


# size in GiB for tableau data on all nodes.  1 block storage volume per node.
variable "data_volume_size" { default = "100" }

# Tableau specific config
variable "tableau_version" { default = "2018.3.0" }
variable "username" { default = "qsadmin" }
variable "password" { default = "alfred_genpass_32" }
variable "tableau_server_admin_user" { default = "admin" }
variable "tableau_server_admin_password" { default = "alfred_genpass_32" }
variable "reg_first_name" { default = "Test First Name" }
variable "reg_last_name" { default = "Test Last Name" }
variable "reg_email" { default = "testemail@example.com" }
variable "reg_company" { default = "Test Company" }
variable "reg_title" { default = "Test Title" }
variable "reg_department" { default = "Test Department" }
variable "reg_industry" { default = "Test Industry" }
variable "reg_phone" { default = "Test Phone" }
variable "reg_city" { default = "Test City" }
variable "reg_state" { default = "Test State" }
variable "reg_zip" { default = "Test Zip" }
variable "reg_country" { default = "Test Country" }
variable "accept_eula" { default = "Yes" }
variable "tableau_server_license_key" { default = "" }



# For Oracle Databases which needs Credentials Wallet zip to authenticate instead of just username/password/sid/servicename. Example ATP, ADW, etc.
# valid values: full/absolute file path: example: /home/opc/Wallet_ADW.zip
variable "oracle_credentials_wallet_zip_path" { default = "" }


variable "instance_shape" {
  default = "VM.Standard2.1"
}

