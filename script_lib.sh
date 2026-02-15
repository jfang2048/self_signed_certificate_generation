#!/usr/bin/env bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_CONFIG_FILE="$SCRIPT_DIR/cert_config.env"

info() {
    printf '%s\n' "$*" >&2
}

die() {
    info "Error: $*"
    exit 1
}

set_output_dir() {
    local dir="$1"

    CERT_OUTPUT_DIR="$dir"
    if [[ "$CERT_OUTPUT_DIR" = /* ]]; then
        CERT_OUTPUT_DIR_ABS="$CERT_OUTPUT_DIR"
    else
        CERT_OUTPUT_DIR_ABS="$SCRIPT_DIR/$CERT_OUTPUT_DIR"
    fi

    mkdir -p "$CERT_OUTPUT_DIR_ABS"
}

load_config() {
    CONFIG_FILE="${CONFIG_FILE:-${CERT_CONFIG_FILE:-$DEFAULT_CONFIG_FILE}}"

    [[ -f "$CONFIG_FILE" ]] || die "Config file not found: $CONFIG_FILE"

    # shellcheck disable=SC1090
    source "$CONFIG_FILE"

    OPENSSL_BIN="${OPENSSL_BIN:-openssl}"
    set_output_dir "${CERT_OUTPUT_DIR:-.}"
}

require_vars() {
    local missing=()
    local var

    for var in "$@"; do
        [[ -n "${!var:-}" ]] || missing+=("$var")
    done

    ((${#missing[@]} == 0)) || die "Missing required config value(s): ${missing[*]}"
}

path_in_output_dir() {
    local path="$1"
    if [[ "$path" = /* ]]; then
        printf '%s\n' "$path"
    else
        printf '%s\n' "$CERT_OUTPUT_DIR_ABS/$path"
    fi
}
