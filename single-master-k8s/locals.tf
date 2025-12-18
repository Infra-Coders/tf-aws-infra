locals {
  cloud_init_user_data = templatefile(
    "${path.module}/cloud-init/user-data.yaml",
    {
      k8sadmin_ssh_key = trimspace(aws_key_pair.ic-k8slab.public_key)
    }
  )
  cloud_init_user_data_base64 = base64encode(local.cloud_init_user_data)

  instance_type = {
    workers1 = "t3.small"
    workers3 = "t3.small"
    workers5 = "t3.micro"
    masters1 = "t3.small"
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
