#!/bin/bash

inv_mode="list"

while true; do
  case "$1" in
    -l | --list)
      inv_mode="list"
      shift
      break
      ;;
    -h | --host)
      inv_mode="host"
      shift
      break
      ;;
    *)
      echo "No such mode!"
      exit 1
      ;;
  esac
done

workers=$(cat ./nodes/workers_public_ip_to_host.json | jq 'keys')
masters=$(cat ./nodes/masters_public_ip_to_host.json | jq 'keys')

[[ "${inv_mode}" == "list" ]] && \
cat << EOF | jq
{
  "workers": {
    "hosts": ${workers},
    "vars": {}
  },
  "masters": {
    "hosts": ${masters},
    "vars": {}
  },
  "_meta": {
    "hostvars": {
    }
  }

}
EOF
