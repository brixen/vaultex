#!/bin/bash

function usage {
  echo "usage: test_vault [options]

  -s    start and configure a Vault server but don't exit the script (default)
  -d    exit this script after starting the Vault server in the background
  -x    stop a running Vault test server
  -h    display this help
"
}

function shutdown {
  local pid_file pid vault_token vault_token_bak

  pid_file=$1
  vault_token=$2
  vault_token_bak=$3
  audit_log=$4

	if [ -f "$pid_file" ]; then
		pid=$(cat "$pid_file")

		kill -INT "$pid"
		rm -f "$pid_file"

    if [ -f "$vault_token_bak" ]; then
      mv "$vault_token_bak" "$vault_token"
    fi
	fi

  if [ -f "$audit_log" ]; then
    rm -f "$audit_log"
  fi

  exit 0
}

declare vault_token vault_token_bak pid_file pid address \
        daemonize policy audit_log

vault_token="$HOME/.vault-token"
vault_token_bak="$HOME/.vault-token.vaultex_bak"
pid_file="/tmp/vaultex_test_vault.pid"
address=127.0.0.1:8222
daemonize=false
audit_log=.vault_audit.log

while getopts "dhsx" opt; do
  case "$opt" in
    d)
      daemonize=true
      ;;
		s)
			# default
			;;
		x)
      shutdown "$pid_file" "$vault_token" "$vault_token_bak" "$audit_log"
			;;
    h)
      usage
      exit 0
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      usage
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

trap 'shutdown $pid_file $vault_token $vault_token_bak $audit_log' INT TERM

# If the process in our pid_file is running, we're done
if [ -f "$pid_file" ] && ps -p "$(cat $pid_file)"; then
  exit 0
fi

if [ -f "$vault_token" ]; then
  cp "$vault_token" "$vault_token_bak"
fi

vault server -dev "-dev-listen-address=$address" &

pid=$!

export VAULT_ADDR='http://127.0.0.1:8222'

echo "Vault server started at $address: pid: $pid"

echo "$pid" > /tmp/vaultex_test_vault.pid

# Start audit logging to help debugging
vault audit-enable file file_path="$audit_log"

# Create Vault policies
read -r -d '' policy << EOP
path "secret/deny" {
  capabilities = ["deny"]
}

path "secret/deny/*" {
  capabilities = ["deny"]
}

path "secret/allow" {
  capabilities = ["read"]
}

path "secret/allow/*" {
  capabilities = ["read"]
}
EOP

echo "$policy" | vault policy-write secret -

# Populate Vault with test data
vault write secret/deny/key name=data value=123
vault write secret/allow/key name=data value=123

# Enable GitHub auth backend and create roles
vault auth-enable github

# Enable user/pass auth backend and create roles
vault auth-enable userpass

vault write auth/userpass/users/vaultex \
    password=vaultex_password \
    policies=secret

# Enable AppRole auth backend and create roles
vault auth-enable approle

vault write auth/approle/role/vaultex_secret_id \
    secret_id_ttl=30h \
    secret_id_num_uses=4000 \
    token_num_uses=4000 \
    token_ttl=30h \
    token_max_ttl=30h \
    policies=secret

vault write auth/approle/role/vaultex_secret_id/role-id \
    role_id=vaultex_secret_id_test_role_id
vault write auth/approle/role/vaultex_secret_id/custom-secret-id \
    secret_id=vaultex_secret_id_test_role_id_secret_id

vault write auth/approle/role/vaultex \
    bind_secret_id=false \
    bound_cidr_list=127.0.0.1/16 \
    token_num_uses=4000 \
    token_ttl=30h \
    token_max_ttl=30h \
    policies=secret

vault write auth/approle/role/vaultex/role-id \
    role_id=vaultex_test_role_id

if $daemonize; then
  echo ""
  echo "Vault server running in background, script exiting..."
  exit 0
else
  wait "$pid"
fi
