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
[calico install](https://docs.tigera.io/calico/latest/getting-started/kubernetes/k8s-single-node)<br>
[calico customize](https://docs.tigera.io/calico/latest/getting-started/kubernetes/self-managed-onprem/config-options)<br>
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

### Setup Workdir

> Note: Setup Workdir (amd64|arm64)
```
> git clone git@github.com:Infra-Coders/tf-aws-infra.git
> cd tf-aws-infra/ic-utils
> ./setup_WORKDIR
[...]

~/WORKSPACE/InfraCoders/tf-aws-infra/ic-utils
/Users/kzaremba/WORKSPACE/InfraCoders/tf-aws-infra/ic-utils/bin_utils/aws_get -> /Users/kzaremba/bin/aws_get
/Users/kzaremba/WORKSPACE/InfraCoders/tf-aws-infra/ic-utils/bin_utils/aws_login -> /Users/kzaremba/bin/aws_login
/Users/kzaremba/WORKSPACE/InfraCoders/tf-aws-infra/ic-utils/bin_utils/ic_git -> /Users/kzaremba/bin/ic_git
/Users/kzaremba/WORKSPACE/InfraCoders/tf-aws-infra/ic-utils/bin_utils/ic_ssh_wrapper -> /Users/kzaremba/bin/ic_ssh_wrapper
/Users/kzaremba/WORKSPACE/InfraCoders/tf-aws-infra/ic-utils/podman/ic-runtime/podman_helm -> /Users/kzaremba/bin/podman_helm
/Users/kzaremba/WORKSPACE/InfraCoders/tf-aws-infra/ic-utils/podman/ic-runtime/podman_kubectl -> /Users/kzaremba/bin/podman_kubectl
/Users/kzaremba/WORKSPACE/InfraCoders/tf-aws-infra/ic-utils/podman/ic-runtime/podman_run -> /Users/kzaremba/bin/podman_run
/Users/kzaremba/WORKSPACE/InfraCoders/tf-aws-infra/ic-utils/podman/ic-runtime/podman_terraform -> /Users/kzaremba/bin/podman_terraform
/Users/kzaremba/WORKSPACE/InfraCoders/tf-aws-infra/ic-utils/podman/ansible/ansible_run -> /Users/kzaremba/bin/ansible_run
/Users/kzaremba/.ssh/ic-k8slab already exists.
Overwrite (y/n)?

```


### Provisioning Infra

> Note: Terraform INIT
```
> cd tf-aws-infra/single-master-k8s
> podman_terraform init

Initializing the backend...
Initializing provider plugins...
- Reusing previous version of hashicorp/aws from the dependency lock file
- Reusing previous version of hashicorp/tls from the dependency lock file
- Reusing previous version of hashicorp/local from the dependency lock file
- Using previously-installed hashicorp/aws v6.23.0
- Using previously-installed hashicorp/tls v4.1.0
- Using previously-installed hashicorp/local v2.6.1

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

> cd tf-aws-infra/single-master-k8s
> podman_terraform plan
data.aws_ami.ubuntu: Reading...
data.aws_ami.ubuntu: Read complete after 0s [id=ami-0ccb7fb77fc31decd]

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # aws_ec2_instance_metadata_defaults.enforce-imdsv2 will be created
  + resource "aws_ec2_instance_metadata_defaults" "enforce-imdsv2" {
      + http_endpoint               = "no-preference"
      + http_put_response_hop_limit = 3
      + http_tokens                 = "required"
      + id                          = (known after apply)
      + instance_metadata_tags      = "no-preference"
      + region                      = "eu-central-1"
    }
[...]

Plan: 20 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + master_private_dns = {
      + master1 = (known after apply)
    }
  + master_public_ip   = {
      + master1 = (known after apply)
    }
  + worker_private_dns = {
      + worker1 = (known after apply)
      + worker2 = (known after apply)
      + worker3 = (known after apply)
    }
  + worker_public_ip   = {
      + worker1 = (known after apply)
      + worker2 = (known after apply)
      + worker3 = (known after apply)
    }

```

> Note: Terraform APPLY
```
> terraform apply

podman_terraform apply
data.aws_ami.ubuntu: Reading...
data.aws_ami.ubuntu: Read complete after 1s [id=ami-0ccb7fb77fc31decd]

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # aws_ec2_instance_metadata_defaults.enforce-imdsv2 will be created
  + resource "aws_ec2_instance_metadata_defaults" "enforce-imdsv2" {
      + http_endpoint               = "no-preference"
      + http_put_response_hop_limit = 3
      + http_tokens                 = "required"
      + id                          = (known after apply)
      + instance_metadata_tags      = "no-preference"
      + region                      = "eu-central-1"
    }

  # aws_iam_instance_profile.ic-aws-ebs-csi-ec2 will be created
  + resource "aws_iam_instance_profile" "ic-aws-ebs-csi-ec2" {
      + arn         = (known after apply)
      + create_date = (known after apply)
      + id          = (known after apply)
      + name        = "ic-aws-ebs-csi-ec2"
      + name_prefix = (known after apply)
      + path        = "/"
      + role        = "ic-aws-ebs-csi-role-ec2"
      + tags_all    = (known after apply)
      + unique_id   = (known after apply)
    }
[...]

Plan: 20 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + master_private_dns = {
      + master1 = (known after apply)
    }
  + master_public_ip   = {
      + master1 = (known after apply)
    }
  + worker_private_dns = {
      + worker1 = (known after apply)
      + worker2 = (known after apply)
      + worker3 = (known after apply)
    }
  + worker_public_ip   = {
      + worker1 = (known after apply)
      + worker2 = (known after apply)
      + worker3 = (known after apply)
    }

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value:

```
### BOOTSTRAP KUBE

> Note: BOOTSTRAP Kube
```
> podman_run ./scripts/BOOTSTRAP_KUBE.sh
--------------------------------------------------------------------------------
STAGE: NODE_BOOTSTRAP
NODE_BOOTSTRAP node=3.71.184.121
NODE_BOOTSTRAP node=3.71.206.191
NODE_BOOTSTRAP node=3.71.34.88
NODE_BOOTSTRAP node=63.176.97.58
Warning: Permanently added '3.71.206.191' (ED25519) to the list of known hosts.
Warning: Permanently added '3.71.34.88' (ED25519) to the list of known hosts.
ip-10-0-8-16 cloud-init status: DONE
ip-10-0-15-220 cloud-init status: DONE
ip-10-0-6-47 cloud-init status: DONE
ip-10-0-8-145 cloud-init status: DONE
STAGE: NODE_BOOTSTRAP success!
--------------------------------------------------------------------------------
STAGE: NODE_REBOOT
NODE_REBOOT node=3.71.184.121
NODE_REBOOT node=3.71.206.191
NODE_REBOOT node=3.71.34.88
NODE_REBOOT node=63.176.97.58
STAGE: NODE_REBOOT success!

[...]

This node has joined the cluster:
* Certificate signing request was sent to apiserver and a response was received.
* The Kubelet was informed of the new secure connection details.

Run 'kubectl get nodes' on the control-plane to see this node join the cluster.


This node has joined the cluster:
* Certificate signing request was sent to apiserver and a response was received.
* The Kubelet was informed of the new secure connection details.

Run 'kubectl get nodes' on the control-plane to see this node join the cluster.


This node has joined the cluster:
* Certificate signing request was sent to apiserver and a response was received.
* The Kubelet was informed of the new secure connection details.

Run 'kubectl get nodes' on the control-plane to see this node join the cluster.

STAGE: DATA_PLANE_BOOTSTRAP success!
--------------------------------------------------------------------------------
STAGE: KUBE_READY
KUBE_READY node=3.71.184.121
--------------------------------------------------------------------------------
Wait for kobject=[namespace/calico-system] condition=create

[...]

Wait for kobject=[deployment.apps/calico-apiserver] condition=condition=Available
Wait for kobject=[deployment.apps/calico-kube-controllers] condition=condition=Available
Wait for kobject=[deployment.apps/calico-typha] condition=condition=Available
Wait for kobject=[deployment.apps/goldmane] condition=condition=Available
Wait for kobject=[deployment.apps/whisker] condition=condition=Available
deployment.apps/calico-typha condition met
deployment.apps/calico-kube-controllers condition met
deployment.apps/calico-apiserver condition met
deployment.apps/whisker condition met
deployment.apps/goldmane condition met
Restart kobjects deployment.apps/coredns
deployment.apps/coredns restarted
--------------------------------------------------------------------------------
Wait for kobject=[deployment.apps/coredns] condition=condition=Available
deployment.apps/coredns condition met
STAGE: KUBE_READY success!
--------------------------------------------------------------------------------
CMD: GET_KUBECONFIG
Add Workers labels
node/ip-10-0-6-47 labeled
node/ip-10-0-8-145 labeled
node/ip-10-0-8-16 labeled
********************************************************************************
export KUBECONFIG=~/.kube/aws-k8s
********************************************************************************

```

> Note: Enjoy new Kube cluster

```
> kubectl get node
NAME             STATUS   ROLES           AGE    VERSION
ip-10-0-1-83     Ready    control-plane   100s   v1.32.10
ip-10-0-11-214   Ready    worker          87s    v1.32.10

```
