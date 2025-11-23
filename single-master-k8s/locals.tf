locals {

  instance_type = {
    workers1 = "t2.micro"
    workers3 = "t2.micro"
    workers5 = "t2.micro"
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
