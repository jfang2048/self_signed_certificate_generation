#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck source=script_lib.sh
source "$SCRIPT_DIR/script_lib.sh"

usage() {
    cat <<'USAGE'
Usage: install_cert_debian.sh [options]

Options:
  -c, --config FILE     Config file path (default: cert_config.env)
  -o, --out-dir DIR     Output directory override (for relative cert paths)
  --cert FILE           CA certificate file to install
  --conf FILE           /etc/ca-certificates.conf path override
  --sudo CMD            Sudo command override (default from config)
  -h, --help            Show help
USAGE
}

arg_out_dir=""
arg_cert=""
arg_conf=""
arg_sudo=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--config)
            CONFIG_FILE="$2"; shift 2 ;;
        -o|--out-dir)
            arg_out_dir="$2"; shift 2 ;;
        --cert)
            arg_cert="$2"; shift 2 ;;
        --conf)
            arg_conf="$2"; shift 2 ;;
        --sudo)
            arg_sudo="$2"; shift 2 ;;
        -h|--help)
            usage; exit 0 ;;
        *)
            die "Unknown option: $1" ;;
    esac
done

load_config
[[ -n "$arg_out_dir" ]] && set_output_dir "$arg_out_dir"

root_name="${ROOT_CA_NAME:-}"
require_vars root_name DEBIAN_CA_CONF_FILE DEBIAN_CA_DIR_PRIMARY DEBIAN_CA_DIR_SECONDARY DEBIAN_UPDATE_CMD DEBIAN_SUDO

ca_cert_file="${arg_cert:-${DEBIAN_CA_CERT_FILE:-${ROOT_CA_CRT_FILE:-${root_name}.crt}}}"
ca_conf_file="${arg_conf:-${DEBIAN_CA_CONF_FILE}}"
sudo_cmd="${arg_sudo:-${DEBIAN_SUDO}}"

if [[ "$ca_cert_file" = /* ]]; then
    ca_cert_path="$ca_cert_file"
else
    ca_cert_path="$(path_in_output_dir "$ca_cert_file")"
fi

[[ -f "$ca_cert_path" ]] || die "CA certificate file not found: $ca_cert_path"

cert_name="$(basename "$ca_cert_path")"

info "Installing CA certificate: $ca_cert_path"
"$sudo_cmd" cp "$ca_cert_path" "$DEBIAN_CA_DIR_PRIMARY/"
"$sudo_cmd" cp "$ca_cert_path" "$DEBIAN_CA_DIR_SECONDARY/"

if ! grep -q "^${cert_name}$" "$ca_conf_file"; then
    echo "$cert_name" | "$sudo_cmd" tee -a "$ca_conf_file" >/dev/null
fi

"$sudo_cmd" "$DEBIAN_UPDATE_CMD"

printf 'INSTALLED_CERT_NAME=%s\n' "$cert_name"
printf 'INSTALLED_CERT_PATH=%s\n' "$ca_cert_path"
