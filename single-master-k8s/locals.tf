locals {
  cloud_init_user_data = templatefile(
    "${path.module}/cloud-init/user-data.yaml",
    {
      k8sadmin_ssh_key = trimspace(tls_private_key.ic-k8slab-cluster.public_key_openssh)
    }
  )
  cloud_init_user_data_base64 = base64encode(local.cloud_init_user_data)
  ssh_key_name                = "ic-k8slab-cluster-${substr(sha1(tls_private_key.ic-k8slab-cluster.public_key_openssh), 0, 8)}"

  instance_type = {
    workers1 = "t2.small"
    workers3 = "t2.small"
    workers5 = "t2.small"
    masters1 = "t2.medium"
  }

  masters = {
    masters1 = [
      "master1"
    ]
  }

  workers = {
    workers1 = [
      "worker1"
    ]
    workers3 = [
      "worker1",
      "worker2",
      "worker3"
    ]

    workers5 = [
      "worker1",
      "worker2",
      "worker3",
      "worker4",
      "worker5"
    ]
  } 
}
