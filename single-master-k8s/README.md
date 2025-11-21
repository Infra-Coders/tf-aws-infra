# tf-aws-infra

### Useful links
#### K8s
[install kubeadm](https://v1-32.docs.kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)<br>
[cri](https://v1-32.docs.kubernetes.io/docs/concepts/architecture/cri/)<br>
[cri-o](https://cri-o.io/)<br>
[create k8s using kubeadm](https://v1-32.docs.kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/)<br>
[create HA k8s](https://v1-32.docs.kubernetes.io/docs/setup/production-environment/tools/kubeadm/high-availability/)<br>
[kubelet customization](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/kubelet-integration/)<br>
#### Tiger Operator, Callico
[callico install](https://docs.tigera.io/calico/latest/getting-started/kubernetes/k8s-single-node)<br>
[callico customize](https://docs.tigera.io/calico/latest/getting-started/kubernetes/self-managed-onprem/config-options)<br>
#### AWS VPC CNI
[amazon-vpc-cni-k8s](https://github.com/aws/amazon-vpc-cni-k8s)
#### Flux
[flux](https://spacelift.io/blog/fluxcd)<br>
[flux install](https://fluxcd.io/flux/installation/)<br>

### AWS connection

> Note: Check your AWS credentials & update provdider.tf
```
> cat ~/.aws/credentials
> aws configure --profile <your_profile>
AWS Access Key ID [****************PTVK]:              
AWS Secret Access Key [****************deH7]: 
Default region name [eu-central-1]: 
Default output format [json]: 
```

> Note: Check connection to AWS, using your AWS account
[amifind.sh](https://gist.github.com/vancluever/7676b4dafa97826ef0e9)
```
> aws ec2 describe-images --filters Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-* --query 'Images[*].[ImageId,CreationDate]'  --output text
ami-0035bcf5147a7448d   2024-08-23T10:35:44.000Z
ami-004e960cde33f9146   2025-10-22T10:49:57.000Z
ami-0046197d856fdeb85   2024-08-09T10:47:04.000Z
ami-0083ee179c14acc6a   2025-06-27T10:40:54.000Z
ami-00d729014c64a6011   2024-08-07T14:40:36.000Z
ami-014dd8ec7f09293e6   2025-05-30T10:40:19.000Z
ami-016157bda71793fa4   2025-05-03T11:14:10.000Z
ami-01c3b1577536650a5   2025-08-21T19:01:22.000Z
ami-01ad4913168550728   2025-09-20T10:57:07.000Z
ami-02003f9f0fde924ea   2025-06-10T10:42:30.000Z
ami-02c70beba709cc62b   2024-07-24T13:31:11.000Z
[...]
```

### Provisioning Infra

> Note: Terraform INIT
```
> terraform init

Initializing the backend...

Initializing provider plugins...
- Reusing previous version of hashicorp/aws from the dependency lock file
- Reusing previous version of hashicorp/template from the dependency lock file
- Installing hashicorp/aws v6.21.0...
- Installed hashicorp/aws v6.21.0 (signed by HashiCorp)
- Installing hashicorp/template v2.2.0...
- Installed hashicorp/template v2.2.0 (signed by HashiCorp)

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
```

> Note: Terraform PLAN
```
> terraform plan
aws_vpc.ic-k8slab: Refreshing state... [id=vpc-090392cc5eb7cbc07]
aws_key_pair.ic-k8slab-cluster: Refreshing state... [id=ic-k8slab-cluster]
aws_internet_gateway.ic-k8slab-igw: Refreshing state... [id=igw-08cd886945397acd4]
aws_route_table.ic-k8slab-route-table: Refreshing state... [id=rtb-028ad686c77788574]
aws_subnet.ic-k8slab-1c: Refreshing state... [id=subnet-07e28846b9a845fdb]
aws_subnet.ic-k8slab-1a: Refreshing state... [id=subnet-060577de26e6e1323]
aws_subnet.ic-k8slab-1b: Refreshing state... [id=subnet-0bc46161f1e90b476]
aws_route.ic-k8slab-route: Refreshing state... [id=r-rtb-028ad686c777885741080289494]
aws_route_table_association.ic-k8slab-1c-association: Refreshing state... [id=rtbassoc-06f4b57d0a0a18f70]
aws_route_table_association.ic-k8slab-1a-association: Refreshing state... [id=rtbassoc-084df43b6971a568c]
aws_security_group.ic-k8slab-sg: Refreshing state... [id=sg-088c3c460ea53edc3]
aws_route_table_association.ic-k8slab-1b-association: Refreshing state... [id=rtbassoc-03b4a61866c25b738]
aws_instance.k8s-master["master1"]: Refreshing state... [id=i-097c3c3334878bf5e]
aws_instance.k8s-worker["worker1"]: Refreshing state... [id=i-0b232f6c0a2c4d368]

Note: Objects have changed outside of Terraform
[...]
```

> Note: Terraform APPLY
```
> terraform apply

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # aws_instance.k8s-master["master1"] will be created
  + resource "aws_instance" "k8s-master" {
      + ami                                  = "ami-0ccb7fb77fc31decd"
      + arn                                  = (known after apply)
      + associate_public_ip_address          = true
      + availability_zone                    = (known after apply)
      + disable_api_stop                     = (known after apply)
      + disable_api_termination              = (known after apply)
      + ebs_optimized                        = (known after apply)
      + enable_primary_ipv6                  = (known after apply)
      + force_destroy                        = false
      + get_password_data                    = false
      + host_id                              = (known after apply)

[...]

Plan: 14 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + master_private_dns = {
      + master1 = (known after apply)
    }
  + master_public_ip   = {
      + master1 = (known after apply)
    }
  + worker_private_dns = {
      + worker1 = (known after apply)
    }
  + worker_public_ip   = {
      + worker1 = (known after apply)
    }

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes
```
### BOOTSTRAP KUBE

> Note: BOOTSTRAP Kube
```
> ./scripts/BOOTSTRAP_KUBE.sh
--------------------------------------------------------------------------------
STAGE: NODE_BOOTSTRAP
NODE_BOOTSTRAP node=3.75.222.143
NODE_BOOTSTRAP node=18.193.71.203
NODE_BOOTSTRAP node=18.199.85.73
NODE_BOOTSTRAP node=3.67.133.90
Warning: Permanently added '3.75.222.143' (ED25519) to the list of known hosts.
ip-10-0-1-29 cloud-init status: DONE
ip-10-0-12-39 cloud-init status: DONE
ip-10-0-4-230 cloud-init status: DONE
ip-10-0-13-139 cloud-init status: DONE
STAGE: NODE_BOOTSTRAP success!
--------------------------------------------------------------------------------
STAGE: NODE_REBOOT
NODE_REBOOT node=3.75.222.143
NODE_REBOOT node=18.193.71.203
NODE_REBOOT node=18.199.85.73
NODE_REBOOT node=3.67.133.90
STAGE: NODE_REBOOT success!
--------------------------------------------------------------------------------
STAGE: NODE_READY
NODE_READY node=3.75.222.143
NODE_READY node=18.193.71.203
NODE_READY node=18.199.85.73
NODE_READY node=3.67.133.90
ip-10-0-1-29
ip-10-0-4-230
ip-10-0-13-139
ip-10-0-12-39
STAGE: NODE_READY success!
--------------------------------------------------------------------------------
STAGE: CONTROL_PLANE_BOOTSTRAP
CONTROL_PLANE_BOOTSTRAP node=3.75.222.143
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100    51  100    51    0     0  17671      0 --:--:-- --:--:-- --:--:-- 25500
I1122 15:36:58.024944    1041 version.go:261] remote version is much newer: v1.34.2; falling back to: stable-1.32
[init] Using Kubernetes version: v1.32.10
[preflight] Running pre-flight checks
[preflight] Pulling images required for setting up a Kubernetes cluster
[preflight] This might take a minute or two, depending on the speed of your internet connection
[preflight] You can also perform this action beforehand using 'kubeadm config images pull'
[certs] Using certificateDir folder "/etc/kubernetes/pki"
[certs] Generating "ca" certificate and key
[certs] Generating "apiserver" certificate and key
[certs] apiserver serving cert is signed for DNS names [ec2-3-75-222-143.eu-central-1.compute.amazonaws.com ip-10-0-4-230 kubernetes kubernetes.default kubernetes.default.svc kubernetes.default.svc.cluster.local] and IPs [10.96.0.1 10.0.4.230]
[certs] Generating "apiserver-kubelet-client" certificate and key
[certs] Generating "front-proxy-ca" certificate and key
[certs] Generating "front-proxy-client" certificate and key
[certs] Generating "etcd/ca" certificate and key
[certs] Generating "etcd/server" certificate and key
[certs] etcd/server serving cert is signed for DNS names [ip-10-0-4-230 localhost] and IPs [10.0.4.230 127.0.0.1 ::1]
[certs] Generating "etcd/peer" certificate and key
[certs] etcd/peer serving cert is signed for DNS names [ip-10-0-4-230 localhost] and IPs [10.0.4.230 127.0.0.1 ::1]
[certs] Generating "etcd/healthcheck-client" certificate and key
[certs] Generating "apiserver-etcd-client" certificate and key
[certs] Generating "sa" key and public key
[kubeconfig] Using kubeconfig folder "/etc/kubernetes"
[kubeconfig] Writing "admin.conf" kubeconfig file
[kubeconfig] Writing "super-admin.conf" kubeconfig file
[kubeconfig] Writing "kubelet.conf" kubeconfig file
[kubeconfig] Writing "controller-manager.conf" kubeconfig file
[kubeconfig] Writing "scheduler.conf" kubeconfig file
[etcd] Creating static Pod manifest for local etcd in "/etc/kubernetes/manifests"
[control-plane] Using manifest folder "/etc/kubernetes/manifests"
[control-plane] Creating static Pod manifest for "kube-apiserver"
[control-plane] Creating static Pod manifest for "kube-controller-manager"
[control-plane] Creating static Pod manifest for "kube-scheduler"
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Starting the kubelet

[...]

--------------------------------------------------------------------------------
STAGE: NODE_BOOTSTRAP
NODE_BOOTSTRAP node=3.75.222.143
NODE_BOOTSTRAP node=18.193.71.203
NODE_BOOTSTRAP node=18.199.85.73
NODE_BOOTSTRAP node=3.67.133.90
Warning: Permanently added '3.75.222.143' (ED25519) to the list of known hosts.
ip-10-0-1-29 cloud-init status: DONE
ip-10-0-12-39 cloud-init status: DONE
ip-10-0-4-230 cloud-init status: DONE
ip-10-0-13-139 cloud-init status: DONE
STAGE: NODE_BOOTSTRAP success!
--------------------------------------------------------------------------------
STAGE: NODE_REBOOT
NODE_REBOOT node=3.75.222.143
NODE_REBOOT node=18.193.71.203
NODE_REBOOT node=18.199.85.73
NODE_REBOOT node=3.67.133.90
STAGE: NODE_REBOOT success!
--------------------------------------------------------------------------------
STAGE: NODE_READY
NODE_READY node=3.75.222.143
NODE_READY node=18.193.71.203
NODE_READY node=18.199.85.73
NODE_READY node=3.67.133.90
ip-10-0-1-29
ip-10-0-4-230
ip-10-0-13-139
ip-10-0-12-39
STAGE: NODE_READY success!
--------------------------------------------------------------------------------
STAGE: CONTROL_PLANE_BOOTSTRAP
CONTROL_PLANE_BOOTSTRAP node=3.75.222.143
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100    51  100    51    0     0  17671      0 --:--:-- --:--:-- --:--:-- 25500
I1122 15:36:58.024944    1041 version.go:261] remote version is much newer: v1.34.2; falling back to: stable-1.32
[init] Using Kubernetes version: v1.32.10
[preflight] Running pre-flight checks
[preflight] Pulling images required for setting up a Kubernetes cluster
[preflight] This might take a minute or two, depending on the speed of your internet connection
[preflight] You can also perform this action beforehand using 'kubeadm config images pull'
[certs] Using certificateDir folder "/etc/kubernetes/pki"
[certs] Generating "ca" certificate and key
[certs] Generating "apiserver" certificate and key
[certs] apiserver serving cert is signed for DNS names [ec2-3-75-222-143.eu-central-1.compute.amazonaws.com ip-10-0-4-230 kubernetes kubernetes.default kubernetes.default.svc kubernetes.default.svc.cluster.local] and IPs [10.96.0.1 10.0.4.230]
[certs] Generating "apiserver-kubelet-client" certificate and key
[certs] Generating "front-proxy-ca" certificate and key
[certs] Generating "front-proxy-client" certificate and key
[certs] Generating "etcd/ca" certificate and key
[certs] Generating "etcd/server" certificate and key
[certs] etcd/server serving cert is signed for DNS names [ip-10-0-4-230 localhost] and IPs [10.0.4.230 127.0.0.1 ::1]
[certs] Generating "etcd/peer" certificate and key
[certs] etcd/peer serving cert is signed for DNS names [ip-10-0-4-230 localhost] and IPs [10.0.4.230 127.0.0.1 ::1]
[certs] Generating "etcd/healthcheck-client" certificate and key
[certs] Generating "apiserver-etcd-client" certificate and key
[certs] Generating "sa" key and public key
[kubeconfig] Using kubeconfig folder "/etc/kubernetes"
[kubeconfig] Writing "admin.conf" kubeconfig file
[kubeconfig] Writing "super-admin.conf" kubeconfig file
[kubeconfig] Writing "kubelet.conf" kubeconfig file
[kubeconfig] Writing "controller-manager.conf" kubeconfig file
[kubeconfig] Writing "scheduler.conf" kubeconfig file
[etcd] Creating static Pod manifest for local etcd in "/etc/kubernetes/manifests"
[control-plane] Using manifest folder "/etc/kubernetes/manifests"
[control-plane] Creating static Pod manifest for "kube-apiserver"
[control-plane] Creating static Pod manifest for "kube-controller-manager"
[control-plane] Creating static Pod manifest for "kube-scheduler"
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Starting the kubelet

[...]

STAGE: DATA_PLANE_BOOTSTRAP success!
--------------------------------------------------------------------------------
CMD: GET_KUBECONFIG
Add Workers labels
node/ip-10-0-12-39 labeled
node/ip-10-0-13-139 labeled
node/ip-10-0-1-29 labeled

```

### BOOTSTRAP KUBE Hard Way

> Note: Update the local cache of Nodes data
```
> ./scripts/tf_masters
> ./scripts/tf_workers
```

> Note: Login to Nodes (masters, workers) & check clooud-init log -> Nodes do upgrades and so on ...
```
> terraform output 
master_private_dns = {
  "master1" = "ip-10-0-1-83.eu-central-1.compute.internal"
}
master_public_ip = {
  "master1" = "3.71.17.135"
}
worker_private_dns = {
  "worker1" = "ip-10-0-11-214.eu-central-1.compute.internal"
}
worker_public_ip = {
  "worker1" = "63.177.249.124"
}


> ./scripts/parse_tf_output ./nodes/workers_public_ip.json 
worker1:3.70.70.157

> ./scripts/parse_tf_output ./nodes/masters_public_ip.json 
master1:52.57.98.164

> ./scripts/aws_login 3.71.17.135 
Warning: Permanently added '3.71.17.135' (ED25519) to the list of known hosts.

The programs included with the Ubuntu system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Ubuntu comes with ABSOLUTELY NO WARRANTY, to the extent permitted by
applicable law.

$ sudo su -
root@ip-10-0-1-83:~# tail -f /var/log/cloud-init-output.log
[...]

No user sessions are running outdated binaries.

No VM guests are running outdated hypervisor (qemu) binaries on this host.
Cloud-init v. 24.4.1-0ubuntu0~24.04.3 finished at Fri, 21 Nov 2025 17:42:21 +0000. Datasource DataSourceEc2Local.  Up 141.56 seconds
```

> Note: Reboot nodes (once cloud-init finishes ^^), all masters & workers
```
> ./scripts/aws_login 3.71.17.135 "sudo shutdown -r now"

Broadcast message from root@ip-10-0-1-83 on pts/1 (Fri 2025-11-21 17:52:39 UTC):

The system will reboot now!

Connection to 3.71.17.135 closed.

```

> Note: BOOTSTRAP KUBE CLUSTER
```
> ./scripts/BOOTSTRAP_KUBE_hard_way.sh
Kubernetes init ControlPlane
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100    50  100    50    0     0  31545      0 --:--:-- --:--:-- --:--:-- 50000
I1121 17:57:11.740199    1252 version.go:261] remote version is much newer: v1.34.2; falling back to: stable-1.32
[init] Using Kubernetes version: v1.32.10
[preflight] Running pre-flight checks
[preflight] Pulling images required for setting up a Kubernetes cluster
[preflight] This might take a minute or two, depending on the speed of your internet connection
[preflight] You can also perform this action beforehand using 'kubeadm config images pull'
[...]
[upload-certs] Using certificate key:
8c32b5c9d95069017afa2f01d7e76f21f6336de183fa14a9e684a7afbbf526e4
[mark-control-plane] Marking the node ip-10-0-1-83 as control-plane by adding the labels: [node-role.kubernetes.io/control-plane node.kubernetes.io/exclude-from-external-load-balancers]
[mark-control-plane] Marking the node ip-10-0-1-83 as control-plane by adding the taints [node-role.kubernetes.io/control-plane:NoSchedule]
[bootstrap-token] Using token: pnxqhn.88dxqacdn78raufi
[bootstrap-token] Configuring bootstrap tokens, cluster-info ConfigMap, RBAC Roles
[bootstrap-token] Configured RBAC rules to allow Node Bootstrap tokens to get nodes
[bootstrap-token] Configured RBAC rules to allow Node Bootstrap tokens to post CSRs in order for nodes to get long term certificate credentials
[bootstrap-token] Configured RBAC rules to allow the csrapprover controller automatically approve CSRs from a Node Bootstrap Token
[bootstrap-token] Configured RBAC rules to allow certificate rotation for all node client certificates in the cluster
[bootstrap-token] Creating the "cluster-info" ConfigMap in the "kube-public" namespace
[kubelet-finalize] Updating "/etc/kubernetes/kubelet.conf" to point to a rotatable kubelet client certificate and key
[addons] Applied essential addon: CoreDNS
[addons] Applied essential addon: kube-proxy

Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
[...]
Kubernetes adding Workers
[preflight] Running pre-flight checks
[preflight] Reading configuration from the "kubeadm-config" ConfigMap in namespace "kube-system"...
[preflight] Use 'kubeadm init phase upload-config --config your-config.yaml' to re-upload it.
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Starting the kubelet
[kubelet-check] Waiting for a healthy kubelet at http://127.0.0.1:10248/healthz. This can take up to 4m0s
[kubelet-check] The kubelet is healthy after 518.26082ms
[kubelet-start] Waiting for the kubelet to perform the TLS Bootstrap

This node has joined the cluster:
* Certificate signing request was sent to apiserver and a response was received.
* The Kubelet was informed of the new secure connection details.

Run 'kubectl get nodes' on the control-plane to see this node join the cluster.

Configure local kubeconf
Add Workers labels
node/ip-10-0-11-214 labeled
```

> Note: Enjoy new Kube cluster

```
> kubectl get node
NAME             STATUS   ROLES           AGE    VERSION
ip-10-0-1-83     Ready    control-plane   100s   v1.32.10
ip-10-0-11-214   Ready    worker          87s    v1.32.10

```
