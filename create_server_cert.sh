#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck source=script_lib.sh
source "$SCRIPT_DIR/script_lib.sh"

usage() {
    cat <<'USAGE'
Usage: create_server_cert.sh [options]

Options:
  -c, --config FILE     Config file path (default: cert_config.env)
  -o, --out-dir DIR     Output directory override
  --name NAME           Server cert basename
  --cn VALUE            Server common name
  --days N              Validity days
  --bits N              RSA key bits
  --country CODE        DN country (C)
  --state VALUE         DN state/province (ST)
  --city VALUE          DN locality/city (L)
  --org VALUE           DN organization (O)
  --dns VALUE           Add SAN DNS entry (repeatable)
  --ip VALUE            Add SAN IP entry (repeatable)
  --ca-name NAME        CA basename override
  --ca-crt FILE         CA CRT filename/path override
  --ca-key FILE         CA KEY filename/path override
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
arg_ca_name=""
arg_ca_crt=""
arg_ca_key=""
arg_dns=()
arg_ips=()

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
        --dns)
            arg_dns+=("$2"); shift 2 ;;
        --ip)
            arg_ips+=("$2"); shift 2 ;;
        --ca-name)
            arg_ca_name="$2"; shift 2 ;;
        --ca-crt)
            arg_ca_crt="$2"; shift 2 ;;
        --ca-key)
            arg_ca_key="$2"; shift 2 ;;
        -h|--help)
            usage; exit 0 ;;
        *)
            die "Unknown option: $1" ;;
    esac
done

load_config
[[ -n "$arg_out_dir" ]] && set_output_dir "$arg_out_dir"

ca_name="${arg_ca_name:-${ROOT_CA_NAME:-}}"
server_name="${arg_name:-${SERVER_CERT_NAME:-}}"
server_cn="${arg_cn:-${SERVER_CN:-$server_name}}"
server_days="${arg_days:-${SERVER_VALID_DAYS:-}}"
server_bits="${arg_bits:-${SERVER_KEY_BITS:-4096}}"
server_country="${arg_country:-${SERVER_COUNTRY:-}}"
server_state="${arg_state:-${SERVER_STATE:-}}"
server_city="${arg_city:-${SERVER_CITY:-}}"
server_org="${arg_org:-${SERVER_ORG:-}}"

require_vars ca_name server_name server_cn server_days server_bits server_country server_state server_city server_org

ca_crt_file="${arg_ca_crt:-${ROOT_CA_CRT_FILE:-${ca_name}.crt}}"
ca_key_file="${arg_ca_key:-${ROOT_CA_KEY_FILE:-${ca_name}.key}}"

server_key_file="${SERVER_KEY_FILE:-${server_name}.key}"
server_csr_file="${SERVER_CSR_FILE:-${server_name}.csr}"
server_crt_file="${SERVER_CRT_FILE:-${server_name}.crt}"
server_ext_file="${SERVER_EXT_FILE:-${server_name}.ext}"

if ((${#arg_dns[@]} > 0)); then
    dns_values=("${arg_dns[@]}")
else
    dns_values=()
    [[ -n "${SERVER_DNS_1:-}" ]] && dns_values+=("${SERVER_DNS_1}")
    [[ -n "${SERVER_DNS_2:-}" ]] && dns_values+=("${SERVER_DNS_2}")
    [[ -n "${SERVER_DNS_3:-}" ]] && dns_values+=("${SERVER_DNS_3}")
fi

if ((${#arg_ips[@]} > 0)); then
    ip_values=("${arg_ips[@]}")
else
    ip_values=()
    [[ -n "${SERVER_IP_1:-}" ]] && ip_values+=("${SERVER_IP_1}")
    [[ -n "${SERVER_IP_2:-}" ]] && ip_values+=("${SERVER_IP_2}")
    [[ -n "${SERVER_IP_3:-}" ]] && ip_values+=("${SERVER_IP_3}")
fi

((${#dns_values[@]} + ${#ip_values[@]} > 0)) || die "No SAN entries found. Use --dns/--ip or set SERVER_DNS_*/SERVER_IP_* in config."

ca_crt_path="$(path_in_output_dir "$ca_crt_file")"
ca_key_path="$(path_in_output_dir "$ca_key_file")"
server_key_path="$(path_in_output_dir "$server_key_file")"
server_csr_path="$(path_in_output_dir "$server_csr_file")"
server_crt_path="$(path_in_output_dir "$server_crt_file")"
server_ext_path="$(path_in_output_dir "$server_ext_file")"

[[ -f "$ca_crt_path" && -f "$ca_key_path" ]] || die "CA files not found: $ca_crt_path, $ca_key_path"

{
    cat <<EOF_EXT
[ req ]
default_bits        = ${server_bits}
distinguished_name  = req_distinguished_name
req_extensions      = req_ext

[ req_distinguished_name ]
C  = ${server_country}
ST = ${server_state}
L  = ${server_city}
O  = ${server_org}

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
EOF_EXT

    dns_idx=1
    for dns in "${dns_values[@]}"; do
        echo "DNS.${dns_idx} = ${dns}"
        dns_idx=$((dns_idx + 1))
    done

    ip_idx=1
    for ip in "${ip_values[@]}"; do
        echo "IP.${ip_idx} = ${ip}"
        ip_idx=$((ip_idx + 1))
    done

    cat <<'EOF_EXT'

[ v3_ca ]
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment

[ SAN ]
subjectAltName = @alt_names
EOF_EXT
} > "$server_ext_path"

dn="/C=${server_country}/ST=${server_state}/L=${server_city}/O=${server_org}/CN=${server_cn}"

info "Generating server certificate in: $CERT_OUTPUT_DIR_ABS"
"$OPENSSL_BIN" genrsa -out "$server_key_path" "$server_bits"
"$OPENSSL_BIN" req -new -key "$server_key_path" -subj "$dn" -sha256 -out "$server_csr_path"
"$OPENSSL_BIN" x509 -req -days "$server_days" -in "$server_csr_path" \
    -CA "$ca_crt_path" -CAkey "$ca_key_path" -CAcreateserial -sha256 \
    -out "$server_crt_path" -extfile "$server_ext_path" -extensions SAN

cert_modulus=$("$OPENSSL_BIN" x509 -noout -modulus -in "$server_crt_path" | "$OPENSSL_BIN" md5)
key_modulus=$("$OPENSSL_BIN" rsa -noout -modulus -in "$server_key_path" | "$OPENSSL_BIN" md5)
[[ "$cert_modulus" == "$key_modulus" ]] || die "Certificate/key mismatch"

printf 'SERVER_KEY_PATH=%s\n' "$server_key_path"
printf 'SERVER_CSR_PATH=%s\n' "$server_csr_path"
printf 'SERVER_CRT_PATH=%s\n' "$server_crt_path"
printf 'SERVER_EXT_PATH=%s\n' "$server_ext_path"
