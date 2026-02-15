#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck source=script_lib.sh
source "$SCRIPT_DIR/script_lib.sh"

usage() {
    cat <<'USAGE'
Usage: cert2pem.sh [options]

Options:
  -c, --config FILE     Config file path (default: cert_config.env)
  -o, --out-dir DIR     Output directory override (for relative paths)
  --crt FILE            CRT file override
  --key FILE            KEY file override
  --out FILE            PEM output file override
  -h, --help            Show help
USAGE
}

arg_out_dir=""
arg_crt=""
arg_key=""
arg_out=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--config)
            CONFIG_FILE="$2"; shift 2 ;;
        -o|--out-dir)
            arg_out_dir="$2"; shift 2 ;;
        --crt)
            arg_crt="$2"; shift 2 ;;
        --key)
            arg_key="$2"; shift 2 ;;
        --out)
            arg_out="$2"; shift 2 ;;
        -h|--help)
            usage; exit 0 ;;
        *)
            die "Unknown option: $1" ;;
    esac
done

load_config
[[ -n "$arg_out_dir" ]] && set_output_dir "$arg_out_dir"

server_name="${SERVER_CERT_NAME:-}"
require_vars server_name

pem_crt_file="${arg_crt:-${PEM_CERT_FILE:-${SERVER_CRT_FILE:-${server_name}.crt}}}"
pem_key_file="${arg_key:-${PEM_KEY_FILE:-${SERVER_KEY_FILE:-${server_name}.key}}}"

if [[ -n "$arg_out" ]]; then
    pem_out_file="$arg_out"
elif [[ -n "${PEM_OUTPUT_FILE:-}" ]]; then
    pem_out_file="$PEM_OUTPUT_FILE"
else
    crt_base="$(basename "$pem_crt_file")"
    crt_base="${crt_base%.crt}"
    pem_out_file="${crt_base}.pem"
fi

if [[ "$pem_crt_file" = /* ]]; then
    crt_path="$pem_crt_file"
else
    crt_path="$(path_in_output_dir "$pem_crt_file")"
fi
if [[ "$pem_key_file" = /* ]]; then
    key_path="$pem_key_file"
else
    key_path="$(path_in_output_dir "$pem_key_file")"
fi
if [[ "$pem_out_file" = /* ]]; then
    out_path="$pem_out_file"
else
    out_path="$(path_in_output_dir "$pem_out_file")"
fi

[[ -f "$crt_path" ]] || die "CRT file not found: $crt_path"
[[ -f "$key_path" ]] || die "KEY file not found: $key_path"

info "Merging KEY + CRT into PEM"
cat "$key_path" "$crt_path" > "$out_path"
"$OPENSSL_BIN" x509 -noout -text -in "$out_path" >/dev/null

printf 'PEM_PATH=%s\n' "$out_path"
