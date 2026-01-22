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
    
    # Store results for table display
    # Format: "domain|latency|ver|code|status"
    local results=()
    
    msg warn "正在自动优选最佳 SNI 域名 (共 ${#domains[@]} 个)..."
    echo "----------------------------------------------------------------"
    printf "%-25s %-10s %-10s %-10s %-10s\n" "域名" "协议" "握手(ms)" "状态码" "评价"
    echo "----------------------------------------------------------------"
    
    # Iterate and check
    for domain in "${domains[@]}"; do
        local result=$(check_domain "$domain")
        local http_ver=$(echo "$result" | cut -d'|' -f1)
        local status_code=$(echo "$result" | cut -d'|' -f2)
        local time_connect=$(echo "$result" | cut -d'|' -f3)
        local latency_ms=$(awk -v t="$time_connect" 'BEGIN {printf "%.0f", t*1000}')
        
        local eval_msg="-"
        local is_valid=0
        local color_code=$gray

        # Logic to determine quality
        if [[ "$http_ver" == "2" || "$http_ver" == "HTTP/2" || "$http_ver" == "h2" ]]; then
            if [[ "$status_code" =~ ^[23] ]]; then
                 is_valid=1
                 
                 # Latency rating
                 if [[ $latency_ms -lt 100 ]]; then
                    eval_msg="极品"
                    color_code=$green
                 elif [[ $latency_ms -lt 300 ]]; then
                    eval_msg="良好"
                    color_code=$cyan
                 else
                    eval_msg="一般"
                    color_code=$yellow
                 fi
                 
                 # Check best
                 local is_better=$(awk -v t="$time_connect" -v min="$min_latency" 'BEGIN {if (t < min) print 1; else print 0}')
                 if [[ $is_better -eq 1 ]]; then
                     min_latency=$time_connect
                     best_domain=$domain
                 fi
            else
                 eval_msg="Skip(Status)"
                 color_code=$red
            fi
        else
            eval_msg="Skip(Proto)"
            color_code=$red
        fi
        
        # Real-time output line
        printf "${color_code}%-25s %-10s %-10s %-10s %-10s${none}\n" "$domain" "$http_ver" "$latency_ms" "$status_code" "$eval_msg"
    done
    
    echo "----------------------------------------------------------------"
    
    if [[ -n "$best_domain" ]]; then
        local ms=$(awk -v t="$min_latency" 'BEGIN {printf "%.0f", t*1000}')
        msg ok "优选结果: $best_domain (延迟: ${ms}ms)"
        echo "$best_domain"
    else
        msg err "未能找到优质域名，将使用默认值."
        echo "www.microsoft.com"
    fi
}
