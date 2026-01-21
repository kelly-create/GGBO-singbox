#!/bin/bash

# SNI Optimization Logic
# Adapted from vps-tools

# Default Domain List (Microsoft, Apple, etc.)
DEFAULT_DOMAINS=(
    "www.microsoft.com"
    "www.bing.com"
    "www.azure.com"
    "www.apple.com"
    "www.adobe.com"
    "www.nvidia.com"
    "www.oracle.com"
    "www.amazon.com"
    "www.salesforce.com"
    "www.cisco.com"
    "www.ibm.com"
    "www.intel.com"
    "www.dell.com"
    "www.samsung.com"
)

# Random User-Agent List
UA_LIST=(
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36 Edg/124.0.0.0"
)

# Function to check a single domain
# Returns: http_ver|status_code|time_connect(s)|redirect_url
check_domain() {
    local domain=$1
    local current_ua="${UA_LIST[$RANDOM % ${#UA_LIST[@]}]}"
    
    curl -o /dev/null -s -w "%{http_version}|%{http_code}|%{time_connect}|%{redirect_url}" \
        --connect-timeout 2 \
        -A "$current_ua" \
        "https://$domain"
}

# Auto-select best SNI
# Usage: get_best_sni [domain_list...]
# Returns: Best domain string
get_best_sni() {
    local domains=("${@:-${DEFAULT_DOMAINS[@]}}")
    local best_domain=""
    local min_latency=9999
    
    msg warn "正在自动优选最佳 SNI 域名 (共 ${#domains[@]} 个)..."
    
    # Iterate and check
    for domain in "${domains[@]}"; do
        # Progress indicator
        echo -ne "Testing $domain ... \r"
        
        local result=$(check_domain "$domain")
        local http_ver=$(echo "$result" | cut -d'|' -f1)
        local status_code=$(echo "$result" | cut -d'|' -f2)
        local time_connect=$(echo "$result" | cut -d'|' -f3)

        # Logic to determine quality
        # 1. Must be HTTP/2 (usually denotes modern/big infra)
        if [[ "$http_ver" == "2" || "$http_ver" == "HTTP/2" ]]; then
            # 2. Status code should be 200 or 3xx (403/404 is bad)
            if [[ "$status_code" =~ ^[23] ]]; then
                 # 3. Check latency
                 # awk for float comparison
                 local is_better=$(awk -v t="$time_connect" -v min="$min_latency" 'BEGIN {if (t < min) print 1; else print 0}')
                 
                 if [[ $is_better -eq 1 ]]; then
                     min_latency=$time_connect
                     best_domain=$domain
                 fi
            fi
        fi
    done
    
    echo -e "\r\033[K" # Clear line
    
    if [[ -n "$best_domain" ]]; then
        local ms=$(awk -v t="$min_latency" 'BEGIN {printf "%.0f", t*1000}')
        msg ok "优选结果: $best_domain (延迟: ${ms}ms)"
        echo "$best_domain"
    else
        msg err "未能找到优质域名，将使用默认值."
        echo "www.microsoft.com"
    fi
}
