InfraCoders Podman Ansible 
--------------------------

## AMD64
```
> podman build --platform linux/amd64 -t ic-podman-ansible -f ./Containerfile.amd64 .

```

## ARM64
```
> podman build --platform linux/arm64 -t ic-podman-ansible -f ./Containerfile.arm64 .

```

## RUN
```
> ./ansible_run ./test_playbook.yml

PLAY [IC Ansible TEST Playbook] ************************************************

TASK [Debug Test] **************************************************************
ok: [localhost] => {
    "msg": "localhost"
}

PLAY RECAP *********************************************************************
localhost                  : ok=1    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```
