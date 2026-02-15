#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck source=script_lib.sh
source "$SCRIPT_DIR/script_lib.sh"

usage() {
    cat <<'USAGE'
Usage: create_root_ca.sh [options]

Options:
  -c, --config FILE     Config file path (default: cert_config.env)
  -o, --out-dir DIR     Output directory override
  --name NAME           Root CA basename
  --cn VALUE            Root CA common name
  --days N              Validity days
  --bits N              RSA key bits
  --country CODE        DN country (C)
  --state VALUE         DN state/province (ST)
  --city VALUE          DN locality/city (L)
  --org VALUE           DN organization (O)
  -h, --help            Show help
USAGE
}

arg_out_dir=""
arg_name=""
arg_cn=""
arg_days=""
arg_bits=""
arg_country=""
arg_state=""
arg_city=""
arg_org=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--config)
            CONFIG_FILE="$2"; shift 2 ;;
        -o|--out-dir)
            arg_out_dir="$2"; shift 2 ;;
        --name)
            arg_name="$2"; shift 2 ;;
        --cn)
            arg_cn="$2"; shift 2 ;;
        --days)
            arg_days="$2"; shift 2 ;;
        --bits)
            arg_bits="$2"; shift 2 ;;
        --country)
            arg_country="$2"; shift 2 ;;
        --state)
            arg_state="$2"; shift 2 ;;
        --city)
            arg_city="$2"; shift 2 ;;
        --org)
            arg_org="$2"; shift 2 ;;
        -h|--help)
            usage; exit 0 ;;
        *)
            die "Unknown option: $1" ;;
    esac
done

load_config
[[ -n "$arg_out_dir" ]] && set_output_dir "$arg_out_dir"

root_name="${arg_name:-${ROOT_CA_NAME:-}}"
root_cn="${arg_cn:-${ROOT_CN:-$root_name}}"
root_days="${arg_days:-${ROOT_CA_VALID_DAYS:-}}"
root_bits="${arg_bits:-${ROOT_CA_KEY_BITS:-}}"
root_country="${arg_country:-${ROOT_COUNTRY:-}}"
root_state="${arg_state:-${ROOT_STATE:-}}"
root_city="${arg_city:-${ROOT_CITY:-}}"
root_org="${arg_org:-${ROOT_ORG:-}}"

require_vars root_name root_cn root_days root_bits root_country root_state root_city root_org

root_key_file="${ROOT_CA_KEY_FILE:-${root_name}.key}"
root_csr_file="${ROOT_CA_CSR_FILE:-${root_name}.csr}"
root_crt_file="${ROOT_CA_CRT_FILE:-${root_name}.crt}"

root_key_path="$(path_in_output_dir "$root_key_file")"
root_csr_path="$(path_in_output_dir "$root_csr_file")"
root_crt_path="$(path_in_output_dir "$root_crt_file")"

dn="/C=${root_country}/ST=${root_state}/L=${root_city}/O=${root_org}/CN=${root_cn}"

info "Generating root CA in: $CERT_OUTPUT_DIR_ABS"
"$OPENSSL_BIN" genrsa -out "$root_key_path" "$root_bits"
"$OPENSSL_BIN" req -new -key "$root_key_path" -subj "$dn" -out "$root_csr_path"
"$OPENSSL_BIN" x509 -req -days "$root_days" -in "$root_csr_path" -signkey "$root_key_path" -out "$root_crt_path"

printf 'ROOT_KEY_PATH=%s\n' "$root_key_path"
printf 'ROOT_CSR_PATH=%s\n' "$root_csr_path"
printf 'ROOT_CRT_PATH=%s\n' "$root_crt_path"
