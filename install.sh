#!/usr/bin/env bash
# ============================================================================
# Project Name : ALIRAZA WEB PANEL v57.1 (protocol isolation + domain diagnose + auto-upgrade)
# Base         : v55.4-HOTFIX engine (Xray / SSH-WS / SSL / UDP / SlowDNS / ZiVPN / HY2)
# Control      : Install terminal se (domain, panel port, user, password),
#                baqi sab kuch Web Panel se.
# ============================================================================

locale -a 2>/dev/null | grep -qiE "^c\.utf-?8$" && export LC_ALL=C.UTF-8
sed -i '/acme.sh.env/d' /root/.bashrc 2>/dev/null || true
export PATH="$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/go/bin"

RED='\033[1;91m'; GREEN='\033[1;92m'; YELLOW='\033[1;93m'; BLUE='\033[1;94m'
PURPLE='\033[1;95m'; CYAN='\033[1;96m'; WHITE='\033[1;97m'; GRAY='\033[0;37m'
BG_PURPLE='\033[1;97;45m'; BG_RED='\033[1;97;41m'; NC='\033[0m'

[[ "$EUID" -ne 0 ]] && { echo -e "${RED}[!] Run as root (sudo su)!${NC}"; exit 1; }

SCRIPT_VER="59.7-ALIRAZA-LOCKFIX"
VER_FLAG="/etc/aliraza/.script_ver"
DATA_DIR="/etc/aliraza"
BACKUP_DIR="/etc/aliraza/backup"
INSTALLED_FLAG="/etc/aliraza/.installed"
V55_FLAG="/etc/aliraza/.v55_fixed_ready"
V554_FLAG="/etc/aliraza/.v554_realip_ready"
USAGE_DIR="/etc/aliraza/usage"
USERS_CONF_DIR="/etc/aliraza/users"
CLIENTS_DIR="/root/aliraza-configs"
BUNNY_DIR="/root/aliraza-configs/bunnycdn"
USERS_DB="/etc/aliraza/users.db"
TG_CONF="/etc/aliraza/tgbot.conf"
TG_ADMINS="/etc/aliraza/tg_admins.txt"
BUNNY_CONF="/etc/aliraza/bunnycdn.conf"
XRAY_CONF="/usr/local/etc/xray/config.json"
SLOWDNS_DIR="/etc/slowdns"
WS_DIR="/etc/aliraza-ws"
UDP_DIR="/etc/udp-custom"
ZIVPN_DIR="/etc/zivpn"
HY2_DIR="/etc/hysteria"
OVPN_DIR="/etc/openvpn"
BANNER_FILE="/etc/issue.net"

# --- Purani ZAINU install se migration (users/domain data AliRaza paths me copy) ---
if [[ -d /etc/zainuxbrand && ! -d /etc/aliraza ]]; then
    echo -e "${CYAN}[*] Purani install mili - data /etc/aliraza me migrate ho raha hai...${NC}"
    for _u in zainu-ws zainu-monitor zainu-tgbot zainu-watchdog zainu-firewall; do
        systemctl stop "$_u" >/dev/null 2>&1 || true; systemctl disable "$_u" >/dev/null 2>&1 || true
        rm -f "/etc/systemd/system/${_u}.service" 2>/dev/null || true
    done
    cp -a /etc/zainuxbrand /etc/aliraza 2>/dev/null || true
    [[ -d /root/zainu-configs && ! -d /root/aliraza-configs ]] && cp -a /root/zainu-configs /root/aliraza-configs 2>/dev/null || true
    rm -f /etc/aliraza/.installed /etc/aliraza/.v55_fixed_ready /etc/aliraza/.v554_realip_ready 2>/dev/null || true
    systemctl daemon-reload >/dev/null 2>&1 || true
fi

mkdir -p "$DATA_DIR" "$BACKUP_DIR" "$USAGE_DIR" "$USERS_CONF_DIR" "$CLIENTS_DIR" "$BUNNY_DIR" "$SLOWDNS_DIR" "$WS_DIR" "$UDP_DIR" "$ZIVPN_DIR" "$HY2_DIR" "$OVPN_DIR" \
         /etc/ssl/xray /var/log/xray /var/log/nginx /etc/nginx/conf.d /etc/nginx/sites-enabled /etc/stunnel /etc/dropbear /etc/haproxy /var/www/html
touch "$USERS_DB" "$TG_ADMINS" /var/log/ws-proxy.log
rm -f "$CLIENTS_DIR"/*-bunnycdn.txt 2>/dev/null || true

backup_original_system_files() {
    [[ ! -f "$BACKUP_DIR/sshd_config.orig" && -f /etc/ssh/sshd_config ]] && cp -pf /etc/ssh/sshd_config "$BACKUP_DIR/sshd_config.orig" 2>/dev/null || true
    [[ ! -d "$BACKUP_DIR/sshd_config.d.orig" && -d /etc/ssh/sshd_config.d ]] && cp -a /etc/ssh/sshd_config.d "$BACKUP_DIR/sshd_config.d.orig" 2>/dev/null || true
    [[ ! -f "$BACKUP_DIR/issue.net.orig" && -f /etc/issue.net ]] && cp -pf /etc/issue.net "$BACKUP_DIR/issue.net.orig" 2>/dev/null || true
}
backup_original_system_files

is_protected_system_user() {
    local u="$1"
    [[ -z "$u" ]] && return 0
    case "$u" in
        root|ubuntu|debian|admin|ec2-user|centos|rocky|almalinux|fedora|sshd|nobody|systemd-*|daemon|bin|sys|sync|haproxy|www-data) return 0 ;;
    esac
    id "$u" >/dev/null 2>&1 && [[ $(id -u "$u" 2>/dev/null || echo 0) -lt 1000 ]] && return 0
    return 1
}

clear_screen() { printf "\n\n"; }  # escape codes hata diye - mobile terminal top par jump karta tha

# ---------------- ALIRAZA animated banner + installer UI ----------------
_AR_PAL=(51 45 39 33 63 99 135 171 207 201 165 129 93 57 33 39 45)
_AR_ART=(
" █████╗ ██╗     ██╗██████╗  █████╗ ███████╗ █████╗ "
"██╔══██╗██║     ██║██╔══██╗██╔══██╗╚══███╔╝██╔══██╗"
"███████║██║     ██║██████╔╝███████║  ███╔╝ ███████║"
"██╔══██║██║     ██║██╔══██╗██╔══██║ ███╔╝  ██╔══██║"
"██║  ██║███████╗██║██║  ██║██║  ██║███████╗██║  ██║"
"╚═╝  ╚═╝╚══════╝╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝"
)
_ar_line() { # $1 text  $2 phase
    local t="$1" ph="$2" out="" i c n=${#_AR_PAL[@]}
    for ((i=0;i<${#t};i++)); do
        c="${t:i:1}"
        if [[ "$c" == " " ]]; then out+=" "; else out+="\033[38;5;${_AR_PAL[$(( (i/3+ph) % n ))]}m${c}"; fi
    done
    printf "%b\033[0m" "$out"
}
_ar_cols() { local c; c=$(tput cols 2>/dev/null); [[ "$c" =~ ^[0-9]+$ && "$c" -gt 0 ]] || c=80; echo "$c"; }
aliraza_banner() { # $1 = anim (default 1) - cursor-move wali animation hata di (terminal top par jump karti thi)
    local anim="${1:-1}" l cols; cols=$(_ar_cols)
    [[ ! -t 1 ]] && anim=0
    echo ""
    if (( cols >= 58 )); then
        for l in "${_AR_ART[@]}"; do printf "  "; _ar_line "$l" 3; echo ""; [[ "$anim" == "1" ]] && sleep 0.04; done
    else
        printf "  "; _ar_line "A L I R A Z A" 3; echo ""
    fi
    local tag="  ⚡ WEB PANEL • Fast • Stable • Secure"
    (( cols < 44 )) && tag="  ⚡ ALIRAZA WEB PANEL"
    printf "\033[1;96m%s\033[0m\n" "$tag"
    printf "  \033[1;95mCreator:\033[0m \033[1;97mALIRAZA\033[0m   \033[1;95mSupport:\033[0m \033[1;96mt.me/ar_tricks\033[0m\n\n"
    return 0
}
trap 'printf "\033[?25h"' EXIT

AR_LOG="/var/log/aliraza-install.log"
AR_TOTAL=16
_ar_bar() { # $1 done  $2 total
    local d="$1" t="$2" w="${AR_BW:-28}" fill i s=""
    fill=$(( d*w/t ))
    for ((i=0;i<w;i++)); do if (( i<fill )); then s+="█"; else s+="░"; fi; done
    printf "\033[1;95m%s\033[0m \033[1;97m%3d%%\033[0m" "$s" $(( d*100/t ))
}

run_step() {
    local label="$1"; shift
    local t0=$SECONDS sp spid i=0 n=0 rc=0
    [[ "$label" =~ \[([0-9]+)/([0-9]+)\] ]] && { n=$(( ${BASH_REMATCH[1]} - 1 )); AR_TOTAL=${BASH_REMATCH[2]}; }
    export DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a
    echo "===== $label =====" >> "$AR_LOG" 2>/dev/null
    local COLS LW BW lbl="${label#*] }"; COLS=$(_ar_cols); LW=22; BW=$(( COLS - LW - 18 ))
    (( BW > 28 )) && BW=28; (( BW < 6 )) && { BW=6; LW=$(( COLS - 24 )); (( LW < 8 )) && LW=8; }
    export AR_BW=$BW; lbl="${lbl:0:$LW}"
    local CR=""
    if [[ -t 1 && "${AR_FANCY:-0}" == "1" ]]; then
        CR='\r\033[K'
        ( local fr=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏'); while true; do
            printf "\r\033[K \033[1;96m%s\033[0m %-*s " "${fr[$((i%10))]}" "$LW" "$lbl"; _ar_bar "$n" "$AR_TOTAL"; printf " \033[0;37m%ss\033[0m" $((SECONDS-t0)); i=$((i+1)); sleep 0.2; done ) &
        spid=$!
    else echo " ▶ ${label} ..."; fi
    "$@" >> "$AR_LOG" 2>&1 < /dev/null || rc=$?
    if [[ -n "${spid:-}" ]]; then kill "$spid" 2>/dev/null; wait "$spid" 2>/dev/null; fi
    local done_n=$((n+1)); [[ "$n" -eq 0 && ! "$label" =~ \[ ]] && done_n=1
    if (( rc == 0 )); then printf "${CR} \033[1;92m✔\033[0m %-*s " "$LW" "$lbl"
    else printf "${CR} \033[1;93m!\033[0m %-*s " "$LW" "$lbl"; fi
    _ar_bar "$done_n" "$AR_TOTAL"; printf " \033[0;37m%ss\033[0m\n" $((SECONDS-t0))
    (( rc != 0 )) && echo -e "   ${YELLOW}warning - details: $AR_LOG${NC}"
    return 0
}

fix_hostname_resolution() {
    local hname=$(hostname 2>/dev/null || echo "localhost")
    [[ -n "$hname" ]] && ! grep -qw -- "$hname" /etc/hosts 2>/dev/null && echo "127.0.0.1 $hname" >> /etc/hosts 2>/dev/null || true
    grep -qE '^127\.0\.0\.1[[:space:]]+localhost' /etc/hosts 2>/dev/null || echo "127.0.0.1 localhost" >> /etc/hosts 2>/dev/null || true
    sed -i '/^#*precedence ::ffff:0:0\/96/d' /etc/gai.conf 2>/dev/null || true
    echo "precedence ::ffff:0:0/96  100" >> /etc/gai.conf 2>/dev/null || true
}

get_vps_ip() {
    local ip=""
    [[ -s "$DATA_DIR/vps_ip.txt" ]] && ip=$(head -n1 "$DATA_DIR/vps_ip.txt" 2>/dev/null | tr -d '[:space:]')
    if [[ -z "$ip" || "$ip" == "127.0.0.1" ]]; then
        ip=$(curl -s4 --max-time 2 api.ipify.org 2>/dev/null | head -n1 | tr -d '[:space:]')
        [[ -z "$ip" ]] && ip=$(curl -s4 --max-time 2 icanhazip.com 2>/dev/null | head -n1 | tr -d '[:space:]')
        [[ -z "$ip" ]] && ip=$(hostname -I 2>/dev/null | awk '{print $1}' | tr -d '[:space:]')
        [[ -n "$ip" ]] && echo "$ip" > "$DATA_DIR/vps_ip.txt"
    fi
    echo "${ip:-Unknown}"
}

get_vps_provider() {
    local prov=""
    [[ -s "$DATA_DIR/provider.txt" ]] && prov=$(head -n1 "$DATA_DIR/provider.txt" 2>/dev/null | tr -d '{}[]"')
    if [[ -z "$prov" ]]; then
        prov=$(curl -s --max-time 2 "http://ip-api.com/line/?fields=isp" 2>/dev/null | head -n1 | tr -d '{}[]"' | cut -c1-18)
        [[ -n "$prov" ]] && echo "$prov" > "$DATA_DIR/provider.txt"
    fi
    echo "${prov:-Cloud VPS}"
}

get_real_google_ping() {
    local ping_out ms CPUS
    CPUS=$(nproc 2>/dev/null || echo 4)
    ping_out=$(ping -c 1 -W 1 8.8.8.8 2>/dev/null)
    if [[ $? -eq 0 ]]; then
        ms=$(echo "$ping_out" | grep -oE 'time=[0-9.]+' | head -n1 | cut -d= -f2)
        [[ -n "$ms" ]] && printf "${GREEN}${ms} ms (${CPUS}-Core BBR Turbo)${NC}" || printf "${GREEN}ONLINE (${CPUS}-Core BBR)${NC}"
    else
        printf "${GREEN}ONLINE (${CPUS}-Core BBR)${NC}"
    fi
}

check_domain_live_status() {
    local dom="$1" my_ip="$2" a_ip cname_rec isp_info
    [[ -z "$dom" || "$dom" == "Not-Set" ]] && { printf "${RED}[NOT SET]${NC}"; return; }
    [[ "$dom" == "$my_ip" ]] && { printf "${YELLOW}[IP ONLY]${NC}"; return; }
    local cache_f="/run/aliraza_dom_${dom//[^a-zA-Z0-9]/_}"
    if [[ -f "$cache_f" ]] && [[ $(( $(date +%s) - $(stat -c %Y "$cache_f" 2>/dev/null || echo 0) )) -lt 60 ]]; then
        cat "$cache_f"
        return
    fi
    cname_rec=$(dig +short +time=1 +tries=1 CNAME "$dom" @8.8.8.8 2>/dev/null | head -n1 | tr '[:upper:]' '[:lower:]')
    a_ip=$(dig +short +time=2 +tries=1 A "$dom" @8.8.8.8 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | tail -n1)
    [[ -z "$a_ip" ]] && a_ip=$(resolve_domain_ip "$dom")
    local out_str=""
    if [[ -z "$a_ip" ]]; then
        out_str="${RED}[NOT POINTED]${NC}"
    elif [[ "$a_ip" == "$my_ip" ]]; then
        out_str="${GREEN}[POINTED -> ${a_ip}]${NC}"
    elif [[ "$cname_rec" == *"b-cdn.net"* || "$dom" == *"b-cdn.net"* ]]; then
        out_str="${CYAN}[BUNNY-CDN -> ${a_ip}]${NC}"
    else
        isp_info=$(curl -s --max-time 1 "http://ip-api.com/line/${a_ip}?fields=isp,org" 2>/dev/null | tr '\n' ' ' | tr '[:upper:]' '[:lower:]')
        if [[ "$isp_info" == *"cloudflare"* || "$isp_info" == *"bunny"* || "$isp_info" == *"fastly"* || "$isp_info" == *"cloudfront"* ]]; then
            out_str="${YELLOW}[CDN/PROXY -> ${a_ip}]${NC}"
        else
            out_str="${RED}[NOT POINTED! IP: ${a_ip}]${NC}"
        fi
    fi
    printf "%b" "$out_str" > "$cache_f" 2>/dev/null || true
    printf "%b" "$out_str"
}

check_ns_live_status() {
    local ns_dom="$1" my_ip="$2"
    [[ -z "$ns_dom" || "$ns_dom" == "Not-Set" || "$ns_dom" == "$my_ip" ]] && { printf "${RED}[NOT SET]${NC}"; return; }
    local cache_f="/run/aliraza_ns_${ns_dom//[^a-zA-Z0-9]/_}"
    if [[ -f "$cache_f" ]] && [[ $(( $(date +%s) - $(stat -c %Y "$cache_f" 2>/dev/null || echo 0) )) -lt 60 ]]; then
        cat "$cache_f"
        return
    fi
    local parent_dom auth_ns ns_target target_ip out_str=""
    parent_dom=$(echo "$ns_dom" | awk -F. '{if (NF>=2) print $(NF-1)"."$NF; else print $0}')
    auth_ns=$(dig +short +time=1 +tries=1 NS "$parent_dom" @8.8.8.8 2>/dev/null | head -n1 | sed 's/\.$//')
    [[ -n "$auth_ns" ]] && ns_target=$(dig +time=1 +tries=1 @"$auth_ns" "$ns_dom" NS +norecurse +noall +authority +answer 2>/dev/null | awk '$4=="NS" {print $5}' | head -n1 | sed 's/\.$//')
    [[ -z "$ns_target" ]] && ns_target=$(dig +short +time=1 +tries=1 NS "$ns_dom" @8.8.8.8 2>/dev/null | head -n1 | sed 's/\.$//')
    if [[ -z "$ns_target" ]]; then
        out_str="${RED}[NS MISSING]${NC}"
    else
        target_ip=$(dig +short +time=1 +tries=1 A "$ns_target" @8.8.8.8 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | tail -n1)
        [[ "$target_ip" == "$my_ip" ]] && out_str="${GREEN}[POINTED -> ${target_ip}]${NC}" || out_str="${RED}[NOT POINTED]${NC}"
    fi
    printf "%b" "$out_str" > "$cache_f" 2>/dev/null || true
    printf "%b" "$out_str"
}

format_bytes() {
    awk -v b="${1:-0}" 'BEGIN {
        b = b + 0;
        if (b >= 1073741824) printf "%.2f GB (%.1f MB)", b/1073741824, b/1048576;
        else printf "%.2f MB", b/1048576;
    }'
}

format_bytes_short() {
    awk -v b="${1:-0}" 'BEGIN {
        b = b + 0;
        if (b >= 1073741824) printf "%.2f GB", b/1073741824;
        else printf "%.2f MB", b/1048576;
    }'
}

get_total_users_count() { awk -F'|' 'NF>=6 && $1!="" {c++} END {print c+0}' "$USERS_DB" 2>/dev/null; }

get_all_users_used_bytes() {
    local sum=0
    if [[ -s "$USERS_DB" ]]; then
        while IFS='|' read -r uname rest; do
            [[ -z "$uname" ]] && continue
            local ub=0
            [[ -f "$USAGE_DIR/${uname}.bytes" ]] && ub=$(head -n1 "$USAGE_DIR/${uname}.bytes" 2>/dev/null | tr -dc '0-9')
            sum=$((sum + ${ub:-0}))
        done < "$USERS_DB"
    fi
    echo "$sum"
}

get_all_users_limit_gb() { awk -F'|' 'NF>=4 && $1!="" {s+=$4} END {print s+0}' "$USERS_DB" 2>/dev/null; }

verify_real_dnstt_binary() {
    local bin="$SLOWDNS_DIR/dnstt-server"
    [[ ! -x "$bin" ]] && return 1
    local tk1="/tmp/.dnstt_k1_$$" tp1="/tmp/.dnstt_p1_$$"
    "$bin" -gen-key -privkey-file "$tk1" -pubkey-file "$tp1" >/dev/null 2>&1 || { rm -f "$tk1" "$tp1"; return 1; }
    local p1=$(head -n1 "$tp1" 2>/dev/null | tr -d '[:space:]')
    rm -f "$tk1" "$tp1"
    [[ "$p1" =~ ^[0-9a-fA-F]{64}$ ]] && return 0 || return 1
}

real_badge() {
    local svc="$1" port="$2" proto="$3" bin="$4"
    if [[ "$proto" == "bot" ]]; then
        [[ -s "$TG_CONF" ]] && systemctl is-active --quiet aliraza-tgbot 2>/dev/null && printf "${GREEN}[ON]${NC}" || printf "${RED}[OF]${NC}"
        return
    fi
    if [[ "$svc" == "mux443" ]]; then
        systemctl is-active --quiet haproxy 2>/dev/null && ss -tln 2>/dev/null | grep -qE ":443\b" && printf "${GREEN}[ON]${NC}" || printf "${RED}[OF]${NC}"
        return
    fi
    [[ -n "$bin" && ! -x "$bin" ]] && { printf "${RED}[OF]${NC}"; return; }
    if [[ "$svc" == "ssh" ]]; then
        systemctl is-active --quiet ssh 2>/dev/null || systemctl is-active --quiet sshd 2>/dev/null || { printf "${RED}[OF]${NC}"; return; }
    elif ! systemctl is-active --quiet "$svc" 2>/dev/null; then
        printf "${RED}[OF]${NC}"; return
    fi
    [[ "$proto" == "tcp" ]] && { ss -tln 2>/dev/null | grep -qE ":${port}\b" && printf "${GREEN}[ON]${NC}" || printf "${RED}[OF]${NC}"; }
    [[ "$proto" == "udp" ]] && { ss -uln 2>/dev/null | grep -qE ":${port}\b" && printf "${GREEN}[ON]${NC}" || printf "${RED}[OF]${NC}"; }
}

enable_bbr_and_kernel_speed() {
    fix_hostname_resolution
    modprobe tcp_bbr >/dev/null 2>&1 || true
    modprobe nf_conntrack >/dev/null 2>&1 || true
    sysctl -w net.core.default_qdisc=fq >/dev/null 2>&1 || true
    sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null 2>&1 || \
        sysctl -w net.ipv4.tcp_congestion_control=cubic >/dev/null 2>&1 || true
    cat << 'EOF' > /etc/sysctl.d/99-aliraza-speed.conf
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.core.rmem_max = 268435456
net.core.wmem_max = 268435456
net.core.rmem_default = 1048576
net.core.wmem_default = 1048576
net.ipv4.tcp_rmem = 16384 1048576 268435456
net.ipv4.tcp_wmem = 16384 1048576 268435456
net.ipv4.tcp_mem = 786432 2097152 33554432
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_retries2 = 12
net.ipv4.tcp_fastopen = 3
net.ipv4.ip_local_port_range = 10240 65535
net.ipv4.tcp_rfc1337 = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_dsack = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_notsent_lowat = 131072
net.ipv4.tcp_limit_output_bytes = 4194304
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_autocorking = 0
net.ipv4.tcp_ecn = 0
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 10
net.ipv4.tcp_keepalive_probes = 6
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 500000
net.core.netdev_budget = 1000
net.core.netdev_budget_usecs = 8000
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_syn_retries = 3
net.ipv4.tcp_synack_retries = 3
fs.file-max = 2097152
fs.nr_open = 2097152
net.netfilter.nf_conntrack_acct = 1
net.netfilter.nf_conntrack_max = 2097152
net.netfilter.nf_conntrack_tcp_timeout_established = 7200
net.netfilter.nf_conntrack_udp_timeout = 60
net.netfilter.nf_conntrack_udp_timeout_stream = 180
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
net.ipv4.neigh.default.gc_thresh1 = 4096
net.ipv4.neigh.default.gc_thresh2 = 8192
net.ipv4.neigh.default.gc_thresh3 = 16384
net.ipv4.neigh.default.gc_stale_time = 60
EOF
    sysctl --system >/dev/null 2>&1 || true
    echo 1 > /proc/sys/net/netfilter/nf_conntrack_acct 2>/dev/null || true
    local gov
    for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        [[ -f "$gov" ]] && echo "performance" > "$gov" 2>/dev/null || true
    done
    local CPUS MASK IF f
    CPUS=$(nproc 2>/dev/null || echo 4)
    MASK=$(printf '%x' $(( (1 << CPUS) - 1 )) 2>/dev/null || echo "ff")
    for IF in $(ls /sys/class/net 2>/dev/null | grep -vE '^(lo|docker|veth|br-|virbr|tun|tap)'); do
        [[ ! -d "/sys/class/net/$IF/queues" ]] && continue
        ip link set dev "$IF" txqueuelen 10000 2>/dev/null || true
        tc qdisc replace dev "$IF" root fq 2>/dev/null || \
            tc qdisc replace dev "$IF" root fq_codel 2>/dev/null || true
        if command -v ethtool >/dev/null 2>&1; then
            ethtool -K "$IF" tso on gso on gro on tx on rx on sg on 2>/dev/null || true
            ethtool -K "$IF" lro off 2>/dev/null || true
        fi
        for f in /sys/class/net/"$IF"/queues/rx-*/rps_cpus; do
            [[ -f "$f" ]] && echo "$MASK" > "$f" 2>/dev/null || true
        done
        for f in /sys/class/net/"$IF"/queues/tx-*/xps_cpus; do
            [[ -f "$f" ]] && echo "$MASK" > "$f" 2>/dev/null || true
        done
    done
}

ensure_golang_compiler() {
    export PATH="$PATH:/usr/local/go/bin"
    # Purana distro Go (Debian 10 = 1.11) dnstt/WS build FAIL karta hai -> Go >= 1.20 zaroori
    if command -v go >/dev/null 2>&1; then
        local GMM=$(go version 2>/dev/null | grep -oE 'go[0-9]+\.[0-9]+' | head -n1 | sed 's/go//')
        local GMJ=${GMM%%.*} GMN=${GMM##*.}
        if [[ "${GMJ:-0}" -gt 1 || ( "${GMJ:-1}" -eq 1 && "${GMN:-0}" -ge 20 ) ]]; then return 0; fi
    fi
    local ARCH=$(uname -m) GO_ARCH="amd64"
    [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]] && GO_ARCH="arm64"
    for base in "https://dl.google.com/go" "https://go.dev/dl"; do
        curl -fsSL --retry 2 --max-time 90 "${base}/go1.22.5.linux-${GO_ARCH}.tar.gz" -o /tmp/go.tar.gz 2>/dev/null || continue
        if tar -tzf /tmp/go.tar.gz >/dev/null 2>&1; then
            rm -rf /usr/local/go && tar -C /usr/local -xzf /tmp/go.tar.gz 2>/dev/null || true
            ln -sf /usr/local/go/bin/go /usr/bin/go 2>/dev/null || true
            break
        fi
    done
    rm -f /tmp/go.tar.gz
    command -v go >/dev/null 2>&1 && return 0
    echo -e "${RED}[!] Go compiler install nahi ho saka! WS Engine/SlowDNS build fail ho sakta hai (network check karein).${NC}"
    return 1
}

ensure_base_packages() {
    fix_hostname_resolution
    rm -f /etc/apt/sources.list.d/*speedtest* /etc/apt/sources.list.d/*ookla* 2>/dev/null || true
    local REQ_PKGS=(curl wget socat jq ufw iptables net-tools openssl cron unzip zip tar screen dropbear stunnel4 python3 nginx haproxy openvpn easy-rsa golang-go git dnsutils conntrack iproute2 psmisc lsof tcpdump rsyslog ethtool ca-certificates gnupg nano)
    local need=""
    for cmd in curl wget nginx haproxy openvpn jq python3 dropbear stunnel4 dig ss iptables conntrack tcpdump git zip rsyslogd lsof nano; do
        command -v "$cmd" >/dev/null 2>&1 || need="yes"
    done
    if [[ -n "$need" ]]; then
        export DEBIAN_FRONTEND=noninteractive
        echo -e "${YELLOW}[*] Base packages install ho rahe hain (fresh VPS one-time setup, 1-2 min lag sakte hain)...${NC}"
        local apt_ok=0
        for attempt in 1 2 3; do
            apt-get update -y >/dev/null 2>&1 || true
            dpkg --configure -a >/dev/null 2>&1 || true
            if apt-get install -y "${REQ_PKGS[@]}" >/dev/null 2>&1; then apt_ok=1; break; fi
            echo -e "${YELLOW}[!] apt attempt ${attempt}/3 fail - 5s baad dobara try...${NC}"
            sleep 5
        done
        apt-get -f install -y >/dev/null 2>&1 || true
        dpkg --configure -a >/dev/null 2>&1 || true
        [[ "$apt_ok" != "1" ]] && apt-get install -y "${REQ_PKGS[@]}" >/dev/null 2>&1 || true
    fi
    local missing=""
    for cmd in nginx haproxy openvpn jq python3 dropbear stunnel4 dig ss iptables tcpdump git rsyslogd curl; do
        command -v "$cmd" >/dev/null 2>&1 || missing="${missing} ${cmd}"
    done
    if [[ -n "$missing" ]]; then
        echo -e "${RED}[X] GHALTI: yeh packages install nahi hue:${missing}${NC}"
        echo -e "${RED}    VPS ka internet/apt repo check karein, warna services chalengi nahi!${NC}"
    fi
    systemctl enable rsyslog >/dev/null 2>&1 || true
    systemctl start rsyslog >/dev/null 2>&1 || true
    touch /var/log/auth.log && chmod 640 /var/log/auth.log 2>/dev/null || true
    ensure_golang_compiler
    if ! command -v speedtest-cli >/dev/null 2>&1; then
        curl -sL --max-time 10 https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py -o /usr/local/bin/speedtest-cli 2>/dev/null && chmod +x /usr/local/bin/speedtest-cli || true
    fi
    enable_bbr_and_kernel_speed
}

write_aliraza_vip_banner() {
    cat << 'BANNER_EOF' > /etc/issue.net
<font color="#FF00FF"><b>━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</b></font><br>
<font color="#00FFFF"><b>         👑  W E L C O M E   T O   AliRaza-server  👑         </b></font><br>
<font color="#00FF00"><b>         ⚡ ULTRA HIGH-SPEED VIP CLOUD GAMING SERVER ⚡         </b></font><br>
<font color="#FF00FF"><b>━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</b></font><br>
<font color="#00FFFF"><b>  💎 Owner & Brand    : AliRaza-server                      </b></font><br>
<font color="#FFFF00"><b>  📢 Support          : https://t.me/ar_tricks               </b></font><br>
<font color="#00FF00"><b>  🚀 Supported        : SSH-WS | SSL | ZIVPN | XHTTP | HY2  </b></font><br>
<font color="#FFA500"><b>  🔥 Performance      : 4K Fast Streaming & Low Gaming Ping </b></font><br>
<font color="#FF00FF"><b>━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</b></font><br>
<font color="#FF3333"><b>  ⚠️ STRICT RULES : NO Torrent | NO DDoS | NO Multi-Login   </b></font><br>
<font color="#FFFF00"><b>  🔒 Auto-Lock System Active : Expiry ya Quota par Auto-Lock</b></font><br>
<font color="#FF00FF"><b>━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</b></font>
BANNER_EOF
    chmod 644 /etc/issue.net 2>/dev/null || true
}

ensure_aliraza_dropbear() {
    if strings /usr/sbin/dropbear 2>/dev/null | grep -qx 'SSH-2.0-AliRaza-server'; then
        return 0
    fi
    echo -e "${CYAN}[*] Dropbear custom build (SSH-2.0-AliRaza-server) install ho raha hai...${NC}"
    local VER
    VER=$(strings /usr/sbin/dropbear 2>/dev/null | grep -oE '^20[0-9]{2}\.[0-9]+$' | head -1)
    [ -z "$VER" ] && VER="2024.86"
    command -v gcc >/dev/null 2>&1 || apt-get install -y build-essential >/dev/null 2>&1 || true
    dpkg -s zlib1g-dev >/dev/null 2>&1 || apt-get install -y zlib1g-dev >/dev/null 2>&1 || true
    local TMP=/tmp/aliraza-db-build
    rm -rf "$TMP"; mkdir -p "$TMP"; cd "$TMP" || return 1
    if ! wget -q "https://matt.ucc.asn.au/dropbear/releases/dropbear-${VER}.tar.bz2" -O db.tar.bz2 2>/dev/null; then
        VER="2024.86"
        wget -q "https://matt.ucc.asn.au/dropbear/releases/dropbear-${VER}.tar.bz2" -O db.tar.bz2 2>/dev/null || { echo -e "${RED}[X] Dropbear source download fail${NC}"; cd /; return 1; }
    fi
    tar xjf db.tar.bz2 || { cd /; return 1; }
    cd "dropbear-${VER}" || { cd /; return 1; }
    sed -i 's|^#define LOCAL_IDENT .*|#define LOCAL_IDENT "SSH-2.0-AliRaza-server"|' src/sysoptions.h
    if ! grep -q 'AliRaza-server' src/sysoptions.h 2>/dev/null; then
        echo -e "${RED}[X] LOCAL_IDENT patch fail${NC}"; cd /; rm -rf "$TMP"; return 1
    fi
    sed -i 's|^#define MAX_UNAUTH_CLIENTS .*|#define MAX_UNAUTH_CLIENTS 500|' default_options.h 2>/dev/null || true
    ./configure --prefix=/usr --sysconfdir=/etc >/dev/null 2>&1
    make -j$(nproc) PROGRAMS="dropbear dropbearkey dropbearconvert scp" >/dev/null 2>&1
    if [ ! -x dropbear ] || ! strings dropbear | grep -qx 'SSH-2.0-AliRaza-server'; then
        echo -e "${RED}[X] Dropbear build fail${NC}"; cd /; rm -rf "$TMP"; return 1
    fi
    cp -p /usr/sbin/dropbear /usr/sbin/dropbear.bak-$(date +%s) 2>/dev/null || true
    cp -f dropbear /usr/sbin/dropbear
    cp -f dropbearkey /usr/bin/dropbearkey 2>/dev/null || true
    cp -f dropbearconvert /usr/bin/dropbearconvert 2>/dev/null || true
    chmod 755 /usr/sbin/dropbear /usr/bin/dropbearkey
    cd /; rm -rf "$TMP"
    echo -e "${GREEN}[OK] Custom Dropbear (AliRaza-server) install ho gaya${NC}"
    return 0
}

fix_dropbear_core() {
    ensure_aliraza_dropbear 2>/dev/null || true
    [[ ! -s /etc/issue.net ]] && write_aliraza_vip_banner
    mkdir -p /etc/dropbear && chmod 700 /etc/dropbear
    # Debian 12 / Ubuntu 24: dropbear.socket port 22 pakad leta hai -> OpenSSH DOWN! Ab mask hoga:
    systemctl stop dropbear.socket >/dev/null 2>&1 || true
    systemctl disable dropbear.socket >/dev/null 2>&1 || true
    systemctl mask dropbear.socket >/dev/null 2>&1 || true
    systemctl unmask dropbear.service >/dev/null 2>&1 || true
    printf 'NO_START=0\nDROPBEAR_BANNER="/etc/issue.net"\nDROPBEAR_PORT=10022\nDROPBEAR_EXTRA_ARGS=""\n' > /etc/default/dropbear 2>/dev/null || true
    [[ ! -f /etc/dropbear/dropbear_rsa_host_key ]] && dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key &>/dev/null || true
    [[ ! -f /etc/dropbear/dropbear_ecdsa_host_key ]] && dropbearkey -t ecdsa -f /etc/dropbear/dropbear_ecdsa_host_key &>/dev/null || true
    [[ ! -f /etc/dropbear/dropbear_ed25519_host_key ]] && dropbearkey -t ed25519 -f /etc/dropbear/dropbear_ed25519_host_key &>/dev/null || true
    local DB_BIN=$(command -v dropbear || echo "/usr/sbin/dropbear")
    cat << EOF > /etc/systemd/system/dropbear.service.new
[Unit]
Description=AliRaza-server Dropbear SSH (internal 127.0.0.1:10022, public via 80/443)
After=network.target
StartLimitIntervalSec=0
[Service]
Type=simple
Nice=-10
ExecStart=${DB_BIN} -F -E -a -p 127.0.0.1:10022 -b /etc/issue.net -W 262144 -K 30 -I 0
Restart=always
RestartSec=2s
[Install]
WantedBy=multi-user.target
EOF
    local _db_chg=0
    if ! cmp -s /etc/systemd/system/dropbear.service.new /etc/systemd/system/dropbear.service 2>/dev/null; then
        mv -f /etc/systemd/system/dropbear.service.new /etc/systemd/system/dropbear.service; _db_chg=1
    else
        rm -f /etc/systemd/system/dropbear.service.new
    fi
    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl enable dropbear >/dev/null 2>&1 || true
    if [[ "$_db_chg" == "1" ]] || ! _dropbear_ok; then systemctl restart dropbear >/dev/null 2>&1 || true; fi
    local _i; for _i in 1 2 3 4 5 6 7 8 9 10; do ss -tln 2>/dev/null | awk '{print $4}' | grep -qE '(^|:)10022$' && break; sleep 1; done
}

_w_stunnel_conf() {
    cat << EOF > /etc/stunnel/stunnel.conf
foreground = yes
cert = /etc/ssl/xray/fullchain.pem
key = /etc/ssl/xray/privkey.pem
client = no
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1
[ssh-tls-8443]
accept = 0.0.0.0:8443
connect = $1
$2
[ssh-tls-444]
accept = 0.0.0.0:444
connect = $1
$2
[ovpn-tls-992]
accept = 0.0.0.0:992
connect = 127.0.0.1:1194
EOF
}

# v58.2: Stunnel -> Go engine (10000) + PROXY header = har SSL user ki ASAL SIM IP (pehle sab ko pehli IP milti thi).
# Engine na ho ya stunnel 'protocol = proxy' support na kare to seedha Dropbear (internal 10022) par fallback.
stunnel_apply_backend() {
    local backend="127.0.0.1:10022" proxy="" ok=0
    if [[ -x "$WS_DIR/aliraza-ws-go" ]]; then backend="127.0.0.1:10000"; proxy="protocol = proxy"; fi
    _w_stunnel_conf "$backend" "$proxy"
    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl restart stunnel4 >/dev/null 2>&1 || true
    sleep 2
    if systemctl is-active --quiet stunnel4 2>/dev/null && ss -tln 2>/dev/null | awk '{print $4}' | grep -qE '(^|:)444$'; then ok=1; fi
    if [[ "$ok" != "1" && -n "$proxy" ]]; then
        _w_stunnel_conf "127.0.0.1:10022" ""
        systemctl restart stunnel4 >/dev/null 2>&1 || true
    fi
}

fix_stunnel_core() {
    generate_fallback_cert
    mkdir -p /etc/stunnel /var/run/stunnel4
    local ST_BIN=$(command -v stunnel4 || command -v stunnel || echo "/usr/bin/stunnel4")
    cat << EOF > /etc/systemd/system/stunnel4.service
[Unit]
Description=Stunnel4 TLS Wrapper
After=network.target
[Service]
Type=simple
Nice=-10
ExecStart=${ST_BIN} /etc/stunnel/stunnel.conf
Restart=always
RestartSec=2s
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload && systemctl enable stunnel4 >/dev/null 2>&1 || true
    stunnel_apply_backend
}

# Dropbear (internal 10022) LIVE hai? (port listen + asli SSH banner)
_dropbear_ok() {
    ss -tln 2>/dev/null | awk '{print $4}' | grep -qE '(^|:)10022$' || return 1
    local b; b=$(timeout 4 bash -c 'exec 3<>/dev/tcp/127.0.0.1/10022 && head -c 8 <&3' 2>/dev/null)
    [[ "$b" == SSH-2.0* ]]
}

# v58.2: OpenSSH PERMANENT remove. Dropbear (10022) pehle verify hota hai - warna lockout se bachne ke liye OpenSSH chhoda jata hai.
remove_openssh_permanently() {
    # v58.3: OpenSSH ab sirf tab hatta hai jab /etc/aliraza/.remove_openssh file bani ho (admin lockout se bachao)
    [[ -f /etc/aliraza/.remove_openssh ]] || return 0
    _dropbear_ok || { fix_dropbear_core >/dev/null 2>&1 || true; sleep 2; }
    if ! _dropbear_ok; then
        echo -e "${RED}[X] Dropbear (127.0.0.1:10022) LIVE nahi - OpenSSH remove NAHI kiya (lockout se bachne ke liye). Check: systemctl status dropbear${NC}"
        return 0
    fi
    mkdir -p /etc/aliraza; touch /etc/aliraza/.openssh_off /etc/aliraza/.openssh_removed
    systemctl stop ssh.socket ssh sshd >/dev/null 2>&1 || true
    systemctl disable ssh.socket ssh sshd >/dev/null 2>&1 || true
    if dpkg -s openssh-server >/dev/null 2>&1 || dpkg -s openssh-sftp-server >/dev/null 2>&1; then
        echo -e "${CYAN}[*] OpenSSH server remove ho raha hai (Dropbear hi ab SSH hai, public port 80/443)...${NC}"
        DEBIAN_FRONTEND=noninteractive timeout 240 apt-get purge -y openssh-server openssh-sftp-server >/dev/null 2>&1 || true
    fi
    # dobara install na ho (apt/unattended-upgrades se bhi nahi)
    printf 'Package: openssh-server openssh-sftp-server\nPin: release *\nPin-Priority: -1\n' > /etc/apt/preferences.d/aliraza-no-openssh 2>/dev/null || true
    systemctl mask ssh.socket ssh sshd >/dev/null 2>&1 || true
    # purani local hardcoded targets (SlowDNS / UDP-Custom) -> Dropbear 8
    if [[ -s "$DATA_DIR/slowdns_target.txt" ]] && grep -qE ':(8|22|2222)$' "$DATA_DIR/slowdns_target.txt"; then
        echo "127.0.0.1:10022" > "$DATA_DIR/slowdns_target.txt"
    fi
    if [[ -f /etc/systemd/system/slowdns.service ]] && grep -qE '127\.0\.0\.1:(8|22|2222)( |$)' /etc/systemd/system/slowdns.service; then
        sed -i -E 's/127\.0\.0\.1:(8|22|2222)( |$)/127.0.0.1:10022\2/' /etc/systemd/system/slowdns.service
        systemctl daemon-reload >/dev/null 2>&1 || true; systemctl restart slowdns >/dev/null 2>&1 || true
    fi
    /usr/local/bin/aliraza-firewall-restore >/dev/null 2>&1 || true
    echo -e "${GREEN}[OK] OpenSSH REMOVED. Ab sirf Dropbear (port 80): ssh -p 80 root@SERVER_IP${NC}"
}

fix_ssh_auth_and_banner() {
    [[ ! -s /etc/issue.net ]] && write_aliraza_vip_banner
    sed -i 's/^ENCRYPT_METHOD.*/ENCRYPT_METHOD SHA512/g' /etc/login.defs 2>/dev/null || true
    sed -i 's/yescrypt/sha512/g' /etc/pam.d/common-password 2>/dev/null || true
    remove_openssh_permanently
}

setup_openvpn_server() {
    generate_fallback_cert
    mkdir -p /etc/openvpn/server /dev/net
    [[ ! -c /dev/net/tun ]] && mknod /dev/net/tun c 10 200 2>/dev/null && chmod 600 /dev/net/tun 2>/dev/null || true
    if [[ ! -s /etc/openvpn/server/ca.crt || ! -s /etc/openvpn/server/server.crt ]]; then
        openssl req -x509 -nodes -newkey rsa:2048 -days 3650 -subj "/CN=AliRazaXBrand-OVPN-CA" -keyout /etc/openvpn/server/ca.key -out /etc/openvpn/server/ca.crt 2>/dev/null
        openssl req -nodes -newkey rsa:2048 -subj "/CN=server" -keyout /etc/openvpn/server/server.key -out /etc/openvpn/server/server.csr 2>/dev/null
        printf "basicConstraints=CA:FALSE\nkeyUsage=digitalSignature,keyEncipherment\nextendedKeyUsage=serverAuth\n" > /etc/openvpn/server/ext.cnf
        openssl x509 -req -days 3650 -in /etc/openvpn/server/server.csr -CA /etc/openvpn/server/ca.crt -CAkey /etc/openvpn/server/ca.key -CAcreateserial -extfile /etc/openvpn/server/ext.cnf -out /etc/openvpn/server/server.crt 2>/dev/null
    fi
    cat << 'EOF' > /etc/openvpn/server/auth-pam.sh
#!/usr/bin/env bash
U=$(head -n1 "$1" 2>/dev/null | tr -d '\r\n'); P=$(tail -n1 "$1" 2>/dev/null | tr -d '\r\n')
LINE=$(grep -m1 "^${U}|" "/etc/aliraza/users.db" 2>/dev/null); [ -z "$LINE" ] && exit 1
[ "$(echo "$LINE"|cut -d"|" -f2)" != "$P" ] && exit 1
[ "$(echo "$LINE"|cut -d"|" -f7)" != "UNLOCKED" ] && exit 1
LPR=$(echo "$LINE"|cut -d"|" -f8); [ -n "$LPR" ] && [ "$LPR" != all ] && [[ ",$LPR," != *",openvpn,"* ]] && exit 1
exit 0
EOF
    chmod +x /etc/openvpn/server/auth-pam.sh
    for p in "tcp:1194:tun0:10.8.0.0" "udp:2200:tun1:10.9.0.0"; do
        IFS=':' read -r prt port dev net <<< "$p"
        cat << EOF > "/etc/openvpn/server/server-${prt}.conf"
port ${port}
proto ${prt}
dev ${dev}
ca /etc/openvpn/server/ca.crt
cert /etc/openvpn/server/server.crt
key /etc/openvpn/server/server.key
dh none
ecdh-curve prime256v1
server ${net} 255.255.255.0
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 1.1.1.1"
tun-mtu 1400
mssfix 1360
keepalive 10 60
data-ciphers AES-128-GCM:AES-256-GCM:CHACHA20-POLY1305:AES-128-CBC
cipher AES-128-GCM
auth SHA256
verify-client-cert none
username-as-common-name
script-security 3
auth-user-pass-verify /etc/openvpn/server/auth-pam.sh via-file
duplicate-cn
persist-key
persist-tun
status /var/log/openvpn-${prt}.log 5
verb 1
EOF
    done
    systemctl enable openvpn-server@server-tcp openvpn-server@server-udp >/dev/null 2>&1 || true
    systemctl restart openvpn-server@server-tcp openvpn-server@server-udp >/dev/null 2>&1 || true
}

fix_xray_systemd_unit() {
    local CPUS=$(nproc 2>/dev/null || echo 8)
    rm -rf /etc/systemd/system/xray.service.d 2>/dev/null || true
    cat << EOF > /etc/systemd/system/xray.service
[Unit]
Description=Xray Multi-Core High-Speed Service
After=network.target
[Service]
User=root
Nice=-15
Environment="GOMAXPROCS=${CPUS}"
Environment="GOGC=100"
ExecStart=/usr/local/bin/xray run -config /usr/local/etc/xray/config.json
Restart=always
RestartSec=2s
LimitNPROC=65535
LimitNOFILE=1000000
[Install]
WantedBy=multi-user.target
EOF
    mkdir -p /var/log/xray && touch /var/log/xray/access.log /var/log/xray/error.log && chmod 666 /var/log/xray/*.log 2>/dev/null || true
    systemctl daemon-reload 2>/dev/null || true
}

ensure_reality_keys() {
    local priv=$(head -n1 "$DATA_DIR/reality_priv.txt" 2>/dev/null | tr -d '[:space:]')
    local pub=$(head -n1 "$DATA_DIR/reality_pub.txt" 2>/dev/null | tr -d '[:space:]')
    if [[ -z "$priv" || -z "$pub" || ${#priv} -lt 40 || ${#pub} -lt 40 ]]; then
        if [[ -x /usr/local/bin/xray ]]; then
            local kout=$(/usr/local/bin/xray x25519 2>/dev/null || true)
            priv=$(echo "$kout" | grep -iE "Private" | awk -F': *' '{print $2}' | tr -d '[:space:]' | head -n1)
            pub=$(echo "$kout" | grep -iE "Public|Password" | awk -F': *' '{print $2}' | tr -d '[:space:]' | head -n1)
            [[ -n "$priv" && -n "$pub" ]] && { echo "$priv" > "$DATA_DIR/reality_priv.txt"; echo "$pub" > "$DATA_DIR/reality_pub.txt"; }
        fi
    fi
    [[ ! -s "$DATA_DIR/ss2022_key.txt" ]] && openssl rand -base64 16 > "$DATA_DIR/ss2022_key.txt"
}

install_xray_binary() {
    if [[ -x /usr/local/bin/xray ]] && /usr/local/bin/xray version >/dev/null 2>&1; then return 0; fi
    echo -e "${YELLOW}[*] Xray-core download/install ho raha hai...${NC}"
    curl -fsSL --retry 3 --max-time 90 "https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh" -o /tmp/xray-inst.sh 2>/dev/null || true
    if [[ -s /tmp/xray-inst.sh ]] && grep -qi 'xray' /tmp/xray-inst.sh; then
        bash /tmp/xray-inst.sh install >/dev/null 2>&1 || true
    fi
    rm -f /tmp/xray-inst.sh
    if ! { [[ -x /usr/local/bin/xray ]] && /usr/local/bin/xray version >/dev/null 2>&1; }; then
        # Fallback 1: official script dobara (GitHub kabi-kabi pehli dafa rate-limit karta hai)
        curl -fsSL --retry 3 --max-time 90 "https://github.com/XTLS/Xray-install/raw/main/install-release.sh" -o /tmp/xray-inst.sh 2>/dev/null || true
        [[ -s /tmp/xray-inst.sh ]] && bash /tmp/xray-inst.sh install >/dev/null 2>&1 || true
        rm -f /tmp/xray-inst.sh
    fi
    if ! { [[ -x /usr/local/bin/xray ]] && /usr/local/bin/xray version >/dev/null 2>&1; }; then
        # Fallback 2: direct release binary zip (amd64/arm64) latest tag detect kar ke
        local ARCH=$(uname -m) XARCH="64"
        [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]] && XARCH="arm64-v8a"
        local XTAG=$(curl -fsSL --retry 2 --max-time 20 "https://api.github.com/repos/XTLS/Xray-core/releases/latest" 2>/dev/null | grep -oE '"tag_name"[[:space:]]*:[[:space:]]*"v[^"]+"' | head -n1 | grep -oE 'v[0-9.]+')
        [[ -z "$XTAG" ]] && XTAG="v25.3.6"
        curl -fsSL --retry 3 --max-time 120 "https://github.com/XTLS/Xray-core/releases/download/${XTAG}/Xray-linux-${XARCH}.zip" -o /tmp/xray-core.zip 2>/dev/null || true
        if [[ -s /tmp/xray-core.zip ]]; then
            mkdir -p /tmp/xray-unpack /usr/local/share/xray
            unzip -o /tmp/xray-core.zip -d /tmp/xray-unpack >/dev/null 2>&1 || true
            [[ -f /tmp/xray-unpack/xray ]] && install -m 755 /tmp/xray-unpack/xray /usr/local/bin/xray
            cp -f /tmp/xray-unpack/geoip.dat /tmp/xray-unpack/geosite.dat /usr/local/share/xray/ 2>/dev/null || true
            cp -f /tmp/xray-unpack/geoip.dat /tmp/xray-unpack/geosite.dat /usr/local/bin/ 2>/dev/null || true
        fi
        rm -rf /tmp/xray-core.zip /tmp/xray-unpack
    fi
    if [[ -x /usr/local/bin/xray ]] && /usr/local/bin/xray version >/dev/null 2>&1; then
        echo -e "${GREEN}[OK] Xray-core LIVE: $(/usr/local/bin/xray version 2>/dev/null | head -n1)${NC}"
        return 0
    fi
    echo -e "${RED}[X] Xray download FAIL! Internet/GitHub block lag raha hai - baad me Panel ka Auto-Doctor chalayein.${NC}"
    return 1
}

write_base_xray_config() {
    mkdir -p /usr/local/etc/xray /var/log/xray
    install_xray_binary || true
    generate_fallback_cert
    ensure_reality_keys
    local R_PRIV=$(head -n1 "$DATA_DIR/reality_priv.txt" 2>/dev/null | tr -d '[:space:]')
    local SS22_KEY=$(head -n1 "$DATA_DIR/ss2022_key.txt" 2>/dev/null | tr -d '[:space:]')
    local DOM_NOW=$(head -n1 "$DATA_DIR/domain.txt" 2>/dev/null | tr -d '[:space:]'); [[ -z "$DOM_NOW" ]] && DOM_NOW="aliraza.com"
    local XHTTP_NET="xhttp" XHTTP_SET="xhttpSettings"
    if [[ -x /usr/local/bin/xray ]] && /usr/local/bin/xray version 2>/dev/null | head -n1 | grep -qE "Xray 1\.8\."; then
        XHTTP_NET="splithttp"; XHTTP_SET="splithttpSettings"
    fi

    cat << EOF > "$XRAY_CONF"
{
  "log": { "access": "/var/log/xray/access.log", "error": "/var/log/xray/error.log", "loglevel": "info" },
  "dns": { "servers": ["8.8.8.8", "1.1.1.1"], "queryStrategy": "UseIPv4" },
  "stats": {},
  "api": { "tag": "api", "services": ["StatsService"] },
  "policy": {
    "levels": { "0": { "handshake": 4, "connIdle": 28800, "uplinkOnly": 0, "downlinkOnly": 0, "bufferSize": 524288, "statsUserUplink": true, "statsUserDownlink": true } },
    "system": { "statsInboundUplink": true, "statsInboundDownlink": true, "statsOutboundUplink": true, "statsOutboundDownlink": true }
  },
  "inbounds": [
    { "tag": "vless-ws", "listen": "127.0.0.1", "port": 10001, "protocol": "vless", "settings": { "clients": [], "decryption": "none" }, "streamSettings": { "network": "ws", "wsSettings": { "path": "/vless" }, "sockopt": { "tcpNoDelay": true, "tcpFastOpen": true, "acceptProxyProtocol": false } } },
    { "tag": "vmess-ws", "listen": "127.0.0.1", "port": 10002, "protocol": "vmess", "settings": { "clients": [] }, "streamSettings": { "network": "ws", "wsSettings": { "path": "/vmess" }, "sockopt": { "tcpNoDelay": true, "tcpFastOpen": true, "acceptProxyProtocol": false } } },
    { "tag": "trojan-ws", "listen": "127.0.0.1", "port": 10003, "protocol": "trojan", "settings": { "clients": [] }, "streamSettings": { "network": "ws", "wsSettings": { "path": "/trojan" }, "sockopt": { "tcpNoDelay": true, "tcpFastOpen": true, "acceptProxyProtocol": false } } },
    { "tag": "vless-grpc", "listen": "127.0.0.1", "port": 10004, "protocol": "vless", "settings": { "clients": [], "decryption": "none" }, "streamSettings": { "network": "grpc", "grpcSettings": { "serviceName": "aliraza-vless-grpc", "multiMode": true }, "sockopt": { "tcpNoDelay": true, "tcpFastOpen": true } } },
    { "tag": "vmess-grpc", "listen": "127.0.0.1", "port": 10005, "protocol": "vmess", "settings": { "clients": [] }, "streamSettings": { "network": "grpc", "grpcSettings": { "serviceName": "aliraza-vmess-grpc", "multiMode": true }, "sockopt": { "tcpNoDelay": true, "tcpFastOpen": true } } },
    { "tag": "trojan-grpc", "listen": "127.0.0.1", "port": 10006, "protocol": "trojan", "settings": { "clients": [] }, "streamSettings": { "network": "grpc", "grpcSettings": { "serviceName": "aliraza-trojan-grpc", "multiMode": true }, "sockopt": { "tcpNoDelay": true, "tcpFastOpen": true } } },
    { "tag": "vless-httpupgrade", "listen": "127.0.0.1", "port": 10007, "protocol": "vless", "settings": { "clients": [], "decryption": "none" }, "streamSettings": { "network": "httpupgrade", "httpupgradeSettings": { "path": "/vless-hup" }, "sockopt": { "tcpNoDelay": true, "tcpFastOpen": true, "acceptProxyProtocol": false } } },
    { "tag": "vmess-httpupgrade", "listen": "127.0.0.1", "port": 10008, "protocol": "vmess", "settings": { "clients": [] }, "streamSettings": { "network": "httpupgrade", "httpupgradeSettings": { "path": "/vmess-hup" }, "sockopt": { "tcpNoDelay": true, "tcpFastOpen": true, "acceptProxyProtocol": false } } },
    { "tag": "trojan-httpupgrade", "listen": "127.0.0.1", "port": 10009, "protocol": "trojan", "settings": { "clients": [] }, "streamSettings": { "network": "httpupgrade", "httpupgradeSettings": { "path": "/trojan-hup" }, "sockopt": { "tcpNoDelay": true, "tcpFastOpen": true, "acceptProxyProtocol": false } } },
    { "tag": "vless-xhttp", "listen": "127.0.0.1", "port": 10010, "protocol": "vless", "settings": { "clients": [], "decryption": "none" }, "streamSettings": { "network": "${XHTTP_NET}", "${XHTTP_SET}": { "path": "/aliraza-vless-xhttp", "mode": "auto" }, "sockopt": { "tcpNoDelay": true, "tcpFastOpen": true, "acceptProxyProtocol": false } } },
    { "tag": "vmess-xhttp", "listen": "127.0.0.1", "port": 10011, "protocol": "vmess", "settings": { "clients": [] }, "streamSettings": { "network": "${XHTTP_NET}", "${XHTTP_SET}": { "path": "/aliraza-vmess-xhttp", "mode": "auto" }, "sockopt": { "tcpNoDelay": true, "tcpFastOpen": true, "acceptProxyProtocol": false } } },
    { "tag": "trojan-xhttp", "listen": "127.0.0.1", "port": 10012, "protocol": "trojan", "settings": { "clients": [] }, "streamSettings": { "network": "${XHTTP_NET}", "${XHTTP_SET}": { "path": "/aliraza-trojan-xhttp", "mode": "auto" }, "sockopt": { "tcpNoDelay": true, "tcpFastOpen": true, "acceptProxyProtocol": false } } },
    { "tag": "vless-vision", "listen": "127.0.0.1", "port": 8444, "protocol": "vless", "settings": { "clients": [], "decryption": "none" }, "streamSettings": { "network": "tcp", "security": "tls", "tlsSettings": { "alpn": ["h2", "http/1.1"], "certificates": [{ "certificateFile": "/etc/ssl/xray/fullchain.pem", "keyFile": "/etc/ssl/xray/privkey.pem" }] }, "sockopt": { "tcpNoDelay": true, "tcpFastOpen": true, "acceptProxyProtocol": true } } },
    { "tag": "vless-reality", "listen": "127.0.0.1", "port": 10013, "protocol": "vless", "settings": { "clients": [], "decryption": "none" }, "streamSettings": { "network": "tcp", "security": "reality", "realitySettings": { "show": false, "dest": "www.apple.com:443", "xver": 0, "serverNames": ["reality.${DOM_NOW}", "www.apple.com", "www.microsoft.com"], "privateKey": "${R_PRIV}", "shortIds": ["", "6ba85179e30d4fc2"] }, "sockopt": { "tcpNoDelay": true, "tcpFastOpen": true, "acceptProxyProtocol": true } } },
    { "tag": "dnstt-vless", "listen": "127.0.0.1", "port": 20010, "protocol": "vless", "settings": { "clients": [], "decryption": "none" }, "streamSettings": { "network": "tcp", "security": "none", "sockopt": { "tcpNoDelay": true } } },
    { "tag": "vless-mkcp", "listen": "0.0.0.0", "port": 10014, "protocol": "vless", "settings": { "clients": [], "decryption": "none" }, "streamSettings": { "network": "kcp", "kcpSettings": { "mtu": 1350, "tti": 20, "uplinkCapacity": 100, "downlinkCapacity": 1000, "congestion": true, "header": { "type": "none" } } } },
    { "tag": "ss-2022", "listen": "0.0.0.0", "port": 10015, "protocol": "shadowsocks", "settings": { "method": "2022-blake3-aes-128-gcm", "password": "${SS22_KEY}", "network": "tcp,udp" } },
    { "tag": "socks5-in", "listen": "0.0.0.0", "port": 10808, "protocol": "socks", "settings": { "auth": "password", "accounts": [], "udp": true } },
    { "tag": "http-in", "listen": "0.0.0.0", "port": 10809, "protocol": "http", "settings": { "accounts": [] } },
    { "tag": "ss-in", "listen": "0.0.0.0", "port": 8888, "protocol": "shadowsocks", "settings": { "clients": [], "network": "tcp,udp" } },
    { "tag": "api", "listen": "127.0.0.1", "port": 10085, "protocol": "dokodemo-door", "settings": { "address": "127.0.0.1" } }
  ],
  "outbounds": [
    { "protocol": "freedom", "tag": "direct", "settings": { "domainStrategy": "UseIPv4" }, "streamSettings": { "sockopt": { "tcpFastOpen": true, "tcpNoDelay": true } } }
  ],
  "routing": { "rules": [{ "type": "field", "inboundTag": ["api"], "outboundTag": "api" }] }
}
EOF
    chmod 644 "$XRAY_CONF"
}

sync_all_users_to_engines() {
    [[ ! -s "$XRAY_CONF" ]] && write_base_xray_config
    local R
    R=$(python3 - << 'PY' 2>>/var/log/aliraza-sync.err
import json, os, hashlib, base64, uuid as _uuid, secrets
D = "/etc/aliraza"; udb = D + "/users.db"; xc = "/usr/local/etc/xray/config.json"
sf = D + "/.dummy_secret"
if not os.path.exists(sf):
    with open(sf, "w") as f: f.write(secrets.token_hex(24))
    os.chmod(sf, 0o600)
SEC = open(sf).read().strip()
def hx(s): return hashlib.sha256((SEC + s).encode()).hexdigest()
D_UUID = str(_uuid.UUID(hx("uuid")[:32])); D_PW = hx("pw")[:24]
def ss22(uid): return base64.b64encode(hashlib.sha256(("ss22" + uid).encode()).digest()[:16]).decode()
users = []
if os.path.exists(udb):
    for ln in open(udb):
        p = ln.strip().split("|")
        if len(p) >= 7 and p[6] == "UNLOCKED":
            users.append({"u": p[0], "pw": p[1], "uuid": p[2], "protos": (p[7] if len(p) > 7 and p[7] else "all")})
def has(u, *n):
    if u["protos"] == "all": return True
    pl = [x.strip() for x in u["protos"].split(",")]
    return any(x in pl for x in n)
def atomic(path, text, mode=0o644):
    tmp = path + ".tmp"
    with open(tmp, "w") as f: f.write(text)
    os.chmod(tmp, mode); os.replace(tmp, path)
VL = {"vless-ws": "vless", "vless-grpc": "vless", "vless-httpupgrade": "vless", "vless-xhttp": "vless", "vless-mkcp": "vless"}
VM = {"vmess-ws", "vmess-grpc", "vmess-httpupgrade", "vmess-xhttp"}
TR = {"trojan-ws", "trojan-grpc", "trojan-httpupgrade", "trojan-xhttp"}
changed = []
if os.path.exists(xc):
    raw = open(xc).read(); c = json.loads(raw)
    for ib in c.get("inbounds", []):
        tg = ib.get("tag", ""); st = ib.setdefault("settings", {})
        if tg in VL:
            f = [u for u in users if has(u, "vless")]
            st["clients"] = [{"id": x["uuid"], "email": x["u"], "level": 0} for x in f]
        elif tg == "dnstt-vless":
            f = [u for u in users if has(u, "vless", "slowdns")]
            st["clients"] = [{"id": x["uuid"], "email": x["u"], "level": 0} for x in f]
        elif tg in ("vless-vision", "vless-reality"):
            f = [u for u in users if has(u, "vless")]
            st["clients"] = [{"id": x["uuid"], "email": x["u"], "flow": "xtls-rprx-vision", "level": 0} for x in f]
        elif tg in VM:
            f = [u for u in users if has(u, "vmess")]
            st["clients"] = [{"id": x["uuid"], "email": x["u"], "level": 0} for x in f]
        elif tg in TR:
            f = [u for u in users if has(u, "trojan")]
            st["clients"] = [{"password": x["pw"], "email": x["u"], "level": 0} for x in f]
        elif tg in ("socks5-in", "http-in"):
            f = [u for u in users if has(u, "socks5")]
            acc = [{"user": x["u"], "pass": x["pw"]} for x in f]
            st["accounts"] = acc or [{"user": "_none_", "pass": D_PW}]
        elif tg == "ss-in":
            f = [u for u in users if has(u, "ss")]
            st["clients"] = [{"password": x["pw"], "method": "chacha20-ietf-poly1305", "email": x["u"], "level": 0} for x in f]
        elif tg == "ss-2022":
            f = [u for u in users if has(u, "ss")]
            st["clients"] = [{"password": ss22(x["uuid"]), "email": x["u"], "level": 0} for x in f] or [{"password": ss22(D_UUID), "email": "_none_", "level": 0}]
    new = json.dumps(c, indent=2)
    if json.dumps(json.loads(raw), indent=2) != new:
        atomic(xc, new); changed.append("xray")
zi = [u["pw"] for u in users if has(u, "zivpn")]
pws = []
for p in zi:
    if p not in pws: pws.append(p)
if not pws: pws = [D_PW]
os.makedirs("/etc/zivpn", exist_ok=True)
ztxt = json.dumps({"listen": ":5667", "cert": "/etc/ssl/xray/fullchain.pem", "key": "/etc/ssl/xray/privkey.pem", "obfs": "zivpn", "auth": {"mode": "passwords", "config": pws}}, indent=2)
zp = "/etc/zivpn/config.json"
if not os.path.exists(zp) or open(zp).read() != ztxt:
    atomic(zp, ztxt); changed.append("zivpn")
hy = [u for u in users if has(u, "hy2")]
os.makedirs("/etc/hysteria", exist_ok=True)
htxt = "listen: :20800\ntls:\n  cert: /etc/ssl/xray/fullchain.pem\n  key: /etc/ssl/xray/privkey.pem\nbandwidth:\n  up: 1 gbps\n  down: 1 gbps\ntrafficStats:\n  listen: 127.0.0.1:9999\nauth:\n  type: userpass\n  userpass:\n"
if hy:
    for u in hy: htxt += "    %s: %s\n" % (json.dumps(u["u"]), json.dumps(u["pw"]))
else:
    htxt += "    %s: %s\n" % (json.dumps("_none_"), json.dumps(D_PW))
hp = "/etc/hysteria/config.yaml"
if not os.path.exists(hp) or open(hp).read() != htxt:
    atomic(hp, htxt); changed.append("hy2")
for x in changed: print("CHG:" + x)
PY
)
    [[ "$R" == *CHG:xray* ]] && { systemctl restart xray >/dev/null 2>&1 || true; }
    [[ "$R" == *CHG:zivpn* ]] && { systemctl restart zivpn >/dev/null 2>&1 || true; }
    [[ "$R" == *CHG:hy2* ]] && { systemctl restart hysteria >/dev/null 2>&1 || true; }
    return 0
}


add_user_to_xray_json() {
    sync_all_users_to_engines
}
setup_slowdns_and_udp_nat() {
    cat << 'EOF' > /usr/local/bin/aliraza-firewall-restore
#!/usr/bin/env bash
modprobe nf_conntrack >/dev/null 2>&1 || true
echo 1 > /proc/sys/net/netfilter/nf_conntrack_acct 2>/dev/null || true
ufw disable >/dev/null 2>&1 || true
iptables -P INPUT ACCEPT >/dev/null 2>&1 || true
iptables -P FORWARD ACCEPT >/dev/null 2>&1 || true
iptables -P OUTPUT ACCEPT >/dev/null 2>&1 || true
iptables -F INPUT >/dev/null 2>&1 || true
iptables -F FORWARD >/dev/null 2>&1 || true

iptables -t mangle -F OUTPUT >/dev/null 2>&1 || true
iptables -t mangle -C FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || true
iptables -t mangle -A OUTPUT -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || true

# v58.2: OpenSSH removed -> purane hardcoded local 127.0.0.1:22/2222 targets (UDP-Custom / SlowDNS) Dropbear (internal 10022) par
if [[ -f /etc/aliraza/.openssh_removed ]]; then
    while iptables -t nat -D OUTPUT -d 127.0.0.1 -p tcp -m multiport --dports 22,2222 -j REDIRECT --to-ports 8 >/dev/null 2>&1; do :; done
    iptables -t nat -C OUTPUT -d 127.0.0.1 -p tcp -m multiport --dports 22,2222 -j REDIRECT --to-ports 10022 >/dev/null 2>&1 || \
    iptables -t nat -A OUTPUT -d 127.0.0.1 -p tcp -m multiport --dports 22,2222 -j REDIRECT --to-ports 10022 >/dev/null 2>&1 || true
fi

DEF_IF=$(ip route get 8.8.8.8 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}' | head -n1)
if [[ -n "$DEF_IF" ]]; then
    ip link set dev "$DEF_IF" txqueuelen 10000 2>/dev/null || true
    iptables -t nat -F PREROUTING >/dev/null 2>&1 || true
    iptables -t nat -A PREROUTING -i "$DEF_IF" -p udp --sport 53 -j ACCEPT >/dev/null 2>&1 || true
    iptables -t nat -A PREROUTING -i "$DEF_IF" -p udp --sport 123 -j ACCEPT >/dev/null 2>&1 || true
    iptables -t nat -A PREROUTING -i "$DEF_IF" -p udp --sport 443 -j ACCEPT >/dev/null 2>&1 || true
    iptables -t nat -A PREROUTING -i "$DEF_IF" -p udp --dport 53 -j REDIRECT --to-ports 5300 >/dev/null 2>&1 || true
    for prt in 2200 5300 5667 7100 7200 7300 8888 10014 10015 10808 20800 36712; do
        iptables -t nat -A PREROUTING -i "$DEF_IF" -p udp --dport "$prt" -j ACCEPT >/dev/null 2>&1 || true
    done
    # Exclude Linux ephemeral outbound ports (32768:65535) so server's own UDP replies never loop into 36712!
    iptables -t nat -A PREROUTING -i "$DEF_IF" -p udp --dport 32768:65535 -j ACCEPT >/dev/null 2>&1 || true
    # v59.3 FIX: ZiVPN app 6000-19999 range use karti hai -> 5667 (pehle ye ports UDP-Custom 36712 me chale jate the, isliye ZiVPN connect nahi hota tha)
    iptables -t nat -A PREROUTING -i "$DEF_IF" -p udp --dport 6000:19999 -j REDIRECT --to-ports 5667 >/dev/null 2>&1 || true
    iptables -t nat -A PREROUTING -i "$DEF_IF" -p udp --dport 1:32767 -j REDIRECT --to-ports 36712 >/dev/null 2>&1 || true
    iptables -t nat -C POSTROUTING -o "$DEF_IF" -j MASQUERADE >/dev/null 2>&1 || iptables -t nat -A POSTROUTING -o "$DEF_IF" -j MASQUERADE >/dev/null 2>&1 || true
fi
EOF
    chmod +x /usr/local/bin/aliraza-firewall-restore
    /usr/local/bin/aliraza-firewall-restore
    cat << 'EOF' > /etc/systemd/system/aliraza-firewall.service
[Unit]
Description=ALIRAZA NAT & Firewall
After=network-online.target
[Service]
Type=oneshot
ExecStart=/usr/local/bin/aliraza-firewall-restore
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload && systemctl enable aliraza-firewall 2>/dev/null || true
}

fix_dns_resolver() {
    fix_hostname_resolution
    chattr -i /etc/resolv.conf 2>/dev/null || true
    systemctl stop systemd-resolved 2>/dev/null || true
    systemctl disable systemd-resolved 2>/dev/null || true
    [[ -L /etc/resolv.conf ]] && rm -f /etc/resolv.conf 2>/dev/null
    printf "nameserver 8.8.8.8\nnameserver 1.1.1.1\nnameserver 9.9.9.9\noptions timeout:2 attempts:2\n" > /etc/resolv.conf 2>/dev/null || {
        rm -f /etc/resolv.conf 2>/dev/null
        printf "nameserver 8.8.8.8\nnameserver 1.1.1.1\n" > /etc/resolv.conf 2>/dev/null || true
    }
    if ! getent ahostsv4 deb.debian.org >/dev/null 2>&1 && ! getent ahostsv4 google.com >/dev/null 2>&1; then
        printf "nameserver 1.1.1.1\nnameserver 8.8.4.4\nnameserver 9.9.9.9\n" > /etc/resolv.conf 2>/dev/null || true
    fi
}

generate_fallback_cert() {
    mkdir -p /etc/ssl/xray /etc/haproxy
    local pub_cert="" pub_key=""
    if [[ -s /etc/ssl/xray/fullchain.pem && -s /etc/ssl/xray/privkey.pem ]]; then
        pub_cert=$(openssl x509 -in /etc/ssl/xray/fullchain.pem -noout -pubkey 2>/dev/null || true)
        pub_key=$(openssl pkey -in /etc/ssl/xray/privkey.pem -pubout 2>/dev/null || true)
    fi
    if [[ -z "$pub_cert" || -z "$pub_key" || "$pub_cert" != "$pub_key" ]]; then
        local FB_DOM FB_IP FB_SAN
        FB_DOM=$(head -n1 "$DATA_DIR/domain.txt" 2>/dev/null | tr -d '[:space:]'); [[ -z "$FB_DOM" ]] && FB_DOM="aliraza.com"
        FB_IP=$(head -n1 "$DATA_DIR/vps_ip.txt" 2>/dev/null | tr -d '[:space:]')
        FB_SAN="DNS:${FB_DOM},DNS:*.${FB_DOM}"; [[ "$FB_IP" =~ ^[0-9.]+$ ]] && FB_SAN="${FB_SAN},IP:${FB_IP}"
        openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 -sha256 -subj "/CN=${FB_DOM}" -addext "subjectAltName=${FB_SAN}" \
            -keyout /etc/ssl/xray/privkey.pem -out /etc/ssl/xray/fullchain.pem 2>/dev/null || \
        openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 -sha256 -subj "/CN=${FB_DOM}" \
            -keyout /etc/ssl/xray/privkey.pem -out /etc/ssl/xray/fullchain.pem 2>/dev/null
    fi
    awk 1 /etc/ssl/xray/fullchain.pem /etc/ssl/xray/privkey.pem > /etc/ssl/xray/haproxy.pem 2>/dev/null || true
    chmod 644 /etc/ssl/xray/*.pem 2>/dev/null || true
}

resolve_domain_ip() {
    local d="$1" ip="" r
    for r in 8.8.8.8 1.1.1.1 9.9.9.9; do
        ip=$(dig +short +time=3 +tries=1 A "$d" @"$r" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | tail -n1)
        [[ -z "$ip" ]] && ip=$(dig +short +tcp +time=4 +tries=1 A "$d" @"$r" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | tail -n1)
        [[ -n "$ip" ]] && { echo "$ip"; return 0; }
    done
    ip=$(getent ahostsv4 "$d" 2>/dev/null | awk '{print $1; exit}')
    [[ -n "$ip" ]] && { echo "$ip"; return 0; }
    ip=$(curl -s4 --max-time 6 -H 'accept: application/dns-json' "https://cloudflare-dns.com/dns-query?name=${d}&type=A" 2>/dev/null | grep -oE '"data":"[0-9.]+"' | tail -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
    [[ -z "$ip" ]] && ip=$(curl -s4 --max-time 6 "https://dns.google/resolve?name=${d}&type=A" 2>/dev/null | grep -oE '"data":"[0-9.]+"' | tail -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
    echo "$ip"
}


install_ssl_autorenew() {
    cat << 'REOF' > /usr/local/bin/aliraza-ssl-renew
#!/bin/bash
# v58.3: Let's Encrypt renew - haproxy 80 pakde hota hai isliye acme.sh ka apna cron fail hota tha -> cert expire -> TLS users disconnect
DOM=$(head -n1 /etc/aliraza/domain.txt 2>/dev/null | tr -d '[:space:]'); [[ -z "$DOM" ]] && exit 0
CERT=/etc/ssl/xray/fullchain.pem; ACME=/root/.acme.sh/acme.sh
[[ -x "$ACME" ]] || exit 0
openssl x509 -in "$CERT" -noout -issuer 2>/dev/null | grep -qiE "Let's Encrypt|ISRG" || exit 0
openssl x509 -in "$CERT" -noout -checkend $((30*86400)) >/dev/null 2>&1 && exit 0
LOG=/var/log/aliraza-ssl-renew.log
echo "== $(date) renew start ($DOM)" >> "$LOG"
systemctl stop haproxy >/dev/null 2>&1; fuser -k 80/tcp >/dev/null 2>&1; sleep 1
if "$ACME" --renew -d "$DOM" --ecc --force --standalone >> "$LOG" 2>&1; then
    "$ACME" --install-cert -d "$DOM" --ecc --fullchain-file "$CERT" --key-file /etc/ssl/xray/privkey.pem >> "$LOG" 2>&1
    awk 1 "$CERT" /etc/ssl/xray/privkey.pem > /etc/ssl/xray/haproxy.pem 2>/dev/null
    chmod 644 /etc/ssl/xray/*.pem 2>/dev/null
    echo "renew OK" >> "$LOG"
else
    echo "renew FAILED" >> "$LOG"
fi
systemctl start haproxy >/dev/null 2>&1
systemctl restart nginx stunnel4 zivpn hysteria aliraza-panel >/dev/null 2>&1
REOF
    chmod +x /usr/local/bin/aliraza-ssl-renew
    printf '17 4 * * * root /usr/local/bin/aliraza-ssl-renew >/dev/null 2>&1\n' > /etc/cron.d/aliraza-ssl-renew
    chmod 644 /etc/cron.d/aliraza-ssl-renew
}

issue_ssl_cert() {
    local DOMAIN="$1"
    local MY_IP=$(get_vps_ip)
    rm -f /run/aliraza_dom_* /run/aliraza_ns_* 2>/dev/null || true
    setup_slowdns_and_udp_nat
    systemctl stop haproxy nginx aliraza-ws apache2 2>/dev/null || true
    fuser -k 80/tcp 443/tcp >/dev/null 2>&1 || true
    local DOM_IP=$(resolve_domain_ip "$DOMAIN")
    if [[ "$DOM_IP" == "$MY_IP" ]]; then
        echo -e "${CYAN}[*] Domain $DOMAIN -> $MY_IP [POINTED OK]${NC}"
        echo -e "${CYAN}[*] Let's Encrypt REAL SSL issue ho raha hai (TLS 443 ke liye)...${NC}"
        [[ ! -f /root/.acme.sh/acme.sh ]] && curl -s https://get.acme.sh | sh -s email=admin@"$DOMAIN" >/dev/null 2>&1
        /root/.acme.sh/acme.sh --set-default-ca --server letsencrypt 2>/dev/null || true
        local issued=0
        for attempt in 1 2; do
            if /root/.acme.sh/acme.sh --issue -d "$DOMAIN" --standalone --keylength ec-256 --force; then
                /root/.acme.sh/acme.sh --install-cert -d "$DOMAIN" --ecc \
                    --fullchain-file /etc/ssl/xray/fullchain.pem \
                    --key-file /etc/ssl/xray/privkey.pem \
                    --reloadcmd "systemctl restart haproxy nginx stunnel4 zivpn hysteria aliraza-panel 2>/dev/null || true" >/dev/null 2>&1 \
                    && issued=1 && break
            fi
            echo -e "${YELLOW}[!] SSL attempt ${attempt}/2 fail - 80/443 free kar ke dobara try...${NC}"
            fuser -k 80/tcp 443/tcp >/dev/null 2>&1 || true
            sleep 3
        done
        [[ "$issued" != "1" ]] && echo -e "${YELLOW}[!] Real SSL issue nahi ho saka - abhi Self-Signed lagega. Baad me Panel -> Domain & SSL -> Renew SSL chalayein.${NC}"
    else
        echo -e "${YELLOW}[!] Domain ($DOMAIN) abhi is VPS IP ($MY_IP) par pointed nahi hai (Current: ${DOM_IP:-None}).${NC}"
        echo -e "${YELLOW}    Abhi Self-Signed SSL lagega - TLS 443 apps me 'allow insecure' ON karna parega.${NC}"
        echo -e "${YELLOW}    Domain point karne ke baad: Panel -> Domain & SSL -> Renew SSL chalayein to REAL SSL mil jayega.${NC}"
    fi
    generate_fallback_cert
    install_ssl_autorenew
    timeout 60 systemctl restart nginx aliraza-ws haproxy stunnel4 zivpn hysteria aliraza-panel 2>/dev/null || true
    local ISSUER=$(openssl x509 -in /etc/ssl/xray/fullchain.pem -noout -issuer 2>/dev/null | sed -e 's/^issuer= *//' -e 's/.*O = //' -e 's/^CN = //' | cut -d, -f1)
    if echo "$ISSUER" | grep -qiE "Let's Encrypt|ISRG"; then
        echo -e "${GREEN}[OK] REAL SSL LIVE hai (Issuer: ${ISSUER:-LE}) - TLS 443/2053/2083/2087/2096 sab chalenge!${NC}"
    else
        echo -e "${YELLOW}[!] Abhi Self-Signed cert active hai (Issuer: ${ISSUER:-self}). Domain point kar ke Renew SSL karein.${NC}"
    fi
}

install_port_watchdog() {
    # v58.3: har 30s check; service tabhi restart hoti hai jab 2 baar lagataar port band mile (ek false alarm sab users ko disconnect na kare)
    cat << 'WEOF' > /usr/local/bin/aliraza-watchdog.sh
#!/bin/bash
declare -A FC
CHK() { ss -tln 2>/dev/null | awk '{print $4}' | grep -qE "[:.]$1\$"; }
guard() { # $1=service, baqi = ports jo listen hone chahiye
    local svc="$1" p ok=1; shift
    for p in "$@"; do CHK "$p" || ok=0; done
    if [[ "$ok" == "1" ]]; then FC[$svc]=0; return; fi
    FC[$svc]=$(( ${FC[$svc]:-0} + 1 ))
    if (( FC[$svc] >= 2 )); then systemctl restart "$svc" >/dev/null 2>&1 || true; FC[$svc]=0; fi
}
while true; do
    sleep 30
    guard haproxy 80 443 8442
    guard nginx 8081
    guard aliraza-ws 10000
    [[ -x /usr/local/bin/xray ]] && guard xray 10001
    guard dropbear 10022
done
WEOF
    chmod +x /usr/local/bin/aliraza-watchdog.sh
    cat << 'WEOF' > /etc/systemd/system/aliraza-watchdog.service
[Unit]
Description=ALIRAZA 24/7 Port Watchdog (443/80/8442/10000 Auto-Repair)
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
ExecStart=/usr/local/bin/aliraza-watchdog.sh
Restart=always
RestartSec=10s

[Install]
WantedBy=multi-user.target
WEOF
    systemctl daemon-reload 2>/dev/null || true
    systemctl enable aliraza-watchdog >/dev/null 2>&1 || true
    systemctl restart aliraza-watchdog 2>/dev/null || true
}

self_test_tls_and_repair() {
    # Real end-to-end 443 TLS handshake test — fail ho to auto-repair (cert regen + restart)
    local DOMC=$(head -n1 "$DATA_DIR/domain.txt" 2>/dev/null | tr -d '[:space:]')
    [[ -z "$DOMC" ]] && DOMC="localhost"
    local ok=0
    for t in 1 2; do
        if timeout 8 openssl s_client -connect 127.0.0.1:443 -servername "$DOMC" </dev/null 2>/dev/null | grep -q "BEGIN CERTIFICATE"; then
            ok=1; break
        fi
        echo -e "${YELLOW}[!] Port 443 TLS self-test FAIL (attempt ${t}/2) — cert+services auto-repair ho rahe hain...${NC}"
        generate_fallback_cert
        systemctl restart aliraza-ws nginx haproxy 2>/dev/null || true
        sleep 3
    done
    if [[ "$ok" == "1" ]]; then
        echo -e "${GREEN}[OK] Port 443 TLS SELF-TEST PASS (handshake verified)${NC}"
    else
        echo -e "${RED}[X] Port 443 TLS ab bhi fail — haproxy logs dekhein, watchdog auto-retry karta rahega.${NC}"
    fi
}

configure_nginx_mux() {
    mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled /root/backups
    generate_fallback_cert
    local DOMAIN=$(head -n1 "$DATA_DIR/domain.txt" 2>/dev/null | tr -d '[:space:]'); [[ -z "$DOMAIN" ]] && DOMAIN="_"
    local B_HOST=$(head -n1 "$DATA_DIR/bunny_host.txt" 2>/dev/null | tr -d '[:space:]')
    rm -f /etc/nginx/sites-enabled/default /etc/nginx/conf.d/*.conf 2>/dev/null || true

    cat << 'EOF' > /etc/nginx/nginx.conf
user www-data;
worker_processes auto;
worker_rlimit_nofile 1000000;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;
events { worker_connections 65535; multi_accept on; use epoll; }
http {
    sendfile on; tcp_nopush on; tcp_nodelay on; keepalive_timeout 86400s;
    types_hash_max_size 2048; server_tokens off;
    proxy_buffer_size 32k; proxy_buffers 8 32k; proxy_busy_buffers_size 64k;
    include /etc/nginx/mime.types; default_type application/octet-stream;
    access_log off; error_log /var/log/nginx/error.log crit;
    include /etc/nginx/conf.d/*.conf;
}
EOF

    cat << EOF > /etc/nginx/conf.d/aliraza-mux.conf
map \$http_x_forwarded_for \$first_xff_ip {
    "~^([^,\\s]+)" \$1;
    default        \$proxy_protocol_addr;
}
map \$http_cf_connecting_ip \$real_client_ip {
    ""      \$first_xff_ip;
    default \$http_cf_connecting_ip;
}

server {
    listen 127.0.0.1:8081 proxy_protocol default_server;
    server_name ${DOMAIN} ${B_HOST} _;
    root /var/www/html;
    set_real_ip_from 127.0.0.1;
    real_ip_header proxy_protocol;
    tcp_nodelay on; keepalive_timeout 86400s; client_max_body_size 0;
    proxy_redirect off; proxy_buffering off; proxy_request_buffering off;
    proxy_http_version 1.1; proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$real_client_ip; proxy_set_header X-Forwarded-For \$real_client_ip;
    proxy_read_timeout 86400s; proxy_send_timeout 86400s;

    location = / { proxy_pass http://127.0.0.1:20090; }
    location = /u { proxy_pass http://127.0.0.1:20090; }
    location = /u/ { proxy_pass http://127.0.0.1:20090; }
    location ^~ /api/ { proxy_pass http://127.0.0.1:20090; }
    location = /favicon.ico { return 204; }
    location ~ ^/(vless|aliraza-vless-ws)\$ { rewrite ^ /vless break; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; proxy_pass http://127.0.0.1:10001; }
    location ~ ^/(vmess|aliraza-vmess-ws)\$ { rewrite ^ /vmess break; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; proxy_pass http://127.0.0.1:10002; }
    location ~ ^/(trojan|aliraza-trojan-ws)\$ { rewrite ^ /trojan break; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; proxy_pass http://127.0.0.1:10003; }
    location ~ ^/(vless-hup|aliraza-vless-httpupgrade)\$ { rewrite ^ /vless-hup break; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; proxy_pass http://127.0.0.1:10007; }
    location ~ ^/(vmess-hup|aliraza-vmess-httpupgrade)\$ { rewrite ^ /vmess-hup break; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; proxy_pass http://127.0.0.1:10008; }
    location ~ ^/(trojan-hup|aliraza-trojan-httpupgrade)\$ { rewrite ^ /trojan-hup break; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; proxy_pass http://127.0.0.1:10009; }
    location ^~ /aliraza-vless-xhttp { proxy_set_header Connection ""; proxy_pass http://127.0.0.1:10010; }
    location ^~ /aliraza-vmess-xhttp { proxy_set_header Connection ""; proxy_pass http://127.0.0.1:10011; }
    location ^~ /aliraza-trojan-xhttp { proxy_set_header Connection ""; proxy_pass http://127.0.0.1:10012; }
}

server {
    listen 127.0.0.1:8082 http2 proxy_protocol default_server;
    server_name ${DOMAIN} ${B_HOST} _;
    set_real_ip_from 127.0.0.1;
    real_ip_header proxy_protocol;
    tcp_nodelay on; keepalive_timeout 86400s; client_max_body_size 0;
    grpc_socket_keepalive on; grpc_set_header Host \$host;
    grpc_set_header X-Real-IP \$real_client_ip; grpc_set_header X-Forwarded-For \$real_client_ip;
    grpc_read_timeout 86400s; grpc_send_timeout 86400s;

    location = / { proxy_buffering off; proxy_request_buffering off; proxy_http_version 1.1; proxy_set_header Host \$host; proxy_set_header X-Real-IP \$real_client_ip; proxy_set_header X-Forwarded-For \$real_client_ip; proxy_pass http://127.0.0.1:20090; }
    location = /u { proxy_buffering off; proxy_request_buffering off; proxy_http_version 1.1; proxy_set_header Host \$host; proxy_set_header X-Real-IP \$real_client_ip; proxy_set_header X-Forwarded-For \$real_client_ip; proxy_pass http://127.0.0.1:20090; }
    location = /u/ { proxy_buffering off; proxy_request_buffering off; proxy_http_version 1.1; proxy_set_header Host \$host; proxy_set_header X-Real-IP \$real_client_ip; proxy_set_header X-Forwarded-For \$real_client_ip; proxy_pass http://127.0.0.1:20090; }
    location ^~ /api/ { proxy_buffering off; proxy_request_buffering off; proxy_http_version 1.1; proxy_set_header Host \$host; proxy_set_header X-Real-IP \$real_client_ip; proxy_set_header X-Forwarded-For \$real_client_ip; proxy_pass http://127.0.0.1:20090; }
    location = /favicon.ico { return 204; }
    location ^~ /aliraza-vless-grpc { grpc_pass grpc://127.0.0.1:10004; }
    location ^~ /aliraza-vmess-grpc { grpc_pass grpc://127.0.0.1:10005; }
    location ^~ /aliraza-trojan-grpc { grpc_pass grpc://127.0.0.1:10006; }
    location ^~ /aliraza-vless-xhttp { proxy_buffering off; proxy_request_buffering off; proxy_http_version 1.1; proxy_set_header Connection ""; proxy_set_header Host \$host; proxy_set_header X-Real-IP \$real_client_ip; proxy_set_header X-Forwarded-For \$real_client_ip; proxy_pass http://127.0.0.1:10010; }
    location ^~ /aliraza-vmess-xhttp { proxy_buffering off; proxy_request_buffering off; proxy_http_version 1.1; proxy_set_header Connection ""; proxy_set_header Host \$host; proxy_set_header X-Real-IP \$real_client_ip; proxy_set_header X-Forwarded-For \$real_client_ip; proxy_pass http://127.0.0.1:10011; }
    location ^~ /aliraza-trojan-xhttp { proxy_buffering off; proxy_request_buffering off; proxy_http_version 1.1; proxy_set_header Connection ""; proxy_set_header Host \$host; proxy_set_header X-Real-IP \$real_client_ip; proxy_set_header X-Forwarded-For \$real_client_ip; proxy_pass http://127.0.0.1:10012; }
}
EOF
    systemctl enable nginx 2>/dev/null || true
    systemctl restart nginx 2>/dev/null || true
}

configure_haproxy_c_mux() {
    generate_fallback_cert
    systemctl stop apache2 2>/dev/null || true
    systemctl disable apache2 2>/dev/null || true

    for p in 80 8080 2082 8880 2052 2086 2095 443 2053 2083 2087 2096 8442; do
        for pid in $(lsof -t -iTCP:"$p" -sTCP:LISTEN 2>/dev/null); do
            local svc=$(ps -o unit= -p "$pid" 2>/dev/null | tr -d '[:space:]')
            if [[ -n "$svc" && "$svc" != "haproxy.service" && "$svc" != "session-"* && "$svc" != "ssh"* && "$svc" != "user@"* ]]; then
                systemctl stop "$svc" >/dev/null 2>&1 || true
                systemctl disable "$svc" >/dev/null 2>&1 || true
            fi
            kill -9 "$pid" >/dev/null 2>&1 || true
        done
    done

    cat << EOF > /etc/haproxy/haproxy.cfg
global
    maxconn 200000
    nbthread $(nproc)
    tune.bufsize 131072
    tune.maxrewrite 32768

defaults
    mode tcp
    timeout connect 5s
    timeout client  86400s
    timeout server  86400s
    timeout tunnel  86400s
    timeout client-fin 5s
    timeout server-fin 5s
    option clitcpka
    option srvtcpka

frontend aliraza_80_http
    bind 0.0.0.0:80
    bind 0.0.0.0:8080
    bind 0.0.0.0:2082
    bind 0.0.0.0:8880
    bind 0.0.0.0:2052
    bind 0.0.0.0:2086
    bind 0.0.0.0:2095
    mode tcp
    tcp-request inspect-delay 500ms
    acl is_h2_preface req.payload(0,14) -m bin 505249202a20485454502f322e30
    acl is_xray_path req.payload(0,0) -m sub /aliraza- /vless /vmess /trojan
    acl is_ovpn_dl req.payload(0,0) -m sub .ovpn .zip .html
    acl is_ssh_banner req.payload(0,4) -m str SSH-
    acl xr_vless_ws req.payload(0,80) -m sub "GET /vless " "GET /aliraza-vless-ws"
    acl xr_vmess_ws req.payload(0,80) -m sub "GET /vmess " "GET /aliraza-vmess-ws"
    acl xr_trojan_ws req.payload(0,80) -m sub "GET /trojan " "GET /aliraza-trojan-ws"
    acl xr_vless_hup req.payload(0,96) -m sub "GET /vless-hup" "GET /aliraza-vless-httpupgrade"
    acl xr_vmess_hup req.payload(0,96) -m sub "GET /vmess-hup" "GET /aliraza-vmess-httpupgrade"
    acl xr_trojan_hup req.payload(0,96) -m sub "GET /trojan-hup" "GET /aliraza-trojan-httpupgrade"
    acl xr_vless_xhttp req.payload(0,96) -m sub "GET /aliraza-vless-xhttp" "POST /aliraza-vless-xhttp"
    acl xr_vmess_xhttp req.payload(0,96) -m sub "GET /aliraza-vmess-xhttp" "POST /aliraza-vmess-xhttp"
    acl xr_trojan_xhttp req.payload(0,96) -m sub "GET /aliraza-trojan-xhttp" "POST /aliraza-trojan-xhttp"
    tcp-request content accept if is_h2_preface or is_xray_path or is_ovpn_dl or is_ssh_banner
    tcp-request content accept if { req.len gt 0 }
    # v55.4 FIX: Xray WS/HUP/XHTTP/gRPC ab Golang Engine (10000) se guzarta hai
    # jo CF-Connecting-IP / X-Forwarded-For se REAL SIM IP extract karta hai
    # (pehle xd_* direct Xray raw path Cloudflare/BunnyCDN ke EDGE IPs show karta tha = FAKE)
    use_backend ws_ssh_plain_backend if is_h2_preface or xr_vless_ws or xr_vmess_ws or xr_trojan_ws or xr_vless_hup or xr_vmess_hup or xr_trojan_hup or xr_vless_xhttp or xr_vmess_xhttp or xr_trojan_xhttp or is_xray_path
    use_backend nginx_http_backend if is_ovpn_dl
    use_backend direct_ssh_backend if is_ssh_banner or { req.len eq 0 }
    default_backend ws_ssh_plain_backend

frontend aliraza_443_raw
    bind 0.0.0.0:443
    bind 0.0.0.0:2053
    bind 0.0.0.0:2083
    bind 0.0.0.0:2087
    bind 0.0.0.0:2096
    mode tcp
    tcp-request inspect-delay 500ms
    acl is_ssl req.ssl_hello_type 1
    acl is_vision_sni req.ssl_sni -m beg vision. xtls.
    acl is_reality_sni req.ssl_sni -m beg reality. www.apple.com www.microsoft.com
    acl is_ssh_banner req.payload(0,4) -m str SSH-
    acl is_xray_plain req.payload(0,0) -m sub /aliraza- /vless /vmess /trojan
    acl xr_vless_ws req.payload(0,80) -m sub "GET /vless " "GET /aliraza-vless-ws"
    acl xr_vmess_ws req.payload(0,80) -m sub "GET /vmess " "GET /aliraza-vmess-ws"
    acl xr_trojan_ws req.payload(0,80) -m sub "GET /trojan " "GET /aliraza-trojan-ws"
    acl xr_vless_hup req.payload(0,96) -m sub "GET /vless-hup" "GET /aliraza-vless-httpupgrade"
    acl xr_vmess_hup req.payload(0,96) -m sub "GET /vmess-hup" "GET /aliraza-vmess-httpupgrade"
    acl xr_trojan_hup req.payload(0,96) -m sub "GET /trojan-hup" "GET /aliraza-trojan-httpupgrade"
    acl xr_vless_xhttp req.payload(0,96) -m sub "GET /aliraza-vless-xhttp" "POST /aliraza-vless-xhttp"
    acl xr_vmess_xhttp req.payload(0,96) -m sub "GET /aliraza-vmess-xhttp" "POST /aliraza-vmess-xhttp"
    acl xr_trojan_xhttp req.payload(0,96) -m sub "GET /aliraza-trojan-xhttp" "POST /aliraza-trojan-xhttp"
    tcp-request content accept if is_ssl or is_ssh_banner or is_xray_plain
    tcp-request content accept if { req.len gt 0 }
    use_backend xray_vision_tls_backend if is_ssl is_vision_sni
    use_backend xray_reality_backend if is_ssl is_reality_sni
    # v55.4 FIX: non-TLS Xray payloads par bhi real SIM IP engine se hi guzarein
    use_backend ws_ssh_plain_backend if xr_vless_ws or xr_vmess_ws or xr_trojan_ws or xr_vless_hup or xr_vmess_hup or xr_trojan_hup or xr_vless_xhttp or xr_vmess_xhttp or xr_trojan_xhttp or is_xray_plain
    use_backend loop_ssl_terminator if is_ssl
    use_backend direct_ssh_backend if is_ssh_banner or { req.len eq 0 }
    default_backend ws_ssh_plain_backend

backend loop_ssl_terminator
    mode tcp
    server local_tls 127.0.0.1:8442 send-proxy

frontend aliraza_443_tls_terminated
    bind 127.0.0.1:8442 accept-proxy ssl crt /etc/ssl/xray/haproxy.pem alpn h2,http/1.1
    mode tcp
    tcp-request inspect-delay 500ms
    acl is_h2_preface req.payload(0,14) -m bin 505249202a20485454502f322e30
    acl is_xray_path req.payload(0,0) -m sub /aliraza- /vless /vmess /trojan
    acl is_ssh_banner req.payload(0,4) -m str SSH-
    acl xr_vless_ws req.payload(0,80) -m sub "GET /vless " "GET /aliraza-vless-ws"
    acl xr_vmess_ws req.payload(0,80) -m sub "GET /vmess " "GET /aliraza-vmess-ws"
    acl xr_trojan_ws req.payload(0,80) -m sub "GET /trojan " "GET /aliraza-trojan-ws"
    acl xr_vless_hup req.payload(0,96) -m sub "GET /vless-hup" "GET /aliraza-vless-httpupgrade"
    acl xr_vmess_hup req.payload(0,96) -m sub "GET /vmess-hup" "GET /aliraza-vmess-httpupgrade"
    acl xr_trojan_hup req.payload(0,96) -m sub "GET /trojan-hup" "GET /aliraza-trojan-httpupgrade"
    acl xr_vless_xhttp req.payload(0,96) -m sub "GET /aliraza-vless-xhttp" "POST /aliraza-vless-xhttp"
    acl xr_vmess_xhttp req.payload(0,96) -m sub "GET /aliraza-vmess-xhttp" "POST /aliraza-vmess-xhttp"
    acl xr_trojan_xhttp req.payload(0,96) -m sub "GET /aliraza-trojan-xhttp" "POST /aliraza-trojan-xhttp"
    tcp-request content accept if is_h2_preface or is_xray_path or is_ssh_banner
    tcp-request content accept if { req.len gt 0 }
    # TLS ke ANDAR wala payload ab Golang Engine dekhta hai (CF-Connecting-IP = real SIM IP)
    use_backend ws_ssh_plain_backend if is_h2_preface or xr_vless_ws or xr_vmess_ws or xr_trojan_ws or xr_vless_hup or xr_vmess_hup or xr_trojan_hup or xr_vless_xhttp or xr_vmess_xhttp or xr_trojan_xhttp or is_xray_path
    use_backend direct_ssh_backend if is_ssh_banner
    default_backend ws_ssh_plain_backend

backend xray_vision_tls_backend
    mode tcp
    server xray_vis 127.0.0.1:8444 send-proxy

backend xray_reality_backend
    mode tcp
    server xray_real 127.0.0.1:10013 send-proxy

backend xd_vless_ws
    mode tcp
    server xd1 127.0.0.1:10001 send-proxy

backend xd_vmess_ws
    mode tcp
    server xd2 127.0.0.1:10002 send-proxy

backend xd_trojan_ws
    mode tcp
    server xd3 127.0.0.1:10003 send-proxy

backend xd_vless_hup
    mode tcp
    server xd7 127.0.0.1:10007 send-proxy

backend xd_vmess_hup
    mode tcp
    server xd8 127.0.0.1:10008 send-proxy

backend xd_trojan_hup
    mode tcp
    server xd9 127.0.0.1:10009 send-proxy

backend xd_vless_xhttp
    mode tcp
    server xd10 127.0.0.1:10010 send-proxy

backend xd_vmess_xhttp
    mode tcp
    server xd11 127.0.0.1:10011 send-proxy

backend xd_trojan_xhttp
    mode tcp
    server xd12 127.0.0.1:10012 send-proxy

backend nginx_h2c_backend
    mode tcp
    server ngx_h2 127.0.0.1:8082 send-proxy

backend nginx_http_backend
    mode tcp
    server ngx_h1 127.0.0.1:8081 send-proxy

backend direct_ssh_backend
    mode tcp
    server ws_direct_ssh 127.0.0.1:10000 send-proxy

backend ws_ssh_plain_backend
    mode tcp
    server ws_engine 127.0.0.1:10000 send-proxy
EOF
    local HAP_BIN=$(command -v haproxy || echo "/usr/sbin/haproxy")
    rm -rf /etc/systemd/system/haproxy.service.d 2>/dev/null || true
    cat << EOF > /etc/systemd/system/haproxy.service
[Unit]
Description=ALIRAZA HAProxy 80/443 Multiplexer
After=network.target nginx.service
StartLimitIntervalSec=0
[Service]
Type=simple
User=root
Nice=-15
LimitNOFILE=1000000
ExecStartPre=-/bin/sh -c "fuser -k 80/tcp 8080/tcp 2082/tcp 8880/tcp 2052/tcp 2086/tcp 2095/tcp 443/tcp 2053/tcp 2083/tcp 2087/tcp 2096/tcp 8442/tcp >/dev/null 2>&1 || true"
ExecStart=${HAP_BIN} -db -f /etc/haproxy/haproxy.cfg
Restart=always
RestartSec=1s
[Install]
WantedBy=multi-user.target
EOF
    # Config validate — fail ho to cert dobara bana ke ek aur try
    local HAP_CHK="$HAP_BIN"
    [[ ! -x "$HAP_CHK" ]] && HAP_CHK="/usr/sbin/haproxy"
    if ! "$HAP_CHK" -c -f /etc/haproxy/haproxy.cfg >/dev/null 2>&1; then
        generate_fallback_cert
        "$HAP_CHK" -c -f /etc/haproxy/haproxy.cfg >/dev/null 2>&1 || true
    fi
    systemctl daemon-reload
    systemctl reset-failed haproxy 2>/dev/null || true
    systemctl enable haproxy 2>/dev/null || true
    systemctl restart haproxy 2>/dev/null || true
    sleep 2
    if ! ss -tln 2>/dev/null | grep -qE ":443\b"; then
        systemctl restart haproxy 2>/dev/null || true
    fi
    install_port_watchdog
}

install_ws_ssh_engine() {
    mkdir -p "$WS_DIR"
    generate_fallback_cert
    ensure_golang_compiler
    cat << 'EOF' > "$WS_DIR/ws.go"
package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"os"
	"runtime"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

type PortEntry struct {
	IP    string `json:"ip"`
	Mode  string `json:"mode"`
	Bytes int64  `json:"bytes"`
	Open  bool   `json:"open"`
	Ts    int64  `json:"ts"`
}

var portMap sync.Map

type byteCounter struct {
	w     io.Writer
	entry *PortEntry
}

var bigBufPool = sync.Pool{New: func() interface{} { b := make([]byte, 262144); return &b }}

func copyBig(dst io.Writer, src io.Reader) (int64, error) {
	bp := bigBufPool.Get().(*[]byte)
	defer bigBufPool.Put(bp)
	return io.CopyBuffer(dst, struct{ io.Reader }{src}, *bp)
}

func (bc *byteCounter) Write(p []byte) (int, error) {
	n, err := bc.w.Write(p)
	if n > 0 && bc.entry != nil {
		atomic.AddInt64(&bc.entry.Bytes, int64(n))
		atomic.StoreInt64(&bc.entry.Ts, time.Now().Unix())
	}
	return n, err
}

func writeMapNow() {
	snap := make(map[string]PortEntry)
	now := time.Now().Unix()
	portMap.Range(func(k, v interface{}) bool {
		key := k.(string)
		pe := v.(*PortEntry)
		if pe.Open || (strings.Contains(pe.Mode, "XHTTP") && now-atomic.LoadInt64(&pe.Ts) < 15) {
			snap[key] = PortEntry{
				IP:    pe.IP,
				Mode:  pe.Mode,
				Bytes: atomic.LoadInt64(&pe.Bytes),
				Open:  true,
				Ts:    atomic.LoadInt64(&pe.Ts),
			}
		}
		return true
	})
	if b, err := json.Marshal(snap); err == nil {
		_ = os.WriteFile("/run/aliraza_ws_map.json", b, 0644)
	}
}

func mapWriterDaemon() {
	for {
		time.Sleep(1500 * time.Millisecond)
		writeMapNow()
	}
}

func tuneTCP(c net.Conn) {
	if tc, ok := c.(*net.TCPConn); ok {
		_ = tc.SetNoDelay(true)
		_ = tc.SetKeepAlive(true)
		_ = tc.SetKeepAlivePeriod(15 * time.Second)
	}
}

// ---- v58.1: REAL SIM IP (spoof-proof) -------------------------------------
// Headers (CF-Connecting-IP / X-Forwarded-For) sirf tab trust hote hain jab
// connection asal me CDN (Cloudflare/Bunny) se aaya ho. Direct client ke
// fake headers (injector payload) ignore hote hain. XFF me RIGHTMOST public
// non-CDN IP lete hain (CDN apni taraf se append karta hai, client ka fake
// pehle hota hai).
var builtinCF = []string{
	"173.245.48.0/20", "103.21.244.0/22", "103.22.200.0/22", "103.31.4.0/22",
	"141.101.64.0/18", "108.162.192.0/18", "190.93.240.0/20", "188.114.96.0/20",
	"197.234.240.0/22", "198.41.128.0/17", "162.158.0.0/15", "104.16.0.0/13",
	"104.24.0.0/14", "172.64.0.0/13", "131.0.72.0/22",
	"2400:cb00::/32", "2606:4700::/32", "2803:f800::/32", "2405:b500::/32",
	"2405:8100::/32", "2a06:98c0::/29", "2c0f:f248::/32",
}

var privateNets []*net.IPNet
var cfNets atomic.Value  // []*net.IPNet
var cdnNets atomic.Value // []*net.IPNet (CF + Bunny + others)
var bunnyN int64

func mustNets(list []string) []*net.IPNet {
	var out []*net.IPNet
	for _, s := range list {
		s = strings.TrimSpace(s)
		if s == "" {
			continue
		}
		if strings.Contains(s, "/") {
			if _, n, err := net.ParseCIDR(s); err == nil {
				out = append(out, n)
			}
			continue
		}
		if ip := net.ParseIP(s); ip != nil {
			bits := 128
			if ip.To4() != nil {
				bits = 32
			}
			out = append(out, &net.IPNet{IP: ip, Mask: net.CIDRMask(bits, bits)})
		}
	}
	return out
}

func readNetFile(path string) []string {
	var out []string
	if b, err := os.ReadFile(path); err == nil {
		for _, ln := range strings.Split(string(b), "\n") {
			ln = strings.TrimSpace(ln)
			if ln == "" || strings.HasPrefix(ln, "#") {
				continue
			}
			out = append(out, ln)
		}
	}
	return out
}

func reloadCDN() {
	cf := mustNets(builtinCF)
	cf = append(cf, mustNets(readNetFile("/etc/aliraza/cf_ips.txt"))...)
	all := append([]*net.IPNet{}, cf...)
	bn := mustNets(readNetFile("/etc/aliraza/cdn_ips.txt"))
	atomic.StoreInt64(&bunnyN, int64(len(bn)))
	all = append(all, bn...)
	cfNets.Store(cf)
	cdnNets.Store(all)
}

func cdnLoader() {
	for {
		reloadCDN()
		time.Sleep(10 * time.Minute)
	}
}

func init() {
	privateNets = mustNets([]string{"0.0.0.0/8", "10.0.0.0/8", "100.64.0.0/10", "127.0.0.0/8", "169.254.0.0/16",
		"172.16.0.0/12", "192.0.0.0/24", "192.168.0.0/16", "198.18.0.0/15", "224.0.0.0/3", "fc00::/7", "fe80::/10"})
	reloadCDN()
}

func inNets(ip net.IP, nets []*net.IPNet) bool {
	for _, n := range nets {
		if n.Contains(ip) {
			return true
		}
	}
	return false
}

func isCDNIP(ip net.IP) bool {
	nets, _ := cdnNets.Load().([]*net.IPNet)
	return inNets(ip, nets)
}

func isCFIP(ip net.IP) bool {
	nets, _ := cfNets.Load().([]*net.IPNet)
	return inNets(ip, nets)
}

func isPublicIP(ip net.IP) bool {
	return ip != nil && ip.IsGlobalUnicast() && !inNets(ip, privateNets)
}

func cleanHdrIP(s string) net.IP {
	s = strings.TrimSpace(s)
	if h, _, err := net.SplitHostPort(s); err == nil {
		s = h
	}
	s = strings.TrimPrefix(strings.Trim(s, "[]"), "::ffff:")
	return net.ParseIP(s)
}

func extractHeaderIP(req string, fallback string) string {
	peer := cleanHdrIP(fallback)
	hv := map[string]string{}
	for i, ln := range strings.Split(req, "\n") {
		l := strings.TrimSpace(ln)
		if i == 0 {
			continue
		}
		if l == "" {
			break
		}
		k := strings.Index(l, ":")
		if k <= 0 {
			continue
		}
		name := strings.ToLower(strings.TrimSpace(l[:k]))
		if strings.ContainsAny(name, " \t/") {
			continue
		}
		val := strings.TrimSpace(l[k+1:])
		if old, ok := hv[name]; ok {
			if name == "x-forwarded-for" {
				hv[name] = old + "," + val
			}
		} else {
			hv[name] = val
		}
	}
	fromCF := peer != nil && isCFIP(peer)
	trusted := false
	if peer == nil || !isPublicIP(peer) {
		trusted = true // local chain (haproxy/nginx) - purana behaviour
	} else if isCDNIP(peer) {
		trusted = true
	} else if (hv["cdn-requestid"] != "" || hv["cdn-pullzone"] != "") && atomic.LoadInt64(&bunnyN) == 0 {
		// v58.2: header par bharosa SIRF tab jab Bunny edge list load na ho (warna client fake CF/CDN headers se IP spoof kar sakta tha)
		trusted = true
	}
	if !trusted {
		return fallback // direct client: asal TCP peer hi real IP hai, headers fake ho sakte hain
	}
	pick := func(v string) string {
		ip := cleanHdrIP(v)
		if isPublicIP(ip) && !isCDNIP(ip) {
			return ip.String()
		}
		return ""
	}
	if fromCF || peer == nil || !isPublicIP(peer) {
		if r := pick(hv["cf-connecting-ip"]); r != "" {
			return r
		}
	}
	parts := strings.Split(hv["x-forwarded-for"], ",")
	for i := len(parts) - 1; i >= 0; i-- {
		if r := pick(parts[i]); r != "" {
			return r
		}
	}
	return fallback
}

func buildProxyHeader(ipStr string) []byte {
	parsed := net.ParseIP(ipStr)
	if parsed != nil && parsed.To4() != nil {
		return []byte(fmt.Sprintf("PROXY TCP4 %s 127.0.0.1 44300 443\r\n", parsed.To4().String()))
	}
	if parsed != nil {
		return []byte(fmt.Sprintf("PROXY TCP6 %s ::1 44300 443\r\n", parsed.String()))
	}
	return []byte("PROXY TCP4 127.0.0.1 127.0.0.1 44300 443\r\n")
}

func stripExtraPayloads(b []byte) []byte {
	if idx := bytes.Index(b, []byte("SSH-2.0-")); idx != -1 {
		return b[idx:]
	}
	trimmed := bytes.TrimLeft(b, "\r\n ")
	for _, m := range [][]byte{[]byte("GET "), []byte("POST "), []byte("CONNECT "), []byte("HEAD "), []byte("PUT "), []byte("OPTIONS "), []byte("HTTP/")} {
		if bytes.HasPrefix(trimmed, m) {
			if sep := bytes.Index(b, []byte("\r\n\r\n")); sep != -1 {
				return stripExtraPayloads(b[sep+4:])
			}
			return nil
		}
	}
	return b
}

func dialLocalSSH() (net.Conn, error) {
	c, err := net.DialTimeout("tcp", "127.0.0.1:10022", 3*time.Second)
	if err == nil {
		tuneTCP(c)
	}
	return c, err
}

func detectXrayMode(firstLine string) string {
	fl := strings.ToLower(firstLine)
	if strings.Contains(fl, "vless-xhttp") {
		return "VLESS-XHTTP"
	} else if strings.Contains(fl, "vmess-xhttp") {
		return "VMESS-XHTTP"
	} else if strings.Contains(fl, "trojan-xhttp") {
		return "TROJAN-XHTTP"
	} else if strings.Contains(fl, "vless-hup") || strings.Contains(fl, "vless-httpupgrade") {
		return "VLESS-HUP"
	} else if strings.Contains(fl, "vmess-hup") || strings.Contains(fl, "vmess-httpupgrade") {
		return "VMESS-HUP"
	} else if strings.Contains(fl, "trojan-hup") || strings.Contains(fl, "trojan-httpupgrade") {
		return "TROJAN-HUP"
	} else if strings.Contains(fl, "/vless") || strings.Contains(fl, "aliraza-vless") {
		return "VLESS-WS"
	} else if strings.Contains(fl, "/vmess") || strings.Contains(fl, "aliraza-vmess") {
		return "VMESS-WS"
	} else if strings.Contains(fl, "/trojan") || strings.Contains(fl, "aliraza-trojan") {
		return "TROJAN-WS"
	}
	return ""
}

var plainPorts = map[string]bool{"80": true, "8080": true, "2082": true, "8880": true, "2052": true, "2086": true, "2095": true}

func reqHeader(req, name string) string {
	for _, ln := range strings.Split(req, "\n") {
		l := strings.TrimSpace(ln)
		if len(l) > len(name)+1 && strings.EqualFold(l[:len(name)+1], name+":") {
			return strings.TrimSpace(l[len(name)+1:])
		}
	}
	return ""
}

// Browser request for the Web Panel (no port needed: https://domain/)
func isPanelRequest(firstLine, reqStr string) bool {
	lower := strings.ToLower(reqStr)
	if strings.Contains(lower, "upgrade:") {
		return false
	}
	if !strings.HasPrefix(firstLine, "GET ") && !strings.HasPrefix(firstLine, "POST ") {
		return false
	}
	fl := strings.Fields(firstLine)
	if len(fl) < 2 {
		return false
	}
	path := fl[1]
	if strings.HasPrefix(path, "/api/") || path == "/u" || path == "/u/" || strings.HasPrefix(path, "/u?") || path == "/favicon.ico" {
		return true
	}
	if (path == "/" || strings.HasPrefix(path, "/?")) && strings.Contains(lower, "text/html") {
		return true
	}
	return false
}

func handleClient(client net.Conn) {
	defer client.Close()
	tuneTCP(client)

	rawIP, _, _ := net.SplitHostPort(client.RemoteAddr().String())
	rawIP = strings.TrimPrefix(rawIP, "::ffff:")
	dport := ""

	_ = client.SetReadDeadline(time.Now().Add(2000 * time.Millisecond))
	buf := make([]byte, 16384)
	n, _ := client.Read(buf)
	_ = client.SetReadDeadline(time.Time{})
	data := buf[:n]

	if bytes.HasPrefix(data, []byte("PROXY ")) {
		if idx := bytes.Index(data, []byte("\r\n")); idx != -1 {
			fields := strings.Fields(string(data[:idx]))
			if len(fields) >= 3 && fields[2] != "127.0.0.1" {
				rawIP = fields[2]
			}
			if len(fields) >= 6 {
				dport = fields[5]
			}
			data = data[idx+2:]
		}
	}
	if len(data) == 0 {
		_ = client.SetReadDeadline(time.Now().Add(300 * time.Millisecond))
		n2, _ := client.Read(buf)
		_ = client.SetReadDeadline(time.Time{})
		data = buf[:n2]
	}

	var target net.Conn
	var err error
	var lportKey string
	var entry *PortEntry
	modeLabel := "SSH-WS"

	// 1. Check HTTP/2 Preface (gRPC / H2 XHTTP)
	if bytes.HasPrefix(data, []byte("PRI * HTTP/2.0")) {
		target, err = net.DialTimeout("tcp", "127.0.0.1:8082", 3*time.Second)
		if err != nil {
			return
		}
		tuneTCP(target)
		defer target.Close()
		_, lportKey, _ = net.SplitHostPort(target.LocalAddr().String())
		_, _ = target.Write(buildProxyHeader(rawIP))
		_, _ = target.Write(data)
		entry = &PortEntry{IP: rawIP, Mode: "XRAY-GRPC", Bytes: 0, Open: true, Ts: time.Now().Unix()}
		portMap.Store("xray-"+lportKey, entry)
		writeMapNow()
		defer func() {
			entry.Open = false
			portMap.Delete("xray-" + lportKey)
			writeMapNow()
		}()
		done := make(chan struct{}, 2)
		go func() {
			_, _ = copyBig(&byteCounter{w: target, entry: entry}, client)
			_ = target.Close()
			done <- struct{}{}
		}()
		go func() {
			_, _ = copyBig(&byteCounter{w: client, entry: entry}, target)
			_ = client.Close()
			done <- struct{}{}
		}()
		<-done
		return
	}

	if len(data) == 0 || bytes.HasPrefix(data, []byte("SSH-")) {
		modeLabel = "SSH-SSL/Direct"
		target, err = dialLocalSSH()
		if err != nil {
			return
		}
		_, lportKey, _ = net.SplitHostPort(target.LocalAddr().String())
		if len(data) > 0 {
			_, _ = target.Write(data)
		}
	} else {
		reqStr := string(data)
		rawIP = extractHeaderIP(reqStr, rawIP)
		firstLine := strings.TrimSpace(strings.Split(reqStr, "\n")[0])
		flLower := strings.ToLower(firstLine)

		// 2. Check Web Config Download (.html / .ovpn / .zip)
		if strings.Contains(flLower, ".html") || strings.Contains(flLower, ".ovpn") || strings.Contains(flLower, ".zip") {
			target, err = net.DialTimeout("tcp", "127.0.0.1:8081", 3*time.Second)
			if err != nil {
				return
			}
			defer target.Close()
			_, _ = target.Write(buildProxyHeader(rawIP))
			_, _ = target.Write(data)
			go func() { _, _ = copyBig(target, client); _ = target.Close() }()
			_, _ = copyBig(client, target)
			return
		}

		// 2b. Web Panel via domain (80/443, no extra port)
		if isPanelRequest(firstLine, reqStr) {
			viaHTTPS := strings.EqualFold(reqHeader(reqStr, "X-Forwarded-Proto"), "https") || strings.Contains(strings.ToLower(reqHeader(reqStr, "Cf-Visitor")), "https")
			if strings.HasPrefix(firstLine, "GET ") && plainPorts[dport] && !viaHTTPS {
				host := reqHeader(reqStr, "Host")
				if h, _, e := net.SplitHostPort(host); e == nil {
					host = h
				}
				fl2 := strings.Fields(firstLine)
				if host != "" && len(fl2) >= 2 {
					_, _ = client.Write([]byte("HTTP/1.1 301 Moved Permanently\r\nLocation: https://" + host + fl2[1] + "\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"))
					return
				}
			}
			target, err = net.DialTimeout("tcp", "127.0.0.1:8081", 3*time.Second)
			if err != nil {
				return
			}
			defer target.Close()
			_, _ = target.Write(buildProxyHeader(rawIP))
			_, _ = target.Write(data)
			go func() { _, _ = copyBig(target, client); _ = target.Close() }()
			_, _ = copyBig(client, target)
			return
		}

		// 3. Check Xray WS / HTTPUpgrade / XHTTP (Direct, Cloudflare, or BunnyCDN)
		if xMode := detectXrayMode(firstLine); xMode != "" {
			if strings.Contains(strings.ToLower(reqStr), "b-cdn.net") || strings.Contains(strings.ToLower(reqStr), "bunny") {
				xMode = "BUNNY-" + xMode
			}
			target, err = net.DialTimeout("tcp", "127.0.0.1:8081", 3*time.Second)
			if err != nil {
				return
			}
			tuneTCP(target)
			defer target.Close()
			_, lportKey, _ = net.SplitHostPort(target.LocalAddr().String())
			_, _ = target.Write(buildProxyHeader(rawIP))
			_, _ = target.Write(data)
			mapKey := "xray-" + lportKey
			if strings.Contains(xMode, "XHTTP") {
				mapKey = "xhttp-" + rawIP
			}
			entry = &PortEntry{IP: rawIP, Mode: xMode, Bytes: 0, Open: true, Ts: time.Now().Unix()}
			portMap.Store(mapKey, entry)
			writeMapNow()
			defer func() {
				entry.Open = false
				if !strings.Contains(xMode, "XHTTP") {
					portMap.Delete(mapKey)
				}
				writeMapNow()
			}()
			done := make(chan struct{}, 2)
			go func() {
				_, _ = copyBig(&byteCounter{w: target, entry: entry}, client)
				_ = target.Close()
				done <- struct{}{}
			}()
			go func() {
				_, _ = copyBig(&byteCounter{w: client, entry: entry}, target)
				_ = client.Close()
				done <- struct{}{}
			}()
			<-done
			return
		}

		// 4. SSH-SSL (CONNECT) or SSH-WS / BunnyCDN SSH-WS
		if strings.HasPrefix(strings.ToUpper(firstLine), "CONNECT ") && !strings.Contains(strings.ToLower(reqStr), "upgrade: websocket") {
			modeLabel = "SSH-SSL"
			target, err = dialLocalSSH()
			if err != nil {
				return
			}
			_, lportKey, _ = net.SplitHostPort(target.LocalAddr().String())
			if sep := bytes.Index(data, []byte("\r\n\r\n")); sep != -1 && sep+4 < len(data) {
				clean := stripExtraPayloads(data[sep+4:])
				if len(clean) > 0 {
					_, _ = target.Write(clean)
				}
			}
		} else {
			modeLabel = "SSH-WS"
			if strings.Contains(strings.ToLower(reqStr), "b-cdn.net") || strings.Contains(strings.ToLower(reqStr), "bunny") {
				modeLabel = "BUNNY-SSH"
			}
			target, err = dialLocalSSH()
			if err != nil {
				return
			}
			_, lportKey, _ = net.SplitHostPort(target.LocalAddr().String())
			_, _ = client.Write([]byte("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n"))
			if sep := bytes.Index(data, []byte("\r\n\r\n")); sep != -1 && sep+4 < len(data) {
				clean := stripExtraPayloads(data[sep+4:])
				if len(clean) > 0 {
					_, _ = target.Write(clean)
				}
			}
		}
	}

	defer target.Close()
	if lportKey != "" {
		entry = &PortEntry{IP: rawIP, Mode: modeLabel, Bytes: 0, Open: true, Ts: time.Now().Unix()}
		portMap.Store(lportKey, entry)
		writeMapNow()
		defer func() {
			entry.Open = false
			portMap.Delete(lportKey)
			writeMapNow()
		}()
	}

	done := make(chan struct{}, 2)
	go func() {
		bufUp := make([]byte, 262144)
		firstChunk := true
		for {
			nr, er := client.Read(bufUp)
			if nr > 0 {
				chunk := bufUp[:nr]
				if firstChunk {
					firstChunk = false
					chunk = stripExtraPayloads(chunk)
				}
				if len(chunk) > 0 {
					nw, ew := target.Write(chunk)
					if nw > 0 && entry != nil {
						atomic.AddInt64(&entry.Bytes, int64(nw))
						atomic.StoreInt64(&entry.Ts, time.Now().Unix())
					}
					if ew != nil {
						break
					}
				}
			}
			if er != nil {
				break
			}
		}
		_ = target.Close()
		done <- struct{}{}
	}()
	go func() {
		bufDown := make([]byte, 262144)
		_, _ = io.CopyBuffer(&byteCounter{w: client, entry: entry}, target, bufDown)
		_ = client.Close()
		done <- struct{}{}
	}()
	<-done
}

func main() {
	runtime.GOMAXPROCS(runtime.NumCPU())
	go mapWriterDaemon()
	go cdnLoader()
	ln, err := net.Listen("tcp", "0.0.0.0:10000")
	if err != nil {
		return
	}
	for {
		c, err := ln.Accept()
		if err == nil {
			go handleClient(c)
		}
	}
}
EOF
    local GO_BIN=$(command -v go || echo "/usr/local/go/bin/go")
    if [[ -x "$GO_BIN" ]]; then
        export GOPATH="/tmp/go-ws" GOCACHE="/tmp/go-ws-cache"
        (cd "$WS_DIR" && timeout 240 "$GO_BIN" build -o "$WS_DIR/aliraza-ws-go" ws.go 2>/dev/null || true)
        chmod +x "$WS_DIR/aliraza-ws-go" 2>/dev/null || true
    fi
    if [[ ! -x "$WS_DIR/aliraza-ws-go" ]]; then
        echo -e "${RED}[X] WS Engine build FAIL! SSH-WS/SSL (ports 80/443) iske baghair nahi chalenge.${NC}"
        echo -e "${RED}    Fix: Panel ka Auto-Doctor dobara chalayein ya 'go version' check karein.${NC}"
    fi
    cat << EOF > /etc/systemd/system/aliraza-ws.service
[Unit]
Description=ALIRAZA Multi-Core Golang WS/SSL Engine
After=network.target dropbear.service nginx.service
[Service]
Nice=-15
ExecStart=$WS_DIR/aliraza-ws-go
Restart=always
RestartSec=2s
User=root
LimitNOFILE=1000000
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload && systemctl enable aliraza-ws 2>/dev/null && systemctl restart aliraza-ws 2>/dev/null || true
    configure_haproxy_c_mux
    [[ -x "$WS_DIR/aliraza-ws-go" && -f /etc/systemd/system/stunnel4.service ]] && stunnel_apply_backend >/dev/null 2>&1 || true
}
# ============================================================================
# UPGRADED LIVE SIM IP ENGINE (WORKS EVEN AFTER CLEAN LOGS & MULTI-USER!)
# ============================================================================
get_live_client_ips_table() {
    install_liveips_helper 2>/dev/null || true
    python3 /usr/local/bin/aliraza-liveips.py 2>/dev/null
}

# ============================================================================
# v55.4-HOTFIX: AUTH-ONLY REAL SIM IP ENGINE (panel + Telegram bot SHARED source)
# 1) Cloudflare/BunnyCDN ke EDGE IPs ko kabhi SIM IP nahi dikhata (FAKE display fix)
# 2) Sirf AUTHENTICATED user sessions dikhata hai (scanner/spoof/bots = show NAHI)
# 3) Xray WS/HUP/XHTTP/gRPC ka real SIM IP Golang Engine ke CF-Connecting-IP
#    extraction se aata hai, Xray access log sirf DIRECT protocols (Vision/Reality/
#    mKCP/SS/Socks) ke liye use hota hai
# ============================================================================
install_openssh_toggle() {
    cat << 'OSSH_EOF' > /usr/local/bin/aliraza-openssh
#!/usr/bin/env bash
echo "OpenSSH PERMANENT remove hai. Sirf Dropbear (port 80) chalta hai: ssh -p 80 root@SERVER_IP"
OSSH_EOF
    chmod +x /usr/local/bin/aliraza-openssh
}

install_cdn_updater() {
    cat << 'CDNUPD_EOF' > /usr/local/bin/aliraza-cdn-update.sh
#!/usr/bin/env bash
# Cloudflare + Bunny edge IP lists update (fail hone par purani/builtin list chalti rahti hai)
D=/etc/aliraza; mkdir -p "$D"
T1=$(mktemp); T2=$(mktemp)
for u in https://www.cloudflare.com/ips-v4 https://www.cloudflare.com/ips-v6; do
    curl -fsS --max-time 15 "$u" 2>/dev/null | grep -E '^[0-9a-fA-F:.]+(/[0-9]+)?$' >> "$T1"
done
for u in https://bunnycdn.com/api/system/edgeserverlist https://bunnycdn.com/api/system/edgeserverlist/IPv6; do
    curl -fsS --max-time 20 "$u" 2>/dev/null | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}|[0-9a-fA-F]*:[0-9a-fA-F:]+' >> "$T2"
done
[[ $(wc -l < "$T1") -ge 10 ]] && cp -f "$T1" "$D/cf_ips.txt"
[[ $(wc -l < "$T2") -ge 10 ]] && cp -f "$T2" "$D/cdn_ips.txt"
rm -f "$T1" "$T2"
rm -f /run/aliraza_liveips.cache 2>/dev/null
exit 0
CDNUPD_EOF
    chmod +x /usr/local/bin/aliraza-cdn-update.sh
    echo '17 4 * * * root /usr/local/bin/aliraza-cdn-update.sh >/dev/null 2>&1' > /etc/cron.d/aliraza-cdn
    ( /usr/local/bin/aliraza-cdn-update.sh >/dev/null 2>&1 & ) 2>/dev/null || true
}

install_liveips_helper() {
    cat << 'LIVEIPS_EOF' > /usr/local/bin/aliraza-liveips.py
#!/usr/bin/env python3
import os, sys, json, subprocess, re, datetime, ipaddress, pwd, time, urllib.request

USERS_DB = "/etc/aliraza/users.db"
WS_MAP_FILE = "/run/aliraza_ws_map.json"
ACTIVE_U_FILE = "/run/aliraza_active_users.json"
XRAY_LOG = "/var/log/xray/access.log"
VPS_IP_FILE = "/etc/aliraza/vps_ip.txt"
CACHE_FILE = "/run/aliraza_liveips.cache"
CACHE_TTL = 1

_CF_NETS = (
    "173.245.48.0/20", "103.21.244.0/22", "103.22.200.0/22", "103.31.4.0/22",
    "141.101.64.0/18", "108.162.192.0/18", "190.93.240.0/20", "188.114.96.0/20",
    "197.234.240.0/22", "198.41.128.0/17", "162.158.0.0/15", "104.16.0.0/13",
    "104.24.0.0/14", "172.64.0.0/13", "131.0.72.0/22",
    "2400:cb00::/32", "2606:4700::/32", "2803:f800::/32", "2405:b500::/32",
    "2405:8100::/32", "2a06:98c0::/29", "2c0f:f248::/32")

def _load_cdn_nets():
    nets = []
    for n in _CF_NETS:
        nets.append(ipaddress.ip_network(n))
    for fn in ("/etc/aliraza/cf_ips.txt", "/etc/aliraza/cdn_ips.txt"):
        try:
            for ln in open(fn, errors="ignore"):
                ln = ln.strip()
                if not ln or ln.startswith("#"): continue
                try: nets.append(ipaddress.ip_network(ln, strict=False))
                except Exception: pass
        except Exception:
            pass
    return nets

CDN_NETS = _load_cdn_nets()

vps_ip = ""
if os.path.exists(VPS_IP_FILE):
    try: vps_ip = open(VPS_IP_FILE).read().split()[0]
    except Exception: vps_ip = ""

def clean_ip(ip):
    return str(ip or "").strip().strip("[]").replace("::ffff:", "")

def is_cdn_ip(ip):
    try:
        a = ipaddress.ip_address(ip)
        return any(a in n for n in CDN_NETS)
    except Exception:
        return False

def is_real_sim_ip(ip):
    ip = clean_ip(ip)
    if not ip or ip == vps_ip: return False
    if is_cdn_ip(ip): return False
    try:
        a = ipaddress.ip_address(ip)
        return a.is_global and not (a.is_private or a.is_loopback or a.is_link_local or a.is_multicast or a.is_reserved)
    except Exception:
        return False

AUTHMAP_FILE = "/run/aliraza_authmap.json"

def ss_estab():
    # Robust ss parser: ss ka State column ho ya na ho, dono layouts me sahi chalta hai.
    # Returns [(local, peer, [pids])] sirf ESTABLISHED sockets ke liye.
    out = ""
    for args in (["ss", "-H", "-tnp"], ["ss", "-tnp"]):
        try:
            out = subprocess.check_output(args, text=True, stderr=subprocess.DEVNULL, timeout=6)
            break
        except Exception:
            continue
    rows = []
    for ln in out.splitlines():
        cols = ln.split()
        if len(cols) < 4: continue
        if cols[0].upper().startswith("ESTAB"): off = 1
        elif cols[0].isdigit(): off = 0
        else: continue
        if len(cols) < off + 4: continue
        rows.append((cols[off + 2], cols[off + 3], re.findall(r"pid=(\d+)", ln)))
    return rows

def _parse_auth_msg(msg):
    low = msg.lower()
    if "auth succeeded" not in low and "accepted password for" not in low and "accepted publickey for" not in low:
        return None
    m_u = re.search(r"for '([^']+)'", msg) or re.search(r"for (\S+)", msg)
    if not m_u: return None
    prt = ""
    m_p = re.search(r"from \S+ port (\d+)", msg)
    if m_p:
        prt = m_p.group(1)
    else:
        m_f = re.search(r"from (\S+)", msg)
        if m_f and ":" in m_f.group(1):
            prt = m_f.group(1).rstrip(".,;>").rsplit(":", 1)[-1]
    return m_u.group(1), prt

def _feed_auth(st, pid, msg, valid_set):
    # Dropbear -E format: "[pid] Mon DD HH:MM:SS message"
    m = re.match(r"^\[(\d+)\]\s+\w{3}\s+\d+\s+[\d:]+\s+(.*)$", msg)
    if m:
        pid, msg = m.group(1), m.group(2)
    if not pid: return
    if msg.startswith("Exit"):
        st["pid"].pop(pid, None)
        for k in [k for k in st["pair"] if k.startswith(pid + ":")]:
            st["pair"].pop(k, None)
        return
    r = _parse_auth_msg(msg)
    if r and r[0] in valid_set:
        st["pid"][pid] = r[0]
        if r[1]: st["pair"][pid + ":" + r[1]] = r[0]

_AUTHLOG_SIG = [None]

def load_auth_maps(valid_set, refresh=True):
    # v59: journald cursor se sirf NAYI lines parh kar pid->user / (pid,port)->user map file me rakhta hai.
    # Pehle har baar 24h ka poora journal parh ke 5s timeout me fail hota tha -> load me users ghayab.
    st = {"cursor": "", "pid": {}, "pair": {}}
    try:
        d = json.loads(open(AUTHMAP_FILE).read())
        if isinstance(d, dict):
            st["cursor"] = d.get("cursor", "") or ""
            st["pid"] = d.get("pid", {}) or {}
            st["pair"] = d.get("pair", {}) or {}
    except Exception:
        pass
    if not refresh:
        # v59.7: journalctl spawn sirf tab jab koi naya/unresolved socket ho (har 250ms par spawn = live IP late)
        for p in list(st["pid"]):
            if not os.path.isdir("/proc/" + p): st["pid"].pop(p, None)
        for k in list(st["pair"]):
            if not os.path.isdir("/proc/" + k.split(":")[0]): st["pair"].pop(k, None)
        return st
    base = ["journalctl", "-u", "dropbear", "-o", "json", "--no-pager", "-q"]
    def run(extra):
        return subprocess.check_output(base + extra, text=True, stderr=subprocess.DEVNULL, timeout=8)
    out = ""
    try:
        out = run(["--after-cursor=" + st["cursor"]] if st["cursor"] else ["-n", "20000"])
    except Exception:
        if st["cursor"]:
            st["cursor"] = ""
            try: out = run(["-n", "20000"])
            except Exception: out = ""
    last_cur = st["cursor"]
    for ln in out.splitlines():
        try: d = json.loads(ln)
        except Exception: continue
        cur = d.get("__CURSOR")
        if cur: last_cur = cur
        msg = d.get("MESSAGE", "")
        if isinstance(msg, str):
            _feed_auth(st, str(d.get("_PID", "") or ""), msg, valid_set)
    # purana /var/log/auth.log (agar maujood ho) bhi merge
    _sig = None
    try: _s = os.stat("/var/log/auth.log"); _sig = (_s.st_mtime_ns, _s.st_size)
    except Exception: pass
    if _sig is not None and _sig != _AUTHLOG_SIG[0]:
        _AUTHLOG_SIG[0] = _sig
        try:
            for ln in subprocess.check_output(["tail", "-n", "2000", "/var/log/auth.log"], text=True, stderr=subprocess.DEVNULL, timeout=3).splitlines():
                m = re.search(r"(?:dropbear|sshd)\[(\d+)\]:\s*(.*)$", ln)
                if m: _feed_auth(st, m.group(1), m.group(2), valid_set)
        except Exception:
            pass
    for p in list(st["pid"]):
        if not os.path.isdir("/proc/" + p): st["pid"].pop(p, None)
    for k in list(st["pair"]):
        if not os.path.isdir("/proc/" + k.split(":")[0]): st["pair"].pop(k, None)
    st["cursor"] = last_cur
    try:
        tmp = AUTHMAP_FILE + ".tmp%d" % os.getpid()
        open(tmp, "w").write(json.dumps(st))
        os.replace(tmp, AUTHMAP_FILE)
    except Exception:
        pass
    return st

def ss_bytes():
    # {(local, peer): ss -i info line} - direct socket ke bytes_acked/bytes_received ke liye
    out = ""
    for args in (["ss", "-H", "-tni"], ["ss", "-tni"]):
        try:
            out = subprocess.check_output(args, text=True, stderr=subprocess.DEVNULL, timeout=6)
            break
        except Exception:
            continue
    res = {}
    lines = out.splitlines()
    i = 0
    while i < len(lines):
        cols = lines[i].split()
        info = ""
        if i + 1 < len(lines) and lines[i + 1][:1] in ("\t", " "):
            info = lines[i + 1]; i += 2
        else:
            i += 1
        if len(cols) < 4: continue
        if cols[0].upper().startswith("ESTAB"): off = 1
        elif cols[0].isdigit(): off = 0
        else: continue
        if len(cols) < off + 4: continue
        res[(cols[off + 2], cols[off + 3])] = info
    return res

_UNRES = {}
def _need_refresh(keys):
    # naya socket: 3s tak har 0.15s retry (auth abhi journal me aa raha ho sakta hai); phir har 10s
    now = time.time(); need = False
    live = set(keys)
    for k in list(_UNRES):
        if k not in live: _UNRES.pop(k, None)
    for k in keys:
        e = _UNRES.get(k)
        if e is None:
            e = _UNRES[k] = [now, 0.0]
        gap = 0.15 if now - e[0] < 3 else 10.0
        if now - e[1] >= gap:
            e[1] = now; need = True
    return need

def _ssh_unresolved(am, rows):
    keys = []
    for loc, peer, pids in rows:
        if loc.rsplit(":", 1)[-1] != "10022": continue
        pp = peer.rsplit(":", 1)[-1]
        ok = False
        for p in pids:
            if am["pair"].get(p + ":" + pp) or am["pid"].get(p): ok = True; break
        if not ok: keys.append((tuple(sorted(pids)), peer))
    return keys

def _auth_for(valid_set, rows):
    am = load_auth_maps(valid_set, refresh=False)
    if _need_refresh(_ssh_unresolved(am, rows)):
        am = load_auth_maps(valid_set)
    return am

def resolve_ssh_sockets(valid_set):
    # Dropbear (internal port 10022) ke har ESTABLISHED socket ka verified user -> [(local, peer, user)]
    rows = ss_estab()
    am = _auth_for(valid_set, rows)
    out = []
    for loc, peer, pids in rows:
        if loc.rsplit(":", 1)[-1] != "10022": continue
        pp = peer.rsplit(":", 1)[-1]
        u = None
        for p in pids:
            u = am["pair"].get(p + ":" + pp) or am["pid"].get(p)
            if u: break
        if u and u in valid_set: out.append((loc, peer, u))
    return out

def build_peers():
    valid_users = []
    if os.path.exists(USERS_DB):
        for line in open(USERS_DB, errors="ignore"):
            pts = line.strip().split("|")
            if len(pts) >= 7 and pts[6] == "UNLOCKED":
                valid_users.append(pts[0])
    if not valid_users:
        return {}
    valid_set = set(valid_users)
    single_user = valid_users[0] if len(valid_users) == 1 else ""

    peers = {}
    def add_peer(ip, proto_label, user, sid="-", verified=True):
        # sid = asli session id (SSH tunnel / socket). Alag sid = alag device/session -> count badhta hai.
        ip = clean_ip(ip)
        if not is_real_sim_ip(ip): return
        tag = ("%s(%s)" % (proto_label, user)) if user else proto_label
        if ip not in peers:
            peers[ip] = {"ports": set(), "tunnels": 0, "sess": {}}
        peers[ip]["ports"].add(tag)
        if verified: peers[ip].setdefault("ver", set()).add(tag)
        peers[ip]["sess"].setdefault(tag, set()).add(str(sid))
        peers[ip]["tunnels"] = sum(len(v) for v in peers[ip]["sess"].values())

    ws_map = {}
    if os.path.exists(WS_MAP_FILE):
        try: ws_map = json.loads(open(WS_MAP_FILE).read())
        except Exception: ws_map = {}

    active_u_map = {}
    if os.path.exists(ACTIVE_U_FILE):
        try: active_u_map = json.loads(open(ACTIVE_U_FILE).read())
        except Exception: active_u_map = {}

    now_ts = int(time.time())
    rx_live = next((u for u, ts in sorted(active_u_map.items(), key=lambda x: -x[1]) if u in valid_set and now_ts - int(ts) < 30), "")

    pid_to_user = {}
    for pid_dir in os.listdir("/proc"):
        if not pid_dir.isdigit(): continue
        p_path = "/proc/" + pid_dir
        try:
            uid = os.stat(p_path).st_uid
            if uid >= 1000:
                uname = pwd.getpwuid(uid).pw_name
                if uname in valid_set:
                    pid_to_user[pid_dir] = uname
                    continue
        except Exception:
            pass
        try:
            cmd = open(p_path + "/cmdline", "rb").read().replace(b"\x00", b" ").decode("utf-8", errors="ignore").strip()
            m = re.search(r"sshd(?:-session)?:\s*([a-zA-Z0-9_-]+)", cmd)
            if m and m.group(1) in valid_set:
                pid_to_user[pid_dir] = m.group(1)
        except Exception:
            pass

    SS = ss_estab()
    am = _auth_for(valid_set, SS)
    auth_by_pid = {p: u for p, u in am["pid"].items() if u in valid_set}
    auth_pair = {}
    for k, u in am["pair"].items():
        if u in valid_set:
            _a, _, _b = k.partition(":")
            auth_pair[(_a, _b)] = u
    auth_by_port = {}

    def who(pids, p_port):
        # user sirf LIVE socket ke pid (+client port) se verify hota hai - purane/ghost log se galat user nahi
        for p in pids:
            if p in pid_to_user: return pid_to_user[p]
        for p in pids:
            u = auth_pair.get((p, p_port))
            if u: return u
        for p in pids:
            u = auth_by_pid.get(p)   # Dropbear child pid ek hi session ka hota hai
            if u: return u
        return None if pids else auth_by_port.get(p_port)

    # pre-pass: SSH-side socket peer-port -> user (pid based, no auth.log dependency)
    port_user = {}
    live_ports = set()
    for _loc, _peer, _pids in SS:
        if _loc.rsplit(":", 1)[-1] != "10022": continue
        pp = _peer.rsplit(":", 1)[-1]
        live_ports.add(pp)
        uu = who(_pids, pp)
        if uu: port_user[pp] = uu

    # v58.1: Xray log se IP -> user exact mapping (multi-user me galat user na dikhe)
    xray_ip_user = {}
    if os.path.exists(XRAY_LOG):
        try:
            _now = datetime.datetime.now()
            for ln in _xlog_lines(800):
                if "accepted" not in ln or "email:" not in ln: continue
                m_ts = re.match(r"^(\d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2})", ln)
                if m_ts and abs((_now - datetime.datetime.strptime(m_ts.group(1), "%Y/%m/%d %H:%M:%S")).total_seconds()) > 120: continue
                eu = ln.split("email:")[-1].strip().split()[0]
                mi = re.search(r"from (?:tcp:|udp:)?([0-9a-fA-F:\.]+):\d+", ln)
                if eu in valid_set and mi: xray_ip_user[clean_ip(mi.group(1))] = eu
        except Exception:
            pass

    # 1) Golang WS/SSL Engine live tunnels (yahan REAL SIM IP header se aati hai)
    for lport_key, wentry in ws_map.items():
        if not wentry.get("open", True): continue
        wip, wmode = wentry.get("ip", ""), wentry.get("mode", "SSH-WS")
        if any(k in wmode for k in ("VLESS", "VMESS", "TROJAN", "XRAY")):
            u = xray_ip_user.get(clean_ip(wip)); _ver = bool(u)
            if not u and rx_live:
                # v59.2: bina auth/traffic wali khali connection ko online na dikhao
                _ets = int(wentry.get("ts", 0) or 0); _eby = int(wentry.get("bytes", 0) or 0)
                if _ets and now_ts - _ets < 45 and _eby > 3000: u = rx_live
            if u: add_peer(wip, wmode, u, verified=_ver)
        else:
            u = port_user.get(lport_key)
            # v58.2: sirf LIVE socket (pid+port verified) ka user - ghost/purane log se galat user nahi
            if u: add_peer(wip, wmode, u, "t" + str(lport_key))

    # 2) Xray access log = sirf DIRECT protocols (Vision/Reality/mKCP/SS/Socks)
    if os.path.exists(XRAY_LOG):
        try:
            now_dt = datetime.datetime.now()
            xlines = _xlog_lines(600)
            for ln in reversed(xlines):
                if "accepted" not in ln or "email:" not in ln: continue
                m_ts = re.match(r"^(\d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2})", ln)
                if m_ts and abs((now_dt - datetime.datetime.strptime(m_ts.group(1), "%Y/%m/%d %H:%M:%S")).total_seconds()) > 45:
                    continue
                u = ln.split("email:")[-1].strip().split()[0]
                if u not in valid_set: continue
                m_tag = re.search(r"\[([a-z0-9-]+)\s*(?:->|>>)", ln)
                lbl = (m_tag.group(1).upper() if m_tag else "XRAY")
                # WS family ka real IP Engine map se aati hai, log ka IP CDN hota hai
                if lbl.endswith("-WS") or "-XHTTP" in lbl or "HTTPUPGRADE" in lbl or lbl.endswith("-GRPC"):
                    continue
                m_ip = re.search(r"from (?:tcp:|udp:)?([0-9a-fA-F:\.]+):\d+", ln)
                if m_ip: add_peer(m_ip.group(1), lbl, u)
        except Exception:
            pass

    # 3) Direct Dropbear (internal 10022) / Stunnel sockets (AUTH-gated only)
    stunnel_ips = []
    try:
        for loc, peer, _pids in SS:
            _lp = loc.rsplit(":", 1)[-1]
            if _lp in ("444", "8443", "992"):
                _pi = clean_ip(peer.rsplit(":", 1)[0])
                if is_real_sim_ip(_pi): stunnel_ips.append((_pi, _lp))
        for loc, peer, pids in SS:
            lport = loc.rsplit(":", 1)[-1]
            p_ip = clean_ip(peer.rsplit(":", 1)[0])
            p_port = peer.rsplit(":", 1)[-1]
            if lport in ("10022",):
                u = who(pids, p_port)
                if not u: continue
                if p_ip == "127.0.0.1" and p_port in ws_map and ws_map[p_port].get("open", True):
                    continue
                if is_real_sim_ip(p_ip):
                    add_peer(p_ip, "DROPBEAR", u, "d" + p_port)
                elif p_ip == "127.0.0.1":
                    # engine ke bagair aaya stunnel socket: sirf tab jab ek hi stunnel IP ho (warna galat IP dene se behtar hai na dena)
                    _uniq = sorted(set(x[0] for x in stunnel_ips))
                    if len(_uniq) == 1:
                        add_peer(_uniq[0], "STUNNEL-" + stunnel_ips[0][1], u, "s" + p_port)
            elif lport in ("8444", "10013", "10015", "8888", "10808", "10809") and is_real_sim_ip(p_ip):
                u = rx_live
                if u:
                    lbl = "VLESS-VISION" if lport == "8444" else ("VLESS-REALITY" if lport == "10013" else ("SOCKS5" if lport == "10808" else "SS/PROXY"))
                    add_peer(p_ip, lbl, u, verified=False)
    except Exception:
        pass

    # 4) OpenVPN status logs
    for ovpn_log in ("/var/log/openvpn-tcp.log", "/var/log/openvpn-udp.log"):
        if os.path.exists(ovpn_log):
            try:
                for ln in open(ovpn_log, errors="ignore"):
                    if ln.startswith("CLIENT_LIST"):
                        pts = ln.strip().split(",")
                        if len(pts) >= 3 and pts[1] in valid_set:
                            add_peer(pts[2].rsplit(":", 1)[0], "OPENVPN", pts[1])
            except Exception:
                pass

    # 5) ASSURED UDP conntrack (ZiVPN / UDP-Custom / Hysteria2 / mKCP)
    hy_u = ""
    try:
        with urllib.request.urlopen("http://127.0.0.1:9999/online", timeout=0.3) as r:
            hy_data = json.loads(r.read().decode())
            hy_u = next((k for k in hy_data if k in valid_set), "")
    except Exception:
        pass
    ssh_active = sorted(set(pid_to_user.values()))
    udp_guess = single_user or (ssh_active[0] if len(ssh_active) == 1 else "")
    try: _udp_stream = int(open("/proc/sys/net/netfilter/nf_conntrack_udp_timeout_stream").read().strip())
    except Exception: _udp_stream = 120
    _udp_fresh = max(_udp_stream - 40, 1)
    if os.path.exists("/proc/net/nf_conntrack"):
        try:
            for ln in _ct_lines():
                if "udp" not in ln or "[ASSURED]" not in ln: continue
                _mt = re.search(r"udp\s+17\s+(\d+)", ln)
                if _mt and int(_mt.group(1)) < _udp_fresh: continue
                m_src = re.search(r"src=([0-9\.]+)\s+dst=[0-9\.]+\s+sport=\d+\s+dport=(\d+)\s+packets=(\d+)", ln)
                if m_src and int(m_src.group(3)) > 15:
                    src_ip, dport = m_src.group(1), m_src.group(2)
                    if not is_real_sim_ip(src_ip): continue
                    if dport == "5667": add_peer(src_ip, "ZIVPN-UDP", udp_guess, verified=False)
                    elif dport == "36712": add_peer(src_ip, "UDP-CUSTOM", udp_guess, verified=False)
                    elif dport == "20800" and hy_u: add_peer(src_ip, "HYSTERIA2", hy_u, verified=False)
                    elif dport == "10014":
                        u = rx_live
                        if u: add_peer(src_ip, "VLESS-MKCP", u, verified=False)
        except Exception:
            pass
    return peers

_XL = [0.0, []]
def _xlog_lines(n=1500):
    # v59.7: `tail` subprocess spawn hata diya (cycle me 2 baar fork hota tha) - seedha last 128KB parh kar, 0.1s cache
    now = time.time()
    if now - _XL[0] > 0.1:
        ls = []
        try:
            with open(XRAY_LOG, "rb") as f:
                f.seek(0, 2); sz = f.tell(); f.seek(max(0, sz - 131072))
                ls = f.read().decode("utf-8", "ignore").splitlines()
            if sz > 131072 and ls: ls = ls[1:]
        except Exception:
            ls = []
        _XL[0] = now; _XL[1] = ls
    return _XL[1][-n:]

_CT = [0.0, []]
def _ct_lines():
    # nf_conntrack bada ho sakta hai - har cycle poora parhna live IP ko slow karta tha; sirf ASSURED UDP lines, 1s cache
    now = time.time()
    if now - _CT[0] < 1.0: return _CT[1]
    out = []
    try:
        for ln in open("/proc/net/nf_conntrack", errors="ignore"):
            if "udp" in ln and "[ASSURED]" in ln: out.append(ln)
    except Exception:
        pass
    _CT[0] = now; _CT[1] = out
    return out

def verified_user_ips(peers=None):
    # {user: set(ip)} - sirf VERIFIED attribution (auth log / xray email / openvpn). rx_live / udp_guess wale andaze shamil nahi.
    # IP-limit enforcement isi se hota hai taake galat user ka account na lock ho.
    if peers is None: peers = build_peers()
    res = {}
    for ip, info in peers.items():
        for tag in info.get("ver", ()):
            m = re.match(r"^(.+)\(([^)]+)\)$", tag)
            if m: res.setdefault(m.group(2), set()).add(ip)
    return res

def _cnt(v):
    return len(v) if isinstance(v, (set, list)) else int(v)

def render(peers, bot_mode):
    rows = []
    for idx, (ip, info) in enumerate(sorted(peers.items()), 1):
        sess = info.get("sess", {})
        if bot_mode:
            tags = []
            for t in sorted(info["ports"]):
                n = _cnt(sess.get(t, 1))
                tags.append(t + (" x%d" % n if n > 1 else ""))
            rows.append("- " + ip + " -> " + ",".join(tags))
        else:
            sc = ";".join("%s=%d" % (t, _cnt(sess.get(t, 1))) for t in sorted(info["ports"]))
            rows.append("%d|%s|%s|%d|%s" % (idx, ip, ",".join(sorted(info["ports"])), info["tunnels"], sc))
    return rows

def main():
    bot_mode = "--bot" in sys.argv
    if "--bench" in sys.argv:
        for _i in range(5):
            _t0 = time.time(); _pe = build_peers()
            print("build_peers: %d ms, %d live ips" % (int((time.time() - _t0) * 1000), len(_pe)))
        return
    try:
        if os.path.exists(CACHE_FILE) and time.time() - os.path.getmtime(CACHE_FILE) < CACHE_TTL:
            raw = open(CACHE_FILE, errors="ignore").read().splitlines()
            peers = {}
            for ln in raw:
                pts = ln.split("|")
                if len(pts) >= 4:
                    sess = {}
                    if len(pts) >= 5:
                        for kv in pts[4].split(";"):
                            if "=" in kv:
                                k, _, v = kv.rpartition("=")
                                try: sess[k] = int(v)
                                except Exception: pass
                    peers[pts[1]] = {"ports": set(x for x in pts[2].split(",") if x), "tunnels": int(pts[3] or 1), "sess": sess}
            out = render(peers, bot_mode)
            if out: print("\n".join(out))
            return
    except Exception:
        pass
    peers = build_peers()
    canonical = render(peers, False)
    try: open(CACHE_FILE, "w").write("\n".join(canonical) + ("\n" if canonical else ""))
    except Exception: pass
    out = render(peers, bot_mode)
    if out: print("\n".join(out))

if __name__ == "__main__":
    main()
LIVEIPS_EOF
    chmod +x /usr/local/bin/aliraza-liveips.py 2>/dev/null || true
    install_cdn_updater 2>/dev/null || true
    install_openssh_toggle 2>/dev/null || true
}

get_live_client_ips_table__legacy_unused() {
    python3 - << 'PY' 2>/dev/null
import os, sys, json, subprocess, re, datetime, ipaddress, pwd, time, urllib.request

USERS_DB = "/etc/aliraza/users.db"
WS_MAP_FILE = "/run/aliraza_ws_map.json"
ACTIVE_U_FILE = "/run/aliraza_active_users.json"
XRAY_LOG = "/var/log/xray/access.log"

valid_users = []
if os.path.exists(USERS_DB):
    for line in open(USERS_DB):
        pts = line.strip().split("|")
        if len(pts) >= 7 and pts[6] == "UNLOCKED":
            valid_users.append(pts[0])
if not valid_users:
    sys.exit(0)
valid_set = set(valid_users)
def_u = valid_users[0]

vps_ip = open("/etc/aliraza/vps_ip.txt").read().strip() if os.path.exists("/etc/aliraza/vps_ip.txt") else ""

def is_real_sim_ip(ip):
    ip = str(ip).strip().strip("[]").replace("::ffff:", "")
    if not ip or ip == vps_ip:
        return False
    try:
        addr = ipaddress.ip_address(ip)
        return addr.is_global and not (addr.is_private or addr.is_loopback or addr.is_link_local or addr.is_multicast or addr.is_reserved)
    except Exception:
        return False

peers = {}
def add_peer(ip, proto_label, user):
    ip = str(ip).strip().strip("[]").replace("::ffff:", "")
    if not is_real_sim_ip(ip):
        return
    if not user or user not in valid_set:
        user = def_u
    tag = f"{proto_label}({user})"
    if ip not in peers:
        peers[ip] = {"ports": set(), "tunnels": 0}
    if tag not in peers[ip]["ports"]:
        peers[ip]["ports"].add(tag)
        peers[ip]["tunnels"] += 1

ws_map = {}
if os.path.exists(WS_MAP_FILE):
    try: ws_map = json.loads(open(WS_MAP_FILE).read())
    except Exception: ws_map = {}

active_u_map = {}
if os.path.exists(ACTIVE_U_FILE):
    try: active_u_map = json.loads(open(ACTIVE_U_FILE).read())
    except Exception: active_u_map = {}

now_ts = int(time.time())
# rx_live = wahi user jo pichle 30s me Xray se REAL traffic kar raha hai (warna None = fake display nahi)
rx_live = next((u for u, ts in sorted(active_u_map.items(), key=lambda x: -x[1]) if u in valid_set and now_ts - ts < 30), None)
recent_xray_user = rx_live or def_u

pid_to_user = {}
for pid_dir in os.listdir("/proc"):
    if not pid_dir.isdigit(): continue
    p_path = f"/proc/{pid_dir}"
    try:
        uid = os.stat(p_path).st_uid
        if uid >= 1000:
            uname = pwd.getpwuid(uid).pw_name
            if uname in valid_set:
                pid_to_user[pid_dir] = uname
                continue
    except Exception:
        pass
    try:
        cmd = open(f"{p_path}/cmdline", "rb").read().replace(b"\x00", b" ").decode("utf-8", errors="ignore").strip()
        m = re.search(r"sshd(?:-session)?:\s*([a-zA-Z0-9_-]+)", cmd)
        if m and m.group(1) in valid_set:
            pid_to_user[pid_dir] = m.group(1)
    except Exception:
        pass

auth_by_port, auth_by_pid = {}, {}
log_lines = []
if os.path.exists("/var/log/auth.log"):
    try: log_lines.extend(subprocess.check_output(["tail", "-n", "250", "/var/log/auth.log"], text=True, stderr=subprocess.DEVNULL).splitlines())
    except Exception: pass
if not log_lines:
    try: log_lines.extend(subprocess.check_output(["journalctl", "-u", "ssh", "-u", "dropbear", "-n", "150", "--no-pager"], text=True, stderr=subprocess.DEVNULL).splitlines())
    except Exception: pass

for ln in log_lines:
    if "Password auth succeeded" in ln or "Accepted password for" in ln:
        m_u = re.search(r"for '([^']+)'", ln) or re.search(r"for (\S+)", ln)
        m_prt = re.search(r"from [0-9a-fA-F:\.]+(?::| port )(\d+)", ln)
        m_pid = re.search(r"\[(\d+)\]:", ln)
        if m_u and m_u.group(1) in valid_set:
            if m_prt: auth_by_port[m_prt.group(1)] = m_u.group(1)
            if m_pid: auth_by_pid[m_pid.group(1)] = m_u.group(1)

if os.path.exists(XRAY_LOG):
    try:
        now_dt = datetime.datetime.now()
        for ln in reversed(subprocess.check_output(["tail", "-n", "250", XRAY_LOG], text=True, stderr=subprocess.DEVNULL).splitlines()):
            if "accepted" not in ln: continue
            m_ts = re.match(r"^(\d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2})", ln)
            if m_ts and abs((now_dt - datetime.datetime.strptime(m_ts.group(1), "%Y/%m/%d %H:%M:%S")).total_seconds()) > 45:
                continue
            u = ln.split("email:")[-1].strip().split()[0] if "email:" in ln else recent_xray_user
            if u in valid_set:
                recent_xray_user = u
                m_tag = re.search(r"\[([a-z0-9-]+)\s*(?:->|>>)", ln)
                m_ip = re.search(r"from (?:tcp:|udp:)?([0-9a-fA-F:\.]+):\d+", ln)
                if m_ip and is_real_sim_ip(m_ip.group(1)):
                    add_peer(m_ip.group(1), m_tag.group(1).upper() if m_tag else "XRAY", u)
    except Exception:
        pass

# 1. All active tunnels tracked by Golang WS/SSL/BunnyCDN/Xray Engine
for lport_key, wentry in ws_map.items():
    if not wentry.get("open", True): continue
    wip = wentry.get("ip", "")
    wmode = wentry.get("mode", "SSH-WS")
    if any(k in wmode for k in ("XRAY", "VLESS", "VMESS", "TROJAN")):
        if rx_live:
            add_peer(wip, wmode, rx_live)
    else:
        u = auth_by_port.get(lport_key)
        if not u and now_ts - int(wentry.get("ts", now_ts) or now_ts) < 15:
            u = def_u
        if u:
            add_peer(wip, wmode, u)

# 2. Established TCP sockets (Direct SSH, Dropbear, Stunnel, Vision, Reality, Socks5, SS)
stunnel_ips = []
try:
    ss_out = subprocess.check_output(["ss", "-tnp", "state", "established"], text=True, stderr=subprocess.DEVNULL)
    for ln in ss_out.splitlines()[1:]:
        cols = ln.split()
        if len(cols) < 5: continue
        loc, peer = cols[3], cols[4]
        lport = loc.rsplit(":", 1)[-1]
        p_ip = peer.rsplit(":", 1)[0].strip("[]").replace("::ffff:", "")
        p_port = peer.rsplit(":", 1)[-1]
        pids = re.findall(r"pid=(\d+)", ln)

        if lport in ("444", "8443", "992") and is_real_sim_ip(p_ip):
            stunnel_ips.append((p_ip, lport))
        elif lport in ("10022",):
            u = next((pid_to_user.get(p) or auth_by_pid.get(p) for p in pids if p in pid_to_user or p in auth_by_pid), None) or auth_by_port.get(p_port)
            if not u: continue
            if p_port in ws_map and ws_map[p_port].get("open", True):
                add_peer(ws_map[p_port].get("ip", ""), ws_map[p_port].get("mode", "SSH-WS"), u)
            elif is_real_sim_ip(p_ip):
                add_peer(p_ip, "DROPBEAR", u)
            elif p_ip == "127.0.0.1" and stunnel_ips:
                add_peer(stunnel_ips[0][0], f"STUNNEL-{stunnel_ips[0][1]}", u)
        elif lport in ("8444", "10013", "10015", "8888", "10808", "10809") and is_real_sim_ip(p_ip):
            if rx_live:
                lbl = "VLESS-VISION" if lport == "8444" else ("VLESS-REALITY" if lport == "10013" else ("SOCKS5" if lport == "10808" else "SS/PROXY"))
                add_peer(p_ip, lbl, rx_live)
except Exception:
    pass

for st_ip, st_prt in stunnel_ips:
    if st_ip not in peers and pid_to_user:
        add_peer(st_ip, f"STUNNEL-{st_prt}", next(iter(pid_to_user.values()), None))

# 3. OpenVPN status logs
for ovpn_log in ("/var/log/openvpn-tcp.log", "/var/log/openvpn-udp.log"):
    if os.path.exists(ovpn_log):
        try:
            for ln in open(ovpn_log):
                if ln.startswith("CLIENT_LIST"):
                    pts = ln.strip().split(",")
                    if len(pts) >= 3 and pts[1] in valid_set:
                        add_peer(pts[2].rsplit(":", 1)[0], "OPENVPN", pts[1])
        except Exception:
            pass

# 4. Hysteria2 online API & ASSURED UDP Conntrack (ZiVPN, UDP-Custom, HY2, mKCP)
hy_u = None
try:
    with urllib.request.urlopen("http://127.0.0.1:9999/online", timeout=1) as r:
        hy_data = json.loads(r.read().decode())
        hy_u = next((k for k in hy_data if k in valid_set), None)
except Exception:
    pass

if os.path.exists("/proc/net/nf_conntrack"):
    try:
        for ln in open("/proc/net/nf_conntrack"):
            if "udp" not in ln or "[ASSURED]" not in ln: continue
            m_src = re.search(r"src=([0-9\.]+)\s+dst=[0-9\.]+\s+sport=\d+\s+dport=(\d+)\s+packets=(\d+)", ln)
            if m_src and is_real_sim_ip(m_src.group(1)) and int(m_src.group(3)) > 15:
                src_ip, dport = m_src.group(1), m_src.group(2)
                if dport == "5667": add_peer(src_ip, "ZIVPN-UDP", def_u)
                elif dport == "36712": add_peer(src_ip, "UDP-CUSTOM", def_u)
                elif dport == "20800" and hy_u: add_peer(src_ip, "HYSTERIA2", hy_u)
                elif dport == "10014" and rx_live: add_peer(src_ip, "VLESS-MKCP", rx_live)
    except Exception:
        pass

for idx, (ip, info) in enumerate(sorted(peers.items()), 1):
    print(f"{idx}|{ip}|{','.join(sorted(info['ports']))}|{info['tunnels']}")
PY
}

install_badvpn_gateway() {
    local force_replace="${1:-0}"
    [[ "$force_replace" == "1" ]] && rm -f /usr/bin/badvpn-udpgw 2>/dev/null || true
    if [[ ! -x /usr/bin/badvpn-udpgw ]]; then
        for url in "https://raw.githubusercontent.com/daybreakersx/premscript/master/badvpn-udpgw64" \
                   "https://github.com/ambrop72/badvpn/releases/download/1.999.130/badvpn-udpgw"; do
            curl -sL --max-time 15 "$url" -o /usr/bin/badvpn-udpgw 2>/dev/null && chmod +x /usr/bin/badvpn-udpgw 2>/dev/null || true
            [[ -x /usr/bin/badvpn-udpgw ]] && /usr/bin/badvpn-udpgw --help 2>&1 | grep -qi "listen-addr" && break || rm -f /usr/bin/badvpn-udpgw
        done
    fi
    cat << 'EOF' > /usr/local/bin/aliraza-badvpn-multi
#!/usr/bin/env bash
pkill -9 badvpn-udpgw 2>/dev/null || true
/usr/bin/badvpn-udpgw --listen-addr 0.0.0.0:7100 --max-clients 1000 --max-connections-for-client 100 &
/usr/bin/badvpn-udpgw --listen-addr 0.0.0.0:7200 --max-clients 1000 --max-connections-for-client 100 &
exec /usr/bin/badvpn-udpgw --listen-addr 0.0.0.0:7300 --max-clients 1000 --max-connections-for-client 100
EOF
    chmod +x /usr/local/bin/aliraza-badvpn-multi
    cat << 'EOF' > /etc/systemd/system/badvpn.service
[Unit]
Description=BadVPN UDPGW (7100-7300)
After=network.target
[Service]
User=root
ExecStart=/usr/local/bin/aliraza-badvpn-multi
Restart=always
RestartSec=2s
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload && systemctl enable badvpn 2>/dev/null && systemctl restart badvpn 2>/dev/null || true
}

# v59.3 FIX: binary download validate hoti hai (size + ELF header), retries + mirrors. Pehle corrupt/HTML file bhi "-x" ban kar kabhi dobara download nahi hoti thi.
bin_is_valid() { # $1 file  $2 min bytes
    local f="$1" min="${2:-1000000}"
    [[ -x "$f" ]] || return 1
    [[ $(stat -c%s "$f" 2>/dev/null || echo 0) -ge $min ]] || return 1
    [[ "$(head -c4 "$f" 2>/dev/null | od -An -tx1 | tr -d ' \n')" == "7f454c46" ]] || return 1
    return 0
}
fetch_validated_bin() { # $1 dest  $2 min bytes  $3.. urls
    local dest="$1" min="$2" url try; shift 2
    for url in "$@"; do
        for try in 1 2 3; do
            rm -f "${dest}.dl" 2>/dev/null
            curl -fL --connect-timeout 10 --max-time 120 "$url" -o "${dest}.dl" >/dev/null 2>&1 || { sleep 2; continue; }
            chmod +x "${dest}.dl" 2>/dev/null
            if bin_is_valid "${dest}.dl" "$min"; then mv -f "${dest}.dl" "$dest"; chmod +x "$dest"; return 0; fi
        done
    done
    rm -f "${dest}.dl" 2>/dev/null
    return 1
}

install_zivpn_and_hysteria() {
    local force_replace="${1:-0}"
    mkdir -p "$ZIVPN_DIR" "$HY2_DIR"
    generate_fallback_cert
    local ARCH=$(uname -m) ZI_A="amd64" HY_A="amd64"
    [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]] && { ZI_A="arm64"; HY_A="arm64"; }
    [[ "$force_replace" == "1" ]] && rm -f "$ZIVPN_DIR/zivpn" /usr/local/bin/hysteria 2>/dev/null || true

    # Corrupt / adhoori binary ho to hata do taake dobara download ho
    bin_is_valid "$ZIVPN_DIR/zivpn" 1000000 || rm -f "$ZIVPN_DIR/zivpn" 2>/dev/null
    bin_is_valid /usr/local/bin/hysteria 5000000 || rm -f /usr/local/bin/hysteria 2>/dev/null

    if [[ ! -x "$ZIVPN_DIR/zivpn" ]]; then
        fetch_validated_bin "$ZIVPN_DIR/zivpn" 1000000 \
            "https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-${ZI_A}" \
            "https://github.com/zahidbd2/udp-zivpn/releases/latest/download/udp-zivpn-linux-${ZI_A}" \
            "https://ghfast.top/https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-${ZI_A}" \
            || echo "[!] ZiVPN binary download FAIL - internet/GitHub access check karein" >> "$AR_LOG"
    fi

    if [[ ! -x /usr/local/bin/hysteria ]]; then
        fetch_validated_bin /usr/local/bin/hysteria 5000000 \
            "https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-${HY_A}" \
            "https://download.hysteria.network/app/latest/hysteria-linux-${HY_A}" \
            "https://ghfast.top/https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-${HY_A}" \
            || echo "[!] Hysteria2 binary download FAIL - internet/GitHub access check karein" >> "$AR_LOG"
    fi

    sync_all_users_to_engines

    cat << EOF > /etc/systemd/system/zivpn.service
[Unit]
Description=ZiVPN Official UDP Server (5667 & 6000-19999)
After=network.target
[Service]
User=root
WorkingDirectory=$ZIVPN_DIR
Nice=-15
ExecStart=$ZIVPN_DIR/zivpn server -c $ZIVPN_DIR/config.json
Restart=always
RestartSec=2s
LimitNOFILE=1000000
[Install]
WantedBy=multi-user.target
EOF

    cat << EOF > /etc/systemd/system/hysteria.service
[Unit]
Description=Hysteria 2 High-Speed QUIC UDP Server (20800)
After=network.target
[Service]
User=root
WorkingDirectory=$HY2_DIR
Nice=-15
ExecStart=/usr/local/bin/hysteria server -c $HY2_DIR/config.yaml
Restart=always
RestartSec=2s
LimitNOFILE=1000000
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable zivpn hysteria 2>/dev/null || true
    systemctl restart zivpn hysteria 2>/dev/null || true
}

install_udp_custom() {
    local force_replace="${1:-0}"
    mkdir -p "$UDP_DIR"
    [[ "$force_replace" == "1" ]] && rm -f "$UDP_DIR/udp-custom" 2>/dev/null || true
    if [[ ! -x "$UDP_DIR/udp-custom" ]]; then
        for url in "https://github.com/noobconner21/UDP-Custom-Script/raw/main/udp-custom-linux-amd64" \
                   "https://raw.githubusercontent.com/rudi9999/Herramientas/main/UDP/udp-custom-linux-amd64"; do
            curl -sL --max-time 15 "$url" -o "$UDP_DIR/udp-custom" 2>/dev/null && chmod +x "$UDP_DIR/udp-custom" 2>/dev/null || true
            [[ $(stat -c%s "$UDP_DIR/udp-custom" 2>/dev/null || echo 0) -gt 1000000 ]] && break || rm -f "$UDP_DIR/udp-custom"
        done
    fi
    printf '{"listen":":36712","stream_buffer":33554432,"receive_buffer":83886080,"auth":{"mode":"passwords"}}\n' > "$UDP_DIR/config.json"
    cat << EOF > /etc/systemd/system/udp-custom.service
[Unit]
Description=UDP Custom Server
After=network.target
[Service]
User=root
ExecStart=$UDP_DIR/udp-custom server -exclude 53,2200,5300,5667,7100,7200,7300,8888,10014,10015,10808,20800
WorkingDirectory=$UDP_DIR/
Restart=always
RestartSec=2s
[Install]
WantedBy=multi-user.target
EOF
    install_zivpn_and_hysteria "$force_replace"
    setup_slowdns_and_udp_nat
    systemctl daemon-reload && systemctl enable udp-custom 2>/dev/null && systemctl restart udp-custom 2>/dev/null || true
}

configure_slowdns_service() {
    local force_rebuild="${1:-0}"
    local NS_DOMAIN=$(head -n1 "$DATA_DIR/ns_domain.txt" 2>/dev/null | tr -d '[:space:]'); [[ -z "$NS_DOMAIN" ]] && NS_DOMAIN="nr.aliraza.com"
    fix_dns_resolver
    if ! verify_real_dnstt_binary; then
        ensure_golang_compiler
        local GO_BIN=$(command -v go || echo "/usr/local/go/bin/go")
        export GOPATH="/tmp/go-dnstt" GOCACHE="/tmp/go-dnstt-cache"
        rm -rf /tmp/dnstt-src
        timeout 90 git clone https://www.bamsoftware.com/git/dnstt.git /tmp/dnstt-src 2>/dev/null || timeout 90 git clone https://github.com/Mygod/dnstt.git /tmp/dnstt-src 2>/dev/null || true
        [[ -d /tmp/dnstt-src/dnstt-server ]] && (cd /tmp/dnstt-src/dnstt-server && timeout 240 "$GO_BIN" build -o "$SLOWDNS_DIR/dnstt-server" 2>/dev/null && chmod +x "$SLOWDNS_DIR/dnstt-server")
        rm -rf /tmp/dnstt-src
    fi
    if verify_real_dnstt_binary && [[ ! -s "$SLOWDNS_DIR/server.pub" || ! -s "$SLOWDNS_DIR/server.key" ]]; then
        "$SLOWDNS_DIR/dnstt-server" -gen-key -privkey-file "$SLOWDNS_DIR/server.key" -pubkey-file "$SLOWDNS_DIR/server.pub" >/dev/null 2>&1 || true
    fi
    if ! verify_real_dnstt_binary; then
        echo -e "${RED}[X] SlowDNS (dnstt-server) build FAIL - internet/git check kar ke Panel ke Auto-Doctor / Tools se dobara try karein.${NC}"
        systemctl stop slowdns >/dev/null 2>&1 || true
        return 1
    fi
    local SDNS_TARGET="127.0.0.1:10022"
    [[ -s "$DATA_DIR/slowdns_target.txt" ]] && SDNS_TARGET=$(head -n1 "$DATA_DIR/slowdns_target.txt" | tr -d '[:space:]')
    [[ "$SDNS_TARGET" =~ :(8|22|2222)$ ]] && SDNS_TARGET="127.0.0.1:10022"
    cat << EOF > /etc/systemd/system/slowdns.service
[Unit]
Description=SlowDNS DNSTT Server
After=network.target
[Service]
ExecStart=$SLOWDNS_DIR/dnstt-server -udp 0.0.0.0:5300 -mtu 1100 -privkey-file $SLOWDNS_DIR/server.key $NS_DOMAIN ${SDNS_TARGET}
Restart=always
RestartSec=2s
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload && systemctl enable slowdns 2>/dev/null && systemctl restart slowdns 2>/dev/null || true
}

# ============================================================================
# 100% ZERO-GHOST-KB REAL AUTHENTICATED DATA TRACKER (`aliraza-enforcer`)
# - ONLY counts authenticated user sessions (Xray UUID/Email, SSH/WS PID, HY2, OVPN)
# - NEVER counts unauthenticated UDP conntrack loops or port scanners!
# ============================================================================
setup_realtime_monitor_service() {
    cat << 'EOF' > /usr/local/bin/aliraza-enforcer
#!/usr/bin/env python3
import os, sys, json, time, re, subprocess, datetime, pwd, urllib.request

USERS_DB = "/etc/aliraza/users.db"
USAGE_DIR = "/etc/aliraza/usage"
USER_CONF_DIR = "/etc/aliraza/users"
XRAY_CONF = "/usr/local/etc/xray/config.json"
WS_MAP_FILE = "/run/aliraza_ws_map.json"
STATE_FILE = "/run/aliraza_tracker_state.json"
ACTIVE_U_FILE = "/run/aliraza_active_users.json"

os.makedirs(USAGE_DIR, exist_ok=True)
os.makedirs(USER_CONF_DIR, exist_ok=True)

PROTECTED_USERS = {"root", "ubuntu", "debian", "admin", "ec2-user", "centos", "rocky", "almalinux", "fedora", "sshd", "nobody", "haproxy", "www-data"}

def load_state():
    if os.path.exists(STATE_FILE):
        try: return json.load(open(STATE_FILE))
        except Exception: pass
    return {"ws": {}, "sock": {}, "ovpn": {}}

def save_state(st):
    try: json.dump(st, open(STATE_FILE, "w"))
    except Exception: pass

def read_int(path):
    try: return int(open(path).read().strip() or 0)
    except Exception: return 0

def write_int(path, val):
    try: open(path, "w").write(str(max(0, int(val))))
    except Exception: pass

AUTH_CACHE = "/run/aliraza_authlines.cache"
def read_auth_lines():
    # v58.2: Dropbear (-E) logs journald me jaate hain; auth.log ke saath dono merge (pehle sirf auth.log/150 lines = online ghayab/galat)
    try:
        if os.path.exists(AUTH_CACHE) and time.time() - os.path.getmtime(AUTH_CACHE) < 3:
            return open(AUTH_CACHE, errors="ignore").read().splitlines()
    except Exception:
        pass
    lines = []
    try:
        out = subprocess.check_output(["journalctl", "-u", "dropbear", "-o", "short", "--since=-24h", "--no-pager", "-g", "auth succeeded"], text=True, stderr=subprocess.DEVNULL, timeout=5)
        lines.extend(out.splitlines())
    except Exception:
        try:
            out = subprocess.check_output(["journalctl", "-u", "dropbear", "-o", "short", "--since=-24h", "--no-pager"], text=True, stderr=subprocess.DEVNULL, timeout=5)
            lines.extend(l for l in out.splitlines() if "auth succeeded" in l)
        except Exception:
            pass
    if os.path.exists("/var/log/auth.log"):
        try:
            out = subprocess.check_output(["tail", "-n", "3000", "/var/log/auth.log"], text=True, stderr=subprocess.DEVNULL, timeout=3)
            lines.extend(l for l in out.splitlines() if "auth succeeded" in l or "Accepted password for" in l)
        except Exception:
            pass
    try: open(AUTH_CACHE, "w").write("\n".join(lines))
    except Exception: pass
    return lines

_LV = [None]
def _liveips():
    # Live-IP helper ke robust ss/auth functions yahan bhi use hote hain (ek hi logic, dono jagah sahi)
    if _LV[0] is None:
        import importlib.machinery, importlib.util
        ldr = importlib.machinery.SourceFileLoader("aliraza_liveips", "/usr/local/bin/aliraza-liveips.py")
        spec = importlib.util.spec_from_loader("aliraza_liveips", ldr)
        mod = importlib.util.module_from_spec(spec)
        ldr.exec_module(mod)
        _LV[0] = mod
    return _LV[0]

_ELOG = {}
def elog(tag):
    # silent failure ki jagah: har 2 minute me ek line journald me (journalctl -u aliraza-monitor)
    try:
        import traceback
        now = time.time()
        if now - _ELOG.get(tag, 0) < 120: return
        _ELOG[tag] = now
        print("[enforcer] %s: %s" % (tag, traceback.format_exc().strip().splitlines()[-1]), flush=True)
    except Exception:
        pass

def get_ssh_and_ws_deltas(valid_set, ws_map, state):
    deltas = {}
    try:
        lv = _liveips()
        socks = lv.resolve_ssh_sockets(valid_set)
        info = lv.ss_bytes()
        for loc, peer, u in socks:
            p_port = peer.rsplit(":", 1)[-1]
            if p_port in ws_map:
                w_entry = ws_map[p_port]
                w_key = f"{p_port}:{w_entry.get('ip','')}"
                cur_b = int(w_entry.get("bytes", 0))
                prev_b = state["ws"].get(w_key, 0)
                if cur_b > prev_b:
                    deltas[u] = deltas.get(u, 0) + (cur_b - prev_b)
                state["ws"][w_key] = cur_b
            else:
                s_key = f"{loc}->{peer}"
                il = info.get((loc, peer), "")
                m_ack = re.search(r"bytes_acked:(\d+)", il)
                m_rcv = re.search(r"bytes_received:(\d+)", il)
                cur_b = (int(m_ack.group(1)) if m_ack else 0) + (int(m_rcv.group(1)) if m_rcv else 0)
                prev_b = state["sock"].get(s_key, 0)
                if cur_b > prev_b:
                    deltas[u] = deltas.get(u, 0) + (cur_b - prev_b)
                state["sock"][s_key] = cur_b
        # state sirf tab saaf hoti hai jab connection sach me khatam ho (user-pehchan me ek tick ki deri se double-count na ho)
        live_ws = {f"{k}:{v.get('ip','')}" for k, v in ws_map.items()}
        state["ws"] = {k: v for k, v in state["ws"].items() if k in live_ws}
        live_sock = {f"{l}->{p}" for (l, p) in info}
        state["sock"] = {k: v for k, v in state["sock"].items() if k in live_sock}
    except Exception:
        elog("ssh/ws deltas")
    return deltas

def get_openssh_deltas(valid_set, state):
    # v59: OpenSSH (port 22 / UDP-Custom / direct SSH) ka data. Pehle sirf Dropbear(10022) count hota tha,
    # isliye 22 par chalne wale users online dikhte the magar Data used 0 rehta tha.
    deltas = {}
    try:
        lv = _liveips()
        info = lv.ss_bytes()
        for loc, peer, pids in lv.ss_estab():
            if loc.rsplit(":", 1)[-1] == "10022": continue
            u = None
            for pid in pids:
                try:
                    cmd = open("/proc/%s/cmdline" % pid, "rb").read().replace(b"\x00", b" ").decode("utf-8", "ignore")
                except Exception:
                    continue
                m = re.search(r"sshd(?:-session)?:\s*([a-zA-Z0-9_.-]+)", cmd)
                if m and m.group(1) in valid_set:
                    u = m.group(1); break
            if not u: continue
            il = info.get((loc, peer), "")
            m_ack = re.search(r"bytes_acked:(\d+)", il)
            m_rcv = re.search(r"bytes_received:(\d+)", il)
            cur_b = (int(m_ack.group(1)) if m_ack else 0) + (int(m_rcv.group(1)) if m_rcv else 0)
            key = f"{loc}->{peer}"
            prev_b = state["sock"].get(key, 0)
            if cur_b > prev_b:
                deltas[u] = deltas.get(u, 0) + (cur_b - prev_b)
            state["sock"][key] = cur_b
    except Exception:
        elog("openssh deltas")
    return deltas

def query_xray_user_delta(valid_set):
    deltas = {}
    try:
        out = subprocess.check_output(["/usr/local/bin/xray", "api", "statsquery", "--server=127.0.0.1:10085", "-reset=true"], stderr=subprocess.DEVNULL, timeout=3).decode("utf-8", errors="ignore")
        for item in json.loads(out).get("stat", []):
            pts = item.get("name", "").split(">>>")
            val = int(item.get("value", 0))
            if val <= 0: continue
            if len(pts) == 4 and pts[0] == "user" and pts[1] in valid_set and pts[2] == "traffic":
                deltas[pts[1]] = deltas.get(pts[1], 0) + val
    except Exception:
        pass
    return deltas

def query_hysteria2_user_delta(valid_set):
    deltas = {}
    try:
        with urllib.request.urlopen("http://127.0.0.1:9999/traffic?clear=1", timeout=2) as r:
            for u, st in json.loads(r.read().decode()).items():
                if u in valid_set:
                    val = int(st.get("tx", 0)) + int(st.get("rx", 0))
                    if val > 0: deltas[u] = deltas.get(u, 0) + val
    except Exception:
        pass
    return deltas

def query_openvpn_user_delta(valid_set, state):
    deltas = {}
    active_keys = set()
    for ovpn_log in ("/var/log/openvpn-tcp.log", "/var/log/openvpn-udp.log"):
        if os.path.exists(ovpn_log):
            try:
                for ln in open(ovpn_log):
                    if ln.startswith("CLIENT_LIST"):
                        pts = ln.strip().split(",")
                        if len(pts) >= 7 and pts[1] in valid_set:
                            u, raddr, cur_b = pts[1], pts[2], int(pts[5]) + int(pts[6])
                            key = f"{ovpn_log}:{u}:{raddr}"
                            active_keys.add(key)
                            prev_b = state["ovpn"].get(key)
                            if prev_b is not None and cur_b > prev_b:
                                deltas[u] = deltas.get(u, 0) + (cur_b - prev_b)
                            state["ovpn"][key] = cur_b
            except Exception:
                pass
    state["ovpn"] = {k: v for k, v in state["ovpn"].items() if k in active_keys}
    return deltas

KICK = "/usr/local/bin/aliraza-kick"
IPL_OFF = "/etc/aliraza/ip_limit_off"      # file bana do to IP-limit auto-lock band
IPL_GRACE = "/etc/aliraza/ip_grace"        # seconds (default 60): limit se zyada IP itni der lagataar rahein tab lock
_IPOVER = {}
_JAN = [0.0]

def hard_lock_user(uname):
    if uname in PROTECTED_USERS: return
    subprocess.call(["passwd", "-l", uname], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.call(["usermod", "-s", "/usr/sbin/nologin", uname], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.call(["pkill", "-9", "-u", uname], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    _IPOVER.pop(uname, None)
    # v59.7: Dropbear/WS/SSL tunnel root ke naam se chalta hai - pkill -u se band nahi hota, isliye explicit kick
    try: subprocess.run([KICK, uname], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=20)
    except Exception: elog("kick")

def _to_int(v):
    try: return int(float(str(v).strip() or 0))
    except Exception: return 0

def ip_grace():
    try: return max(5, int(open(IPL_GRACE).read().strip()))
    except Exception: return 60

def ip_limit_exceeded(user, n_ips, limit, over, now, grace):
    # limit se ZYADA (barabar nahi) IP lagataar `grace` seconds rahein tab True - network badalte waqt purana socket kuch der rehta hai
    if limit > 0 and n_ips > limit:
        t0 = over.setdefault(user, now)
        return (now - t0) >= grace
    over.pop(user, None)
    return False

def verified_ips_by_user():
    try: return _liveips().verified_user_ips()
    except Exception:
        elog("ip-limit"); return None

state = load_state()
active_users_ts = {}
while True:
    try:
        if os.path.exists(USERS_DB):
            rows = [l.strip().split("|") for l in open(USERS_DB) if "|" in l]
            unlocked_list = [r[0] for r in rows if len(r) >= 7 and r[6] == "UNLOCKED" and r[0] not in PROTECTED_USERS]
            if unlocked_list:
                valid_set = set(unlocked_list)
                ws_map = {}
                if os.path.exists(WS_MAP_FILE):
                    try: ws_map = json.loads(open(WS_MAP_FILE).read())
                    except Exception: ws_map = {}

                ssh_deltas = get_ssh_and_ws_deltas(valid_set, ws_map, state)
                for _ou, _ov in get_openssh_deltas(valid_set, state).items():
                    ssh_deltas[_ou] = ssh_deltas.get(_ou, 0) + _ov
                xray_deltas = query_xray_user_delta(valid_set)
                hy2_deltas = query_hysteria2_user_delta(valid_set)
                ovpn_deltas = query_openvpn_user_delta(valid_set, state)
                save_state(state)

                now_ts = int(time.time())
                for u, val in xray_deltas.items():
                    if val > 0: active_users_ts[u] = now_ts
                try: json.dump(active_users_ts, open(ACTIVE_U_FILE, "w"))
                except Exception: pass

                today_str = datetime.date.today().strftime("%Y-%m-%d")
                need_xray_restart = False
                new_rows = []
                status_changes = {}
                uip = None
                if not os.path.exists(IPL_OFF) and any(len(_r) >= 7 and _r[6] == "UNLOCKED" and _to_int(_r[4]) > 0 for _r in rows):
                    uip = verified_ips_by_user()
                _grace = ip_grace(); _tnow = time.time()

                for r in rows:
                    if len(r) < 7: continue
                    uname, upass, uuid, q_gb, ip_lim, exp_date, status = r[:7]
                    if uname in PROTECTED_USERS: continue
                    u_file = os.path.join(USAGE_DIR, f"{uname}.bytes")
                    accum = read_int(u_file)

                    if status == "UNLOCKED":
                        real_delta = (
                            ssh_deltas.get(uname, 0)
                            + xray_deltas.get(uname, 0)
                            + hy2_deltas.get(uname, 0)
                            + ovpn_deltas.get(uname, 0)
                        )
                        if real_delta > 0:
                            accum += real_delta
                            write_int(u_file, accum)

                        if real_delta > 0 or not os.path.exists(os.path.join(USER_CONF_DIR, f"{uname}.conf")):
                            try:
                                open(os.path.join(USER_CONF_DIR, f"{uname}.conf"), "w").write(f"IP_LIMIT={ip_lim}\nGB_LIMIT={q_gb}\nUSED_MB={accum/(1024.0*1024.0):.2f}\n")
                            except Exception:
                                pass

                        if today_str > exp_date:
                            hard_lock_user(uname)
                            status = "EXPIRED"
                            need_xray_restart = True

                        try: q_f = float(q_gb or 0)
                        except Exception: q_f = 0.0
                        if status == "UNLOCKED" and q_f > 0 and accum >= int(q_f * 1073741824):
                            hard_lock_user(uname)
                            status = "QUOTA_FULL"
                            need_xray_restart = True

                        # v59.7: IP limit - limit se zyada alag-alag (verified) IP lagataar rahein to account off (status IP_LIMIT)
                        if status == "UNLOCKED" and uip is not None:
                            _ipl = _to_int(ip_lim)
                            if _ipl > 0 and ip_limit_exceeded(uname, len(uip.get(uname, ())), _ipl, _IPOVER, _tnow, _grace):
                                hard_lock_user(uname)
                                status = "IP_LIMIT"
                                need_xray_restart = True

                    new_rows.append("|".join([uname, upass, uuid, q_gb, ip_lim, exp_date, status] + list(r[7:])))
                    if status != r[6]: status_changes[uname] = status
                if status_changes:
                    # v58.3: DB ko dobara padh kar sirf status badlo (panel ke naye/delete users overwrite na hon, protocols column na urre)
                    try:
                        _cur = open(USERS_DB).read().splitlines()
                        _out = []
                        for _ln in _cur:
                            _pp = _ln.split("|")
                            if len(_pp) >= 7 and _pp[0] in status_changes and _pp[6] == "UNLOCKED":
                                _pp[6] = status_changes[_pp[0]]
                            _out.append("|".join(_pp))
                        _tmpdb = USERS_DB + ".tmp"
                        open(_tmpdb, "w").write("\n".join(_out) + "\n")
                        os.replace(_tmpdb, USERS_DB)
                    except Exception:
                        pass

                if need_xray_restart and os.path.exists(XRAY_CONF):
                    try:
                        unlock_rows2 = [r.split("|") for r in new_rows if r.split("|")[6] == "UNLOCKED"]
                        cfg = json.load(open(XRAY_CONF))
                        locked_set = {r.split("|")[0] for r in new_rows if r.split("|")[6] != "UNLOCKED"}
                        for inb in cfg.get("inbounds", []):
                            clients = inb.get("settings", {}).get("clients", [])
                            if clients:
                                inb["settings"]["clients"] = [c for c in clients if c.get("email") not in locked_set]
                        json.dump(cfg, open(XRAY_CONF, "w"), indent=2)
                        subprocess.run(["systemctl", "restart", "xray"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                        # ZiVPN & Hysteria2 se bhi locked users hatao (warna UDP par locked user chalta rehta)
                        def has_pr(rr, n):
                            pr = rr[7] if len(rr) > 7 else "all"
                            return pr == "all" or n in [x.strip() for x in pr.split(",")]
                        pws2 = [r2[1] for r2 in unlock_rows2 if has_pr(r2, "zivpn")] or ["aliraza"]
                        json.dump({"listen": ":5667", "cert": "/etc/ssl/xray/fullchain.pem", "key": "/etc/ssl/xray/privkey.pem", "obfs": "zivpn", "auth": {"mode": "passwords", "config": pws2}}, open("/etc/zivpn/config.json", "w"), indent=2)
                        with open("/etc/hysteria/config.yaml", "w") as hf2:
                            hf2.write("listen: :20800\ntls:\n  cert: /etc/ssl/xray/fullchain.pem\n  key: /etc/ssl/xray/privkey.pem\nbandwidth:\n  up: 1 gbps\n  down: 1 gbps\ntrafficStats:\n  listen: 127.0.0.1:9999\nauth:\n  type: userpass\n  userpass:\n")
                            for r2 in ([r for r in unlock_rows2 if has_pr(r, "hy2")] or [["aliraza","aliraza"]]):
                                hf2.write(f"    {r2[0]}: {r2[1]}\n")
                        subprocess.run(["systemctl", "restart", "zivpn", "hysteria"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    except Exception:
                        pass
    except Exception:
        elog("main loop")
    # v59.7: janitor - jo users LOCKED/EXPIRED/QUOTA_FULL/IP_LIMIT hain unke koi bhi bache hue connection har 15s me kaat do
    try:
        if time.time() - _JAN[0] >= 15 and os.path.exists(USERS_DB):
            _JAN[0] = time.time()
            _lk = []
            for _l in open(USERS_DB):
                _p = _l.strip().split("|")
                if len(_p) >= 7 and _p[6] != "UNLOCKED" and _p[0] not in PROTECTED_USERS: _lk.append(_p[0])
            if _lk: subprocess.run([KICK] + _lk[:200], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=40)
    except Exception:
        elog("janitor")
    time.sleep(2)
EOF
    chmod +x /usr/local/bin/aliraza-enforcer
    # v59: usage diagnose command -> `aliraza-usage-check`
    cat << 'USAGECHK_EOF' > /usr/local/bin/aliraza-usage-check
#!/usr/bin/env python3
import os, re, subprocess, importlib.machinery, importlib.util
USERS_DB = "/etc/aliraza/users.db"; USAGE = "/etc/aliraza/usage"
def sh(c):
    try: return subprocess.check_output(c, shell=True, text=True, stderr=subprocess.STDOUT, timeout=10).strip()
    except Exception as e: return "ERR %s" % e
print("== Monitor service:", sh("systemctl is-active aliraza-monitor"))
print(sh("journalctl -u aliraza-monitor -n 6 --no-pager -o cat 2>/dev/null"))
users = []
for ln in open(USERS_DB, errors="ignore"):
    p = ln.strip().split("|")
    if len(p) >= 7: users.append((p[0], p[6]))
print("\n== Users: usage file ==")
for u, st in users:
    try: b = int(open("%s/%s.bytes" % (USAGE, u)).read().strip() or 0)
    except Exception: b = 0
    print("  %-18s %-10s %10.2f MB" % (u, st, b / 1048576.0))
ldr = importlib.machinery.SourceFileLoader("lv", "/usr/local/bin/aliraza-liveips.py")
spec = importlib.util.spec_from_loader("lv", ldr); lv = importlib.util.module_from_spec(spec); ldr.exec_module(lv)
vs = {u for u, s in users if s == "UNLOCKED"}
print("\n== Dropbear (10022) sockets ==")
res = {(l, pe): u for l, pe, u in lv.resolve_ssh_sockets(vs)}
for l, pe, pids in lv.ss_estab():
    if l.rsplit(":", 1)[-1] == "10022":
        print("  peer %-22s -> %s" % (pe, res.get((l, pe), "USER NAHI MILA (count nahi hoga)")))
print("\n== OpenSSH / UDP-Custom sockets ==")
for l, pe, pids in lv.ss_estab():
    if l.rsplit(":", 1)[-1] == "10022": continue
    for pid in pids:
        try: cmd = open("/proc/%s/cmdline" % pid, "rb").read().replace(b"\x00", b" ").decode("utf-8", "ignore")
        except Exception: continue
        m = re.search(r"sshd(?:-session)?:\s*([a-zA-Z0-9_.-]+)", cmd)
        if m: print("  %-22s -> %s" % (l, m.group(1) if m.group(1) in vs else m.group(1) + " (valid user nahi)")); break
print("\n== Xray user stats ==")
o = sh("/usr/local/bin/xray api statsquery --server=127.0.0.1:10085 2>&1 | grep -c 'user>>>'")
print("  user stat entries:", o)
USAGECHK_EOF
    chmod +x /usr/local/bin/aliraza-usage-check
    cp -f /usr/local/bin/aliraza-enforcer /usr/local/bin/autokill.py 2>/dev/null || true
    cat << 'EOF' > /etc/systemd/system/aliraza-monitor.service
[Unit]
Description=ALIRAZA Real Kernel Bandwidth & Auto-Lock Daemon
After=network.target
[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 /usr/local/bin/aliraza-enforcer
Restart=always
RestartSec=2s
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload && systemctl enable aliraza-monitor 2>/dev/null && systemctl restart aliraza-monitor 2>/dev/null || true
    legacy_cleanup_user_services
}

# Purane panel versions ka autokill.service (agar installed ho) GB double-count karta hai
legacy_cleanup_user_services() {
    systemctl stop autokill >/dev/null 2>&1 || true
    systemctl disable autokill >/dev/null 2>&1 || true
    rm -f /etc/systemd/system/autokill.service >/dev/null 2>&1 || true
    rm -f /etc/systemd/system/multi-user.target.wants/autokill.service >/dev/null 2>&1 || true
    systemctl daemon-reload >/dev/null 2>&1 || true
}
setup_cli_account_helper() {
    # v59.7: aliraza-kick - lock/expire/quota/IP-limit par user ke SAARE live connections turant band.
    # Dropbear ka tunnel process root ke naam se chalta hai, isliye `pkill -u user` se tunnel zinda rehta tha.
    cat << 'KICK_EOF' > /usr/local/bin/aliraza-kick
#!/usr/bin/env python3
import os, sys, re, json, pwd, subprocess, signal, time

AUTHMAP = "/run/aliraza_authmap.json"
PROTECTED = {"root", "ubuntu", "debian", "admin", "ec2-user", "centos", "rocky", "almalinux", "fedora", "sshd", "nobody", "haproxy", "www-data"}

def run(a, t=6):
    try: return subprocess.check_output(a, text=True, stderr=subprocess.DEVNULL, timeout=t)
    except Exception: return ""

def ss_rows():
    out = run(["ss", "-H", "-tnp"]) or run(["ss", "-tnp"])
    rows = []
    for ln in out.splitlines():
        c = ln.split()
        if len(c) < 4: continue
        if c[0].upper().startswith("ESTAB"): off = 1
        elif c[0].isdigit(): off = 0
        else: continue
        if len(c) < off + 4: continue
        rows.append((c[off + 2], c[off + 3], re.findall(r"pid=(\d+)", ln)))
    return rows

def comm(pid):
    try: return open("/proc/%s/comm" % pid).read().strip()
    except Exception: return ""

def kill(pid):
    try: os.kill(int(pid), signal.SIGKILL); return 1
    except Exception: return 0

def user_of_pid(pid):
    out = run(["journalctl", "_PID=" + pid, "-o", "cat", "--no-pager", "-q", "-n", "60"], 5)
    m = re.findall(r"auth succeeded for '?([A-Za-z0-9_.-]+)'?", out)
    return m[-1] if m else None

def main():
    users = [u for u in sys.argv[1:] if re.match(r"^[A-Za-z0-9_.-]+$", u) and u not in PROTECTED]
    if not users: return
    tset = set(users); n = 0
    # 1) Dropbear connection processes (root ke naam se) - internal 10022 ke ESTABLISHED sockets
    try: am_pid = json.load(open(AUTHMAP)).get("pid", {}) or {}
    except Exception: am_pid = {}
    seen = set(); lookups = 0
    for loc, peer, pids in ss_rows():
        if loc.rsplit(":", 1)[-1] != "10022": continue
        for p in pids:
            if p in seen: continue
            seen.add(p)
            if comm(p) != "dropbear": continue
            u = am_pid.get(p)
            if u is None and lookups < 60:
                lookups += 1; u = user_of_pid(p)
            if u in tset: n += kill(p)
    # 2) user ke apne processes + sshd privsep parent (OpenSSH / UDP-Custom)
    uids = {}
    for u in users:
        try:
            pw = pwd.getpwnam(u)
            if pw.pw_uid >= 1000: uids[pw.pw_uid] = u
        except KeyError:
            pass
    me = os.getpid()
    for d in os.listdir("/proc"):
        if not d.isdigit() or int(d) == me: continue
        try: uid = os.stat("/proc/" + d).st_uid
        except OSError: continue
        hit = uid in uids
        if not hit and comm(d).startswith("sshd"):
            try: cmd = open("/proc/%s/cmdline" % d, "rb").read().replace(b"\x00", b" ").decode("utf-8", "ignore")
            except Exception: continue
            m = re.match(r"^sshd(?:-session)?:\s*([A-Za-z0-9_.-]+)", cmd)
            hit = bool(m and m.group(1) in tset)
        if hit: n += kill(d)
    # 3) OpenVPN: connected client ko akela kill nahi kar sakte -> server restart (max 1 baar / 60s)
    for unit, logf in (("openvpn-server@server-tcp", "/var/log/openvpn-tcp.log"), ("openvpn-server@server-udp", "/var/log/openvpn-udp.log")):
        hit = False
        try:
            for ln in open(logf, errors="ignore"):
                pt = ln.strip().split(",")
                if len(pt) > 2 and ((pt[0] == "CLIENT_LIST" and pt[1] in tset) or (pt[0] in tset and ":" in pt[1])):
                    hit = True; break
        except Exception:
            pass
        if not hit: continue
        stamp = "/run/aliraza_kick_%s.ts" % unit.rsplit("-", 1)[-1]
        try: fresh = time.time() - os.path.getmtime(stamp) > 60
        except OSError: fresh = True
        if fresh:
            try: open(stamp, "w").write("1")
            except Exception: pass
            run(["systemctl", "restart", unit], 30)
    print("KICKED:%s:%d" % (",".join(users[:5]), n))

try: main()
except Exception: pass
KICK_EOF
    chmod +x /usr/local/bin/aliraza-kick
    cat << 'EOF' > /usr/local/bin/aliraza-cli
#!/usr/bin/env bash
ACTION="$1"
DATA_DIR="/etc/aliraza"; USAGE_DIR="/etc/aliraza/usage"; USERS_CONF_DIR="/etc/aliraza/users"
CLIENTS_DIR="/root/aliraza-configs"; BUNNY_DIR="/root/aliraza-configs/bunnycdn"; USERS_DB="/etc/aliraza/users.db"
XRAY_CONF="/usr/local/etc/xray/config.json"; SLOWDNS_DIR="/etc/slowdns"
mkdir -p "$USAGE_DIR" "$USERS_CONF_DIR" "$CLIENTS_DIR" "$BUNNY_DIR" /var/www/html

B3=$'\x60\x60\x60'; B1=$'\x60'

is_protected_user() {
    local u="$1"
    [[ -z "$u" ]] && return 0
    case "$u" in root|ubuntu|debian|admin|ec2-user|centos|rocky|almalinux|fedora|sshd|nobody|systemd-*|daemon|bin|sys|sync|haproxy|www-data) return 0 ;; esac
    id "$u" >/dev/null 2>&1 && [[ $(id -u "$u" 2>/dev/null || echo 0) -lt 1000 ]] && return 0
    return 1
}

sync_engines_py() {
    local R
    R=$(python3 - << 'PY' 2>>/var/log/aliraza-sync.err
import json, os, hashlib, base64, uuid as _uuid, secrets
D = "/etc/aliraza"; udb = D + "/users.db"; xc = "/usr/local/etc/xray/config.json"
sf = D + "/.dummy_secret"
if not os.path.exists(sf):
    with open(sf, "w") as f: f.write(secrets.token_hex(24))
    os.chmod(sf, 0o600)
SEC = open(sf).read().strip()
def hx(s): return hashlib.sha256((SEC + s).encode()).hexdigest()
D_UUID = str(_uuid.UUID(hx("uuid")[:32])); D_PW = hx("pw")[:24]
def ss22(uid): return base64.b64encode(hashlib.sha256(("ss22" + uid).encode()).digest()[:16]).decode()
users = []
if os.path.exists(udb):
    for ln in open(udb):
        p = ln.strip().split("|")
        if len(p) >= 7 and p[6] == "UNLOCKED":
            users.append({"u": p[0], "pw": p[1], "uuid": p[2], "protos": (p[7] if len(p) > 7 and p[7] else "all")})
def has(u, *n):
    if u["protos"] == "all": return True
    pl = [x.strip() for x in u["protos"].split(",")]
    return any(x in pl for x in n)
def atomic(path, text, mode=0o644):
    tmp = path + ".tmp"
    with open(tmp, "w") as f: f.write(text)
    os.chmod(tmp, mode); os.replace(tmp, path)
VL = {"vless-ws": "vless", "vless-grpc": "vless", "vless-httpupgrade": "vless", "vless-xhttp": "vless", "vless-mkcp": "vless"}
VM = {"vmess-ws", "vmess-grpc", "vmess-httpupgrade", "vmess-xhttp"}
TR = {"trojan-ws", "trojan-grpc", "trojan-httpupgrade", "trojan-xhttp"}
changed = []
if os.path.exists(xc):
    raw = open(xc).read(); c = json.loads(raw)
    for ib in c.get("inbounds", []):
        tg = ib.get("tag", ""); st = ib.setdefault("settings", {})
        if tg in VL:
            f = [u for u in users if has(u, "vless")]
            st["clients"] = [{"id": x["uuid"], "email": x["u"], "level": 0} for x in f]
        elif tg == "dnstt-vless":
            f = [u for u in users if has(u, "vless", "slowdns")]
            st["clients"] = [{"id": x["uuid"], "email": x["u"], "level": 0} for x in f]
        elif tg in ("vless-vision", "vless-reality"):
            f = [u for u in users if has(u, "vless")]
            st["clients"] = [{"id": x["uuid"], "email": x["u"], "flow": "xtls-rprx-vision", "level": 0} for x in f]
        elif tg in VM:
            f = [u for u in users if has(u, "vmess")]
            st["clients"] = [{"id": x["uuid"], "email": x["u"], "level": 0} for x in f]
        elif tg in TR:
            f = [u for u in users if has(u, "trojan")]
            st["clients"] = [{"password": x["pw"], "email": x["u"], "level": 0} for x in f]
        elif tg in ("socks5-in", "http-in"):
            f = [u for u in users if has(u, "socks5")]
            acc = [{"user": x["u"], "pass": x["pw"]} for x in f]
            st["accounts"] = acc or [{"user": "_none_", "pass": D_PW}]
        elif tg == "ss-in":
            f = [u for u in users if has(u, "ss")]
            st["clients"] = [{"password": x["pw"], "method": "chacha20-ietf-poly1305", "email": x["u"], "level": 0} for x in f]
        elif tg == "ss-2022":
            f = [u for u in users if has(u, "ss")]
            st["clients"] = [{"password": ss22(x["uuid"]), "email": x["u"], "level": 0} for x in f] or [{"password": ss22(D_UUID), "email": "_none_", "level": 0}]
    new = json.dumps(c, indent=2)
    if json.dumps(json.loads(raw), indent=2) != new:
        atomic(xc, new); changed.append("xray")
zi = [u["pw"] for u in users if has(u, "zivpn")]
pws = []
for p in zi:
    if p not in pws: pws.append(p)
if not pws: pws = [D_PW]
os.makedirs("/etc/zivpn", exist_ok=True)
ztxt = json.dumps({"listen": ":5667", "cert": "/etc/ssl/xray/fullchain.pem", "key": "/etc/ssl/xray/privkey.pem", "obfs": "zivpn", "auth": {"mode": "passwords", "config": pws}}, indent=2)
zp = "/etc/zivpn/config.json"
if not os.path.exists(zp) or open(zp).read() != ztxt:
    atomic(zp, ztxt); changed.append("zivpn")
hy = [u for u in users if has(u, "hy2")]
os.makedirs("/etc/hysteria", exist_ok=True)
htxt = "listen: :20800\ntls:\n  cert: /etc/ssl/xray/fullchain.pem\n  key: /etc/ssl/xray/privkey.pem\nbandwidth:\n  up: 1 gbps\n  down: 1 gbps\ntrafficStats:\n  listen: 127.0.0.1:9999\nauth:\n  type: userpass\n  userpass:\n"
if hy:
    for u in hy: htxt += "    %s: %s\n" % (json.dumps(u["u"]), json.dumps(u["pw"]))
else:
    htxt += "    %s: %s\n" % (json.dumps("_none_"), json.dumps(D_PW))
hp = "/etc/hysteria/config.yaml"
if not os.path.exists(hp) or open(hp).read() != htxt:
    atomic(hp, htxt); changed.append("hy2")
for x in changed: print("CHG:" + x)
PY
)
    [[ "$R" == *CHG:xray* ]] && { systemctl restart xray >/dev/null 2>&1 || true; }
    [[ "$R" == *CHG:zivpn* ]] && { systemctl restart zivpn >/dev/null 2>&1 || true; }
    [[ "$R" == *CHG:hy2* ]] && { systemctl restart hysteria >/dev/null 2>&1 || true; }
    return 0
}

if [[ "$ACTION" == "create" || "$ACTION" == "regen" ]]; then
    USER_NAME=$(echo "$2" | tr -dc 'a-zA-Z0-9_-')
    USER_PASS="${3:-1234}"; QUOTA_GB="${4:-0}"; IP_LIMIT="${5:-2}"; VALID_DAYS="${6:-30}"
    is_protected_user "$USER_NAME" && { echo "[!] Protected user!"; exit 1; }
    OLD_LINE=$(grep "^${USER_NAME}|" "$USERS_DB" 2>/dev/null | head -n1 || true)
    # --- protocol selection: create arg7 / regen reads saved value ---
    if [[ "$ACTION" == "regen" && -n "$OLD_LINE" ]]; then PROTOS=$(echo "$OLD_LINE" | cut -d'|' -f8); else PROTOS="${7:-all}"; fi
    PROTOS=$(echo "${PROTOS:-all}" | tr 'A-Z' 'a-z' | tr ',' '\n' | awk '$0=="all"||$0=="ssh"||$0=="vless"||$0=="vmess"||$0=="trojan"||$0=="ss"||$0=="socks5"||$0=="zivpn"||$0=="hy2"||$0=="slowdns"{ if(!s[$0]++) print }' | paste -sd, -)
    [[ ",$PROTOS," == *",all,"* ]] && PROTOS="all"
    [[ -z "$PROTOS" ]] && { echo "[!] Invalid protocol selection"; exit 1; }
    want() { [[ "$PROTOS" == "all" || ",$PROTOS," == *",$1,"* ]]; }
    need_linux() { want ssh || want slowdns; }
    if [[ "$ACTION" == "regen" && -n "$OLD_LINE" ]]; then
        UUID=$(echo "$OLD_LINE" | cut -d'|' -f3); EXP_DATE=$(echo "$OLD_LINE" | cut -d'|' -f6)
    else
        EXP_DATE=$(date -d "+${VALID_DAYS} days" +"%Y-%m-%d")
        [[ -n "$OLD_LINE" ]] && UUID=$(echo "$OLD_LINE" | cut -d'|' -f3) || UUID=$(/usr/local/bin/xray uuid 2>/dev/null || cat /proc/sys/kernel/random/uuid)
        echo "0" > "$USAGE_DIR/${USER_NAME}.bytes"
        printf "IP_LIMIT=%s\nGB_LIMIT=%s\nUSED_MB=0.00\n" "$IP_LIMIT" "$QUOTA_GB" > "$USERS_CONF_DIR/${USER_NAME}.conf"
        EXP_SYS=$(date -d "$EXP_DATE + 1 day" +"%Y-%m-%d" 2>/dev/null || echo "$EXP_DATE")
        useradd -e "$EXP_SYS" -M -s /bin/bash "$USER_NAME" >/dev/null 2>&1 || true
        usermod -s /bin/bash -p "$(openssl passwd -6 "$USER_PASS")" "$USER_NAME" >/dev/null 2>&1 || echo "$USER_NAME:$USER_PASS" | chpasswd -c SHA512 >/dev/null 2>&1
        passwd -u "$USER_NAME" >/dev/null 2>&1 || true
        chage -E "$EXP_SYS" "$USER_NAME" >/dev/null 2>&1 || true
        # SSH-family (OpenSSH/Dropbear/WS/SSL/UDP/OpenVPN/SlowDNS) = Linux user. ssh select nahi hua to account lock.
        need_linux || { passwd -l "$USER_NAME" >/dev/null 2>&1 || true; usermod -s /usr/sbin/nologin "$USER_NAME" >/dev/null 2>&1 || true; }
        sed -i "/^${USER_NAME}|/d" "$USERS_DB" 2>/dev/null || true
        echo "${USER_NAME}|${USER_PASS}|${UUID}|${QUOTA_GB}|${IP_LIMIT}|${EXP_DATE}|UNLOCKED|${PROTOS}" >> "$USERS_DB"
        sync_engines_py
    fi

    VPS_IP=$(head -n1 "$DATA_DIR/vps_ip.txt" 2>/dev/null | tr -d '[:space:]'); [[ -z "$VPS_IP" ]] && VPS_IP=$(curl -s4 api.ipify.org)
    DOMAIN=$(head -n1 "$DATA_DIR/domain.txt" 2>/dev/null | tr -d '[:space:]'); [[ -z "$DOMAIN" ]] && DOMAIN="$VPS_IP"
    NS_DOMAIN=$(head -n1 "$DATA_DIR/ns_domain.txt" 2>/dev/null | tr -d '[:space:]'); [[ -z "$NS_DOMAIN" ]] && NS_DOMAIN="$DOMAIN"
    BUNNY_HOST=$(head -n1 "$DATA_DIR/bunny_host.txt" 2>/dev/null | tr -d '[:space:]'); [[ -z "$BUNNY_HOST" ]] && BUNNY_HOST="$DOMAIN"
    SLOWDNS_PUBKEY=$(head -n1 "$SLOWDNS_DIR/server.pub" 2>/dev/null | tr -d '[:space:]')
    REALITY_PUB=$(head -n1 "$DATA_DIR/reality_pub.txt" 2>/dev/null | tr -d '[:space:]')
    SS22_KEY=$(head -n1 "$DATA_DIR/ss2022_key.txt" 2>/dev/null | tr -d '[:space:]')

    VLESS_WS_TLS="vless://${UUID}@${DOMAIN}:443?path=%2Faliraza-vless-ws&security=tls&encryption=none&host=${DOMAIN}&type=ws&sni=${DOMAIN}#${USER_NAME}-tls"
    VLESS_WS_80="vless://${UUID}@${DOMAIN}:80?path=%2Faliraza-vless-ws&security=none&encryption=none&host=${DOMAIN}&type=ws&sni=${DOMAIN}#${USER_NAME}-ntls"
    VLESS_HUP_443="vless://${UUID}@${DOMAIN}:443?path=%2Faliraza-vless-httpupgrade&security=tls&encryption=none&host=${DOMAIN}&type=httpupgrade&sni=${DOMAIN}#${USER_NAME}-hup-tls"
    VLESS_HUP_80="vless://${UUID}@${DOMAIN}:80?path=%2Faliraza-vless-httpupgrade&security=none&encryption=none&host=${DOMAIN}&type=httpupgrade&sni=${DOMAIN}#${USER_NAME}-hup-ntls"
    VLESS_GRPC="vless://${UUID}@${DOMAIN}:443?mode=gun&security=tls&encryption=none&type=grpc&serviceName=aliraza-vless-grpc&sni=${DOMAIN}#${USER_NAME}-grpc"
    VLESS_XHTTP_443="vless://${UUID}@${DOMAIN}:443?path=%2Faliraza-vless-xhttp&security=tls&encryption=none&mode=auto&type=xhttp&host=${DOMAIN}&sni=${DOMAIN}#${USER_NAME}-xhttp-tls"
    VLESS_XHTTP_80="vless://${UUID}@${DOMAIN}:80?path=%2Faliraza-vless-xhttp&security=none&encryption=none&mode=auto&type=xhttp&host=${DOMAIN}#${USER_NAME}-xhttp-ntls"
    VLESS_VISION_443="vless://${UUID}@${VPS_IP}:443?security=tls&encryption=none&flow=xtls-rprx-vision&type=tcp&sni=vision.${DOMAIN}&fp=chrome&allowInsecure=1#${USER_NAME}-vision"
    VLESS_REALITY_443="vless://${UUID}@${VPS_IP}:443?security=reality&encryption=none&pbk=${REALITY_PUB}&fp=chrome&type=tcp&flow=xtls-rprx-vision&sni=reality.${DOMAIN}&sid=6ba85179e30d4fc2#${USER_NAME}-reality"
    VLESS_MKCP_UDP="vless://${UUID}@${VPS_IP}:10014?security=none&encryption=none&type=kcp&headerType=none#${USER_NAME}-mkcp-udp"

    VMESS_WS_TLS="vmess://$(echo -n "{\"v\":\"2\",\"ps\":\"${USER_NAME}-vmess-tls\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${UUID}\",\"aid\":\"0\",\"net\":\"ws\",\"path\":\"/aliraza-vmess-ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}" | base64 -w 0)"
    VMESS_WS_80="vmess://$(echo -n "{\"v\":\"2\",\"ps\":\"${USER_NAME}-vmess-ntls\",\"add\":\"${DOMAIN}\",\"port\":\"80\",\"id\":\"${UUID}\",\"aid\":\"0\",\"net\":\"ws\",\"path\":\"/aliraza-vmess-ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"tls\":\"none\"}" | base64 -w 0)"
    VMESS_HUP="vmess://$(echo -n "{\"v\":\"2\",\"ps\":\"${USER_NAME}-vmess-hup-tls\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${UUID}\",\"aid\":\"0\",\"net\":\"httpupgrade\",\"path\":\"/aliraza-vmess-httpupgrade\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}" | base64 -w 0)"
    VMESS_GRPC="vmess://$(echo -n "{\"v\":\"2\",\"ps\":\"${USER_NAME}-vmess-grpc\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${UUID}\",\"aid\":\"0\",\"net\":\"grpc\",\"path\":\"aliraza-vmess-grpc\",\"type\":\"gun\",\"host\":\"${DOMAIN}\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}" | base64 -w 0)"
    VMESS_XHTTP="vmess://$(echo -n "{\"v\":\"2\",\"ps\":\"${USER_NAME}-vmess-xhttp\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${UUID}\",\"aid\":\"0\",\"net\":\"xhttp\",\"path\":\"/aliraza-vmess-xhttp\",\"type\":\"auto\",\"host\":\"${DOMAIN}\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}" | base64 -w 0)"

    TROJAN_WS_TLS="trojan://${USER_PASS}@${DOMAIN}:443?path=%2Faliraza-trojan-ws&security=tls&host=${DOMAIN}&type=ws&sni=${DOMAIN}#${USER_NAME}-trojan-tls"
    TROJAN_WS_80="trojan://${USER_PASS}@${DOMAIN}:80?path=%2Faliraza-trojan-ws&security=none&host=${DOMAIN}&type=ws&sni=${DOMAIN}#${USER_NAME}-trojan-ntls"
    TROJAN_HUP="trojan://${USER_PASS}@${DOMAIN}:443?path=%2Faliraza-trojan-httpupgrade&security=tls&host=${DOMAIN}&type=httpupgrade&sni=${DOMAIN}#${USER_NAME}-trojan-hup-tls"
    TROJAN_GRPC="trojan://${USER_PASS}@${DOMAIN}:443?mode=gun&security=tls&type=grpc&serviceName=aliraza-trojan-grpc&sni=${DOMAIN}#${USER_NAME}-trojan-grpc"
    TROJAN_XHTTP="trojan://${USER_PASS}@${DOMAIN}:443?path=%2Faliraza-trojan-xhttp&security=tls&mode=auto&type=xhttp&host=${DOMAIN}&sni=${DOMAIN}#${USER_NAME}-trojan-xhttp"
    SS_LINK="ss://$(echo -n "chacha20-ietf-poly1305:${USER_PASS}" | base64 -w 0)@${DOMAIN}:8888#${USER_NAME}-ss"
    SS22_USER=$(printf '%s' "ss22${UUID}" | openssl dgst -sha256 -binary | head -c 16 | base64 -w 0)
    SS2022_LINK="ss://$(echo -n "2022-blake3-aes-128-gcm:${SS22_KEY}:${SS22_USER}" | base64 -w 0)@${VPS_IP}:10015#${USER_NAME}-ss2022"
    HY2_LINK="hysteria2://${USER_NAME}:${USER_PASS}@${DOMAIN}:20800?insecure=1&sni=${DOMAIN}#${USER_NAME}-hysteria2"

    OUT_FILE="${CLIENTS_DIR}/${USER_NAME}.txt"
    blk() { printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n   %s\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n%s\n%s\n%s\n\n" "$1" "$B3" "$2" "$B3"; }
    {
        printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n   👑 ALIRAZA VIP 👑\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        printf "• Username : %s%s%s\n• Password : %s%s%s\n• UUID     : %s%s%s\n" "$B1" "$USER_NAME" "$B1" "$B1" "$USER_PASS" "$B1" "$B1" "$UUID" "$B1"
        printf "• Quota GB : %s GB (0=Unlim)\n• IP Limit : %s Devices\n• Expiry   : %s\n" "$QUOTA_GB" "$IP_LIMIT" "$EXP_DATE"
        printf "• Host/SNI : %s%s%s\n• BunnyCDN : %s%s%s\n\n" "$B1" "$DOMAIN" "$B1" "$B1" "$BUNNY_HOST" "$B1"
        printf "Protocols : %s%s%s\n\n" "$B1" "$([[ "$PROTOS" == all ]] && echo ALL || echo "$PROTOS")" "$B1"
        want ssh && blk "SSH SSL / TLS 443" "${DOMAIN}:443@${USER_NAME}:${USER_PASS}"
        want ssh && blk "SSH NTLS / HTTP 80" "${DOMAIN}:80@${USER_NAME}:${USER_PASS}"
        want zivpn && blk "ZiVPN UDP" "ZiVPN Host/IP : ${VPS_IP} (Ports: 5667 / 6000-19999)
ZiVPN Pass    : ${USER_PASS}"
        want ssh && blk "UDP Custom" "UDP Custom    : ${VPS_IP}:22@${USER_NAME}:${USER_PASS} (Port 1-32767)"
        want ssh && blk "SSH WS Payload" "GET / HTTP/1.1[crlf]Host: ${DOMAIN}[crlf]Upgrade: websocket[crlf]Connection: Keep-Alive[crlf][crlf]"
        { want slowdns || want ssh; } && blk "SlowDNS (DNSTT)" "DNS : https://dns.google/dns-query
NS  : ${NS_DOMAIN}
Key : ${SLOWDNS_PUBKEY}"
        want vless && blk "Link TLS" "$VLESS_WS_TLS"
        want vless && blk "Link NTLS" "$VLESS_WS_80"
        want vless && blk "Link HUP-TLS" "$VLESS_HUP_443"
        want vless && blk "Link HUP-NTLS" "$VLESS_HUP_80"
        want vless && blk "Link gRPC-TLS" "$VLESS_GRPC"
        want vless && blk "Link XHTTP-TLS" "$VLESS_XHTTP_443"
        want vless && blk "Link XHTTP-NTLS" "$VLESS_XHTTP_80"
        want vless && blk "VLESS Vision TLS (443)" "$VLESS_VISION_443"
        want vless && blk "VLESS Reality (443)" "$VLESS_REALITY_443"
        want vless && blk "VLESS mKCP UDP (10014)" "$VLESS_MKCP_UDP"
        want vmess && blk "VMess Link TLS" "$VMESS_WS_TLS"
        want vmess && blk "VMess Link NTLS" "$VMESS_WS_80"
        want vmess && blk "VMess Link HUP-TLS" "$VMESS_HUP"
        want vmess && blk "VMess Link gRPC-TLS" "$VMESS_GRPC"
        want vmess && blk "VMess Link XHTTP-TLS" "$VMESS_XHTTP"
        want trojan && blk "Trojan Link TLS" "$TROJAN_WS_TLS"
        want trojan && blk "Trojan Link NTLS" "$TROJAN_WS_80"
        want trojan && blk "Trojan Link HUP-TLS" "$TROJAN_HUP"
        want trojan && blk "Trojan Link gRPC-TLS" "$TROJAN_GRPC"
        want trojan && blk "Trojan Link XHTTP-TLS" "$TROJAN_XHTTP"
        want hy2 && blk "Hysteria2" "${HY2_LINK}"
        want ss && blk "Shadowsocks" "${SS2022_LINK}
${SS_LINK}"
        want socks5 && blk "Socks5 / HTTP" "Socks5: ${VPS_IP}:10808@${USER_NAME}:${USER_PASS}
HTTP  : ${VPS_IP}:10809@${USER_NAME}:${USER_PASS}"
        printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n📢 Telegram: t.me/ar_tricks\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
    } > "$OUT_FILE"

    BUNNY_FILE="${BUNNY_DIR}/${USER_NAME}-bunnycdn.txt"
    B_VMESS_TLS="vmess://$(echo -n "{\"v\":\"2\",\"ps\":\"${USER_NAME}-bunny-tls\",\"add\":\"${BUNNY_HOST}\",\"port\":\"443\",\"id\":\"${UUID}\",\"aid\":\"0\",\"net\":\"ws\",\"path\":\"/aliraza-vmess-ws\",\"type\":\"none\",\"host\":\"${BUNNY_HOST}\",\"tls\":\"tls\",\"sni\":\"${BUNNY_HOST}\"}" | base64 -w 0)"
    B_VMESS_80="vmess://$(echo -n "{\"v\":\"2\",\"ps\":\"${USER_NAME}-bunny-80\",\"add\":\"${BUNNY_HOST}\",\"port\":\"80\",\"id\":\"${UUID}\",\"aid\":\"0\",\"net\":\"ws\",\"path\":\"/aliraza-vmess-ws\",\"type\":\"none\",\"host\":\"${BUNNY_HOST}\",\"tls\":\"none\"}" | base64 -w 0)"
    {
        printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n  🐰 ALIRAZA BUNNY-CDN 🐰\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        printf "• Username   : %s%s%s\n• Password   : %s%s%s\n• UUID       : %s%s%s\n" "$B1" "$USER_NAME" "$B1" "$B1" "$USER_PASS" "$B1" "$B1" "$UUID" "$B1"
        printf "• Bunny Host : %s%s%s\n• Origin IP  : %s%s%s\n• Expiry     : %s\n\n" "$B1" "$BUNNY_HOST" "$B1" "$B1" "$VPS_IP" "$B1" "$EXP_DATE"
        want ssh && blk "BunnyCDN SSH-SSL (443)" "${BUNNY_HOST}:443@${USER_NAME}:${USER_PASS}"
        want ssh && blk "BunnyCDN SSH-WS (80)" "${BUNNY_HOST}:80@${USER_NAME}:${USER_PASS}"
        want ssh && blk "BunnyCDN WS Payload" "GET / HTTP/1.1[crlf]Host: ${BUNNY_HOST}[crlf]Upgrade: websocket[crlf]Connection: Upgrade[crlf][crlf]"
        want vless && blk "BunnyCDN VLESS-WS TLS (443)" "vless://${UUID}@${BUNNY_HOST}:443?path=%2Faliraza-vless-ws&security=tls&encryption=none&host=${BUNNY_HOST}&type=ws&sni=${BUNNY_HOST}#${USER_NAME}-Bunny-TLS"
        want vless && blk "BunnyCDN VLESS-WS HTTP (80)" "vless://${UUID}@${BUNNY_HOST}:80?path=%2Faliraza-vless-ws&security=none&encryption=none&host=${BUNNY_HOST}&type=ws#${USER_NAME}-Bunny-80"
        want vless && blk "BunnyCDN VLESS-HUP TLS (443)" "vless://${UUID}@${BUNNY_HOST}:443?path=%2Faliraza-vless-httpupgrade&security=tls&encryption=none&host=${BUNNY_HOST}&type=httpupgrade&sni=${BUNNY_HOST}#${USER_NAME}-Bunny-HUP"
        want vless && blk "BunnyCDN VLESS-XHTTP (443)" "vless://${UUID}@${BUNNY_HOST}:443?path=%2Faliraza-vless-xhttp&security=tls&encryption=none&mode=auto&type=xhttp&host=${BUNNY_HOST}&sni=${BUNNY_HOST}#${USER_NAME}-Bunny-XHTTP"
        want vmess && blk "BunnyCDN VMess-WS TLS (443)" "$B_VMESS_TLS"
        want vmess && blk "BunnyCDN VMess-WS HTTP (80)" "$B_VMESS_80"
        want trojan && blk "BunnyCDN Trojan-WS TLS (443)" "trojan://${USER_PASS}@${BUNNY_HOST}:443?path=%2Faliraza-trojan-ws&security=tls&host=${BUNNY_HOST}&type=ws&sni=${BUNNY_HOST}#${USER_NAME}-Bunny-Trojan"
        printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n📢 Telegram: t.me/ar_tricks\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
    } > "$BUNNY_FILE"

    python3 - "$OUT_FILE" "/var/www/html/aliraza-${USER_NAME}.html" "$USER_NAME" << 'PY' 2>/dev/null || true
import sys, html, json
txt = open(sys.argv[1]).read()
page = f"""<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>ALIRAZA - {sys.argv[3]}</title><style>body{{background:#0d0221;color:#fff;font-family:sans-serif;padding:15px;margin:0}}.btn{{display:block;width:100%;padding:16px;background:linear-gradient(90deg,#ff007f,#7928ca);color:#fff;font-size:17px;font-weight:bold;border:none;border-radius:10px;cursor:pointer;margin-bottom:15px}}pre{{background:#190a36;padding:12px;border-radius:8px;overflow-x:auto;font-size:12px;border:1px solid #7928ca;white-space:pre}}</style></head><body><button class="btn" onclick="navigator.clipboard.writeText({json.dumps(txt)}).then(()=>this.innerText='✅ COPIED!')">📋 1-CLICK COPY FULL TELEGRAM POST</button><pre>{html.escape(txt)}</pre></body></html>"""
open(sys.argv[2], "w").write(page)
PY
    python3 - "$BUNNY_FILE" "/var/www/html/aliraza-${USER_NAME}-bunny.html" "${USER_NAME} (BunnyCDN)" << 'PY' 2>/dev/null || true
import sys, html, json
txt = open(sys.argv[1]).read()
page = f"""<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>BUNNY CDN - {sys.argv[3]}</title><style>body{{background:#0d0221;color:#fff;font-family:sans-serif;padding:15px;margin:0}}.btn{{display:block;width:100%;padding:16px;background:linear-gradient(90deg,#ff7700,#ff0055);color:#fff;font-size:17px;font-weight:bold;border:none;border-radius:10px;cursor:pointer;margin-bottom:15px}}pre{{background:#190a36;padding:12px;border-radius:8px;overflow-x:auto;font-size:12px;border:1px solid #ff7700;white-space:pre}}</style></head><body><button class="btn" onclick="navigator.clipboard.writeText({json.dumps(txt)}).then(()=>this.innerText='✅ BUNNY CDN COPIED!')">🐰 1-CLICK COPY BUNNY-CDN CONFIG</button><pre>{html.escape(txt)}</pre></body></html>"""
open(sys.argv[2], "w").write(page)
PY

    if [[ "$ACTION" == "create" ]]; then
        cat "$OUT_FILE"
        echo -e "\n\033[1;92m[★] MAIN 1-CLICK COPY LINK  : \033[1;96mhttp://${DOMAIN}/aliraza-${USER_NAME}.html\033[0m"
        echo -e "\033[1;93m[🐰] BUNNY-CDN SEPARATE FILE : \033[1;92m${BUNNY_FILE}\033[0m"
        echo -e "\033[1;93m[🐰] BUNNY-CDN 1-CLICK LINK  : \033[1;96mhttp://${DOMAIN}/aliraza-${USER_NAME}-bunny.html\033[0m"
    fi
elif [[ "$ACTION" == "lock" ]]; then
    L_USER="$2"; is_protected_user "$L_USER" && exit 1
    passwd -l "$L_USER" >/dev/null 2>&1 || true; usermod -s /usr/sbin/nologin "$L_USER" >/dev/null 2>&1 || true; pkill -9 -u "$L_USER" >/dev/null 2>&1 || true
    sed -i "s/^\(${L_USER}|.*|\)UNLOCKED/\1LOCKED/" "$USERS_DB" 2>/dev/null || true
    /usr/local/bin/aliraza-kick "$L_USER" >/dev/null 2>&1 || true
    sync_engines_py
    /usr/local/bin/aliraza-kick "$L_USER" >/dev/null 2>&1 || true
    echo "LOCKED:$L_USER"
elif [[ "$ACTION" == "unlock" ]]; then
    U_USER="$2"; NEW_DAYS="${3:-30}"; is_protected_user "$U_USER" && exit 1
    LINE=$(grep "^${U_USER}|" "$USERS_DB" 2>/dev/null | head -n1 || true)
    if [[ -n "$LINE" ]]; then
        UPASS=$(echo "$LINE" | cut -d'|' -f2); UUID=$(echo "$LINE" | cut -d'|' -f3); OLD_QUOTA="${4:-$(echo "$LINE" | cut -d'|' -f4)}"; OLD_IPLIM="${5:-$(echo "$LINE" | cut -d'|' -f5)}"
        NEW_EXP=$(date -d "+${NEW_DAYS} days" +"%Y-%m-%d")
        echo "0" > "$USAGE_DIR/${U_USER}.bytes"
        usermod -s /bin/bash -p "$(openssl passwd -6 "$UPASS")" "$U_USER" >/dev/null 2>&1 || true
        passwd -u "$U_USER" >/dev/null 2>&1 || true
        chage -E "$(date -d "$NEW_EXP + 1 day" +"%Y-%m-%d" 2>/dev/null || echo "$NEW_EXP")" "$U_USER" >/dev/null 2>&1 || true
        U_PROTOS=$(echo "$LINE" | cut -d'|' -f8); U_PROTOS="${U_PROTOS:-all}"
        [[ "$U_PROTOS" == "all" || ",$U_PROTOS," == *",ssh,"* || ",$U_PROTOS," == *",slowdns,"* ]] || { passwd -l "$U_USER" >/dev/null 2>&1 || true; usermod -s /usr/sbin/nologin "$U_USER" >/dev/null 2>&1 || true; }
        sed -i "s/^${U_USER}|.*/${U_USER}|${UPASS}|${UUID}|${OLD_QUOTA}|${OLD_IPLIM}|${NEW_EXP}|UNLOCKED|${U_PROTOS}/" "$USERS_DB"
        sync_engines_py
        /usr/local/bin/aliraza-cli regen "$U_USER" "$UPASS" "$OLD_QUOTA" "$OLD_IPLIM" >/dev/null 2>&1 || true
        echo "UNLOCKED:$U_USER:$NEW_EXP"
    fi
elif [[ "$ACTION" == "delete" ]]; then
    D_USER="$2"; is_protected_user "$D_USER" && exit 1
    passwd -l "$D_USER" >/dev/null 2>&1 || true; /usr/local/bin/aliraza-kick "$D_USER" >/dev/null 2>&1 || true
    pkill -9 -u "$D_USER" >/dev/null 2>&1 || true; userdel -rf "$D_USER" >/dev/null 2>&1 || true
    sed -i "/^${D_USER}|/d" "$USERS_DB" 2>/dev/null || true
    sync_engines_py
    rm -f "${CLIENTS_DIR}/${D_USER}.txt" "${CLIENTS_DIR}/${D_USER}-bunnycdn.txt" "${BUNNY_DIR}/${D_USER}-bunnycdn.txt" "$USAGE_DIR/${D_USER}.bytes" "$USERS_CONF_DIR/${D_USER}.conf" "/var/www/html/aliraza-${D_USER}.html" "/var/www/html/aliraza-${D_USER}-bunny.html"
    echo "DELETED:$D_USER"
fi
EOF
    chmod +x /usr/local/bin/aliraza-cli
}

regenerate_all_user_files() {
    rm -f "$CLIENTS_DIR"/*-bunnycdn.txt 2>/dev/null || true
    if [[ -s "$USERS_DB" ]]; then
        while IFS='|' read -r uname upass uuid q_gb ip_lim exp_date status protos; do
            [[ -z "$uname" ]] && continue
            /usr/local/bin/aliraza-cli regen "$uname" "$upass" "$q_gb" "$ip_lim" "$protos" >/dev/null 2>&1 || true
        done < "$USERS_DB"
    fi
}

# ============================================================================
# STYLISH VIP TELEGRAM BOT (HYBRID TAP-BUTTONS + CUSTOM TEXT INPUT WIZARD!)
# ============================================================================
setup_telegram_bot_daemon() {
    cat << 'EOF' > /usr/local/bin/aliraza-tgbot.py
#!/usr/bin/env python3
import os, time, json, urllib.request, subprocess, random

TG_CONF = "/etc/aliraza/tgbot.conf"
TG_ADMINS = "/etc/aliraza/tg_admins.txt"
USERS_DB = "/etc/aliraza/users.db"
USAGE_DIR = "/etc/aliraza/usage"
CLIENTS_DIR = "/root/aliraza-configs"
BUNNY_DIR = "/root/aliraza-configs/bunnycdn"

def load_conf():
    if os.path.exists(TG_CONF):
        for l in open(TG_CONF):
            if l.startswith("TOKEN="): return l.strip().split("=", 1)[1]
    return ""

def get_admins():
    return {int(l.strip()) for l in open(TG_ADMINS) if l.strip().isdigit()} if os.path.exists(TG_ADMINS) else set()

def api_call(token, method, data=None):
    try:
        req = urllib.request.Request(
            f"https://api.telegram.org/bot{token}/{method}",
            data=json.dumps(data).encode() if data else None,
            headers={"Content-Type": "application/json"} if data else {}
        )
        with urllib.request.urlopen(req, timeout=35) as r:
            return json.loads(r.read().decode())
    except Exception:
        return {}

def send_msg(token, cid, text, reply_markup=None, parse_mode="Markdown"):
    payload = {"chat_id": cid, "text": text}
    if parse_mode: payload["parse_mode"] = parse_mode
    if reply_markup: payload["reply_markup"] = reply_markup
    res = api_call(token, "sendMessage", payload)
    if not res.get("ok") and parse_mode:
        payload.pop("parse_mode", None)
        api_call(token, "sendMessage", payload)

def send_long_markdown(token, cid, text, reply_markup=None):
    chunks, cur = [], ""
    for block in text.split("\n\n"):
        if len(cur) + len(block) + 2 > 3800:
            chunks.append(cur)
            cur = block
        else:
            cur = (cur + "\n\n" + block) if cur else block
    if cur: chunks.append(cur)
    for i, ch in enumerate(chunks):
        rm = reply_markup if i == len(chunks) - 1 else None
        send_msg(token, cid, ch, rm, "Markdown")

def fmt_b(b):
    b = float(b or 0)
    if b >= 1073741824: return f"{b/1073741824:.2f} GB"
    return f"{b/1048576:.2f} MB"

def main_kb():
    return {"inline_keyboard": [
        [{"text": "⚡ Create VIP Account", "callback_data": "create_vip"}, {"text": "⏱️ Fast 24h Trial", "callback_data": "create_trial"}],
        [{"text": "📊 Real GB & Live SIM IPs", "callback_data": "live_stats"}, {"text": "📋 All Accounts List", "callback_data": "list_users"}],
        [{"text": "📂 View User / Bunny Config", "callback_data": "view_cfg"}, {"text": "🔄 Renew / Edit GB", "callback_data": "renew_user"}],
        [{"text": "🔒 Lock User", "callback_data": "lock_user"}, {"text": "🔓 Unlock User", "callback_data": "unlock_user"}, {"text": "🗑️ Delete User", "callback_data": "del_user"}],
        [{"text": "🖥️ Server Status", "callback_data": "srv_status"}, {"text": "♻️ Restart All", "callback_data": "restart_all"}, {"text": "🧹 Clean RAM", "callback_data": "clean_ram"}]
    ]}

def cancel_kb(rows=None):
    kb = list(rows) if rows else []
    kb.append([{"text": "🔙 Cancel / Main Menu", "callback_data": "menu_home"}])
    return {"inline_keyboard": kb}

def user_buttons_kb(prefix):
    rows, cur = [], []
    if os.path.exists(USERS_DB):
        for ln in open(USERS_DB):
            pts = ln.strip().split("|")
            if len(pts) >= 7 and pts[0]:
                cur.append({"text": f"👤 {pts[0]}", "callback_data": f"{prefix}:{pts[0]}"})
                if len(cur) == 3:
                    rows.append(cur); cur = []
    if cur: rows.append(cur)
    return cancel_kb(rows)

def get_pass_kb(uname):
    return cancel_kb([
        [{"text": "🔑 1234", "callback_data": "set_pass:1234"}, {"text": "🔑 1122", "callback_data": "set_pass:1122"}, {"text": f"🔑 {uname}", "callback_data": f"set_pass:{uname}"}]
    ])

def get_gb_kb():
    return cancel_kb([
        [{"text": "📦 5 GB", "callback_data": "set_gb:5"}, {"text": "📦 10 GB", "callback_data": "set_gb:10"}, {"text": "📦 25 GB", "callback_data": "set_gb:25"}],
        [{"text": "📦 50 GB", "callback_data": "set_gb:50"}, {"text": "📦 100 GB", "callback_data": "set_gb:100"}, {"text": "♾️ Unlimited (0)", "callback_data": "set_gb:0"}]
    ])

def get_ip_kb():
    return cancel_kb([
        [{"text": "📱 1 IP", "callback_data": "set_ip:1"}, {"text": "📱 2 IPs", "callback_data": "set_ip:2"}, {"text": "📱 3 IPs", "callback_data": "set_ip:3"}],
        [{"text": "📱 5 IPs", "callback_data": "set_ip:5"}, {"text": "📱 10 IPs", "callback_data": "set_ip:10"}, {"text": "📱 50 IPs", "callback_data": "set_ip:50"}]
    ])

PROTO_BTNS = [("All Protocols", "all"), ("SSH / WS / SSL", "ssh"), ("VLESS", "vless"), ("VMess", "vmess"), ("Trojan", "trojan"), ("Shadowsocks", "ss"), ("Socks5/HTTP", "socks5"), ("ZiVPN UDP", "zivpn"), ("Hysteria2", "hy2"), ("SlowDNS", "slowdns")]
def get_proto_kb():
    rows, row = [], []
    for t, k in PROTO_BTNS:
        row.append({"text": t, "callback_data": "set_proto:" + k})
        if len(row) == 2: rows.append(row); row = []
    if row: rows.append(row)
    return cancel_kb(rows)

def get_days_kb():
    return cancel_kb([
        [{"text": "📅 1 Day", "callback_data": "set_days:1"}, {"text": "📅 3 Days", "callback_data": "set_days:3"}, {"text": "📅 7 Days", "callback_data": "set_days:7"}],
        [{"text": "📅 15 Days", "callback_data": "set_days:15"}, {"text": "📅 30 Days", "callback_data": "set_days:30"}, {"text": "📅 60 Days", "callback_data": "set_days:60"}]
    ])

def get_live_ips():
    # v55.4: shared AUTH-ONLY REAL SIM IP engine (fake CDN IPs filtered)
    try:
        out = subprocess.getoutput("python3 /usr/local/bin/aliraza-liveips.py --bot 2>/dev/null").strip()
        if out:
            return out
        return out
    except Exception:
        pass
    cmd = r"""python3 -c '
import os, json, subprocess, re, datetime, ipaddress, pwd, time
USERS_DB="/etc/aliraza/users.db"; WS_MAP="/run/aliraza_ws_map.json"; ACT_U="/run/aliraza_active_users.json"
vu=[l.strip().split("|")[0] for l in open(USERS_DB) if len(l.strip().split("|"))>=7 and l.strip().split("|")[6]=="UNLOCKED"] if os.path.exists(USERS_DB) else []
if not vu: raise SystemExit()
vset=set(vu); du=vu[0]
vip=open("/etc/aliraza/vps_ip.txt").read().strip() if os.path.exists("/etc/aliraza/vps_ip.txt") else ""
def ok(ip):
    ip=str(ip).strip().strip("[]").replace("::ffff:","")
    if not ip or ip==vip: return False
    try: a=ipaddress.ip_address(ip); return a.is_global and not (a.is_private or a.is_loopback)
    except: return False
peers={}
def add(ip,pr,u):
    ip=str(ip).strip().strip("[]").replace("::ffff:","")
    if ok(ip): peers.setdefault(ip,set()).add(f"{pr}({u if u in vset else du})")
wm=json.loads(open(WS_MAP).read()) if os.path.exists(WS_MAP) else {}
am=json.loads(open(ACT_U).read()) if os.path.exists(ACT_U) else {}
now_ts=int(time.time())
rx_u=next((u for u,ts in sorted(am.items(),key=lambda x:-x[1]) if u in vset and now_ts-ts<30),None)
_ap={}
for _ln2 in subprocess.getoutput("tail -n 200 /var/log/auth.log 2>/dev/null").splitlines():
    if "Accepted password for" in _ln2 or "Password auth succeeded" in _ln2:
        _mu=re.search(r"for '([^']+)'",_ln2) or re.search(r"for (\S+)",_ln2)
        _mp=re.search(r"from [0-9a-fA-F:\.]+(?::| port )(\d+)",_ln2)
        if _mu and _mp and _mu.group(1) in vset: _ap[_mp.group(1)]=_mu.group(1)
for k,we in wm.items():
    if we.get("open",True):
        m=we.get("mode","SSH-WS")
        if any(x in m for x in ("XRAY","VLESS","VMESS","TROJAN")):
            if rx_u: add(we.get("ip",""),m,rx_u)
        else:
            uu=_ap.get(k) or (du if now_ts-int(we.get("ts",now_ts) or now_ts)<15 else None)
            if uu: add(we.get("ip",""),m,uu)
for ln in subprocess.getoutput("ss -tnp state established").splitlines()[1:]:
    cs=ln.split()
    if len(cs)>=5:
        lp=cs[3].rsplit(":",1)[-1]; pip=cs[4].rsplit(":",1)[0].strip("[]").replace("::ffff:","")
        if lp in ("10022","444","8443","8444","10013") and ok(pip):
            add(pip,f"PORT-{lp}",rx_u or du)
for ip,prs in sorted(peers.items()): print(f"• {ip} -> {','.join(sorted(prs))}")
'"""
    return subprocess.getoutput(cmd).strip()

def finish_wizard(token, cid, st):
    act = st.get("act", "create")
    u = st["u"]; pw = st.get("pw", "1234"); gb = st.get("gb", "0"); ip = st.get("ip", "2"); days = st.get("days", "30")
    if act == "create":
        subprocess.getoutput(f"/usr/local/bin/aliraza-cli create {u} {pw} {gb} {ip} {days} {st.get('protos', 'all')}")
        cfg_p = f"{CLIENTS_DIR}/{u}.txt"
        if os.path.exists(cfg_p):
            kb = {"inline_keyboard": [
                [{"text": f"🐰 View {u} BunnyCDN File", "callback_data": f"show_bunny:{u}"}],
                [{"text": "🏠 Back to Main Menu", "callback_data": "menu_home"}]
            ]}
            send_long_markdown(token, cid, open(cfg_p).read(), kb)
        else:
            send_msg(token, cid, "❌ Account create nahi ho saka!", main_kb())
    elif act == "renew":
        subprocess.getoutput(f"/usr/local/bin/aliraza-cli unlock {u} {days} {gb} {ip}")
        send_msg(token, cid, f"✅ *Account Renewed & Quota Reset!*\n• User: `{u}`\n• Quota: `{gb} GB` | Max IP: `{ip}` | Days: `{days}`", main_kb())

def handle_step_input(token, cid, uid, state, val):
    st = state.get(uid)
    if not st: return False
    step = st.get("step", "")
    if step == "c_user":
        u = "".join(c for c in val if c.isalnum() or c in "_-")
        if not u or u in ("root", "ubuntu", "admin", "sshd"):
            send_msg(token, cid, "⚠️ Invalid ya protected username! Dusra naam likhein:", cancel_kb())
            return True
        st["u"] = u
        if st.get("act") == "renew":
            st["step"] = "c_gb"
            send_msg(token, cid, f"👤 User: `{u}`\n📦 *Step 2/4:* Naya GB Limit button tap karein ya chat me number likhein (0 = Unlimited):", get_gb_kb())
        else:
            st["step"] = "c_pass"
            send_msg(token, cid, f"👤 Username: `{u}`\n🔑 *Step 2/6:* Password button tap karein ya apni marzi ka password likh kar bhejein:", get_pass_kb(u))
        return True
    elif step == "c_pass":
        st["pw"] = val.strip() or "1234"
        st["step"] = "c_gb"
        send_msg(token, cid, f"🔑 Password: `{st['pw']}`\n📦 *Step 3/6:* Total GB Limit button tap karein ya khud number likh kar bhejein (0 = Unlimited):", get_gb_kb())
        return True
    elif step == "c_gb":
        gb = "".join(c for c in val if c.isdigit() or c == ".") or "0"
        st["gb"] = gb
        st["step"] = "c_ip"
        send_msg(token, cid, f"📦 Quota: `{gb} GB`\n📱 *Step 4/6:* Max IP / Device Limit button tap karein ya khud number likh kar bhejein:", get_ip_kb())
        return True
    elif step == "c_ip":
        ip_l = "".join(c for c in val if c.isdigit()) or "2"
        st["ip"] = ip_l
        st["step"] = "c_days"
        send_msg(token, cid, f"📱 IP Limit: `{ip_l} Devices`\n📅 *Step 5/6:* Validity Days button tap karein ya khud din likh kar bhejein:", get_days_kb())
        return True
    elif step == "c_days":
        days = "".join(c for c in val if c.isdigit()) or "30"
        st["days"] = days
        if st.get("act") == "renew":
            state.pop(uid, None)
            finish_wizard(token, cid, st)
        else:
            st["step"] = "c_proto"
            send_msg(token, cid, f"Validity: `{days} Days`\n*Step 6/6:* Protocol chunein (sirf wohi account banega):", get_proto_kb())
        return True
    elif step == "c_proto":
        k = val.strip().lower()
        if k not in ("all", "ssh", "vless", "vmess", "trojan", "ss", "socks5", "zivpn", "hy2", "slowdns"): k = "all"
        st["protos"] = k
        state.pop(uid, None)
        finish_wizard(token, cid, st)
        return True
    elif step in ("lock_user", "unlock_user", "del_user", "view_cfg"):
        u = val.strip().split()[0]
        state.pop(uid, None)
        if step == "lock_user":
            out = subprocess.getoutput(f"/usr/local/bin/aliraza-cli lock {u}")
            send_msg(token, cid, f"🔒 `{out}`", main_kb())
        elif step == "unlock_user":
            out = subprocess.getoutput(f"/usr/local/bin/aliraza-cli unlock {u} 30")
            send_msg(token, cid, f"🔓 `{out}`", main_kb())
        elif step == "del_user":
            out = subprocess.getoutput(f"/usr/local/bin/aliraza-cli delete {u}")
            send_msg(token, cid, f"🗑️ `{out}`", main_kb())
        elif step == "view_cfg":
            kb = {"inline_keyboard": [
                [{"text": f"📄 {u} Main Config", "callback_data": f"show_main:{u}"}, {"text": f"🐰 {u} BunnyCDN File", "callback_data": f"show_bunny:{u}"}],
                [{"text": "🏠 Main Menu", "callback_data": "menu_home"}]
            ]}
            send_msg(token, cid, f"📂 Select Config File for `{u}`:", kb)
        return True
    return False

def main():
    state, offset = {}, 0
    while True:
        token = load_conf()
        if not token:
            time.sleep(5); continue
        for upd in api_call(token, "getUpdates", {"offset": offset, "timeout": 25}).get("result", []):
            offset = upd["update_id"] + 1
            admins = get_admins()
            if "callback_query" in upd:
                cb = upd["callback_query"]
                uid = cb["from"]["id"]
                cid = cb["message"]["chat"]["id"]
                d = cb.get("data", "")
                api_call(token, "answerCallbackQuery", {"callback_query_id": cb["id"]})
                if uid not in admins: continue

                if d == "menu_home":
                    state.pop(uid, None)
                    send_msg(token, cid, "👑 *ALIRAZA VIP BOT PANEL*\nNeeche diye gaye buttons se control karein:", main_kb())
                elif d == "create_vip":
                    state[uid] = {"act": "create", "step": "c_user"}
                    kb = cancel_kb([[{"text": "🎲 Generate Random Username", "callback_data": f"set_user:vip{random.randint(1000,9999)}"}]])
                    send_msg(token, cid, "👤 *Step 1/5:* Naya Username chat me likh kar bhejein (ya Random button tap karein):", kb)
                elif d == "renew_user":
                    state[uid] = {"act": "renew", "step": "c_user"}
                    send_msg(token, cid, "🔄 *Renew / Edit Account:*\nNeeche user button tap karein ya username likh kar bhejein:", user_buttons_kb("set_user"))
                elif d.startswith("set_user:"):
                    handle_step_input(token, cid, uid, state, d.split(":", 1)[1])
                elif d.startswith("set_pass:"):
                    handle_step_input(token, cid, uid, state, d.split(":", 1)[1])
                elif d.startswith("set_gb:"):
                    handle_step_input(token, cid, uid, state, d.split(":", 1)[1])
                elif d.startswith("set_ip:"):
                    handle_step_input(token, cid, uid, state, d.split(":", 1)[1])
                elif d.startswith("set_days:"):
                    handle_step_input(token, cid, uid, state, d.split(":", 1)[1])
                elif d.startswith("set_proto:"):
                    handle_step_input(token, cid, uid, state, d.split(":", 1)[1])
                elif d == "create_trial":
                    uname = f"trial{random.randint(1000,9999)}"
                    subprocess.getoutput(f"/usr/local/bin/aliraza-cli create {uname} 1234 2 1 1")
                    kb = {"inline_keyboard": [
                        [{"text": f"🐰 View {uname} BunnyCDN File", "callback_data": f"show_bunny:{uname}"}],
                        [{"text": "🏠 Main Menu", "callback_data": "menu_home"}]
                    ]}
                    send_long_markdown(token, cid, open(f"{CLIENTS_DIR}/{uname}.txt").read(), kb)
                elif d in ("live_stats", "list_users"):
                    lines = ["📊 *REAL-TIME GB & LIVE SIM IPs:*"]
                    if os.path.exists(USERS_DB):
                        for r in open(USERS_DB):
                            pts = r.strip().split("|")
                            if len(pts) >= 7 and pts[0]:
                                ub = int(open(f"{USAGE_DIR}/{pts[0]}.bytes").read().strip() or 0) if os.path.exists(f"{USAGE_DIR}/{pts[0]}.bytes") else 0
                                lim = f"{pts[3]} GB" if float(pts[3] or 0) > 0 else "Unlim"
                                lines.append(f"👤 `{pts[0]}` ({pts[6]}) ➔ `{fmt_b(ub)} / {lim}` (Exp: {pts[5]})")
                    ips_txt = get_live_ips()
                    lines.append("\n🌐 *LIVE CONNECTED SIM IPs:*")
                    lines.append(f"```\n{ips_txt if ips_txt else '0 Clients Connected'}\n```")
                    send_msg(token, cid, "\n".join(lines), main_kb())
                elif d == "view_cfg":
                    state[uid] = {"step": "view_cfg"}
                    send_msg(token, cid, "📂 *View Config:* User button tap karein ya username likh kar bhejein:", user_buttons_kb("pick_cfg"))
                elif d.startswith("pick_cfg:"):
                    handle_step_input(token, cid, uid, state, d.split(":", 1)[1])
                elif d.startswith("show_main:"):
                    u = d.split(":", 1)[1]
                    p = f"{CLIENTS_DIR}/{u}.txt"
                    if os.path.exists(p): send_long_markdown(token, cid, open(p).read(), main_kb())
                    else: send_msg(token, cid, "❌ File nahi mili!", main_kb())
                elif d.startswith("show_bunny:"):
                    u = d.split(":", 1)[1]
                    p = f"{BUNNY_DIR}/{u}-bunnycdn.txt"
                    if os.path.exists(p): send_long_markdown(token, cid, open(p).read(), main_kb())
                    else: send_msg(token, cid, "❌ BunnyCDN file nahi mili!", main_kb())
                elif d in ("lock_user", "unlock_user", "del_user"):
                    state[uid] = {"step": d}
                    send_msg(token, cid, f"👤 Neeche user button tap karein ya username likh kar bhejein:", user_buttons_kb(f"do_{d}"))
                elif d.startswith("do_lock_user:") or d.startswith("do_unlock_user:") or d.startswith("do_del_user:"):
                    act_k, u = d.split(":", 1)
                    state[uid] = {"step": act_k.replace("do_", "")}
                    handle_step_input(token, cid, uid, state, u)
                elif d == "srv_status":
                    ram = subprocess.getoutput("free -m | awk '/Mem:/ {print $3\"/\"$2\" MB\"}'")
                    up = subprocess.getoutput("uptime -p")
                    dom = open("/etc/aliraza/domain.txt").read().strip() if os.path.exists("/etc/aliraza/domain.txt") else "Not-Set"
                    vip = open("/etc/aliraza/vps_ip.txt").read().strip() if os.path.exists("/etc/aliraza/vps_ip.txt") else ""
                    send_msg(token, cid, f"🖥️ *SERVER LIVE STATUS:*\n• IP: `{vip}`\n• Domain: `{dom}`\n• RAM: `{ram}`\n• Uptime: `{up}`", main_kb())
                elif d == "restart_all":
                    subprocess.Popen("systemctl restart dropbear nginx aliraza-ws haproxy xray zivpn hysteria udp-custom badvpn slowdns stunnel4 aliraza-monitor", shell=True)
                    send_msg(token, cid, "♻️ *All Services Restarted Successfully!*", main_kb())
                elif d == "clean_ram":
                    subprocess.Popen("sync; echo 3 > /proc/sys/vm/drop_caches; > /var/log/xray/access.log", shell=True)
                    send_msg(token, cid, "🧹 *RAM Cache & Logs Cleaned Safely!*", main_kb())
                continue

            msg = upd.get("message", {})
            if not msg or "text" not in msg: continue
            uid = msg["from"]["id"]
            cid = msg["chat"]["id"]
            txt = msg["text"].strip()
            if uid not in admins: continue
            if txt in ("/start", "/menu"):
                state.pop(uid, None)
                send_msg(token, cid, "👑 *ALIRAZA VIP BOT PANEL*\nNeeche diye gaye buttons se control karein:", main_kb())
                continue
            if not handle_step_input(token, cid, uid, state, txt):
                send_msg(token, cid, "👑 *ALIRAZA VIP BOT PANEL*", main_kb())

if __name__ == "__main__":
    main()
EOF
    chmod +x /usr/local/bin/aliraza-tgbot.py
    cat << 'EOF' > /etc/systemd/system/aliraza-tgbot.service
[Unit]
Description=ALIRAZA Telegram Bot
After=network.target
[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 /usr/local/bin/aliraza-tgbot.py
Restart=always
RestartSec=3s
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    [[ -s "$TG_CONF" ]] && systemctl restart aliraza-tgbot 2>/dev/null || true
}
# ============================================================================
# ALIRAZA WEB PANEL LAYER
# ============================================================================
SELF_PATH="$(readlink -f "$0" 2>/dev/null || echo "$0")"
CORE_PATH="/usr/local/bin/aliraza-core.sh"
PANEL_BIN="/usr/local/bin/aliraza-panel.py"
PANEL_CONF="/etc/aliraza/panel.conf"
RESERVED_PORTS=" 22 53 80 109 143 443 444 447 992 1194 2052 2053 2082 2083 2086 2087 2095 2096 2200 2222 5300 5667 7100 7200 7300 8080 8081 8082 8442 8443 8880 9999 10000 10001 10002 10003 10004 10005 10006 10007 10008 10009 10010 10011 10012 10013 10014 10015 10022 10808 20010 20090 20800 36712 "

panel_conf_get() { grep -m1 "^$1=" "$PANEL_CONF" 2>/dev/null | cut -d= -f2-; }

panel_port_ok() {
    local p="$1"
    [[ "$p" =~ ^[0-9]+$ ]] && (( p >= 1024 && p <= 65535 )) || { echo "Port 1024-65535 ke beech hona chahiye"; return 1; }
    [[ "$RESERVED_PORTS" == *" $p "* ]] && { echo "Port $p VPN protocols ke liye reserved hai"; return 1; }
    if ss -tln 2>/dev/null | grep -qE ":${p}\b"; then
        [[ "$(panel_conf_get PANEL_PORT)" == "$p" ]] && systemctl is-active --quiet aliraza-panel 2>/dev/null && return 0
        echo "Port $p pehle se kisi aur service ne use kiya hua hai"; return 1
    fi
    return 0
}

panel_hash_pw() { # $1 password -> prints "salt hash"
    PW="$1" python3 -c 'import os,secrets,hashlib;s=secrets.token_hex(16);print(s,hashlib.pbkdf2_hmac("sha256",os.environ["PW"].encode(),bytes.fromhex(s),200000).hex())'
}

panel_save_conf() { # user port pass
    local U="$1" P="$2" PW="$3" S H TLS
    read -r S H < <(panel_hash_pw "$PW")
    TLS=$(panel_conf_get PANEL_TLS); TLS="${TLS:-1}"
    mkdir -p "$DATA_DIR"
    printf 'PANEL_USER=%s\nPANEL_PORT=%s\nPANEL_TLS=%s\nPANEL_SALT=%s\nPANEL_HASH=%s\n' "$U" "$P" "$TLS" "$S" "$H" > "$PANEL_CONF"
    chmod 600 "$PANEL_CONF"
}

ask_panel_credentials() {
    local IN_PORT IN_USER IN_P1 MSG
    while true; do
        read -rp " • Panel Port [2026]: " IN_PORT || exit 1
        IN_PORT="${IN_PORT:-2026}"
        MSG=$(panel_port_ok "$IN_PORT") && break
        echo -e "   ${RED}[!] ${MSG}${NC}"
    done
    while true; do
        read -rp " • Panel Username [admin]: " IN_USER || exit 1
        IN_USER="${IN_USER:-admin}"
        [[ "$IN_USER" =~ ^[a-zA-Z0-9_-]{3,32}$ ]] && break
        echo -e "   ${RED}[!] Username 3-32 chars: a-z A-Z 0-9 _ -${NC}"
    done
    while true; do
        read -rp " • Panel Password (min 6): " IN_P1 || exit 1
        [[ ${#IN_P1} -lt 6 ]] && { echo -e "   ${RED}[!] Password kam az kam 6 characters ka ho${NC}"; continue; }
        break
    done
    PANEL_PORT_IN="$IN_PORT"; PANEL_USER_IN="$IN_USER"; PANEL_PASS_IN="$IN_P1"
    panel_save_conf "$IN_USER" "$IN_PORT" "$IN_P1"
}

install_web_panel() {
    mkdir -p /var/log/aliraza-panel
    cat << 'PANEL_PY_EOF' > "$PANEL_BIN"
#!/usr/bin/env python3
# AliRaza Web Panel - stdlib only (no pip needed)
import datetime, os, sys, json, time, re, hmac, hashlib, secrets, subprocess, threading, ssl, shutil, socket
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import urllib.request

ZDATA = os.environ.get("ZDATA", "/etc/aliraza")
CONF = os.environ.get("PANEL_CONF", ZDATA + "/panel.conf")
CORE = os.environ.get("ZCORE", "/usr/local/bin/aliraza-core.sh")
ZCLI = os.environ.get("ZCLI", "/usr/local/bin/aliraza-cli")
LIVEIPS = os.environ.get("ZLIVEIPS", "/usr/local/bin/aliraza-liveips.py")
KEYS_FILE = ZDATA + "/userkeys.json"
USERS_DB = ZDATA + "/users.db"
USAGE = ZDATA + "/usage"
CLIENTS = os.environ.get("ZCLIENTS", "/root/aliraza-configs")
BUNNY = CLIENTS + "/bunnycdn"
JOB_DIR = os.environ.get("JOB_DIR", "/var/log/aliraza-panel")
CERT, KEY = "/etc/ssl/xray/fullchain.pem", "/etc/ssl/xray/privkey.pem"
PORT_INFO = [["SSH WebSocket", "80, 8080, 8880, 2052, 2082"], ["SSH WS TLS / SSL", "443, 2053, 2083, 2087, 2096"], ["Dropbear (AliRaza-server)", "80"], ["Stunnel SSL", "444, 8443, 992"], ["UDP Custom", "1-32767 -> 36712"], ["ZiVPN UDP", "5667"],
    ["Hysteria 2", "20800"], ["SlowDNS", "53 / 5300"], ["OpenVPN", "TCP 1194 / UDP 2200"], ["Xray XHTTP", "10010"], ["Xray Reality", "10013"],
    ["Xray WS/gRPC/HUP", "80, 443"], ["Shadowsocks", "8888, 10015"], ["Socks5 / HTTP", "10808, 10809"], ["BadVPN UDPGW", "7100, 7200, 7300"]]
PROTO_KEYS = ["ssh", "vless", "vmess", "trojan", "ss", "socks5", "zivpn", "hy2", "slowdns"]
PORT_PROTO = {"SSH WebSocket": ["ssh"], "SSH WS TLS / SSL": ["ssh"], "Dropbear (AliRaza-server)": ["ssh"], "Stunnel SSL": ["ssh"],
    "UDP Custom": ["ssh"], "ZiVPN UDP": ["zivpn"], "Hysteria 2": ["hy2"], "SlowDNS": ["slowdns", "ssh"], "OpenVPN": ["ssh"],
    "Xray XHTTP": ["vless", "vmess", "trojan"], "Xray Reality": ["vless"], "Xray WS/gRPC/HUP": ["vless", "vmess", "trojan"],
    "Shadowsocks": ["ss"], "Socks5 / HTTP": ["socks5"], "BadVPN UDPGW": ["ssh"]}
def ports_for(protos):
    if not protos or protos == "all": return PORT_INFO
    sel = set(protos.split(","))
    return [p for p in PORT_INFO if sel & set(PORT_PROTO.get(p[0], [])) and not (p[0] == "OpenSSH" and os.path.exists("/etc/aliraza/.openssh_off"))]
ANSI = re.compile(r"\x1b\[[0-9;?]*[a-zA-Z]")
RE_USER = re.compile(r"^[a-zA-Z0-9_-]{1,32}$")
RE_PASS = re.compile(r"^[A-Za-z0-9_@#%+=:.-]{1,64}$")
RE_HOST = re.compile(r"^[A-Za-z0-9]([A-Za-z0-9.-]{0,250}[A-Za-z0-9])?$")
os.makedirs(JOB_DIR, exist_ok=True)

SERVICES = [
    ("dropbear", "tcp", 10022, "AliRaza-server Dropbear (SSH on 80/443)"),
    ("stunnel4", "tcp", 444, "Stunnel SSL (444/8443/992)"), ("aliraza-ws", "tcp", 10000, "Golang WS Engine (10000)"),
    ("haproxy", "tcp", 80, "HAProxy HTTP Mux (80/8080/8880/2052/2082)"), ("haproxy", "tcp", 443, "HAProxy TLS Mux (443/2053/2083/2087/2096)"),
    ("xray", "tcp", 10001, "Xray WS/gRPC/HUP"), ("xray", "tcp", 10010, "Xray Native XHTTP"),
    ("xray", "tcp", 10013, "Xray Reality & Vision"), ("xray", "udp", 10014, "Xray VLESS mKCP UDP"),
    ("xray", "tcp", 10015, "Shadowsocks-2022 & AEAD"), ("xray", "tcp", 10808, "Socks5 & HTTP Proxy"),
    ("openvpn-server@server-tcp", "tcp", 1194, "OpenVPN TCP/UDP (1194/2200)"), ("zivpn", "udp", 5667, "ZiVPN UDP (5667)"),
    ("udp-custom", "udp", 36712, "SSH UDP Custom (36712)"), ("hysteria", "udp", 20800, "Hysteria 2 QUIC (20800)"),
    ("slowdns", "udp", 5300, "SlowDNS Server (53/5300)"),
]
RESTARTABLE = {"ssh", "dropbear", "stunnel4", "aliraza-ws", "haproxy", "nginx", "xray", "zivpn", "hysteria",
               "udp-custom", "badvpn", "slowdns", "aliraza-monitor", "aliraza-tgbot", "openvpn-server@server-tcp", "openvpn-server@server-udp"}

# ---------------- helpers ----------------
def clean(s): return ANSI.sub("", s or "").replace("\r", "")

def sh(args, timeout=60, shell=False):
    try:
        p = subprocess.run(args, shell=shell, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
        return p.returncode, clean(p.stdout.decode("utf-8", "replace"))
    except subprocess.TimeoutExpired:
        return 124, "Timeout"
    except Exception as e:
        return 1, str(e)

def core(fn, *args, timeout=180): return sh(["bash", CORE, "--fn", fn] + [str(a) for a in args], timeout=timeout)

def rd(path, default=""):
    try:
        with open(path, errors="ignore") as f: return f.read().strip()
    except Exception: return default

def rd1(path, default=""):
    return (rd(path, default).splitlines() or [default])[0].strip()

def load_conf():
    d = {}
    for ln in rd(CONF).splitlines():
        if "=" in ln and not ln.startswith("#"):
            k, v = ln.split("=", 1); d[k.strip()] = v.strip()
    return d

def ceq(a, b): return hmac.compare_digest(str(a).encode("utf-8", "replace"), str(b).encode("utf-8", "replace"))

def hash_pw(pw, salt): return hashlib.pbkdf2_hmac("sha256", pw.encode(), bytes.fromhex(salt), 200000).hex()

def save_conf(d):
    tmp = CONF + ".tmp"
    with open(tmp, "w") as f:
        for k, v in d.items(): f.write("%s=%s\n" % (k, v))
    os.chmod(tmp, 0o600); os.replace(tmp, CONF)

_cache = {}
def cached(key, ttl, fn):
    now = time.time(); c = _cache.get(key)
    if c and now - c[0] < ttl: return c[1]
    v = fn(); _cache[key] = (now, v); return v

# ---------------- data ----------------
def vps_ip():
    ip = rd1(ZDATA + "/vps_ip.txt")
    if ip and ip != "127.0.0.1": return ip
    rc, out = sh("curl -s4 --max-time 3 api.ipify.org", timeout=6, shell=True)
    return out.strip() if rc == 0 and out.strip() else "Unknown"

def ping_ms():
    rc, out = sh(["ping", "-c", "1", "-W", "1", "8.8.8.8"], timeout=4)
    m = re.search(r"time=([0-9.]+)", out)
    return float(m.group(1)) if m else None

def dns_a(host):
    rc, out = sh(["dig", "+short", "+time=2", "+tries=1", "A", host, "@8.8.8.8"], timeout=6)
    ips = [x for x in out.split() if re.match(r"^\d+\.\d+\.\d+\.\d+$", x)]
    return ips[-1] if ips else ""

def dom_status(dom, ip):
    if not dom or dom == "Not-Set": return "NOT SET"
    if dom == ip: return "IP ONLY"
    a = cached("dom:" + dom, 60, lambda: dns_a(dom))
    if not a: return "NOT POINTED"
    return "POINTED" if a == ip else "OTHER IP (%s)" % a

_UC = [None, None]
def load_users():
    try:
        _st = os.stat(USERS_DB); _sig = (_st.st_mtime_ns, _st.st_size, int(time.time() // 3))
    except OSError:
        _sig = None
    if _sig is not None and _UC[0] == _sig: return [dict(x) for x in _UC[1]]
    rows = []
    for ln in rd(USERS_DB).splitlines():
        p = ln.strip().split("|")
        if len(p) >= 7 and p[0]:
            try: used = int(re.sub(r"\D", "", rd1("%s/%s.bytes" % (USAGE, p[0]), "0")) or 0)
            except Exception: used = 0
            try:
                q = float(p[3] or 0)
                q = int(q) if q == int(q) else round(q, 4)
            except Exception: q = 0
            rows.append({"username": p[0], "uuid": p[2], "password": p[1], "quota_gb": q, "ip_limit": p[4], "expiry": p[5], "status": p[6], "used": used, "protos": (p[7] if len(p) > 7 and p[7] else "all")})
    _UC[0] = _sig; _UC[1] = rows
    return [dict(x) for x in rows]

# v59.6: liveips engine ab panel ke andar hi (in-process) chalta hai - har baar naya python process spawn nahi hota (~100-300ms bachat)
_LVM = {"mod": None, "mt": 0.0, "lock": threading.Lock(), "bad": 0}
def _lv_module():
    try: mt = os.path.getmtime(LIVEIPS)
    except Exception: return None
    if _LVM["mod"] is not None and _LVM["mt"] == mt: return _LVM["mod"]
    import importlib.machinery, importlib.util
    ldr = importlib.machinery.SourceFileLoader("aliraza_liveips_fast", LIVEIPS)
    spec = importlib.util.spec_from_loader("aliraza_liveips_fast", ldr)
    m = importlib.util.module_from_spec(spec); ldr.exec_module(m)
    if not (hasattr(m, "build_peers") and hasattr(m, "render")): raise RuntimeError("liveips: build_peers/render missing")
    _LVM["mod"] = m; _LVM["mt"] = mt
    return m

def _live_rows_fast():
    m = _lv_module()
    if m is None: raise RuntimeError("liveips missing")
    with _LVM["lock"]:
        return "\n".join(m.render(m.build_peers(), False) or [])

def live_ips():
    def f():
        out = None
        if _LVM["bad"] < 3:
            try: out = _live_rows_fast(); _LVM["bad"] = 0
            except Exception: _LVM["bad"] += 1; out = None
        if out is None:
            rc, out = sh(["python3", LIVEIPS], timeout=20)
        res = []
        for ln in out.splitlines():
            p = ln.split("|")
            if len(p) >= 4 and re.match(r"^[0-9a-fA-F:.]+$", p[1]): res.append({"ip": p[1], "ports": p[2], "tunnels": p[3], "sess": (p[4] if len(p) > 4 else "")})
        return res
    return cached("live", 0.03, f)

# ---------- v59.5: IP -> EXACT SIM / ISP operator (Pakistan + India + world fallback) ----------
import ipaddress
# (name, color, country, mobile_only, [keywords], [ASNs])
CARRIERS = [
    # ---- Pakistan (mobile) ----
    ("Jazz",      "#e30613", "PK", True,  ["pakistan mobile communications", "pmcl", "mobilink", "jazz", "warid"], [45669]),
    ("Zong",      "#8dc63f", "PK", True,  ["cmpak", "zong", "china mobile pakistan"], [59257]),
    ("Ufone",     "#f7941d", "PK", True,  ["ufone", "ptml", "pakistan telecommunication mobile", "pak telecom mobile"], []),
    ("Telenor",   "#00a1e0", "PK", True,  ["telenor pakistan", "telenor"], [24499]),
    ("SCOM",      "#2e8b57", "PK", True,  ["special communications organization", "scom"], []),
    # ---- Pakistan (broadband / fiber) ----
    ("PTCL",      "#00a651", "PK", False, ["ptcl", "pakistan telecommunication company", "smartlink"], [17557, 38264]),
    ("StormFiber","#ffb400", "PK", False, ["stormfiber", "storm fiber", "cybernet", "lakson"], []),
    ("Nayatel",   "#0a74da", "PK", False, ["nayatel"], []),
    ("Wateen",    "#e2001a", "PK", False, ["wateen", "qubee"], []),
    ("Transworld","#1f6fb5", "PK", False, ["transworld associates", "twa"], []),
    ("WorldCall", "#d4145a", "PK", False, ["worldcall", "world call"], []),
    ("Wi-Tribe",  "#6a1b9a", "PK", False, ["wi-tribe", "witribe"], []),
    ("Multinet",  "#0d47a1", "PK", False, ["multinet"], []),
    ("Supernet",  "#00897b", "PK", False, ["supernet"], []),
    ("Fiberlink", "#5e35b1", "PK", False, ["fiberlink"], []),
    # ---- India (mobile) ----
    ("Jio",       "#0a5cff", "IN", True,  ["reliance jio", "jio"], [55836, 64049]),
    ("Airtel",    "#ed1c24", "IN", True,  ["bharti airtel", "airtel"], [24560, 9498, 45609]),
    ("Vi (Vodafone Idea)", "#e60000", "IN", True, ["vodafone idea", "vodafone india", "idea cellular", "vodafone"], [38266, 55410]),
    ("BSNL",      "#f58220", "IN", True,  ["bsnl", "bharat sanchar", "national internet backbone"], [9829, 17426]),
    ("MTNL",      "#005baa", "IN", True,  ["mtnl", "mahanagar telephone"], [17813]),
    ("Aircel",    "#8e44ad", "IN", True,  ["aircel", "dishnet"], []),
    ("Reliance Comm.", "#1a73e8", "IN", True, ["reliance communications"], []),
    # ---- India (broadband / fiber) ----
    ("ACT Fibernet", "#f36f21", "IN", False, ["act fibernet", "atria convergence"], [24309]),
    ("Hathway",   "#e31e24", "IN", False, ["hathway"], [17488]),
    ("Tata",      "#0072bc", "IN", False, ["tata play", "tata teleservices", "tata communications", "tata tele"], [4755, 45820]),
    ("Excitel",   "#ff4f00", "IN", False, ["excitel"], [133982]),
    ("Sify",      "#0066b3", "IN", False, ["sify"], [9583]),
    ("Tikona",    "#00a859", "IN", False, ["tikona"], []),
    ("Spectra",   "#7b1fa2", "IN", False, ["spectranet", "spectra"], []),
    ("You Broadband", "#d81b60", "IN", False, ["you broadband", "you telecom"], []),
    ("Alliance",  "#1565c0", "IN", False, ["alliance broadband"], []),
    ("GTPL",      "#e53935", "IN", False, ["gtpl"], []),
    ("Railwire",  "#00838f", "IN", False, ["railtel", "railwire"], []),
    ("Netplus",   "#00acc1", "IN", False, ["netplus"], []),
    ("Connect Broadband", "#43a047", "IN", False, ["connect broadband", "i-net"], []),
]
IPINFO = {}; IPINFO_Q = set(); IPINFO_FAIL = {}; IPINFO_L = threading.Lock()
IPINFO_TTL = 6 * 3600

def _flag(cc):
    try:
        cc = (cc or "").upper()
        if len(cc) != 2 or not cc.isalpha(): return ""
        return chr(0x1F1E6 + ord(cc[0]) - 65) + chr(0x1F1E6 + ord(cc[1]) - 65)
    except Exception:
        return ""

def _asn_num(s):
    m = re.search(r"AS?(\d{2,10})", str(s or ""), re.I)
    return int(m.group(1)) if m else 0

def detect_carrier(cc, asn, blob):
    """ASN pehle (sab se pakka), phir naam ke keywords. Country match zaroori (Airtel Africa != Airtel India)."""
    cc = (cc or "").upper(); blob = (blob or "").lower()
    for name, color, c, mob, kws, asns in CARRIERS:
        if cc and c != cc: continue
        if asn and asn in asns: return name, color, mob
    for name, color, c, mob, kws, asns in CARRIERS:
        if cc and c != cc: continue
        for k in kws:
            if k and k in blob: return name, color, mob
    return None

def _clean_isp(s):
    s = re.sub(r"\b(pvt|private|ltd|limited|llc|inc|co|corp|corporation|company|plc|gmbh)\b\.?", "", str(s or ""), flags=re.I)
    return re.sub(r"\s+", " ", s).strip(" ,.-") or "Unknown"

def _fetch_ipapi(ip):
    url = "http://ip-api.com/json/%s?fields=status,country,countryCode,regionName,city,isp,org,as,asname,mobile,proxy,hosting" % ip
    with urllib.request.urlopen(url, timeout=5) as r:
        d = json.loads(r.read().decode())
    if d.get("status") != "success": return None
    return {"cc": d.get("countryCode") or "", "country": d.get("country") or "", "city": d.get("city") or "",
            "isp": d.get("isp") or d.get("org") or "", "blob": " ".join(str(d.get(k) or "") for k in ("isp", "org", "asname", "as")),
            "asn": _asn_num(d.get("as")), "mobile": bool(d.get("mobile")), "hosting": bool(d.get("hosting") or d.get("proxy"))}

def _fetch_ipwho(ip):
    with urllib.request.urlopen("https://ipwho.is/%s" % ip, timeout=5) as r:
        d = json.loads(r.read().decode())
    if not d.get("success"): return None
    c = d.get("connection") or {}
    return {"cc": d.get("country_code") or "", "country": d.get("country") or "", "city": d.get("city") or "",
            "isp": c.get("isp") or c.get("org") or "", "blob": " ".join(str(c.get(k) or "") for k in ("isp", "org", "domain")),
            "asn": int(c.get("asn") or 0), "mobile": False, "hosting": False}

def _ipinfo_fetch(ip):
    try:
        raw = None
        for fn in (_fetch_ipapi, _fetch_ipwho):
            try:
                raw = fn(ip)
            except Exception:
                raw = None
            if raw: break
        if not raw:
            IPINFO_FAIL[ip] = time.time(); return
        hit = detect_carrier(raw["cc"], raw["asn"], raw["blob"])
        if hit:
            name, color, mob_only = hit
        else:
            name, color, mob_only = _clean_isp(raw["isp"]), "#8892a6", False
        if raw["hosting"]: kind = "VPN/Hosting"
        elif raw["mobile"] or (hit and mob_only): kind = "Mobile SIM"
        else: kind = "Broadband/WiFi"
        if len(IPINFO) > 2000:
            for k in sorted(IPINFO, key=lambda x: IPINFO[x]["ts"])[:500]: IPINFO.pop(k, None)
        IPINFO[ip] = {"carrier": name, "color": color, "known": bool(hit), "kind": kind, "cc": raw["cc"], "flag": _flag(raw["cc"]),
                      "country": raw["country"], "city": raw["city"], "isp": _clean_isp(raw["isp"]), "ts": time.time()}
    except Exception:
        IPINFO_FAIL[ip] = time.time()
    finally:
        with IPINFO_L: IPINFO_Q.discard(ip)

def _public_ip(ip):
    try:
        a = ipaddress.ip_address(ip)
        return not (a.is_private or a.is_loopback or a.is_link_local or a.is_reserved or a.is_multicast)
    except Exception:
        return False

def ipinfo_obj(ip):
    d = IPINFO.get(ip)
    if d and time.time() - d["ts"] < IPINFO_TTL: return d
    if not _public_ip(ip): return d
    with IPINFO_L:
        if ip not in IPINFO_Q and len(IPINFO_Q) < 20 and time.time() - IPINFO_FAIL.get(ip, 0) > 120:
            IPINFO_Q.add(ip)
            threading.Thread(target=_ipinfo_fetch, args=(ip,), daemon=True).start()
    return d

def ipinfo_text(ip):
    d = ipinfo_obj(ip)
    if d:
        icon = {"Mobile SIM": "📱", "VPN/Hosting": "⚠", "Broadband/WiFi": "🏠"}.get(d["kind"], "")
        loc = ", ".join(x for x in (d["city"], d["country"]) if x)
        parts = [("%s %s" % (d["flag"], d["carrier"])).strip()]
        if loc: parts.append(loc)
        parts.append("%s %s" % (icon, d["kind"]))
        return " · ".join(parts)
    return "" if ip in IPINFO_FAIL else "lookup ho raha hai..."

def ipinfo_sim(ip):
    d = ipinfo_obj(ip)
    if not d: return None
    return {"carrier": d["carrier"], "color": d["color"], "kind": d["kind"], "flag": d["flag"], "cc": d["cc"], "known": d["known"],
            "loc": ", ".join(x for x in (d["city"], d["country"]) if x), "isp": d["isp"]}

TAGRE = re.compile(r"([A-Za-z0-9/_.-]+)\(([^)]+)\)")
LIVE = {"data": None, "ts": 0.0, "want": 0.0, "seq": 0}
LIVE_CV = threading.Condition()
def live_snapshot():
    ips = live_ips(); users = load_users(); by = {}; byn = {}; known = set(); total_sess = 0
    def _scnt(l):
        d = {}
        for kv in (l.get("sess") or "").split(";"):
            k, _, v = kv.rpartition("=")
            if k and v.isdigit(): d[k] = int(v)
        return d
    for l in ips:
        sc = _scnt(l)
        for t in l["ports"].split(","):
            m = re.match(r"^(.+)\(([^)]+)\)$", t.strip())
            if not m: continue
            proto, u = m.group(1), m.group(2)
            by.setdefault(u, {}).setdefault(l["ip"], set()).add(proto); known.add(l["ip"])
            byn[(u, l["ip"])] = byn.get((u, l["ip"]), 0) + sc.get(t.strip(), 1)
            total_sess += sc.get(t.strip(), 1)
    out = []
    for u in users:
        conns = by.get(u["username"], {})
        out.append({"username": u["username"], "online": bool(conns), "status": u["status"], "used": u["used"], "quota_gb": u["quota_gb"],
                    "ip_limit": u["ip_limit"], "expiry": u["expiry"], "sessions": sum(byn.get((u["username"], ip), 1) for ip in conns),
                    "conns": [{"ip": ip, "protos": sorted(pr), "n": byn.get((u["username"], ip), 1)} for ip, pr in sorted(conns.items())]})
    out.sort(key=lambda x: (not x["online"], x["username"].lower()))
    ipl = []
    for l in ips:
        cs = []; sc = _scnt(l)
        for t in l["ports"].split(","):
            m = re.match(r"^(.+)\(([^)]+)\)$", t.strip())
            cs.append({"user": m.group(2) if m else "-", "proto": m.group(1) if m else t.strip(), "n": sc.get(t.strip(), 1)})
        ipl.append({"ip": l["ip"], "info": ipinfo_text(l["ip"]), "sim": ipinfo_sim(l["ip"]), "conns": cs})
    return {"ts": int(time.time()), "online": sum(1 for x in out if x["online"]), "total": len(out), "ip_count": len(ips), "sessions": total_sess,
            "ips": ipl, "users": out, "unassigned": [l["ip"] for l in ips if l["ip"] not in known]}

_LIVE_WATCH = ("/run/aliraza_ws_map.json", "/var/log/xray/access.log")
def _live_sig():
    sig = []
    for p in _LIVE_WATCH:
        try: st = os.stat(p); sig.append((st.st_mtime_ns, st.st_size))
        except OSError: sig.append(None)
    return tuple(sig)

def live_loop():
    # v59.7: event-driven - WS engine map / xray log badalte hi turant naya snapshot (max 0.25s heartbeat).
    # Data badla nahi to seq nahi badhta (browser ko faltu update nahi), 1s heartbeat me ts refresh hota hai.
    last_body = None; last_bump = 0.0
    while True:
        if time.time() - LIVE["want"] > 20:
            time.sleep(0.4); continue
        t0 = time.time(); base = _live_sig()
        try:
            d = live_snapshot(); d["ms"] = int((time.time() - t0) * 1000)
            body = json.dumps({k: v for k, v in d.items() if k not in ("ts", "ms", "seq")}, sort_keys=True, default=str)
            with LIVE_CV:
                if body != last_body or time.time() - last_bump >= 1.0:
                    LIVE["data"] = d; LIVE["ts"] = time.time(); LIVE["seq"] += 1; d["seq"] = LIVE["seq"]
                    last_body = body; last_bump = time.time()
                    LIVE_CV.notify_all()
                else:
                    LIVE["ts"] = time.time()
        except Exception:
            time.sleep(0.5)
        el = time.time() - t0
        floor = max(0.12, 1.5 * el)          # CPU bachane ke liye: busy server par bhi duty-cycle ~40% se kam
        end = t0 + max(0.25, floor)
        while time.time() < end:
            time.sleep(0.02)
            if time.time() - t0 >= floor and _live_sig() != base: break

def svc_status():
    def f():
        rc, tcp = sh("ss -tln", timeout=5, shell=True); rc, udp = sh("ss -uln", timeout=5, shell=True)
        res = []
        for svc, proto, port, label in SERVICES:
            rc, _ = sh(["systemctl", "is-active", "--quiet", svc], timeout=5)
            listen = re.search(r":%d(?=\s)" % port, tcp if proto == "tcp" else udp) is not None
            res.append({"service": svc, "label": label, "port": port, "proto": proto, "live": rc == 0 and listen})
        return res
    return cached("svc", 5, f)

def sysinfo():
    mem = {}
    for ln in rd("/proc/meminfo").splitlines():
        k, _, v = ln.partition(":"); mem[k] = int(v.split()[0]) // 1024 if v.split() else 0
    total = mem.get("MemTotal", 0); used = total - mem.get("MemAvailable", 0)
    du = shutil.disk_usage("/")
    up = float((rd("/proc/uptime") or "0 0").split()[0])
    la = (rd("/proc/loadavg") or "0 0 0").split()[:3]
    ip = vps_ip()
    dom = rd1(ZDATA + "/domain.txt", "Not-Set") or "Not-Set"
    ns = rd1(ZDATA + "/ns_domain.txt", "Not-Set") or "Not-Set"
    bh = rd1(ZDATA + "/bunny_host.txt", "Not-Set") or "Not-Set"
    users = load_users()
    return {
        "ip": ip, "provider": cached("prov", 3600, lambda: rd1(ZDATA + "/provider.txt", "Cloud VPS")),
        "ping": cached("ping", 15, ping_ms), "cpus": os.cpu_count() or 1, "load": la,
        "ram_used": used, "ram_total": total, "disk_used": du.used // 2**30, "disk_total": du.total // 2**30,
        "uptime": int(up), "domain": dom, "domain_status": dom_status(dom, ip), "ns": ns, "bunny": bh,
        "users": len(users), "locked": sum(1 for u in users if u["status"] != "UNLOCKED"),
        "used_bytes": sum(u["used"] for u in users), "limit_gb": sum(u["quota_gb"] for u in users),
        "tg": os.path.exists(ZDATA + "/tgbot.conf"),
    }

# ---------------- user keys / user panel ----------------
def load_keys():
    try:
        with open(KEYS_FILE) as f: return json.load(f)
    except Exception: return {}

def save_keys(k):
    tmp = KEYS_FILE + ".tmp"
    with open(tmp, "w") as f: json.dump(k, f)
    os.chmod(tmp, 0o600); os.replace(tmp, KEYS_FILE)

def make_key():
    al = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
    return "AR-" + "-".join("".join(secrets.choice(al) for _ in range(4)) for _ in range(3))

def ensure_key(u, regen=False):
    k = load_keys()
    if regen or u not in k: k[u] = make_key(); save_keys(k)
    return k[u]

def drop_key(u):
    k = load_keys()
    if u in k: k.pop(u); save_keys(k)

def base_url(h):
    host = h.headers.get("Host") or ("%s:%s" % (rd1(ZDATA + "/domain.txt"), load_conf().get("PANEL_PORT", "")))
    return ("https://" if h.server.is_tls else "http://") + host

def user_view(u):
    rows = [x for x in load_users() if x["username"] == u]
    if not rows: return None
    x = rows[0]; mine = [l for l in live_ips() if "(%s)" % u in l["ports"]]
    try: left = (datetime.date.fromisoformat(x["expiry"]) - datetime.date.today()).days
    except Exception: left = None
    status = "ACTIVE" if x["status"] == "UNLOCKED" else "LOCKED"
    if left is not None and left < 0: status = "EXPIRED"
    dom = rd1(ZDATA + "/domain.txt")
    return {"username": u, "password": x["password"], "uuid": x["uuid"], "ns": rd1(ZDATA + "/ns_domain.txt", "Not-Set"),
            "ports": ports_for(x.get("protos", "all")), "protos": x.get("protos", "all"), "total_days": max(30, left or 0), "bunny_config": rd("%s/%s-bunnycdn.txt" % (BUNNY, u)), "status": status, "used": x["used"], "quota_gb": x["quota_gb"],
            "ip_limit": x["ip_limit"], "expiry": x["expiry"], "days_left": left, "live": len(mine),
            "domain": dom, "config": rd("%s/%s.txt" % (CLIENTS, u), ""),
            "link": "http://%s/aliraza-%s.html" % (dom, u), "support": "https://t.me/ar_tricks"}

def user_info(h, u, key):
    v = user_view(u) or {}
    v["key"] = key; v["user_url"] = base_url(h) + "/u#" + key
    return v

# ---------------- jobs ----------------
JOBS = {}
JLOCK = threading.Lock()

def start_job(title, fn, *args):
    with JLOCK:
        for j in JOBS.values():
            if j["running"]: return None, j["id"]
        jid = secrets.token_hex(4)
        log = "%s/job-%s.log" % (JOB_DIR, jid)
        cmd = "bash %s --fn %s %s </dev/null >%s 2>&1; echo \"::EXIT:$?\" >>%s" % (
            CORE, fn, " ".join(shlex_quote(a) for a in args), log, log)
        JOBS[jid] = {"id": jid, "title": title, "log": log, "running": True, "started": time.time()}
        open(log, "w").close()
        if shutil.which("systemd-run"):
            rc, out = sh(["systemd-run", "--quiet", "--collect", "--unit=aliraza-job-" + jid, "bash", "-c", cmd], timeout=15)
            if rc != 0: subprocess.Popen(["bash", "-c", cmd], start_new_session=True)
        else:
            subprocess.Popen(["bash", "-c", cmd], start_new_session=True)
        return jid, None

def shlex_quote(s):
    return "'" + str(s).replace("'", "'\"'\"'") + "'"

def job_state(jid):
    j = JOBS.get(jid)
    if not j: return None
    txt = clean(rd(j["log"]))
    done = re.search(r"::EXIT:(\d+)", txt)
    if done or (time.time() - j["started"] > 3600): j["running"] = False
    txt = re.sub(r"\n?::EXIT:\d+\s*$", "", txt)
    return {"id": jid, "title": j["title"], "running": j["running"], "exit": int(done.group(1)) if done else None, "log": txt[-20000:]}

# ---------------- auth ----------------
SESS = {}; USESS = {}; VSESS = {}; FAILS = {}
SLOCK = threading.Lock()
SESS_FILE = ZDATA + "/sessions.json"
ADMIN_TTL = 7 * 86400; USER_TTL = 30 * 86400

def _sh(t): return hashlib.sha256(str(t).encode()).hexdigest()

def _sess_save():  # caller SLOCK pakde hoga
    try:
        tmp = SESS_FILE + ".tmp"
        with open(tmp, "w") as f: json.dump({"a": SESS, "u": {k: [v[0], v[1]] for k, v in USESS.items()}, "v": {k: [v[0], v[1]] for k, v in VSESS.items()}}, f)
        os.chmod(tmp, 0o600); os.replace(tmp, SESS_FILE)
    except Exception: pass

def _sess_load():
    try:
        with open(SESS_FILE) as f: d = json.load(f)
        now = time.time()
        for k, v in (d.get("a") or {}).items():
            if float(v) > now: SESS[k] = float(v)
        for k, v in (d.get("u") or {}).items():
            if float(v[1]) > now: USESS[k] = (v[0], float(v[1]))
        for k, v in (d.get("v") or {}).items():
            if float(v[1]) > now: VSESS[k] = (v[0], float(v[1]))
    except Exception: pass
_sess_load()

def new_session():
    t = secrets.token_urlsafe(32)
    with SLOCK:
        SESS[_sh(t)] = time.time() + ADMIN_TTL
        for k in [k for k, v in SESS.items() if v < time.time()]: SESS.pop(k, None)
        _sess_save()
    return t

def new_usession(u):
    t = secrets.token_urlsafe(32)
    with SLOCK:
        USESS[_sh(t)] = (u, time.time() + USER_TTL)
        for k in [k for k, v in USESS.items() if v[1] < time.time()]: USESS.pop(k, None)
        _sess_save()
    return t

# ---------------- VIEW-ONLY PANEL LOGINS ----------------
# Admin panel (Settings) se banaye jate hain. Login page par "User (view only)" tab se login hota hai.
# Ye login sirf dekh sakta hai: VPS info, passwords, keys, settings sab hidden. Expiry (days) khatam => login band + live session kick.
VIEWERS_FILE = ZDATA + "/viewers.json"
VW_TTL = 30 * 86400

def load_viewers():
    try:
        with open(VIEWERS_FILE) as f: d = json.load(f)
        return d if isinstance(d, dict) else {}
    except Exception: return {}

def save_viewers(d):
    tmp = VIEWERS_FILE + ".tmp"
    with open(tmp, "w") as f: json.dump(d, f)
    os.chmod(tmp, 0o600); os.replace(tmp, VIEWERS_FILE)

def viewer_active(name):
    v = load_viewers().get(name)
    if not v: return None
    if v.get("exp") and float(v["exp"]) < time.time(): return None
    return v

def new_vsession(name):
    t = secrets.token_urlsafe(32)
    with SLOCK:
        VSESS[_sh(t)] = (name, time.time() + VW_TTL)
        for k in [k for k, v in VSESS.items() if v[1] < time.time()]: VSESS.pop(k, None)
        _sess_save()
    return t

def viewer_purge(name):
    with SLOCK:
        for k in [k for k, v in VSESS.items() if v[0] == name]: VSESS.pop(k, None)
        _sess_save()

def viewer_contact():
    c = rd1(ZDATA + "/viewer_contact.txt", "")
    return c if re.match(r"^https?://[^\s<>\"']{3,200}$", c or "") else "https://t.me/ar_tricks"

def viewer_left(name):
    v = load_viewers().get(name) or {}
    return int(float(v["exp"]) - time.time()) if v.get("exp") else None

def viewer_me(who):
    return {"username": who, "left": viewer_left(who), "contact": viewer_contact()}

def viewer_data(who):
    # Sirf safe fields: koi password/uuid/key/VPS-IP/domain/port nahi
    LIVE["want"] = time.time()
    if LIVE["data"] is None or time.time() - LIVE["ts"] > 3:
        LIVE["data"] = live_snapshot(); LIVE["ts"] = time.time()
    s = LIVE["data"]; us = []
    for x in s["users"]:
        us.append({"username": x["username"], "online": bool(x["online"]), "status": x["status"], "used": x["used"], "quota_gb": x["quota_gb"],
                   "ip_limit": x["ip_limit"], "expiry": x["expiry"], "sessions": x["sessions"],
                   "conns": [{"ip": c["ip"], "protos": c["protos"], "n": c["n"]} for c in x["conns"]]})
    d = viewer_me(who)
    d.update({"total": len(us), "online": s["online"], "ip_count": s["ip_count"], "sessions": s["sessions"],
              "locked": sum(1 for x in us if x["status"] != "UNLOCKED"), "used_bytes": sum(int(x["used"] or 0) for x in us), "users": us})
    return d

# ---------------- THEME (server-wide: admin set karta hai, har user ko wohi dikhta hai) ----------------
THEME_FILE = ZDATA + "/theme.json"
TH_AN = {"embers", "none", "pulse", "breathe", "scan", "ripple", "neon", "stars", "bubbles", "flow", "aurora", "duo", "orbit", "wave", "prism", "fusion"}

def load_theme():
    try:
        with open(THEME_FILE) as f: d = json.load(f)
        return d if isinstance(d, dict) else {}
    except Exception: return {}

def save_theme(b):
    cur = load_theme()
    t = str(b.get("theme", cur.get("theme", "fusion")))
    if not re.match(r"^[a-z0-9_-]{1,24}$", t): t = "fusion"
    an = str(b.get("an", cur.get("an", "fusion")))
    if an not in TH_AN: an = "fusion"
    fx = str(b.get("fx", cur.get("fx", "full")))
    if fx not in ("full", "lite", "off"): fx = "full"
    cu = b.get("custom", cur.get("custom", {})); c = {}
    if isinstance(cu, dict):
        c["mode"] = "double" if cu.get("mode") == "double" else "single"
        for k in ("c1", "c2"):
            v = str(cu.get(k, ""))
            if re.match(r"^#[0-9a-fA-F]{6}$", v): c[k] = v
    d = {"theme": t, "an": an, "fx": fx, "custom": c, "v": int(time.time() * 1000)}
    tmp = THEME_FILE + ".tmp"
    with open(tmp, "w") as f: json.dump(d, f)
    os.chmod(tmp, 0o644); os.replace(tmp, THEME_FILE)
    return d

def parse_quota(body):
    # quota + unit (gb/mb) -> GB string (e.g. 500 MB -> 0.4883, 5 -> 5)
    raw = str(body.get("quota", 0) or 0).strip().replace(",", ".")
    v = float(raw)
    unit = str(body.get("unit", "gb") or "gb").strip().lower()
    if v != v or v < 0 or v > 10000000: raise ValueError("quota")
    gb = v / 1024.0 if unit == "mb" else v
    gb = round(gb, 4)
    if gb == 0 and v > 0: gb = 0.0001
    return str(int(gb)) if gb == int(gb) else ("%.4f" % gb).rstrip("0").rstrip(".")

# ---------------- API ----------------
def api(h, method, path, q, body):
    P = lambda k, d="": str(body.get(k, d)).strip()
    if path == "/api/theme": return 200, (save_theme(body) if method == "POST" else load_theme())
    if path == "/api/dashboard": return 200, sysinfo()
    if path == "/api/users":
        us = load_users(); live = live_ips(); keys = load_keys()
        for u in us:
            mine = [l for l in live if "(%s)" % u["username"] in l["ports"]]
            u["live"] = len(mine)
            u["ips"] = [{"ip": l["ip"], "info": ipinfo_text(l["ip"]), "sim": ipinfo_sim(l["ip"]), "protos": sorted(set(pp for pp, uu in TAGRE.findall(l["ports"]) if uu == u["username"]))} for l in mine]
            u.pop("password", None); u["key"] = keys.get(u["username"], "")
        return 200, {"users": us, "live_ips": len(live)}
    if path == "/api/user/create":
        u, p = P("username"), P("password", "1234") or "1234"
        if not RE_USER.match(u): return 400, {"error": "Username: sirf a-z A-Z 0-9 _ - (max 32)"}
        if not RE_PASS.match(p): return 400, {"error": "Password me sirf A-Z a-z 0-9 _ @ # % + = : . - allowed hain"}
        if any(x["username"] == u for x in load_users()): return 400, {"error": "Username pehle se maujood hai"}
        try: gb, ipl, days = parse_quota(body), int(P("ip_limit", 2) or 2), int(P("days", 30) or 30)
        except ValueError: return 400, {"error": "Data (GB/MB) / IP / Days numbers hone chahiye"}
        pr = body.get("protos", "all")
        sel = list(PROTO_KEYS) if pr == "all" else [x for x in (pr if isinstance(pr, list) else str(pr).split(",")) if x in PROTO_KEYS]
        if not sel: return 400, {"error": "Kam az kam 1 protocol chunein"}
        pstr = "all" if set(sel) == set(PROTO_KEYS) else ",".join(k for k in PROTO_KEYS if k in sel)
        rc, out = sh([ZCLI, "create", u, p, str(gb), str(ipl), str(days), pstr], timeout=120)
        info = user_info(h, u, ensure_key(u)) if rc == 0 else None
        return 200, {"ok": rc == 0, "output": out, "info": info}
    if path == "/api/user/trial":
        u = "trial%d" % (secrets.randbelow(9000) + 1000)
        rc, out = sh([ZCLI, "create", u, "1234", "2", "1", "1"], timeout=120)
        info = user_info(h, u, ensure_key(u)) if rc == 0 else None
        return 200, {"ok": rc == 0, "output": out, "info": info}
    if path in ("/api/user/lock", "/api/user/unlock", "/api/user/delete", "/api/user/renew"):
        u = P("username")
        if not RE_USER.match(u) or not any(x["username"] == u for x in load_users()): return 400, {"error": "User nahi mila"}
        act = path.rsplit("/", 1)[1]
        try: days = int(P("days", 30) or 30)
        except ValueError: return 400, {"error": "Days number hona chahiye"}
        if act == "lock": rc, out = sh([ZCLI, "lock", u], timeout=60)
        elif act == "delete": rc, out = sh([ZCLI, "delete", u], timeout=60); drop_key(u)
        elif act == "unlock": rc, out = sh([ZCLI, "unlock", u, str(days)], timeout=120)
        else:
            try: gb, ipl = parse_quota(body), int(P("ip_limit", 2) or 2)
            except ValueError: return 400, {"error": "Data (GB/MB) / IP numbers hone chahiye"}
            rc, out = core("panel_renew_user", u, gb, ipl, days, "1" if body.get("reset", True) else "0")
        return 200, {"ok": rc == 0, "output": out}
    if path == "/api/user/config":
        u, kind = q.get("username", [""])[0], q.get("type", ["main"])[0]
        if not RE_USER.match(u) or not any(x["username"] == u for x in load_users()): return 400, {"error": "User nahi mila"}
        f = "%s/%s-bunnycdn.txt" % (BUNNY, u) if kind == "bunny" else "%s/%s.txt" % (CLIENTS, u)
        dom = rd1(ZDATA + "/domain.txt")
        link = "http://%s/aliraza-%s%s.html" % (dom, u, "-bunny" if kind == "bunny" else "")
        return 200, {"config": rd(f, "Config file nahi mili"), "link": link}
    if path == "/api/user/info":
        u = q.get("username", [""])[0]
        if not RE_USER.match(u) or not any(x["username"] == u for x in load_users()): return 400, {"error": "User nahi mila"}
        return 200, {"info": user_info(h, u, load_keys().get(u, ""))}
    if path in ("/api/user/key", "/api/user/key/revoke"):
        u = P("username")
        if not RE_USER.match(u) or not any(x["username"] == u for x in load_users()): return 400, {"error": "User nahi mila"}
        if path.endswith("revoke"):
            drop_key(u)
            with SLOCK:
                for t in [t for t, v in USESS.items() if v[0] == u]: USESS.pop(t, None)
                _sess_save()
            return 200, {"ok": True}
        k = ensure_key(u, bool(body.get("regenerate")))
        if body.get("regenerate"):
            with SLOCK:
                for t in [t for t, v in USESS.items() if v[0] == u]: USESS.pop(t, None)
                _sess_save()
        return 200, {"key": k, "user_url": base_url(h) + "/u#" + k}
    if path == "/api/user/key/all":
        n = 0
        for x in load_users():
            if x["username"] not in load_keys(): ensure_key(x["username"]); n += 1
        return 200, {"ok": True, "created": n}
    if path == "/api/viewers":
        now = time.time()
        return 200, {"viewers": [{"username": k, "expired": bool(v.get("exp") and float(v["exp"]) < now),
                                  "left": (int(float(v["exp"]) - now) if v.get("exp") else None)} for k, v in sorted(load_viewers().items())]}
    if path == "/api/viewers/act":
        act = P("act"); name = P("username"); vs = load_viewers(); now = time.time()
        if not re.match(r"^[A-Za-z0-9_.-]{3,32}$", name): return 400, {"error": "Username 3-32 characters (a-z, 0-9, _ . -)"}
        def _days(lo):
            try: dd = int(P("days", "0") or 0)
            except Exception: dd = -1
            return dd if lo <= dd <= 3650 else None
        def _setpw(rec):
            pw_ = P("password") or secrets.token_urlsafe(8)
            if len(pw_) < 6 or len(pw_) > 128: return None
            rec["salt"] = secrets.token_hex(16); rec["hash"] = hash_pw(pw_, rec["salt"]); return pw_
        if act == "create":
            if name in vs: return 400, {"error": "Ye username pehle se maujood hai"}
            dd = _days(0)
            if dd is None: return 400, {"error": "Days 0-3650 (0 = no expiry)"}
            rec = {"exp": (now + dd * 86400) if dd else None, "created": int(now)}
            pw_ = _setpw(rec)
            if pw_ is None: return 400, {"error": "Password 6-128 characters ka ho"}
            vs[name] = rec; save_viewers(vs)
            return 200, {"ok": True, "username": name, "password": pw_}
        if name not in vs: return 404, {"error": "Login nahi mila"}
        if act == "password":
            pw_ = _setpw(vs[name])
            if pw_ is None: return 400, {"error": "Password 6-128 characters ka ho"}
            save_viewers(vs); viewer_purge(name)
            return 200, {"ok": True, "username": name, "password": pw_}
        if act == "extend":
            dd = _days(1)
            if not dd: return 400, {"error": "Days 1-3650"}
            vs[name]["exp"] = max(now, float(vs[name].get("exp") or 0)) + dd * 86400; save_viewers(vs)
            return 200, {"ok": True}
        if act == "noexpiry":
            vs[name]["exp"] = None; save_viewers(vs); return 200, {"ok": True}
        if act == "delete":
            vs.pop(name, None); save_viewers(vs); viewer_purge(name); return 200, {"ok": True}
        return 400, {"error": "Invalid action"}
    if path == "/api/live":
        LIVE["want"] = time.time()
        try: since = int((q.get("seq") or ["0"])[0])
        except Exception: since = 0
        if LIVE["data"] is None:
            d = live_snapshot()
            with LIVE_CV:
                if LIVE["data"] is None: LIVE["seq"] += 1; d["seq"] = LIVE["seq"]; LIVE["data"] = d; LIVE["ts"] = time.time()
        elif since and LIVE["seq"] <= since:
            with LIVE_CV: LIVE_CV.wait_for(lambda: LIVE["seq"] > since, timeout=1.5)
        if LIVE["data"] is None or time.time() - LIVE["ts"] > 3:
            LIVE["data"] = live_snapshot(); LIVE["ts"] = time.time(); LIVE["data"]["seq"] = LIVE["seq"]
        return 200, LIVE["data"]
    if path == "/api/services": return 200, {"services": svc_status()}
    if path == "/api/service/restart":
        s = P("name")
        if s not in RESTARTABLE: return 400, {"error": "Invalid service"}
        rc, out = sh(["systemctl", "restart", s], timeout=60); _cache.pop("svc", None)
        return 200, {"ok": rc == 0, "output": out or "Restarted: " + s}
    if path == "/api/domain":
        ip = vps_ip(); dom = rd1(ZDATA + "/domain.txt"); ns = rd1(ZDATA + "/ns_domain.txt")
        rc, cert = sh("openssl x509 -in /etc/ssl/xray/fullchain.pem -noout -issuer -enddate 2>/dev/null", timeout=8, shell=True)
        return 200, {"ip": ip, "domain": dom, "domain_status": dom_status(dom, ip), "ns": ns, "cert": cert.strip()}
    if path == "/api/domain/set":
        d, n = P("domain"), P("ns")
        if d and not RE_HOST.match(d): return 400, {"error": "Domain galat hai"}
        if n and not RE_HOST.match(n): return 400, {"error": "NS domain galat hai"}
        jid, busy = start_job("Domain / SSL apply", "panel_apply_domain", d, n)
        return 200, {"job": jid} if jid else (409, {"error": "Pehle se ek job chal raha hai", "job": busy})
    if path == "/api/ssl/renew":
        jid, busy = start_job("SSL Renew", "panel_renew_ssl")
        return 200, {"job": jid} if jid else (409, {"error": "Pehle se ek job chal raha hai", "job": busy})
    if path == "/api/banner":
        return 200, {"banner": rd("/etc/issue.net")}
    if path == "/api/banner/set":
        txt = str(body.get("banner", ""))
        if len(txt) > 20000: return 400, {"error": "Banner bohat bara hai"}
        with open("/etc/issue.net", "w") as f: f.write(txt + "\n")
        os.chmod("/etc/issue.net", 0o644)
        rc, out = core("panel_apply_banner")
        return 200, {"ok": rc == 0, "output": out or "Banner apply ho gaya (SSH + Dropbear)"}
    if path == "/api/banner/default":
        rc, out = core("panel_default_banner")
        return 200, {"ok": rc == 0, "output": out or "Default AliRaza-server banner apply ho gaya", "banner": rd("/etc/issue.net")}
    if path == "/api/bunny":
        return 200, {"host": rd1(ZDATA + "/bunny_host.txt"), "ip": vps_ip(), "guide": rd(ZDATA + "/bunnycdn.conf")}
    if path == "/api/bunny/set":
        h_ = P("host")
        if not RE_HOST.match(h_): return 400, {"error": "Hostname galat hai"}
        jid, busy = start_job("Bunny CDN setup", "panel_set_bunny", h_)
        return 200, {"job": jid} if jid else (409, {"error": "Pehle se ek job chal raha hai", "job": busy})
    if path == "/api/bunny/regen":
        jid, busy = start_job("Regenerate user files", "panel_regen_files")
        return 200, {"job": jid} if jid else (409, {"error": "Pehle se ek job chal raha hai", "job": busy})
    if path == "/api/telegram":
        rc, act = sh(["systemctl", "is-active", "aliraza-tgbot"], timeout=5)
        return 200, {"configured": os.path.exists(ZDATA + "/tgbot.conf"), "active": act.strip() == "active", "admin": rd1(ZDATA + "/tg_admins.txt")}
    if path == "/api/telegram/set":
        t, uid = P("token"), P("uid")
        if not re.match(r"^\d{6,12}:[A-Za-z0-9_-]{30,50}$", t) or not re.match(r"^\d{5,15}$", uid): return 400, {"error": "Token ya UID ka format galat hai"}
        rc, out = core("panel_set_tg", t, uid, timeout=120)
        return 200, {"ok": rc == 0, "output": out or "Telegram bot connected. Telegram par /start bhejein."}
    if path == "/api/telegram/ctl":
        a = P("action")
        if a not in ("restart", "stop"): return 400, {"error": "Invalid"}
        rc, out = sh(["systemctl", a, "aliraza-tgbot"], timeout=30)
        return 200, {"ok": rc == 0, "output": out or a + " done"}
    if path == "/api/action":
        a = P("name")
        table = {"restart_all": ("Restart All Services", "restart_all_services_menu", []),
                 "autodoctor": ("Auto-Doctor Fix", "smart_auto_doctor", []),
                 "clean": ("Clean RAM / Logs", "clean_ram_and_logs", []),
                 "reinstall": ("Re-Install All", "panel_reinstall", []),
                 "udp_test": ("UDP Firewall Test (15s)", "panel_udp_test", []),
                 "speedtest": ("VPS Speedtest", "panel_speedtest", []),
                 "uninstall": ("Clean Uninstall", "panel_uninstall", [])}
        if a.startswith("slowdns_"):
            opt = a.split("_", 1)[1]
            if opt not in ("1", "2", "3"): return 400, {"error": "Invalid"}
            ent = ("SlowDNS / UDP Reinstall", "panel_slowdns_target", [opt])
        elif a in table: ent = table[a]
        else: return 400, {"error": "Invalid action"}
        if a == "uninstall" and P("confirm") != "DELETE": return 400, {"error": "Confirm ke liye DELETE likhein"}
        jid, busy = start_job(ent[0], ent[1], *ent[2])
        return 200, {"job": jid} if jid else (409, {"error": "Pehle se ek job chal raha hai", "job": busy})
    if path == "/api/job":
        jid = q.get("id", [""])[0]
        if not jid:
            run = [j for j in JOBS.values()]
            jid = sorted(run, key=lambda j: j["started"])[-1]["id"] if run else ""
        st = job_state(jid) if jid else None
        return 200, st or {"none": True}
    if path == "/api/password":
        c = load_conf()
        if not hmac.compare_digest(hash_pw(P("current"), c.get("PANEL_SALT", "00")), c.get("PANEL_HASH", "")): return 403, {"error": "Current password galat hai"}
        nu, np_ = P("new_username") or c.get("PANEL_USER"), P("new")
        if not RE_USER.match(nu): return 400, {"error": "Username galat hai"}
        if len(np_) < 6: return 400, {"error": "Naya password kam az kam 6 characters ka ho"}
        salt = secrets.token_hex(16); c.update({"PANEL_USER": nu, "PANEL_SALT": salt, "PANEL_HASH": hash_pw(np_, salt)}); save_conf(c)
        with SLOCK: SESS.clear(); _sess_save()
        return 200, {"ok": True, "output": "Credentials update ho gaye. Dobara login karein."}
    return 404, {"error": "Not found"}

# ---------------- HTTP ----------------
class H(BaseHTTPRequestHandler):
    server_version = "AliRazaPanel"
    timeout = 60
    def log_message(self, *a): pass
    def _send(self, code, data, ctype="application/json", extra=None):
        b = data if isinstance(data, bytes) else (json.dumps(data) if ctype == "application/json" else data).encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype + "; charset=utf-8"); self.send_header("Content-Length", str(len(b)))
        self.send_header("Cache-Control", "no-store"); self.send_header("X-Frame-Options", "DENY")
        self.send_header("X-Content-Type-Options", "nosniff"); self.send_header("Referrer-Policy", "no-referrer")
        self.send_header("Content-Security-Policy", "default-src 'self'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; img-src data:")
        for k, v in (extra or {}).items(): self.send_header(k, v)
        self.end_headers(); self.wfile.write(b)
    def _tok(self):
        for part in (self.headers.get("Cookie") or "").split(";"):
            k, _, v = part.strip().partition("=")
            if k == "ar_sess": return v
        return ""
    def _authed(self):
        t = self._tok()
        with SLOCK: return SESS.get(_sh(t), 0) > time.time()
    def _utok(self):
        for part in (self.headers.get("Cookie") or "").split(";"):
            k, _, v = part.strip().partition("=")
            if k == "ar_usess": return v
        return ""
    def _uuser(self):
        with SLOCK:
            v = USESS.get(_sh(self._utok()))
        return v[0] if v and v[1] > time.time() else None
    def _vtok(self):
        for part in (self.headers.get("Cookie") or "").split(";"):
            k, _, v = part.strip().partition("=")
            if k == "ar_vsess": return v
        return ""
    def _vuser(self):
        with SLOCK: v = VSESS.get(_sh(self._vtok()))
        if not v or v[1] <= time.time(): return None
        if not viewer_active(v[0]):
            viewer_purge(v[0]); return None   # delete/expire => live session turant band
        return v[0]
    def _ip(self):
        ip = self.client_address[0]
        if ip == "127.0.0.1":
            x = (self.headers.get("X-Real-IP") or "").strip()
            if re.match(r"^[0-9a-fA-F:.]{3,45}$", x): return x
        return ip
    def do_GET(self):
        u = urlparse(self.path)
        if u.path in ("/", "/u"): return self._send(200, PAGE, "text/html")
        if u.path == "/api/theme": return self._send(200, load_theme())
        if u.path == "/api/u/me":
            who = self._uuser()
            if not who: return self._send(401, {"error": "Login required"})
            v = user_view(who)
            return self._send(200, v) if v else self._send(404, {"error": "Account nahi mila"})
        if u.path in ("/api/v/me", "/api/v/data"):
            who = self._vuser()
            if not who: return self._send(401, {"error": "Login required"})
            try: return self._send(200, viewer_me(who) if u.path == "/api/v/me" else viewer_data(who))
            except Exception as e: return self._send(500, {"error": str(e)})
        if not u.path.startswith("/api/") or u.path in ("/api/login",): return self._send(404, {"error": "Not found"})
        if not self._authed(): return self._send(401, {"error": "Login required"})
        try: code, data = api(self, "GET", u.path, parse_qs(u.query), {})
        except Exception as e: code, data = 500, {"error": str(e)}
        self._send(code, data)
    def do_POST(self):
        u = urlparse(self.path)
        if "application/json" not in (self.headers.get("Content-Type") or "") or self.headers.get("X-Requested-With") != "AliRazaPanel":
            return self._send(400, {"error": "Bad request"})
        try:
            n = int(self.headers.get("Content-Length") or 0)
            body = json.loads(self.rfile.read(min(n, 200000)) or b"{}")
        except Exception: return self._send(400, {"error": "Bad JSON"})
        if u.path == "/api/login":
            ip = self._ip(); now = time.time()
            with SLOCK:
                f = [t for t in FAILS.get(ip, []) if now - t < 300]; FAILS[ip] = f
            if len(f) >= 5: return self._send(429, {"error": "Bohat ghalat koshishen. 5 minute baad try karein."})
            with SLOCK:
                gf = [t for t in FAILS.get("*", []) if now - t < 300]; FAILS["*"] = gf
            if len(gf) >= 40: return self._send(429, {"error": "Bohat ghalat koshishen. 5 minute baad try karein."})
            c = load_conf()
            ok = ceq(body.get("username", ""), c.get("PANEL_USER", "")) and \
                 hmac.compare_digest(hash_pw(str(body.get("password", "")), c.get("PANEL_SALT", "00")), c.get("PANEL_HASH", ""))
            if not ok:
                with SLOCK: FAILS[ip].append(now); FAILS.setdefault("*", []).append(now)
                time.sleep(1); return self._send(403, {"error": "Username ya password galat hai"})
            t = new_session(); flags = "; Secure" if self.server.is_tls else ""
            return self._send(200, {"ok": True}, extra={"Set-Cookie": "ar_sess=%s; Path=/; HttpOnly; SameSite=Strict; Max-Age=604800%s" % (t, flags)})
        if u.path == "/api/u/login":
            ip = "u" + self._ip(); now = time.time()
            with SLOCK:
                f = [t for t in FAILS.get(ip, []) if now - t < 300]; FAILS[ip] = f
            if len(f) >= 8: return self._send(429, {"error": "Bohat ghalat koshishen. 5 minute baad try karein."})
            key = str(body.get("key", "")).strip().upper(); found = None
            for name, k in load_keys().items():
                if ceq(k, key): found = name
            if not found or not user_view(found):
                with SLOCK: FAILS[ip].append(now)
                time.sleep(1); return self._send(403, {"error": "Key galat hai"})
            t = new_usession(found); flags = "; Secure" if self.server.is_tls else ""
            return self._send(200, {"ok": True}, extra={"Set-Cookie": "ar_usess=%s; Path=/; HttpOnly; SameSite=Strict; Max-Age=2592000%s" % (t, flags)})
        if u.path == "/api/v/login":
            ip = "v" + self._ip(); now = time.time()
            with SLOCK:
                f = [t for t in FAILS.get(ip, []) if now - t < 300]; FAILS[ip] = f
            if len(f) >= 8: return self._send(429, {"error": "Bohat ghalat koshishen. 5 minute baad try karein."})
            name = str(body.get("username", "")).strip(); pw_ = str(body.get("password", ""))
            v = load_viewers().get(name)
            good = bool(v) and hmac.compare_digest(hash_pw(pw_, v.get("salt", "00")), v.get("hash", ""))
            if good and v.get("exp") and float(v["exp"]) < now:
                return self._send(403, {"error": "Ye key expire ho chuki hai. Naya key admin se len."})
            if not good:
                with SLOCK: FAILS[ip].append(now)
                time.sleep(1); return self._send(403, {"error": "Username ya password galat hai"})
            t = new_vsession(name); flags = "; Secure" if self.server.is_tls else ""
            return self._send(200, {"ok": True}, extra={"Set-Cookie": "ar_vsess=%s; Path=/; HttpOnly; SameSite=Strict; Max-Age=2592000%s" % (t, flags)})
        if u.path == "/api/v/logout":
            with SLOCK: VSESS.pop(_sh(self._vtok()), None); _sess_save()
            return self._send(200, {"ok": True}, extra={"Set-Cookie": "ar_vsess=; Path=/; Max-Age=0"})
        if u.path == "/api/u/logout":
            with SLOCK: USESS.pop(_sh(self._utok()), None); _sess_save()
            return self._send(200, {"ok": True}, extra={"Set-Cookie": "ar_usess=; Path=/; Max-Age=0"})
        if u.path == "/api/logout":
            with SLOCK: SESS.pop(_sh(self._tok()), None); _sess_save()
            return self._send(200, {"ok": True}, extra={"Set-Cookie": "ar_sess=; Path=/; Max-Age=0"})
        if not self._authed(): return self._send(401, {"error": "Login required"})
        try: code, data = api(self, "POST", u.path, parse_qs(u.query), body)
        except Exception as e: code, data = 500, {"error": str(e)}
        self._send(code, data)

def redirect_to_https(sock):
    sock.settimeout(5)
    data = sock.recv(4096).decode("latin1", "replace")
    lines = data.split("\r\n"); path = "/"; host = ""
    if lines and lines[0].count(" ") >= 2: path = lines[0].split(" ")[1]
    for ln in lines[1:]:
        if ln.lower().startswith("host:"): host = ln.split(":", 1)[1].strip(); break
    if not re.match(r"^[A-Za-z0-9.\-:\[\]]{1,260}$", host or ""):
        host = "%s:%s" % (rd1(ZDATA + "/domain.txt") or vps_ip(), load_conf().get("PANEL_PORT", ""))
    if not path.startswith("/") or re.search(r"[\s\x00-\x1f]", path): path = "/"
    body = "Redirecting to HTTPS"
    sock.sendall(("HTTP/1.1 301 Moved Permanently\r\nLocation: https://%s%s\r\nContent-Type: text/plain\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s" % (host, path, len(body), body)).encode())

class Srv(ThreadingHTTPServer):
    daemon_threads = True; allow_reuse_address = True; is_tls = False; tls_ctx = None
    address_family = socket.AF_INET  # IPv4 only
    def finish_request(self, request, client_address):
        # Same port par http:// aur https:// dono chalte hain (http -> https redirect)
        if self.tls_ctx is not None:
            try:
                request.settimeout(8)
                first = request.recv(1, socket.MSG_PEEK)
                if not first: return
                if first[0] != 0x16:
                    try: redirect_to_https(request)
                    except Exception: pass
                    return
                request = self.tls_ctx.wrap_socket(request, server_side=True)
                request.settimeout(120)
            except Exception:
                return
        try: self.RequestHandlerClass(request, client_address, self)
        finally:
            try: request.close()
            except Exception: pass

def main():
    c = load_conf(); port = int(os.environ.get("PANEL_PORT") or c.get("PANEL_PORT", "2026"))
    srv = Srv(("0.0.0.0", port), H)
    # internal plain listener: domain traffic (80/443) reaches the panel here via WS engine + nginx (no extra port needed)
    try:
        isrv = Srv(("127.0.0.1", int(os.environ.get("PANEL_INT_PORT") or c.get("PANEL_INT_PORT", "20090"))), H)
        isrv.is_tls = True
        threading.Thread(target=isrv.serve_forever, daemon=True).start()
    except Exception as e: print("internal listener off:", e, flush=True)
    threading.Thread(target=live_loop, daemon=True).start()
    if c.get("PANEL_TLS", "1") == "1" and os.path.exists(CERT) and os.path.exists(KEY):
        try:
            ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER); ctx.minimum_version = ssl.TLSVersion.TLSv1_2
            ctx.load_cert_chain(CERT, KEY); srv.tls_ctx = ctx; srv.is_tls = True
        except Exception as e: print("TLS disabled:", e, flush=True)
    print("AliRaza Panel on port %d (%s)" % (port, "HTTPS (+http redirect)" if srv.is_tls else "HTTP"), flush=True)
    srv.serve_forever()

PAGE = r'''<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="theme-color" content="#0a0e1c"><title>ALIRAZA PANEL MANAGEMENT</title>
<style>
:root{--bg:#0a0e1c;--bg2:#17204a;--card:rgba(20,27,50,.78);--line:rgba(255,255,255,.09);--tx:#eaf0ff;--mut:#97a3c7;--ac:#7c5cff;--ac2:#00d4ff;--glow:#7c5cff66;--inp:rgba(0,0,0,.28);--pre:rgba(0,0,0,.36);--ok:#2ecc71;--bad:#ff4d5e;--warn:#ffb020}
*{box-sizing:border-box}html,body{margin:0}body{background:radial-gradient(1100px 600px at 85% -10%,var(--bg2),transparent 70%),var(--bg);color:var(--tx);font:14px/1.5 system-ui,"Segoe UI",Roboto,sans-serif;min-height:100vh;overflow-x:hidden;transition:background .5s,color .4s}
a{color:var(--ac2)}button,input,select,textarea{font:inherit}
#bgfx{position:fixed;inset:0;z-index:0;pointer-events:none;overflow:hidden}
#bgfx i{position:absolute;inset:-25%;opacity:0;will-change:transform,opacity;pointer-events:none}
#cf{position:fixed;inset:0;width:100%;height:100%;pointer-events:none;z-index:80}
body.fx-lite #bgfx,body.fx-off #bgfx{display:none}
body.fx-off *,body.fx-off *::before,body.fx-off *::after{animation:none!important}
/* ===== theme animations (GPU-cheap: only transform/opacity) ===== */
/* single colour */
body.an-pulse #bgfx .l1{background:radial-gradient(circle at 50% 40%,var(--ac) 0,transparent 55%);animation:a-breath 5s ease-in-out infinite}
body.an-breathe .card{animation:a-cardglow 4.5s ease-in-out infinite}
body.an-scan #bgfx .l1{inset:0;height:160px;background:linear-gradient(180deg,transparent,var(--ac),transparent);animation:a-scan 7s linear infinite}
body.an-ripple #bgfx .l1,body.an-ripple #bgfx .l2{inset:auto;left:50%;top:45%;width:60vmin;height:60vmin;margin:-30vmin 0 0 -30vmin;border-radius:50%;border:2px solid var(--ac);animation:a-ripple 6s ease-out infinite}
body.an-ripple #bgfx .l2{animation-delay:3s}
body.an-neon .logo,body.an-neon .nav button.on{animation:a-flick 3.2s steps(1,end) infinite}
body.an-neon #bgfx .l1{background:radial-gradient(circle at 15% 85%,var(--ac) 0,transparent 40%);animation:a-breath 3s ease-in-out infinite}
/* double colour */
body.an-flow #bgfx .l1{background:linear-gradient(135deg,var(--ac),transparent 40%,var(--ac2) 70%,transparent);animation:a-flow 16s linear infinite alternate}
body.an-aurora #bgfx .l1{background:radial-gradient(circle at 25% 30%,var(--ac) 0,transparent 45%);animation:a-drift1 20s ease-in-out infinite alternate}
body.an-aurora #bgfx .l2{background:radial-gradient(circle at 75% 70%,var(--ac2) 0,transparent 45%);animation:a-drift2 24s ease-in-out infinite alternate}
body.an-duo #bgfx .l1{background:radial-gradient(circle at 50% 35%,var(--ac) 0,transparent 55%);animation:a-duo 8s ease-in-out infinite}
body.an-duo #bgfx .l2{background:radial-gradient(circle at 50% 35%,var(--ac2) 0,transparent 55%);animation:a-duo 8s ease-in-out -4s infinite}
body.an-orbit #bgfx .l1{inset:auto;left:50%;top:45%;width:70vmin;height:70vmin;margin:-35vmin 0 0 -35vmin;border-radius:50%;background:conic-gradient(from 0deg,var(--ac),transparent 30%,var(--ac2) 55%,transparent 80%,var(--ac));animation:a-spin 14s linear infinite}
body.an-orbit #bgfx .l1{-webkit-mask:radial-gradient(circle,transparent 58%,#000 60%,#000 62%,transparent 64%);mask:radial-gradient(circle,transparent 58%,#000 60%,#000 62%,transparent 64%)}
body.an-wave #bgfx .l1{inset:auto 0 0 -50%;width:200%;height:140px;background:repeating-linear-gradient(90deg,var(--ac) 0,var(--ac2) 120px,var(--ac) 240px);-webkit-mask:linear-gradient(0deg,#000,transparent);mask:linear-gradient(0deg,#000,transparent);animation:a-wave 9s linear infinite}
body.an-flow #bgfx .l1,body.an-aurora #bgfx .l1,body.an-aurora #bgfx .l2,body.an-duo #bgfx .l1,body.an-duo #bgfx .l2,body.an-pulse #bgfx .l1,body.an-neon #bgfx .l1{opacity:.28}
body.an-scan #bgfx .l1,body.an-orbit #bgfx .l1,body.an-wave #bgfx .l1{opacity:.32}
@keyframes a-breath{0%,100%{opacity:.12;transform:scale(.95)}50%{opacity:.4;transform:scale(1.08)}}
@keyframes a-cardglow{0%,100%{box-shadow:0 0 0 transparent}50%{box-shadow:0 0 22px var(--glow);border-color:var(--ac)}}
@keyframes a-scan{from{transform:translateY(-200px)}to{transform:translateY(110vh)}}
@keyframes a-ripple{0%{opacity:.5;transform:scale(.2)}100%{opacity:0;transform:scale(1.6)}}
@keyframes a-flick{0%,19%,21%,60%,62%,100%{opacity:1;filter:drop-shadow(0 0 8px var(--ac))}20%,61%{opacity:.55;filter:none}}
@keyframes a-flow{from{transform:translate3d(-8%,-6%,0) rotate(0deg)}to{transform:translate3d(8%,6%,0) rotate(14deg)}}
@keyframes a-drift1{from{transform:translate3d(-10%,-6%,0) scale(1)}to{transform:translate3d(14%,10%,0) scale(1.2)}}
@keyframes a-drift2{from{transform:translate3d(10%,8%,0) scale(1.1)}to{transform:translate3d(-14%,-8%,0) scale(.9)}}
@keyframes a-duo{0%,100%{opacity:0}50%{opacity:.4}}
@keyframes a-spin{to{transform:rotate(360deg)}}
@keyframes a-wave{to{transform:translateX(240px)}}
.wrap{position:relative;z-index:1}
.top{position:sticky;top:0;z-index:10;background:linear-gradient(180deg,var(--bg),transparent);display:flex;align-items:center;gap:10px;padding:10px 16px;border-bottom:1px solid var(--line)}
.logo{font-weight:900;letter-spacing:.5px;font-size:16px;background:linear-gradient(90deg,var(--ac),var(--ac2),var(--ac));background-size:200% auto;-webkit-background-clip:text;background-clip:text;color:transparent;animation:shine 5s linear infinite}
@keyframes shine{to{background-position:200% center}}
.sp{flex:1}
/* ===== vertical sidebar layout ===== */
.shell{display:flex;align-items:flex-start}.content{flex:1;min-width:0}
.nav{width:232px;flex:0 0 232px;position:sticky;top:58px;align-self:flex-start;max-height:calc(100vh - 58px);overflow-y:auto;display:flex;flex-direction:column;gap:6px;padding:14px 12px 20px 14px;border-right:1px solid var(--line);scrollbar-width:thin}
.nav button{display:flex;align-items:center;gap:8px;width:100%;text-align:left;white-space:nowrap;background:transparent;color:var(--mut);border:1px solid transparent;padding:11px 14px;border-radius:12px;cursor:pointer;position:relative;transition:transform .25s,background .25s,color .25s,box-shadow .25s;animation:navin .5s cubic-bezier(.2,.9,.3,1) backwards}
.nav button:hover{color:var(--tx);background:var(--card);transform:translateX(5px)}
.nav button.on{background:linear-gradient(90deg,var(--ac),var(--ac2));color:#fff;box-shadow:0 6px 22px var(--glow);transform:translateX(4px)}
.nav button.on::before{content:"";position:absolute;left:-14px;top:22%;height:56%;width:4px;border-radius:4px;background:var(--ac2);box-shadow:0 0 12px var(--ac2)}
@keyframes navin{from{opacity:0;transform:translateX(-30px)}to{opacity:1;transform:none}}
.burger{display:none;padding:6px 12px;font-size:16px}
.ov{position:fixed;inset:0;background:#0009;z-index:55;display:none;backdrop-filter:blur(2px)}.ov.show{display:block;animation:fi .25s}
@media(max-width:860px){.burger{display:inline-flex}
.nav{position:fixed;top:0;left:0;bottom:0;max-height:none;z-index:60;width:252px;flex:none;padding-top:72px;background:var(--bg);box-shadow:12px 0 40px #000b;transform:translateX(-106%);transition:transform .35s cubic-bezier(.2,.9,.3,1)}
.nav.open{transform:none}.nav.hide{display:none}}



main{max-width:1120px;margin:0 auto;padding:6px 16px 30px}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(165px,1fr));gap:12px;margin-bottom:12px}
.card{position:relative;background:var(--card);border:1px solid var(--line);border-radius:16px;padding:16px;margin-bottom:12px;transition:transform .25s,box-shadow .25s,border-color .25s}
.grid .card{margin:0}.card:hover{border-color:var(--ac);box-shadow:0 10px 34px var(--glow)}
.stat .k{color:var(--mut);font-size:12px;text-transform:uppercase;letter-spacing:.6px}.stat .v{font-size:22px;font-weight:800;margin-top:3px;word-break:break-all}.stat .s{color:var(--mut);font-size:12px;margin-top:2px}
.fadein{animation:fup .55s cubic-bezier(.2,.8,.2,1) both}@keyframes fup{from{opacity:0;transform:translateY(16px)}to{opacity:1;transform:none}}
h2{margin:2px 0 12px;font-size:17px}h3{margin:0 0 10px;font-size:12px;color:var(--mut);text-transform:uppercase;letter-spacing:.8px}
.btn{position:relative;overflow:hidden;background:linear-gradient(90deg,var(--ac),var(--ac2));color:#fff;border:0;padding:10px 17px;border-radius:11px;cursor:pointer;font-weight:700;box-shadow:0 6px 20px var(--glow);transition:.2s}
.btn:hover{transform:translateY(-2px);filter:brightness(1.1)}.btn:active{transform:scale(.97)}
.btn::after{content:"";position:absolute;top:0;left:-80%;width:50%;height:100%;background:linear-gradient(90deg,transparent,#fff5,transparent);transform:skewX(-20deg)}.btn:hover::after{animation:sw .7s}
@keyframes sw{to{left:140%}}
.btn.g{background:var(--card);border:1px solid var(--line);color:var(--tx);box-shadow:none}.btn.r{background:linear-gradient(90deg,#ff3b4e,#ff7a5a);box-shadow:0 6px 20px #ff3b4e55}.btn.o{background:linear-gradient(90deg,#1fbf63,#7be495);color:#03200f;box-shadow:0 6px 20px #2ecc7155}
.btn.s{padding:6px 11px;font-size:12px;border-radius:9px}.btn:disabled{opacity:.5}
input,select,textarea{width:100%;background:var(--inp);color:var(--tx);border:1px solid var(--line);border-radius:10px;padding:10px 12px;margin:3px 0 10px;outline:0;transition:.2s}
input:focus,textarea:focus,select:focus{border-color:var(--ac);box-shadow:0 0 0 3px var(--glow)}
label{font-size:12px;color:var(--mut)}.row{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:0 12px}
table{width:100%;border-collapse:collapse}th,td{text-align:left;padding:10px 8px;border-bottom:1px solid var(--line);white-space:nowrap}th{color:var(--mut);font-size:11px;text-transform:uppercase;letter-spacing:.6px}
tr.rw{animation:fup .45s both}tbody tr:hover td{background:#ffffff08}.tw{overflow-x:auto}
.pill{display:inline-block;padding:2px 10px;border-radius:12px;font-size:12px;font-weight:700}.on_{background:#2ecc7122;color:var(--ok)}.off_{background:#ff4d5e22;color:var(--bad)}.warn_{background:#ffb02022;color:var(--warn)}
.on_::before{content:"";display:inline-block;width:6px;height:6px;border-radius:50%;background:var(--ok);margin-right:6px;animation:pulse 1.6s infinite}
@keyframes pulse{50%{opacity:.25;transform:scale(1.5)}}
pre{background:var(--pre);border:1px solid var(--line);border-radius:10px;padding:12px;overflow:auto;max-height:340px;white-space:pre-wrap;word-break:break-word;font:12px/1.55 ui-monospace,Menlo,Consolas,monospace;margin:0}
.bar{height:8px;background:var(--inp);border-radius:6px;overflow:hidden;margin-top:8px}.bar i{display:block;height:100%;background:linear-gradient(90deg,var(--ac),var(--ac2));border-radius:6px;transition:width 1.1s cubic-bezier(.2,.8,.2,1)}
.acts{display:flex;gap:6px;flex-wrap:wrap}.mut{color:var(--mut)}.hide{display:none!important}
.modal{position:fixed;inset:0;background:#000b;display:none;align-items:center;justify-content:center;padding:14px;z-index:50}.modal.show{display:flex;animation:fi .25s}
@keyframes fi{from{opacity:0}}.modal .card{max-width:680px;width:100%;max-height:90vh;overflow:auto;margin:0;animation:pop .4s cubic-bezier(.2,1.2,.3,1)}
@keyframes pop{from{opacity:0;transform:scale(.88) translateY(20px)}}
.toast{position:fixed;bottom:18px;left:50%;transform:translateX(-50%);background:var(--card);border:1px solid var(--ac);padding:11px 18px;border-radius:12px;display:none;z-index:90;max-width:90vw;box-shadow:0 10px 34px var(--glow)}
.foot{text-align:center;color:var(--mut);font-size:12px;padding:6px 0 22px}
/* login */
.lg{min-height:100vh;display:flex;align-items:center;justify-content:center;padding:18px}
.lgbox{width:100%;max-width:400px;position:relative;text-align:center}
.emb{width:92px;height:92px;margin:0 auto 14px;position:relative;display:flex;align-items:center;justify-content:center;font-weight:900;font-size:30px;letter-spacing:1px}
.emb::before,.emb::after{content:"";position:absolute;inset:0;border-radius:50%;border:2px solid transparent;border-top-color:var(--ac);border-right-color:var(--ac2);animation:spin 2.4s linear infinite}
@keyframes spin{to{transform:rotate(360deg)}}
.emb b{background:linear-gradient(90deg,var(--ac),var(--ac2));-webkit-background-clip:text;background-clip:text;color:transparent;animation:float 3s ease-in-out infinite}
@keyframes float{50%{transform:translateY(-4px)}}
.ttl{font-size:21px;font-weight:900;letter-spacing:3px;margin:0 0 4px;line-height:1.25}
.ttl{background:linear-gradient(90deg,var(--ac),var(--ac2));-webkit-background-clip:text;background-clip:text;color:transparent;animation:fup .7s .1s both}
@keyframes lt{to{opacity:1;transform:none}}@keyframes glowt{50%{filter:drop-shadow(0 0 9px var(--ac2))}}
.sub{color:var(--mut);margin-bottom:18px;opacity:0;animation:fup .6s .4s forwards}
.lgcard{position:relative;border-radius:18px;padding:2px;overflow:hidden;animation:fup .8s .3s both}
.lgcard::before{content:"";position:absolute;inset:0;background:linear-gradient(135deg,var(--ac),var(--ac2));opacity:.9}.lgcard{box-shadow:0 0 28px var(--glow)}
.lgin{position:relative;background:var(--bg);border-radius:16px;padding:20px;text-align:left}
.err{color:var(--bad);min-height:18px;margin:2px 0 6px;font-size:13px}
/* account info */
.chk{width:76px;height:76px;display:block;margin:0 auto 6px}.chk circle{stroke:var(--ok);fill:none;stroke-width:4;stroke-dasharray:226;stroke-dashoffset:226;animation:dr .7s .1s forwards}
.chk path{stroke:var(--ok);fill:none;stroke-width:5;stroke-linecap:round;stroke-linejoin:round;stroke-dasharray:50;stroke-dashoffset:50;animation:dr .5s .65s forwards}@keyframes dr{to{stroke-dashoffset:0}}
.ai{display:flex;justify-content:space-between;gap:12px;padding:9px 12px;border-radius:10px;background:var(--inp);margin-bottom:6px;opacity:0;transform:translateX(-24px);animation:slin .5s cubic-bezier(.2,.9,.3,1) forwards}
@keyframes slin{to{opacity:1;transform:none}}.ai .k{color:var(--mut)}.ai .v{font-weight:700;text-align:right;word-break:break-all}
.chips{display:flex;flex-wrap:wrap;gap:6px}.chip{background:var(--inp);border:1px solid var(--line);border-radius:20px;padding:4px 11px;font-size:12px;opacity:0;animation:fup .5s forwards}.chip b{color:var(--ac2)}
details summary{cursor:pointer;color:var(--ac2);margin:8px 0}
.keybox{background:linear-gradient(90deg,var(--ac)22,var(--ac2)22);border:1px dashed var(--ac2);border-radius:12px;padding:12px;text-align:center;margin-top:10px;animation:pop .5s}
.keybox code{font-size:19px;font-weight:800;letter-spacing:2px;color:var(--ac2);word-break:break-all}
/* rings */
.ring{position:relative;width:150px;height:150px;margin:0 auto}.ring svg{transform:rotate(-90deg)}.ring circle{fill:none;stroke-width:10;stroke-linecap:round}.ring .bg{stroke:var(--inp)}
.ring .fg{stroke:url(#gr);stroke-dasharray:264;stroke-dashoffset:264;transition:stroke-dashoffset 1.4s cubic-bezier(.2,.8,.2,1)}
.ring .mid{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center}.ring .mid b{font-size:22px}.ring .mid small{color:var(--mut)}
.hero{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:12px}
.themes{display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:12px}
.th{cursor:pointer;border-radius:14px;padding:10px;border:2px solid var(--line);background:var(--card);transition:.25s}.th:hover{transform:translateY(-4px) scale(1.03)}.th.on{border-color:var(--ac2);box-shadow:0 0 0 3px var(--glow)}
.th .sw{height:64px;border-radius:9px;position:relative;overflow:hidden}.th .sw i{position:absolute;border-radius:50%;filter:blur(10px)}.th .nm{margin-top:8px;font-weight:700;text-align:center}
/* no replay of animations on background refresh */
#main.still .rw,#main.still .ai,#main.still .chip,#main.still .grid>.card,#main.still .hero>.card{animation:none!important;opacity:1;transform:none}
#main.still .ring .fg{transition:none}
#main.still .lx-ip,#main.still .lx-u{animation:none!important;opacity:1;transform:none}
#main.still .lx-u.on .lx-av{animation:avglow 2.4s ease-in-out infinite!important}
/* ===== extra animated UI ===== */
.card::before{content:"";position:absolute;left:16px;right:16px;top:0;height:2px;border-radius:2px;background:linear-gradient(90deg,transparent,var(--ac),var(--ac2),transparent);background-size:220% 100%;opacity:.85;animation:topline 3.6s linear infinite;pointer-events:none}
@keyframes topline{from{background-position:120% 0}to{background-position:-120% 0}}
.grid>.card,.hero>.card{animation:fup .6s cubic-bezier(.2,.8,.2,1) backwards}
.grid>.card:nth-child(2),.hero>.card:nth-child(2){animation-delay:.07s}.grid>.card:nth-child(3),.hero>.card:nth-child(3){animation-delay:.14s}
.grid>.card:nth-child(4){animation-delay:.21s}.grid>.card:nth-child(5){animation-delay:.28s}.grid>.card:nth-child(6){animation-delay:.35s}
.card:hover{transform:translateY(-3px)}.modal .card:hover{transform:none}
.stat .v{background:linear-gradient(90deg,var(--tx),var(--ac2));-webkit-background-clip:text;background-clip:text;color:transparent}
.ring .fg{filter:drop-shadow(0 0 6px var(--ac2))}
.keybox code{animation:glowt 2.6s ease-in-out infinite}
body.an-stars #bgfx .l1{inset:0;opacity:.75;background-image:radial-gradient(2px 2px at 20px 30px,var(--ac),transparent),radial-gradient(2px 2px at 90px 120px,var(--ac2),transparent),radial-gradient(1.5px 1.5px at 160px 60px,#fff,transparent),radial-gradient(2px 2px at 220px 180px,var(--ac),transparent);background-size:260px 220px;animation:a-stars 40s linear infinite}
@keyframes a-stars{to{background-position:-260px 440px}}
body.an-bubbles #bgfx .l1,body.an-bubbles #bgfx .l2{inset:auto;left:18%;bottom:-24vmin;width:18vmin;height:18vmin;border-radius:50%;border:2px solid var(--ac);background:radial-gradient(circle at 30% 30%,#fff3,transparent 60%);opacity:.5;animation:a-rise 11s ease-in infinite}
body.an-bubbles #bgfx .l2{left:68%;width:26vmin;height:26vmin;border-color:var(--ac2);animation-duration:15s;animation-delay:-6s}
@keyframes a-rise{0%{transform:translateY(0) scale(.7);opacity:0}15%{opacity:.5}100%{transform:translateY(-130vh) scale(1.1);opacity:0}}
body.an-prism #bgfx .l1{opacity:.2;background:conic-gradient(from 0deg at 50% 50%,var(--ac),var(--ac2),var(--ac));animation:a-spin 34s linear infinite}
.utb{display:flex;gap:10px;align-items:center;flex-wrap:wrap;margin:6px 0 16px}
.utabs{display:flex;gap:4px;padding:5px;border-radius:18px;background:var(--inp);border:1px solid var(--line);overflow-x:auto;max-width:100%}
.utab{flex:none;border:0;background:transparent;color:var(--tx);font-weight:800;letter-spacing:.5px;font-size:13px;padding:10px 16px;border-radius:14px;cursor:pointer;font-family:inherit;white-space:nowrap}
.utab i{font-style:normal;opacity:.7;font-size:11px;margin-left:6px;background:rgba(255,255,255,.1);border-radius:9px;padding:1px 7px}
.utab.on{background:linear-gradient(90deg,var(--ac),var(--ac2));color:#fff;box-shadow:0 6px 20px -6px var(--ac)}
body.ui-alyan .utab.on{color:#1b0600}
.usrch{display:flex;align-items:center;gap:8px;padding:0 14px;border-radius:18px;background:var(--inp);border:1px solid var(--line);flex:1;min-width:150px;max-width:280px;margin:0}
.usrch input{border:0!important;background:transparent!important;box-shadow:none!important;margin:0!important;padding:11px 0!important;width:100%;height:auto!important}
.uc2grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(min(100%,340px),1fr));gap:16px}
.uc2{border:1px solid var(--line);border-radius:22px;padding:16px;background:var(--inp);display:flex;flex-direction:column;gap:13px;min-width:0;overflow:hidden}
.uc2.onl{border-color:#22c55e55}
.uc2 .hd{display:flex;gap:13px;align-items:center}
.hex{width:54px;height:58px;flex:none;display:grid;place-items:center;font-weight:800;font-size:21px;background:linear-gradient(160deg,rgba(255,255,255,.16),rgba(255,255,255,.04));clip-path:polygon(50% 0,100% 25%,100% 75%,50% 100%,0 75%,0 25%)}
.uc2 .nm{display:flex;align-items:center;gap:8px;flex-wrap:wrap}.uc2 .nm b{font-size:19px;overflow:hidden;text-overflow:ellipsis}
.st{display:inline-flex;align-items:center;gap:6px;font-size:12px;font-weight:700;padding:3px 11px;border-radius:999px;border:1px solid var(--line)}
.st::before{content:"";width:8px;height:8px;border-radius:50%;background:#7a7f92}
.st.on{color:#22c55e;border-color:#22c55e66}.st.on::before{background:#22c55e;box-shadow:0 0 8px #22c55e}
.st.lk{color:#ff6b6b;border-color:#ff6b6b66}.st.lk::before{background:#ff6b6b}
.uc2 .sb{font-size:12.5px;color:var(--mut);margin-top:4px;word-break:break-all}.uc2 .sb b{color:var(--tx)}
.uc2 .tr{display:flex;justify-content:space-between;gap:8px;font-size:12px;font-weight:800;letter-spacing:.8px}
.tiles{display:grid;grid-template-columns:repeat(3,1fr);gap:8px}
.tile{border:1px solid var(--line);border-radius:14px;padding:10px 12px;background:rgba(255,255,255,.02);min-width:0}
.tile span{display:block;font-size:10.5px;letter-spacing:1px;color:var(--mut);font-weight:700;margin-bottom:4px}.tile b{font-size:17px;word-break:break-all}
.uc2 .ab{display:flex;gap:8px;justify-content:flex-end;flex-wrap:wrap;align-items:center}
.ibtn{width:42px;height:42px;padding:0!important;display:inline-grid;place-items:center;font-size:17px;border-radius:12px}
body.ui-alyan .uc2{border-radius:24px;background:linear-gradient(160deg,rgba(255,60,20,.05),transparent 45%),rgba(14,14,19,.9);border-color:rgba(255,80,35,.2)}
.ugrid{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:14px}
.ucard{position:relative;max-width:290px;min-height:230px;display:flex;flex-direction:column;gap:7px;background:var(--inp);border:1px solid var(--line);border-radius:20px;padding:15px 15px 13px;transition:transform .25s,border-color .25s,box-shadow .25s}
.ucard:hover{transform:translateY(-3px);border-color:var(--ac);box-shadow:0 8px 26px var(--glow)}
.uav{display:inline-flex;align-items:center;justify-content:center;width:40px;height:40px;flex:0 0 40px;background:#000;color:#fff;font-weight:900;font-size:17px;clip-path:polygon(50% 0,100% 38%,82% 100%,18% 100%,0 38%);padding-top:3px;transition:background .3s}
.ucard.onl .uav{background:linear-gradient(135deg,var(--ac),var(--ac2));animation:avglow 2.4s ease-in-out infinite}
@keyframes avglow{50%{filter:brightness(1.35)}}
.ai{opacity:1!important;transform:none!important;animation:none!important}
.chip{opacity:1!important;animation:none!important}
.chk circle,.chk path{stroke-dashoffset:0!important;animation:none!important}
#cf{display:none!important}
.cfb{background:var(--inp);border:1px solid var(--line);border-radius:12px;padding:8px 10px;margin-bottom:8px}
.cfh{display:flex;justify-content:space-between;align-items:center;gap:8px;margin-bottom:4px;font-weight:800;font-size:12.5px}
.cfb pre{margin:0;white-space:pre-wrap;word-break:break-all;font-size:12px;max-height:150px;overflow:auto}
.ugrid{grid-template-columns:repeat(auto-fill,minmax(min(100%,270px),1fr))}
.ucard{max-width:none;min-width:0;min-height:0;overflow:hidden}
.ucard .acts{flex-wrap:wrap}
.ucard.off{opacity:.78;filter:saturate(.55)}
.ucard.onl{border-color:rgba(46,230,140,.6);background:linear-gradient(160deg,rgba(46,230,140,.14),var(--inp) 60%);box-shadow:0 0 0 1px rgba(46,230,140,.25),0 10px 30px rgba(46,230,140,.16);animation:onlglow 3.2s ease-in-out infinite}
@keyframes onlglow{50%{box-shadow:0 0 0 1px rgba(46,230,140,.5),0 12px 38px rgba(46,230,140,.3)}}
.ucard.onl::before{content:"";position:absolute;left:0;top:0;bottom:0;width:4px;background:linear-gradient(180deg,#2ee68c,var(--ac2),#2ee68c);background-size:100% 300%;animation:onlflow 3s linear infinite}
@keyframes onlflow{to{background-position:0 300%}}
.lvb{display:inline-flex;align-items:center;gap:8px;padding:5px 12px 5px 10px;border-radius:999px;font-size:11px;font-weight:800;letter-spacing:.9px;white-space:nowrap;color:var(--ok);background:linear-gradient(135deg,rgba(46,230,140,.26),rgba(46,230,140,.07));border:1px solid rgba(46,230,140,.55);box-shadow:0 0 16px rgba(46,230,140,.28),inset 0 0 10px rgba(46,230,140,.1)}
.lvb .rd{position:relative;width:8px;height:8px;border-radius:50%;background:currentColor;flex:none}
.lvb .rd::before,.lvb .rd::after{content:"";position:absolute;inset:-1px;border-radius:50%;border:2px solid currentColor;opacity:0;animation:lvr 1.9s ease-out infinite}
.lvb .rd::after{animation-delay:.95s}
@keyframes lvr{0%{transform:scale(1);opacity:.85}100%{transform:scale(3.4);opacity:0}}
.lvb .sg{display:inline-flex;align-items:flex-end;gap:2px;height:11px}
.lvb .sg i{display:block;width:2.5px;border-radius:2px;background:currentColor;animation:lvs 1.1s ease-in-out infinite}
.lvb .sg i:nth-child(1){height:4px}.lvb .sg i:nth-child(2){height:7px;animation-delay:.15s}.lvb .sg i:nth-child(3){height:11px;animation-delay:.3s}
@keyframes lvs{50%{opacity:.25}}
.lvb.off{color:var(--mut);background:var(--inp);border-color:var(--line);box-shadow:none;font-weight:700}
.lvb.off .rd::before,.lvb.off .rd::after{display:none}
.lvb.off .rd{opacity:.5}
.ldot{width:8px;height:8px;border-radius:50%;background:#2ee68c;display:inline-block;margin-right:6px;animation:lping 1.6s infinite}
@keyframes lping{0%{box-shadow:0 0 0 0 rgba(46,230,140,.7)}70%{box-shadow:0 0 0 8px rgba(46,230,140,0)}100%{box-shadow:0 0 0 0 rgba(46,230,140,0)}}
.lbox{background:rgba(46,230,140,.08);border:1px solid rgba(46,230,140,.3);border-radius:12px;padding:8px 10px;display:flex;flex-direction:column;gap:6px}
.lhd{font-size:10.5px;letter-spacing:.8px;color:#2ee68c;font-weight:800}
.lrow{display:flex;justify-content:space-between;align-items:center;gap:8px;font-size:12.5px;flex-wrap:wrap}
.lip{font-family:ui-monospace,Menlo,Consolas,monospace;font-weight:700;word-break:break-all;min-width:0}
.linfo{font-size:11px;opacity:.85;margin:-3px 0 2px;word-break:break-word}
.lpr{font-size:10.5px;padding:2px 8px;border-radius:999px;background:rgba(46,230,140,.18);color:#2ee68c;font-weight:800;white-space:nowrap}
.mini{height:6px;border-radius:6px;background:rgba(255,255,255,.09);overflow:hidden}
.mini i{display:block;height:100%;border-radius:6px;background:linear-gradient(90deg,#2ee68c,var(--ac2))}
.mini.warn i{background:linear-gradient(90deg,#ffb020,#ff3b4e)}
@media(max-width:560px){.ugrid{grid-template-columns:1fr}.grid{grid-template-columns:repeat(auto-fit,minmax(130px,1fr))}}
@media(prefers-reduced-motion:reduce){*{animation-duration:.01s!important;animation-iteration-count:1!important}}

/* ===== FUSION: Orbit Ring + Colour Wave + Prism (light blue x red) ===== */
body.an-fusion #bgfx .l1{inset:-30%;opacity:.15;background:conic-gradient(from 0deg at 50% 50%,var(--ac),var(--ac2),var(--ac),var(--ac2),var(--ac));animation:a-spin 42s linear infinite}
body.an-fusion #bgfx .l2{inset:auto;left:50%;top:44%;width:76vmin;height:76vmin;margin:-38vmin 0 0 -38vmin;border-radius:50%;opacity:.6;background:conic-gradient(from 0deg,var(--ac),transparent 28%,var(--ac2) 52%,transparent 78%,var(--ac));-webkit-mask:radial-gradient(circle,transparent 60%,#000 62%,#000 64.5%,transparent 66.5%);mask:radial-gradient(circle,transparent 60%,#000 62%,#000 64.5%,transparent 66.5%);animation:a-spin 16s linear infinite}
body.an-fusion #bgfx .l3{inset:auto 0 0 -50%;width:200%;height:150px;opacity:.3;background:repeating-linear-gradient(90deg,var(--ac) 0,var(--ac2) 120px,var(--ac) 240px);-webkit-mask:linear-gradient(0deg,#000,transparent);mask:linear-gradient(0deg,#000,transparent);animation:a-wave 8s linear infinite}
body.an-fusion #bgfx::before{content:"";position:absolute;left:50%;top:44%;width:54vmin;height:54vmin;margin:-27vmin 0 0 -27vmin;border-radius:50%;opacity:.5;background:conic-gradient(from 180deg,var(--ac2),transparent 30%,var(--ac) 55%,transparent 80%,var(--ac2));-webkit-mask:radial-gradient(circle,transparent 59%,#000 61%,#000 64%,transparent 66%);mask:radial-gradient(circle,transparent 59%,#000 61%,#000 64%,transparent 66%);animation:a-spin 11s linear infinite reverse}
body.an-fusion #bgfx::after{content:"";position:absolute;left:50%;top:44%;width:76vmin;height:76vmin;margin:-38vmin 0 0 -38vmin;border-radius:50%;background:radial-gradient(circle at 50% 1.6%,#fff 0,var(--ac) 5px,transparent 13px),radial-gradient(circle at 50% 98.4%,#fff 0,var(--ac2) 5px,transparent 13px);animation:a-spin 16s linear infinite}
body.an-fusion .card{border-color:rgba(76,201,255,.2);background:linear-gradient(135deg,rgba(76,201,255,.07),rgba(255,45,74,.06)),var(--card)}
body.an-fusion .card:hover{border-color:var(--ac2);box-shadow:0 10px 32px -12px rgba(255,45,74,.5),0 0 22px rgba(76,201,255,.18)}
body.an-fusion .nav button.on{background:linear-gradient(90deg,var(--ac),var(--ac2));color:#fff;text-shadow:0 1px 6px rgba(0,0,0,.45)}

/* ===== ALYAN FLAME UI (Tunnel Command Deck) ===== */
@keyframes a-embers{to{background-position:70px -420px}}
@keyframes a-embers2{to{background-position:-50px -520px}}
body.an-embers #bgfx .l1{inset:0;opacity:.9;background-image:radial-gradient(2px 2px at 20px 380px,var(--ac2),transparent),radial-gradient(1.6px 1.6px at 120px 250px,var(--ac),transparent),radial-gradient(2.4px 2.4px at 200px 120px,var(--ac2),transparent),radial-gradient(1.4px 1.4px at 260px 330px,#ffd9a0,transparent);background-size:300px 420px;animation:a-embers 16s linear infinite}
body.an-embers #bgfx .l2{inset:0;opacity:.6;background-image:radial-gradient(3px 3px at 60px 300px,var(--ac),transparent),radial-gradient(2px 2px at 190px 80px,var(--ac2),transparent),radial-gradient(2px 2px at 320px 220px,var(--ac),transparent);background-size:380px 520px;animation:a-embers2 26s linear infinite}
body.an-embers #bgfx .l3{inset:auto 0 -22vh 0;height:52vh;opacity:.2;background:radial-gradient(60% 100% at 50% 100%,var(--ac),transparent 70%);animation:a-breath 6s ease-in-out infinite}
@keyframes fl-spin{to{transform:rotate(360deg)}}
.fl-spin{transform-origin:62px 62px;animation:fl-spin 7s linear infinite}
body.ui-alyan{background:radial-gradient(900px 520px at 50% 115%,rgba(255,60,20,.16),transparent 70%),linear-gradient(rgba(255,255,255,.022) 1px,transparent 1px) 0 0/46px 46px,linear-gradient(90deg,rgba(255,255,255,.022) 1px,transparent 1px) 0 0/46px 46px,#050507;font-family:"Space Grotesk","Inter",system-ui,"Segoe UI",Roboto,sans-serif}
body.ui-alyan .lgbox{max-width:440px}
body.ui-alyan .lgcard{padding:1px;border-radius:34px;box-shadow:0 0 70px rgba(255,59,29,.22),0 0 0 1px rgba(255,59,29,.0)}
body.ui-alyan .lgcard::before{background:linear-gradient(160deg,rgba(255,59,29,.75),rgba(255,59,29,.18) 40%,rgba(255,59,29,.45));opacity:1}
body.ui-alyan .lgin{background:#0b0b10;border-radius:33px;padding:36px 30px 28px;text-align:left}
body.ui-alyan .emb{width:124px;height:124px;margin:0 auto 18px}
body.ui-alyan .emb::before,body.ui-alyan .emb::after{display:none}
body.ui-alyan .emb svg{display:block;animation:float 4s ease-in-out infinite}
body.ui-alyan .ttl{background:none;-webkit-background-clip:border-box;background-clip:border-box;color:#f6f1ea;font-size:31px;letter-spacing:6px;text-align:center;margin:0 0 14px;font-weight:800;animation:none}
body.ui-alyan .ttl .t1{background:linear-gradient(90deg,#ff2a1a,#ff6a00);-webkit-background-clip:text;background-clip:text;color:transparent}
body.ui-alyan .sub{text-align:center;color:#b9b3bd;font-size:19px;margin:0 0 34px;opacity:1;animation:none}
body.ui-alyan .lgin label{display:block;text-transform:uppercase;letter-spacing:3px;font-size:13px;font-weight:700;color:#a9a4ae;margin-top:4px}
body.ui-alyan .lgin input{height:58px;border-radius:20px;background:#0d0d13;border:1px solid #272731;padding:0 22px;font-size:18px;margin:12px 0 22px}
body.ui-alyan .lgin input:focus{border-color:#ff5a28;box-shadow:0 0 0 3px rgba(255,90,40,.22)}
body.ui-alyan #lbtn{height:58px;border-radius:20px;font-size:18px;letter-spacing:.3px;background:linear-gradient(90deg,#ff2a1a,#ff6a00 60%,#ffb000);box-shadow:0 10px 34px rgba(255,80,20,.42)}
body.ui-alyan .lgin .foot,body.ui-alyan #lfoot{color:#6f6a76;letter-spacing:1px;margin-top:42px!important;padding:0}
body.ui-alyan .err{text-align:center}
/* panel */
body.ui-alyan .top{background:rgba(8,8,11,.88);backdrop-filter:blur(10px);border-bottom:1px solid rgba(255,70,30,.2)}
body.ui-alyan .logo{background:linear-gradient(90deg,#ff2a1a,#ff6a00,#ffb000,#ff2a1a);background-size:200% auto;-webkit-background-clip:text;background-clip:text;letter-spacing:2px}
body.ui-alyan .nav{background:rgba(7,7,10,.6);border-right:1px solid rgba(255,70,30,.14)}
body.ui-alyan .nav button{border-radius:16px;font-weight:600}
body.ui-alyan .nav button:hover{background:rgba(255,70,30,.08);color:#fff}
body.ui-alyan .nav button.on{background:linear-gradient(90deg,#ff2a1a,#ff6a00 60%,#ffb000);color:#1b0600;font-weight:800;text-shadow:none;box-shadow:0 8px 26px rgba(255,80,20,.38)}
body.ui-alyan .nav button.on::before{background:#ffb000;box-shadow:0 0 14px #ff6a00}
body.ui-alyan .card{border-radius:24px;border-color:rgba(255,80,35,.16);background:linear-gradient(160deg,rgba(255,60,20,.05),transparent 45%),rgba(14,14,19,.88)}
body.ui-alyan .card:hover{border-color:rgba(255,90,40,.55);box-shadow:0 12px 40px -14px rgba(255,70,20,.55)}
body.ui-alyan .btn{border-radius:16px;background:linear-gradient(90deg,#ff2a1a,#ff6a00 60%,#ffb000);color:#1b0600;font-weight:800;box-shadow:0 8px 26px rgba(255,80,20,.36)}
body.ui-alyan .btn.g{background:rgba(255,255,255,.04);border:1px solid rgba(255,80,35,.25);color:var(--tx);box-shadow:none}
body.ui-alyan .btn.r{background:linear-gradient(90deg,#c2101a,#ff3b3b);color:#fff;box-shadow:0 6px 20px #ff3b4e55}
body.ui-alyan .btn.o{background:linear-gradient(90deg,#1fbf63,#7be495);color:#03200f}
body.ui-alyan input,body.ui-alyan select,body.ui-alyan textarea{border-radius:14px;border-color:#272731;background:#0d0d13}
body.ui-alyan input:focus,body.ui-alyan select:focus,body.ui-alyan textarea:focus{border-color:#ff5a28;box-shadow:0 0 0 3px rgba(255,90,40,.22)}
body.ui-alyan .ucard,body.ui-alyan .lx-ip,body.ui-alyan .lx-u{border-radius:22px}
body.ui-alyan .stat .v{background:linear-gradient(90deg,#fff,#ffb000);-webkit-background-clip:text;background-clip:text}
body.ui-alyan .bar i,body.ui-alyan .lx-bar i{background:linear-gradient(90deg,#ff2a1a,#ffb000)}
body.ui-alyan .toast{border-color:#ff5a28}
body.ui-alyan .th.on{border-color:#ff6a00}
/* ===== Live IPs / Users cards ===== */
.lx-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(250px,1fr));gap:12px}
.lx-ip,.lx-u{position:relative;background:linear-gradient(145deg,var(--inp),transparent);border:1px solid var(--line);border-radius:18px;padding:13px 14px 13px 17px;overflow:hidden;animation:fup .5s both;transition:transform .25s,border-color .25s,box-shadow .25s}
.lx-ip::before,.lx-u.on::before{content:"";position:absolute;left:0;top:0;bottom:0;width:4px;background:linear-gradient(180deg,var(--ac),var(--ac2),var(--ac));background-size:100% 300%;animation:onlflow 3s linear infinite}
.lx-ip:hover,.lx-u:hover{transform:translateY(-3px);border-color:var(--ac);box-shadow:0 10px 26px var(--glow)}
.lx-h{display:flex;align-items:center;gap:8px}
.lx-n{flex:1;min-width:0;font-family:ui-monospace,Menlo,Consolas,monospace;font-weight:800;font-size:14px;letter-spacing:.3px;word-break:break-all}
.lx-c{min-width:24px;height:24px;border-radius:12px;display:inline-flex;align-items:center;justify-content:center;font-size:12px;font-weight:800;background:linear-gradient(135deg,var(--ac),var(--ac2));color:#fff;padding:0 7px;flex:none}
.lx-inf{color:var(--mut);font-size:11px;margin:5px 0 0}
.simb{display:inline-flex;align-items:center;gap:6px;flex-wrap:wrap;margin:6px 0 0;font-size:11px}
.simb .sn{display:inline-flex;align-items:center;gap:6px;padding:3px 10px;border-radius:999px;font-weight:800;letter-spacing:.3px;color:#fff;background:var(--sc,#8892a6);box-shadow:0 0 12px color-mix(in srgb,var(--sc,#8892a6) 55%,transparent)}
.simb .sk,.simb .sl{padding:2px 8px;border-radius:999px;background:var(--inp);border:1px solid var(--line);color:var(--mut);font-weight:700;white-space:nowrap}
.lx-body{display:flex;flex-direction:column;gap:6px;margin-top:10px}
.lx-r{display:flex;align-items:center;justify-content:space-between;gap:8px;background:var(--inp);border:1px solid var(--line);border-radius:10px;padding:6px 10px;font-size:13px}
.lx-p{font-size:11px;font-weight:800;letter-spacing:.5px;padding:2px 9px;border-radius:10px;background:linear-gradient(135deg,var(--ac),var(--ac2));color:#fff;white-space:nowrap}
.lx-t{display:flex;align-items:center;gap:10px;margin-bottom:9px}
.lx-av{width:38px;height:38px;flex:none;border-radius:12px;display:inline-flex;align-items:center;justify-content:center;font-weight:900;font-size:17px;color:#fff;background:#000;transition:background .3s}
.lx-u.on .lx-av{background:linear-gradient(135deg,var(--ac),var(--ac2));animation:avglow 2.4s ease-in-out infinite}
.lx-nm{flex:1;min-width:0}.lx-nm b{display:block;word-break:break-all}.lx-nm small{color:var(--mut);font-size:11px}
.lx-bar{height:7px;border-radius:6px;background:var(--inp);border:1px solid var(--line);overflow:hidden;margin-top:6px}
.lx-bar i{display:block;height:100%;border-radius:6px;background:linear-gradient(90deg,var(--ac),var(--ac2));transition:width .6s}
.lx-bl{display:flex;justify-content:space-between;gap:8px;color:var(--mut);font-size:12px;margin:5px 0 8px;flex-wrap:wrap}
.lx-empty{padding:18px;text-align:center;color:var(--mut);border:1px dashed var(--line);border-radius:14px}
</style></head><body>
<div id="bgfx"><i class="l1"></i><i class="l2"></i><i class="l3"></i></div><canvas id="cf"></canvas>
<div class="wrap">
<div id="login" class="lg hide"><div class="lgbox"><div class="emb"><b>AR</b></div><h1 class="ttl" id="ttl"></h1><div class="sub" id="sub"></div>
<div class="lgcard"><div class="lgin"><div id="lf"></div><div class="err" id="le"></div><button class="btn" style="width:100%" id="lbtn" onclick="doLogin()">Login</button></div></div>
<div class="foot" id="lfoot" style="margin-top:14px">Support: <a href="https://t.me/ar_tricks" target="_blank" rel="noopener">t.me/ar_tricks</a></div></div></div>
<div id="app" class="hide"><div class="top"><button class="btn g s burger" id="burger" onclick="toggleNav()">☰</button><span class="logo" id="logo">★ ALIRAZA</span><span class="sp"></span><button class="btn g s" id="thbtn" onclick="topTheme()">🎨 Theme</button><button class="btn g s" onclick="logout()">Logout</button></div>
<div class="shell"><aside class="nav" id="nav"></aside><div class="content"><main id="main"></main><div class="foot">© ALIRAZA · Support: <a href="https://t.me/ar_tricks" target="_blank" rel="noopener">t.me/ar_tricks</a></div></div></div><div class="ov" id="ov" onclick="toggleNav(false)"></div></div></div>
<div class="modal" id="modal"><div class="card"><div id="mbody"></div><div style="text-align:right;margin-top:12px"><button class="btn g" onclick="closeM()">Close</button></div></div></div>
<div class="toast" id="toast"></div>
<svg width="0" height="0" style="position:absolute"><defs><linearGradient id="gr" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="var(--ac)"/><stop offset="1" stop-color="var(--ac2)"/></linearGradient></defs></svg>
<script>
const $=id=>document.getElementById(id);
const MODE=/^\/u\/?$/.test(location.pathname)?'user':'admin';let VW=false,LROLE='admin';
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const LS={get(k,d){try{return localStorage.getItem(k)||d}catch(e){return d}},set(k,v){try{localStorage.setItem(k,v)}catch(e){}}};
/* ---------- themes ---------- */
const D=(id,n,bg,bg2,ac,ac2,x)=>Object.assign({id,n,bg,bg2,ac,ac2,card:'rgba(255,255,255,.055)',line:'rgba(255,255,255,.1)',tx:'#eef1ff',mut:'#9aa3c2',inp:'rgba(0,0,0,.3)',pre:'rgba(0,0,0,.38)'},x||{});
const THEMES=[D('alyan','🔥 AliRaza Flame (Command Center)','#050507','#1a0804','#ff3a1d','#ffb000',{ui:'alyan',card:'rgba(14,14,19,.86)',line:'rgba(255,80,35,.17)',tx:'#f6f1ea',mut:'#8f8a96',inp:'rgba(6,6,10,.85)',pre:'rgba(0,0,0,.5)'}),D('fusion','Blue × Red Fusion','#060914','#1c0c1e','#4cc9ff','#ff2d4a'),D('aurora','Aurora','#0a0e1c','#17204a','#7c5cff','#00d4ff'),D('neon','Neon Pink','#0b0614','#2a0d3d','#ff2bd6','#00ffa3'),D('sunset','Sunset','#140a0f','#3d1424','#ff7a18','#ff2d75'),
D('ocean','Deep Ocean','#04111f','#0a2f4f','#1e90ff','#00e5c3'),D('emerald','Emerald','#04140d','#0b3a24','#10d96f','#b6ff3b'),D('gold','Royal Gold','#0e0b05','#3a2a08','#f5b942','#ffe29a'),
D('crimson','Crimson','#130507','#40121a','#ff3b4e','#ff9a5a'),D('midnight','Midnight','#070914','#1b1f5c','#5b6cff','#b36bff'),D('matrix','Matrix','#000a03','#003d12','#00ff41','#00b32c'),
D('rose','Rose Quartz','#170a14','#451a35','#ff6fae','#ffc2dd'),D('cyber','Cyber Yellow','#0b0b00','#2b2b00','#fcee0a','#00f0ff'),D('violet','Royal Violet','#0d0618','#2d1060','#a855f7','#f0abfc'),
D('ice','Ice Light','#eef3fb','#d6e2ff','#4f6bff','#00b8d9',{card:'rgba(255,255,255,.75)',line:'rgba(20,30,70,.12)',tx:'#0f1a33',mut:'#5b678c',inp:'rgba(20,30,70,.06)',pre:'rgba(20,30,70,.07)'})];
const AN1=[['embers','🔥 Embers (AliRaza Flame)'],['pulse','💗 Pulse Glow'],['breathe','🫧 Breathing Cards'],['scan','📡 Scan Line'],['ripple','🌊 Ripple'],['neon','💡 Neon Flicker'],['stars','✨ Starfield'],['bubbles','🫧 Bubbles']];
const AN2=[['fusion','🔮 Fusion (Orbit+Wave+Prism)'],['flow','🌈 Gradient Flow'],['aurora','🌌 Aurora'],['duo','🔀 Duo Fade'],['orbit','🪐 Orbit Ring'],['wave','〰️ Colour Wave'],['prism','🔷 Prism Spin']];
const hx=h=>{h=h.replace('#','');return[0,2,4].map(i=>parseInt(h.substr(i,2),16))};
const mixc=(a,b,t)=>'#'+hx(a).map((v,i)=>Math.round(v+(hx(b)[i]-v)*t).toString(16).padStart(2,'0')).join('');
const ST={theme:'fusion',an:'fusion',fx:'full',custom:{},v:0,t:0};
function buildCustom(){const c=ST.custom||{};
 const c1=c.c1||'#4cc9ff',c2=c.mode==='double'?(c.c2||'#ff2d4a'):mixc(c1,'#ffffff',.38);
 return D('custom','Custom',mixc(c1,'#000000',.93),mixc(c.mode==='double'?c2:c1,'#000000',.80),c1,c2)}
function saveSrv(){if(MODE!=='admin')return;ST.t=Date.now();api('/api/theme',{theme:ST.theme,an:ST.an,fx:ST.fx,custom:ST.custom}).then(d=>{if(d&&d.error)return toast(d.error);if(d&&d.v)ST.v=d.v;toast('✔ Theme sab users ke liye lag gayi')}).catch(()=>{})}
function setAn(a,p=true){a=a||'none';document.body.className=document.body.className.replace(/\ban-\S+/g,'').trim();if(a!=='none')document.body.classList.add('an-'+a);ST.an=a;if(p)saveSrv()}
function applyTheme(id,p=true){const t=id==='custom'?buildCustom():(THEMES.find(x=>x.id===id)||THEMES[0]),r=document.documentElement.style;
 document.body.classList.toggle('ui-alyan',t.ui==='alyan');if(t.ui==='alyan'&&p&&ST.an!=='embers')setAn('embers',false);setTimeout(()=>{brandLogin();fixLogo()},0);
 ['bg','bg2','card','line','tx','mut','ac','ac2','inp','pre'].forEach(k=>r.setProperty('--'+k,t[k]));r.setProperty('--glow',t.ac+'66');
 document.querySelector('meta[name=theme-color]').content=t.bg;ST.theme=t.id;window._ptheme=t;document.querySelectorAll('.th').forEach(e=>e.classList.toggle('on',e.dataset.id===t.id));if(p)saveSrv()}
const FLAME_SVG='<svg viewBox="0 0 124 124" width="124" height="124" aria-hidden="true"><defs><linearGradient id="fgA" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ff2a1a"/><stop offset=".55" stop-color="#ff6a00"/><stop offset="1" stop-color="#ffb000"/></linearGradient><radialGradient id="fgB" cx=".5" cy=".7" r=".6"><stop offset="0" stop-color="#fff2b0"/><stop offset="1" stop-color="#ffb000"/></radialGradient></defs><circle cx="62" cy="62" r="60" fill="none" stroke="#ff6a00" stroke-opacity=".6" stroke-width="1.2" stroke-dasharray="2.5 3.5"/><g class="fl-spin"><path d="M18 68 A44 44 0 0 1 62 18" fill="none" stroke="#ff2a1a" stroke-width="3" stroke-linecap="round"/><path d="M62 18 A44 44 0 0 1 106 66" fill="none" stroke="#ffb000" stroke-width="3" stroke-linecap="round"/></g><path d="M62 30 C64 46 82 52 82 72 C82 88 72 98 62 98 C51 98 41 88 41 72 C41 58 51 52 54 42 C57 47 58 50 61 51 C63 45 62 38 62 30 Z" fill="url(#fgA)" style="filter:drop-shadow(0 0 8px #ff4a1a)"/><path d="M62 76 C65 82 70 84 70 90 C70 95 66 98 62 98 C57 98 54 95 54 90 C54 84 59 82 62 76 Z" fill="url(#fgB)"/></svg>';
let LGO=null;
function brandLogin(fromSetup){const e=$('emb'),t=$('ttl'),sb=$('sub'),b=$('lbtn'),f=$('lfoot'),box=document.querySelector('.lgbox'),card=document.querySelector('.lgcard'),inn=document.querySelector('.lgin');if(!e||!t||!inn)return;
 if(!LGO)LGO={foot:f.innerHTML};const a=document.body.classList.contains('ui-alyan');
 if(a){e.innerHTML=FLAME_SVG;t.innerHTML='<span class="t1">ALIRAZA</span> <span class="t2">WEBPANEL</span>';sb.textContent=MODE==='user'?'Your Account Deck':'Tunnel Command Center';b.textContent='Ignite Access';f.innerHTML='encrypted session · brute-force protected';
  inn.insertBefore(sb,inn.firstChild);inn.insertBefore(t,sb);inn.insertBefore(e,t);
  const u=$('lu'),p=$('lp'),k=$('lk');if(u)u.placeholder='Enter your username';if(p)p.placeholder='Enter your password';if(k)k.placeholder='AR-XXXX-XXXX-XXXX-XXXX'}
 else{if(e.querySelector('svg'))e.innerHTML='<b>AR</b>';b.textContent='Login';f.innerHTML=LGO.foot;
  if(inn.contains(e)){box.insertBefore(sb,card);box.insertBefore(t,sb);box.insertBefore(e,t)}
  if(!fromSetup&&!$('login').classList.contains('hide'))setupLogin()}}
function fixLogo(){}
new MutationObserver(fixLogo).observe($('logo'),{childList:true,characterData:true,subtree:true});
function alyanOn(){applyTheme('alyan',false);setAn('embers',false);saveSrv();setTimeout(()=>V.themes(),50)}
function alyanOff(){applyTheme('fusion',false);setAn('fusion',false);saveSrv();setTimeout(()=>V.themes(),50)}
function customApply(mode,an){const c=Object.assign({},ST.custom||{});c.mode=mode;c.c1=($('c1'+mode)||{}).value||c.c1||'#4cc9ff';if(mode==='double')c.c2=($('c2d')||{}).value||c.c2||'#ff2d4a';
 ST.custom=c;applyTheme('custom',false);setAn(an,false);saveSrv();V.themes()}
function applyFx(m,p=true){document.body.classList.remove('fx-lite','fx-off');if(m!=='full')document.body.classList.add('fx-'+m);ST.fx=m;document.querySelectorAll('[data-fx]').forEach(e=>e.classList.toggle('g',e.dataset.fx!==m));if(p)saveSrv()}
function applySrv(s){if(!s||!s.theme)return;ST.custom=s.custom||{};ST.v=s.v||0;applyTheme(s.theme,false);setAn(s.an||'fusion',false);applyFx(s.fx||'full',false)}
async function syncTheme(first){if(!first&&Date.now()-ST.t<6000)return;try{const r=await fetch('/api/theme',{cache:'no-store'});const s=await r.json();if(s&&s.theme&&(first||s.v!==ST.v))applySrv(s)}catch(e){}}
/* ---------- particles / confetti ---------- */
const cf=$('cf'),cx=cf.getContext('2d');function sizeC(){cf.width=innerWidth;cf.height=innerHeight}addEventListener('resize',sizeC);sizeC();
let CF=[],cfRun=false;
function confetti(n=110){return;const t=window._ptheme||THEMES[0],cols=[t.ac,t.ac2,'#ffd166','#06d6a0','#ff5d8f','#fff'];
 for(let i=0;i<n;i++)CF.push({x:innerWidth/2,y:innerHeight/3,vx:(Math.random()-.5)*14,vy:Math.random()*-13-3,g:.32,s:Math.random()*7+4,c:cols[i%cols.length],a:1,r:Math.random()*6,vr:(Math.random()-.5)*.4});
 if(!cfRun){cfRun=true;(function f(){cx.clearRect(0,0,cf.width,cf.height);CF=CF.filter(p=>p.a>0.02);for(const p of CF){p.x+=p.vx;p.y+=p.vy;p.vy+=p.g;p.vx*=.99;p.r+=p.vr;p.a-=.009;cx.save();cx.globalAlpha=Math.max(p.a,0);cx.translate(p.x,p.y);cx.rotate(p.r);cx.fillStyle=p.c;cx.fillRect(-p.s/2,-p.s/4,p.s,p.s/2);cx.restore()}
  if(CF.length)requestAnimationFrame(f);else{cfRun=false;cx.clearRect(0,0,cf.width,cf.height)}})()}}
/* ---------- helpers ---------- */
async function api(path,body){
 const o=body===undefined?{}:{method:'POST',headers:{'Content-Type':'application/json','X-Requested-With':'AliRazaPanel'},body:JSON.stringify(body)};
 try{const r=await fetch(path,o);const d=await r.json().catch(()=>({error:'Bad response'}));
  if(r.status===401&&!/login$/.test(path)){showLogin();throw 0}if(!r.ok)d.error=d.error||('HTTP '+r.status);return d}catch(e){if(e===0)throw e;return{error:'Network error'}}}
function toast(m){const t=$('toast');t.textContent=m;t.style.display='block';clearTimeout(t._t);t._t=setTimeout(()=>t.style.display='none',3600)}
const fq=q=>{q=+q||0;if(!q)return'Unlimited';return q<1?Math.max(1,Math.round(q*1024))+' MB':(+q.toFixed(2))+' GB'};
const qsplit=q=>{q=+q||0;return q>0&&q<1?[Math.max(1,Math.round(q*1024)),'mb']:[q,'gb']};
const fb=b=>{b=+b||0;if(b>=2**40)return(b/2**40).toFixed(2)+' TB';if(b>=2**30)return(b/2**30).toFixed(2)+' GB';return(b/2**20).toFixed(2)+' MB'};
const fu=s=>{const d=Math.floor(s/86400),h=Math.floor(s%86400/3600),m=Math.floor(s%3600/60);return(d?d+'d ':'')+h+'h '+m+'m'};
const isAct=s=>s==='UNLOCKED'||s==='ACTIVE';
const pill=(ok,a='ON',b='OFF')=>`<span class="pill ${ok?'on_':'off_'}">${ok?a:b}</span>`;
function openM(h){$('mbody').innerHTML=h;$('modal').classList.add('show')}function closeM(){$('modal').classList.remove('show')}
function countUp(el,to,fmt,dur=1000,instant){to=+to||0;fmt=fmt||(v=>Math.round(v));if(instant||document.body.classList.contains('fx-off')){el.textContent=fmt(to);return}
 const t0=performance.now();(function s(t){const k=Math.min((t-t0)/dur,1),e=1-Math.pow(1-k,3);el.textContent=fmt(to*e);if(k<1)requestAnimationFrame(s)})(t0)}
function runCounts(root,instant){(root||document).querySelectorAll('[data-count]').forEach(e=>countUp(e,e.dataset.count,e.dataset.f==='gb'?v=>(+v).toFixed(2)+' GB':e.dataset.f==='dec'?v=>(+v).toFixed(0):null,1000,instant))}
function ring(pct,big,small){pct=Math.max(0,Math.min(100,pct));return `<div class="ring"><svg width="150" height="150" viewBox="0 0 100 100"><circle class="bg" cx="50" cy="50" r="42"/><circle class="fg" cx="50" cy="50" r="42" data-p="${pct}"/></svg><div class="mid"><b>${big}</b><small>${small}</small></div></div>`}
function fillRings(root){const f=()=>(root||document).querySelectorAll('.ring .fg').forEach(e=>e.style.strokeDashoffset=264-264*(+e.dataset.p)/100);if(root&&root.classList&&root.classList.contains('still'))f();else setTimeout(f,60)}
const copy=t=>navigator.clipboard.writeText(t).then(()=>toast('Copied ✔'),()=>toast('Copy fail'));
/* ---------- login ---------- */
function setupLogin(){const hk=(location.hash||'').slice(1);const t=MODE==='user'?'ALIRAZA USER PANEL':'ALIRAZA PANEL MANAGEMENT';
 $('ttl').textContent=t;
 $('sub').textContent=MODE==='user'?'Apni account ki details dekhne ke liye Access Key likhein':(LROLE==='viewer'?'View-only access · admin se mila username/password likhein':'Secure admin access · AliRaza-server');
 $('lf').innerHTML=MODE==='user'?'<label>Access Key</label><input id="lk" placeholder="AR-XXXX-XXXX-XXXX-XXXX" autocomplete="off" style="letter-spacing:1px">':
 lrTabs()+'<label>Username</label><input id="lu" autocomplete="username"><label>Password</label><input id="lp" type="password" autocomplete="current-password">';
 $('lf').querySelectorAll('input').forEach(i=>i.addEventListener('keydown',e=>{if(e.key==='Enter')doLogin()}));if(MODE==='user'&&/^AR-/i.test(hk)){$('lk').value=hk;setTimeout(doLogin,1400)}brandLogin(true)}
function showLogin(){VW=false;$('nav').innerHTML='';$('thbtn').classList.remove('hide');$('logo').textContent='★ ALIRAZA';$('app').classList.add('hide');$('login').classList.remove('hide');stopPoll();setupLogin()}
async function doLogin(){$('lbtn').disabled=true;
 const d=MODE==='user'?await api('/api/u/login',{key:$('lk').value}):(LROLE==='viewer'?await api('/api/v/login',{username:$('lu').value,password:$('lp').value}):await api('/api/login',{username:$('lu').value,password:$('lp').value}));$('lbtn').disabled=false;
 if(d.ok){history.replaceState(null,'',location.pathname);$('login').classList.add('hide');$('app').classList.remove('hide');$('le').textContent='';if(MODE==='user'){V.me()}else if(LROLE==='viewer'){viewerBoot()}else{if(/^v(dash|users|live)$/.test(cur))cur='dash';go(cur)}confetti(50)}else $('le').textContent=d.error||'Error'}
async function logout(){await api(MODE==='user'?'/api/u/logout':(VW?'/api/v/logout':'/api/logout'),{});showLogin()}
/* ---------- shell ---------- */
const TABS=[['dash','📊 Dashboard'],['users','👥 Users'],['live','📡 Live IPs'],['svc','⚙️ Services'],['domain','🌐 Domain & SSL'],['banner','🏷️ SSH Banner'],['bunny','🐰 Bunny CDN'],['tg','🤖 Telegram'],['tools','🧰 Tools'],['themes','🎨 Themes'],['set','🔐 Settings']];
let cur='dash',poll=null;
function stopPoll(){clearInterval(poll);poll=null}
function toggleNav(f){const n=$('nav'),o=$('ov'),on=f===undefined?!n.classList.contains('open'):f;n.classList.toggle('open',on);o.classList.toggle('show',on)}
function buildNav(){$('nav').innerHTML=(VW?VTABS:TABS).map((x,i)=>`<button id="t_${x[0]}" style="animation-delay:${i*.05}s" onclick="go('${x[0]}')">${x[1]}</button>`).join('')}
function go(t){if(MODE==='user')return userGo(t);cur=t;stopPoll();const n=$('nav');if(!n.children.length)buildNav();n.classList.remove('hide');
 n.querySelectorAll('button').forEach(b=>b.classList.toggle('on',b.id==='t_'+t));toggleNav(false);
 $('main').innerHTML='<div class="mut">Loading...</div>';V[t]();scrollTo({top:0})}
function topTheme(){if(MODE==='user'||VW)return;go('themes')}
function userGo(t){stopPoll();window._sig='';V.me()}
const V={};
let _lastHtml='';
function morphKids(a,b){
 const an=a.childNodes,bn=b.childNodes;
 for(let i=0;i<bn.length;i++){
  const x=an[i],y=bn[i];
  if(!x){a.appendChild(y.cloneNode(true));continue}
  if(x.nodeType!==y.nodeType||x.nodeName!==y.nodeName){a.replaceChild(y.cloneNode(true),x);continue}
  if(x.nodeType!==1){if(x.nodeValue!==y.nodeValue)x.nodeValue=y.nodeValue;continue}
  if(/^(INPUT|TEXTAREA|SELECT)$/.test(x.tagName))continue;
  for(const at of [...x.attributes]){if(at.name==='open')continue;if(!y.hasAttribute(at.name))x.removeAttribute(at.name)}
  for(const at of [...y.attributes]){if(at.name==='open')continue;if(x.getAttribute(at.name)!==at.value)x.setAttribute(at.name,at.value)}
  morphKids(x,y)}
 while(an.length>bn.length)a.removeChild(a.lastChild)}
const show=(h,anim=true)=>{const m=$('main');
 if(!anim){if(h===_lastHtml)return;const ae=document.activeElement;if(ae&&m.contains(ae)&&/^(INPUT|TEXTAREA|SELECT)$/.test(ae.tagName))return;
  _lastHtml=h;m.classList.add('still');let w=m.firstElementChild;
  if(!w||!w.classList.contains('fadein')||m.children.length!==1){m.innerHTML='<div class="fadein" style="animation:none"></div>';w=m.firstElementChild}
  const t=document.createElement('template');t.innerHTML=h;morphKids(w,t.content);return}
 _lastHtml=h;m.classList.remove('still');m.innerHTML=`<div class="fadein">${h}</div>`};
/* ---------- dashboard ---------- */
V.dash=async()=>{let first=true;const render=async()=>{if(!first&&document.hidden)return;const d=await api('/api/dashboard');if(d.error)return;
 const rp=d.ram_total?Math.round(d.ram_used*100/d.ram_total):0,dp=d.disk_total?Math.round(d.disk_used*100/d.disk_total):0;
 const st=(k,v,x='')=>`<div class="card stat"><div class="k">${k}</div><div class="v">${v}</div>${x}</div>`;
 show(`<div class="grid">
 ${st('Server IP',esc(d.ip),`<div class="s">${esc(d.provider)}</div>`)}
 ${st('Google Ping',d.ping==null?'n/a':`<span data-count="${d.ping}" data-f="dec">0</span> ms`,`<div class="s">${d.cpus}-Core · load ${esc(d.load.join(' '))}</div>`)}
 ${st('Uptime',fu(d.uptime))}
 ${st('Accounts',`<span data-count="${d.users}">0</span>`,`<div class="s">${d.locked} locked</div>`)}
 ${st('Real Used',fb(d.used_bytes),`<div class="s">Total limit: ${fq(d.limit_gb)}</div>`)}
</div>
 <div class="hero"><div class="card" style="text-align:center"><h3>RAM</h3>${ring(rp,rp+'%',d.ram_used+'/'+d.ram_total+' MB')}</div>
 <div class="card" style="text-align:center"><h3>Disk</h3>${ring(dp,dp+'%',d.disk_used+'/'+d.disk_total+' GB')}</div>
 <div class="card"><h3>Hosts</h3><table><tr><td class="mut">Main Domain</td><td>${esc(d.domain)}</td></tr><tr><td class="mut">Status</td><td><span class="pill ${d.domain_status==='POINTED'?'on_':'warn_'}">${esc(d.domain_status)}</span></td></tr>
 <tr><td class="mut">SlowDNS NS</td><td>${esc(d.ns)}</td></tr><tr><td class="mut">Bunny CDN</td><td>${esc(d.bunny)}</td></tr><tr><td class="mut">Telegram Bot</td><td>${pill(d.tg,'Configured','Not set')}</td></tr></table></div></div>
 <div class="card"><h3>Quick actions</h3><div class="acts"><button class="btn s" onclick="act('restart_all','Restart all services?')">♻ Restart All</button>
 <button class="btn s g" onclick="act('autodoctor','Auto-Doctor chalayein?')">🩺 Auto-Doctor</button><button class="btn s g" onclick="act('clean','RAM/Logs clean karein?')">🧹 Clean RAM/Logs</button></div></div>`,first);
 runCounts($('main'),!first);fillRings($('main'));first=false};
 await render();poll=setInterval(render,8000)};
/* ---------- users ---------- */
function userRow(u,i){const q=+u.quota_gb||0,e=esc(u.username),act=u.status==='UNLOCKED',lim=+u.ip_limit||0,pct=q?Math.min(100,Math.round(u.used*100/(q*2**30))):0,live=+u.live||0,over=lim>0&&live>lim,lp=lim?Math.min(100,Math.round(live*100/lim)):(live?100:0);
 const badge=!act?`<span class="pill warn_">${esc(u.status)}</span>`:live?'<span class="lvb"><span class="rd"></span>ONLINE<span class="sg"><i></i><i></i><i></i></span></span>':'<span class="lvb off"><span class="rd"></span>OFFLINE</span>';
 const ips=(u.ips||[]).map(x=>`<div class="lrow"><span class="lip">${esc(x.ip)}</span><span class="lpr">${esc((x.protos||[]).join(' · ')||'LIVE')}</span></div>${simHTML(x)}`).join('');
 const lbox=live?`<div class="lbox"><div class="lhd">LIVE SIM IPs</div>${ips}</div>`:'';
 return `<div class="ucard rw${live?' onl':' off'}" style="animation-delay:${Math.min(i,12)*.04}s"><div class="uh"><span style="display:flex;align-items:center;gap:8px;min-width:0"><span class="uav">${esc((u.username||'A').charAt(0).toUpperCase())}</span><b style="overflow:hidden;text-overflow:ellipsis">${e}</b></span>${badge}</div>
 <div class="mut" style="font-size:11px">${esc(!u.protos||u.protos==='all'?'ALL protocols':u.protos.toUpperCase().replace(/,/g,' · '))}</div>
 ${lbox}
 <div class="ur"><span class="k">📶 Data used</span><span><b>${fb(u.used)}</b> / ${q?fq(q):'∞'}</span></div><div class="bar"><i style="width:${pct}%"></i></div>
 <div class="ur"><span class="k">🟢 Connected</span><span><b>${live}</b> / ${lim||'-'} IPs${over?' <span class="pill warn_">limit se zyada</span>':''}</span></div><div class="mini${over?' warn':''}"><i style="width:${lp}%"></i></div>
 <div class="ur"><span class="k">📅 Expiry</span><span>${esc(u.expiry)}</span></div>
 <div class="acts"><button class="btn s g" onclick="info('${e}')">Info</button><button class="btn s g" onclick="renew('${e}',${q},${lim||2})">Renew</button>
 ${act?`<button class="btn s g" onclick="uact('lock','${e}')">Lock</button>`:`<button class="btn s o" onclick="unlock('${e}')">Unlock</button>`}
 <button class="btn s r" onclick="uact('delete','${e}')">Delete</button></div></div>`}
const PICO={ssh:'🔑',vless:'⚡',vmess:'🚀',trojan:'🛡️',ss:'🌑',socks5:'🧦',zivpn:'📡',hy2:'🌪️',slowdns:'🐢',all:'🌐'};
let UDATA=null,UTAB='',USRQ='';
const plabel=k=>{if(k==='all')return 'ALL';if(k==='ssh')return 'SSH';const p=PROTOS.find(x=>x[0]===k);return p?p[1].toUpperCase():String(k).toUpperCase()};
function dleft(x){if(!x)return '-';const t=Date.parse(String(x).trim().slice(0,10)+'T23:59:59');if(isNaN(t))return '-';const d=Math.ceil((t-Date.now())/864e5);return d<0?'Expired':d+'d'}
function userCard(u,i,k){const q=+u.quota_gb||0,e=esc(u.username),act=u.status==='UNLOCKED',lim=+u.ip_limit||0,live=+u.live||0,over=lim>0&&live>lim,pct=q?Math.min(100,Math.round(u.used*100/(q*2**30))):0;
 const st=!act?`<span class="st lk">${esc(String(u.status||'locked').toLowerCase())}</span>`:live?'<span class="st on">online</span>':'<span class="st">offline</span>';
 const showId=['vless','vmess','trojan','all'].includes(k)&&u.uuid;
 const ips=live?(u.ips||[]).map(x=>`<div class="lrow"><span class="lip">${esc(x.ip)}</span><span class="lpr">${esc((x.protos||[]).join(' · ')||'LIVE')}</span></div>${simHTML(x)}`).join(''):'';
 const dl=dleft(u.expiry);
 return `<div class="uc2 rw${live?' onl':''}" style="animation-delay:${Math.min(i,10)*.04}s">
 <div class="hd"><div class="hex">${esc((u.username||'A').charAt(0).toUpperCase())}</div><div style="min-width:0;flex:1"><div class="nm"><b>${e}</b>${st}</div>
 <div class="sb"><b>${esc(plabel(k))}</b> · cap ${lim||'∞'} ${lim===1?'IP':'IPs'} · exp ${esc(u.expiry||'-')}</div>
 <div class="sb">👑 Owner: <b>AliRaza</b></div>
 ${showId?`<div class="sb">${esc(String(u.uuid).slice(0,18))}… <span style="cursor:pointer" title="Copy UUID" onclick="copy('${esc(u.uuid)}')">⧉</span></div>`:''}</div></div>
 <div><div class="tr"><span>TRAFFIC</span><span>${fb(u.used)} / ${q?fq(q):'∞'}</span></div><div class="bar" style="margin-top:7px"><i style="width:${pct}%"></i></div></div>
 <div class="tiles"><div class="tile"><span>LIVE USERS</span><b${over?' style="color:#ff6b6b"':''}>${live}</b></div><div class="tile"><span>IP LIMIT</span><b>${lim||'∞'}</b></div><div class="tile"><span>EXPIRY</span><b${dl==='Expired'?' style="color:#ff6b6b"':''}>${esc(dl)}</b></div></div>
 ${ips?`<div class="lbox"><div class="lhd">LIVE SIM IPs</div>${ips}</div>`:''}
 <div class="ab"><button class="btn" onclick="info('${e}')">🔗 Links &amp; Info</button>
 ${act?`<button class="btn r" onclick="uact('lock','${e}')">⏻ Disable</button>`:`<button class="btn o" onclick="unlock('${e}')">⏻ Enable</button>`}
 <button class="btn g ibtn" title="Edit / Renew" onclick="renew('${e}',${q},${lim||2})">✏️</button><button class="btn g ibtn" title="Delete" onclick="uact('delete','${e}')">🗑️</button></div></div>`}
function paintUsers(){const d=UDATA;if(!d||!$('ucards'))return;
 const g={},all=[];
 d.users.forEach(u=>{const p=(!u.protos||u.protos==='all')?[]:String(u.protos).split(',').map(x=>x.trim().toLowerCase()).filter(Boolean);
  if(!p.length){all.push(u);return}p.forEach(k=>{(g[k]=g[k]||[]).push(u)})});
 const order=PROTOS.map(p=>p[0]),idx=k=>{const i=order.indexOf(k);return i<0?99:i};
 const tabs=Object.keys(g).sort((a,b)=>idx(a)-idx(b)||a.localeCompare(b));if(all.length)tabs.push('all');
 if(!tabs.includes(UTAB))UTAB=tabs[0]||'';
 const tb=$('utabs'),sl=tb.scrollLeft;
 tb.innerHTML=tabs.map(k=>`<button class="utab${k===UTAB?' on':''}" onclick="UTAB='${esc(k)}';paintUsers()">${PICO[k]||'🔌'} ${esc(plabel(k))}<i>${(k==='all'?all:g[k]).length}</i></button>`).join('');tb.scrollLeft=sl;
 const q=USRQ.trim().toLowerCase(),base=UTAB==='all'?all:(g[UTAB]||[]),list=base.filter(u=>!q||String(u.username).toLowerCase().includes(q));
 $('ucards').innerHTML=!d.users.length?'<div class="mut">Koi account nahi.</div>':list.length?list.map((u,i)=>userCard(u,i,UTAB)).join(''):'<div class="mut">Koi match nahi.</div>'}
V.users=async()=>{let first=true;const render=async()=>{if(!first&&document.hidden)return;const d=await api('/api/users');if(d.error)return;UDATA=d;
 const on=d.users.filter(u=>u.live>0).length,tot=d.users.reduce((a,u)=>a+(+u.used||0),0);
 const st=(k,v,x='')=>`<div class="card stat"><div class="k">${k}</div><div class="v">${v}</div>${x}</div>`;
 const stats=`<div class="grid">${st('Accounts',d.users.length)}${st('Online Now',on+' / '+d.users.length,'<div class="s">'+(d.live_ips||0)+' live IPs</div>')}${st('Total Data Used',fb(tot))}</div>`;
 if(!$('ucards'))show(`<div id="ustats">${stats}</div>
 <div class="card"><div class="acts" style="margin-bottom:12px"><button class="btn" onclick="newUser()">＋ Create Account</button><button class="btn g" onclick="trial()">⏱ 24h Trial</button></div>
 <div class="utb"><div class="utabs" id="utabs"></div><label class="usrch"><span>🔍</span><input id="usq" placeholder="Search" value="${esc(USRQ)}" oninput="USRQ=this.value;paintUsers()"></label></div><div class="uc2grid" id="ucards"></div></div>`,first);
 else $('ustats').innerHTML=stats;
 paintUsers();first=false};
 await render();poll=setInterval(()=>{if(!$('modal').classList.contains('show'))render()},3000)};
const PROTOS=[['ssh','SSH / WS / SSL / UDP / OpenVPN'],['vless','VLESS'],['vmess','VMess'],['trojan','Trojan'],['ss','Shadowsocks'],['socks5','Socks5 / HTTP'],['zivpn','ZiVPN UDP'],['hy2','Hysteria2'],['slowdns','SlowDNS']];
function pAll(v){document.querySelectorAll('.pk').forEach(c=>c.checked=!!v)}
function newUser(){openM(`<h2>Create VIP Account</h2><div class="row"><div><label>Username</label><input id="nu"></div><div><label>Password</label><input id="np" value="1234"></div>
 <div><label>Data Limit (0 = unlimited)</label><div style="display:grid;grid-template-columns:1fr 84px;gap:8px"><input id="nq" type="number" min="0" step="any" value="0"><select id="nu_u" style="margin-top:3px"><option value="gb">GB</option><option value="mb">MB</option></select></div></div><div><label>IP Limit</label><input id="ni" type="number" value="2"></div><div><label>Validity (days)</label><input id="nd" type="number" value="30"></div></div>
 <h3 style="margin-top:4px">Protocols — jo tick karoge SIRF wohi chalega (kam az kam 1)</h3>
 <div class="acts" style="margin-bottom:8px"><button class="btn s g" onclick="pAll(1)">Select all</button><button class="btn s g" onclick="pAll(0)">Clear</button></div>
 <div class="chips">${PROTOS.map(p=>`<label class="chip" style="opacity:1;animation:none;cursor:pointer;display:flex;align-items:center;gap:6px"><input type="checkbox" class="pk" value="${p[0]}" style="width:auto;margin:0">${p[1]}</label>`).join('')}</div>
 <button class="btn" style="margin-top:12px" onclick="createUser()">Create</button>`)}
async function createUser(){const ps=[...document.querySelectorAll('.pk:checked')].map(c=>c.value);if(!ps.length)return toast('Kam az kam 1 protocol chunein');const d=await api('/api/user/create',{protos:ps,username:$('nu').value,password:$('np').value,quota:$('nq').value,unit:$('nu_u').value,ip_limit:$('ni').value,days:$('nd').value});
 if(d.error)return toast(d.error);if(!d.ok||!d.info)return openM(`<h2>Create failed</h2><pre>${esc(d.output)}</pre>`);showAccount(d.info,true);go('users')}
async function trial(){if(!confirm('24h trial account banayein?'))return;const d=await api('/api/user/trial',{});if(d.error)return toast(d.error);if(d.info){showAccount(d.info,true)}else openM(`<pre>${esc(d.output)}</pre>`);go('users')}
async function uact(a,u){if(!confirm(a.toUpperCase()+' '+u+' ?'))return;const d=await api('/api/user/'+a,{username:u});toast(d.error||(a+' done: '+u));go('users')}
function unlock(u){openM(`<h2>Unlock ${esc(u)}</h2><label>Naye din</label><input id="ud" type="number" value="30"><p class="mut">Used GB reset ho jayega.</p><button class="btn" onclick="doUnlock('${esc(u)}')">Unlock</button>`)}
async function doUnlock(u){const d=await api('/api/user/unlock',{username:u,days:$('ud').value});closeM();toast(d.error||'Unlocked');go('users')}
function renew(u,q,i){const qs=qsplit(q);openM(`<h2>Renew / Edit ${esc(u)}</h2><div class="row"><div><label>Data Limit (0 = unlimited)</label><div style="display:grid;grid-template-columns:1fr 84px;gap:8px"><input id="rq" type="number" min="0" step="any" value="${qs[0]}"><select id="rq_u" style="margin-top:3px"><option value="gb" ${qs[1]==='gb'?'selected':''}>GB</option><option value="mb" ${qs[1]==='mb'?'selected':''}>MB</option></select></div></div><div><label>IP Limit</label><input id="ri" type="number" value="${i}"></div><div><label>Din (aaj se)</label><input id="rd" type="number" value="30"></div></div>
 <label><input type="checkbox" id="rr" checked style="width:auto;margin-right:6px">Used data 0 par reset karein</label><br><br><button class="btn" onclick="doRenew('${esc(u)}')">Save</button>`)}
async function doRenew(u){const d=await api('/api/user/renew',{username:u,quota:$('rq').value,unit:$('rq_u').value,ip_limit:$('ri').value,days:$('rd').value,reset:$('rr').checked});closeM();toast(d.error||'Account updated');go('users')}
async function info(u){const d=await api('/api/user/info?username='+encodeURIComponent(u));if(d.error)return toast(d.error);showAccount(d.info,false)}
/* ---------- animated account card ---------- */
function summary(i){return `━━━ ALIRAZA ━━━\nUsername : ${i.username}\nPassword : ${i.password}\nDomain   : ${i.domain}\nNS Domain: ${i.ns}\nExpiry   : ${i.expiry} (${i.days_left??'?'} days)\nData     : ${fq(i.quota_gb)}\nIP Limit : ${i.ip_limit}\nUUID     : ${i.uuid}\n\n`+i.ports.map(p=>p[0]+': '+p[1]).join('\n')+`\n\nSupport: https://t.me/ar_tricks`}
function summaryAll(i){return summary(i)+'\n\n'+String(i.config||'').split(String.fromCharCode(96).repeat(3)).join('')}
function cfgBlocks(c){const T=String.fromCharCode(96).repeat(3),re=new RegExp('━+\\n\\s*([^\\n]+)\\n━+\\n'+T+'\\n([\\s\\S]*?)\\n'+T,'g'),o=[];let m;while((m=re.exec(c||'')))o.push([m[1].trim(),m[2]]);return o}
function cfgHTML(c,id){const b=cfgBlocks(c);if(!b.length)return c?`<details open><summary>Full config</summary><pre>${esc(c)}</pre></details>`:'<div class="mut">Config file nahi mili.</div>';
 window['_b'+id]=b;return b.map((x,k)=>`<div class="cfb"><div class="cfh"><span>${esc(x[0])}</span><button class="btn s g" onclick="copy(window._b${id}[${k}][1])">Copy</button></div><pre>${esc(x[1])}</pre></div>`).join('')}
function accountHTML(i,anim,admin){const row=(k,v)=>`<div class="ai"><span class="k">${k}</span><span class="v">${v}</span></div>`;
 return `<h2 style="text-align:center;margin-bottom:14px">${anim?'✅ Account Created':'Account Details'}</h2>
 ${row('👤 Username',esc(i.username))}${row('🔑 Password',esc(i.password))}${row('🌐 Domain',esc(i.domain))}${row('📡 NS Domain',esc(i.ns))}${row('🧩 Protocols',esc(!i.protos||i.protos==='all'?'ALL':i.protos.toUpperCase().replace(/,/g,', ')))}
 ${row('📅 Expiry',esc(i.expiry)+' <span class="pill '+((i.days_left??0)>3?'on_':'warn_')+'">'+(i.days_left??'?')+' days</span>')}${row('💾 Data Limit',fq(i.quota_gb))}${row('📶 Used',fb(i.used))}${row('📱 IP Limit',esc(i.ip_limit))}${row('🔒 Status',pill(isAct(i.status),'Active',i.status==='EXPIRED'?'Expired':'Locked'))}${row('🆔 UUID','<small>'+esc(i.uuid)+'</small>')}
 <h3 style="margin-top:14px">Protocols &amp; Ports</h3><div class="chips">${i.ports.map(p=>`<span class="chip">${esc(p[0])}: <b>${esc(p[1])}</b></span>`).join('')}</div>
 <div class="acts" style="margin-top:14px"><button class="btn s" onclick='copy(summaryAll(window._acc))'>📋 Copy All</button>
 ${admin?`<button class="btn s g" onclick="genKey('${esc(i.username)}')">🔑 User Panel Key</button>`:''}<a class="btn s g" style="text-decoration:none" href="https://t.me/ar_tricks" target="_blank" rel="noopener">💬 Support</a></div><div id="keyslot"></div>
 ${i.key?keyHTML(i.username,i.key,i.user_url):''}<h3 style="margin-top:14px">Links &amp; Config (sirf selected protocols)</h3>${cfgHTML(i.config,'m')}${cfgBlocks(i.bunny_config).length?`<details><summary>Bunny CDN config</summary>${cfgHTML(i.bunny_config,'b')}</details>`:''}`}
function showAccount(i,created){window._acc=i;openM(accountHTML(i,created,true));if(created)confetti(140)}
function keyHTML(u,key,url){return `<div class="keybox"><div class="mut">User Panel Access Key (read-only panel)</div><code>${esc(key)}</code><div style="margin:6px 0" class="mut">Link: ${esc(url)}</div>
 <div class="acts" style="justify-content:center"><button class="btn s" onclick='copy("User Panel: ${esc(url)}\nKey: ${esc(key)}")'>Copy Link + Key</button><button class="btn s g" onclick="genKey('${esc(u)}',true)">Regenerate</button><button class="btn s r" onclick="revKey('${esc(u)}')">Revoke</button></div></div>`}
async function genKey(u,regen){const d=await api('/api/user/key',{username:u,regenerate:!!regen});if(d.error)return toast(d.error);$('keyslot').innerHTML=keyHTML(u,d.key,d.user_url);if(window._acc){window._acc.key=d.key;window._acc.user_url=d.user_url}}
async function revKey(u){if(!confirm('Key revoke karein? User panel band ho jayega.'))return;const d=await api('/api/user/key/revoke',{username:u});toast(d.error||'Key revoked');$('keyslot').innerHTML='';if(window._acc)window._acc.key=''}
/* ---------- other admin tabs ---------- */
function simHTML(x){const m=x.sim;if(!m)return x.info?`<div class="lx-inf">${esc(x.info)}</div>`:'';return `<div class="simb"><span class="sn" style="--sc:${esc(m.color||'#8892a6')}">${esc(m.flag||'')} ${esc(m.carrier)}</span><span class="sk">${esc(m.kind)}</span>${m.loc?`<span class="sl">${esc(m.loc)}</span>`:''}</div>`}
V.live=async()=>{let first=true;window._lvc={};
 const ONB='<span class="lvb"><span class="rd"></span>ONLINE<span class="sg"><i></i><i></i><i></i></span></span>',OFFB='<span class="lvb off"><span class="rd"></span>OFFLINE</span>';
 const render=async()=>{if(document.hidden||window._lvb)return;window._lvb=1;let d;try{d=await api('/api/live?seq='+(window._lvs||0))}finally{window._lvb=0}
  if(d&&d.seq)window._lvs=d.seq;
  if(d.error){const e=$('lvst');if(e)e.innerHTML='<span class="pill off_">⚠ connection lost - retrying...</span>';window._lvb=1;setTimeout(()=>{window._lvb=0},1500);return}
  const C=window._lvc,NOW=Date.now();
  d.users.forEach(u=>{const s=C[u.username];if(!s){C[u.username]={on:!!u.online,ls:NOW};return}
   if(u.online){s.ls=NOW;if(!s.on){s.on=true;toast('🟢 '+u.username+' online ho gaya')}}
   else{if(s.on&&NOW-s.ls>=2500){s.on=false;toast('🔴 '+u.username+' offline ho gaya')}}});
  const isOn=u=>!!(u.online||(C[u.username]&&C[u.username].on&&NOW-C[u.username].ls<2500));
  const ipCards=(d.ips||[]).map((x,k)=>{
   const rr=x.conns.map(c=>`<div class="lx-r"><span>${c.user==='-'?'<span class="mut">-</span>':'👤 <b>'+esc(c.user)+'</b>'}</span><span class="lx-p">${esc(c.proto)}${c.n>1?' ×'+c.n:''}</span></div>`).join('');
   return `<div class="lx-ip" style="animation-delay:${Math.min(k,12)*.04}s"><div class="lx-h"><span class="lvb"><span class="rd"></span>LIVE</span><span class="lx-n">${esc(x.ip)}</span><span class="lx-c">${x.conns.length}</span></div>${simHTML(x)}<div class="lx-body">${rr}</div></div>`}).join('');
  const uCards=d.users.map((u,k)=>{const on=isOn(u),q=+u.quota_gb||0,used=+u.used||0,pct=q?Math.min(100,Math.round(used*100/(q*2**30))):0,lim=+u.ip_limit||0,over=lim&&u.conns.length>lim;
   const chips=u.conns.map(c=>`<span class="chip" style="opacity:1;animation:none">${esc(c.ip)} <b>${esc(c.protos.join(', '))}${c.n>1?' ×'+c.n:''}</b></span>`).join('')||'<span class="mut">Koi connection nahi</span>';
   return `<div class="lx-u ${on?'on':''}" style="animation-delay:${Math.min(k,12)*.04}s"><div class="lx-t"><span class="lx-av">${esc((u.username||'?').charAt(0).toUpperCase())}</span><div class="lx-nm"><b>${esc(u.username)}</b><small>Expiry: ${esc(u.expiry)}</small></div>${on?ONB:OFFB}</div>
   ${u.status!=='UNLOCKED'?`<span class="pill warn_" style="margin-bottom:6px">${esc(u.status)}</span>`:''}
   <div class="lx-bar"><i style="width:${pct}%"></i></div><div class="lx-bl"><span>${fb(used)} / ${fq(q)}</span><span>${u.conns.length} / ${esc(u.ip_limit)} IPs${over?' <span class="pill warn_">limit se zyada</span>':''}</span></div><div class="chips">${chips}</div></div>`}).join('');
  show(`<div class="grid"><div class="card stat"><div class="k">Online Users</div><div class="v">${d.online} / ${d.total}</div></div><div class="card stat"><div class="k">Live IPs</div><div class="v">${d.ip_count}</div></div><div class="card stat"><div class="k">Live Sessions</div><div class="v">${d.sessions||0}</div></div><div class="card stat"><div class="k">Status</div><div class="v" id="lvst"><span class="pill on_">LIVE</span></div><div class="s">Updated ${new Date(d.ts*1000).toLocaleTimeString()}</div></div></div>
  <div class="card"><h2>🌐 Live IPs — kaun, kis protocol se</h2><p class="mut">Real-time auto-update (1 second se kam) - refresh ki zaroorat nahi.</p>${ipCards?`<div class="lx-grid">${ipCards}</div>`:'<div class="lx-empty">Abhi koi connected nahi.</div>'}</div>
  <div class="card"><h2>📡 Users</h2>${uCards?`<div class="lx-grid">${uCards}</div>`:'<div class="lx-empty">Koi account nahi.</div>'}</div>`,first);first=false};
 await render();poll=setInterval(render,40)};
V.svc=async()=>{let first=true;const render=async()=>{if(!first&&document.hidden)return;const d=await api('/api/services');if(d.error)return;
 show(`<div class="card"><h2>All protocols &amp; live status</h2><div class="tw"><table><tr><th>Service</th><th>Port</th><th>Status</th><th></th></tr>
 ${d.services.map(s=>`<tr><td>${esc(s.label)}</td><td>${s.port}/${s.proto}</td><td>${pill(s.live,'LIVE','DOWN')}</td><td><button class="btn s g" onclick="rsvc('${esc(s.service)}')">Restart</button></td></tr>`).join('')}</table></div></div>
 <div class="card"><div class="acts"><button class="btn" onclick="act('restart_all','Sab services restart karein?')">♻ Restart All</button><button class="btn g" onclick="act('autodoctor','Auto-Doctor chalayein?')">🩺 Auto-Doctor Fix</button></div></div>`,first);first=false};
 await render();poll=setInterval(render,8000)};
async function rsvc(n){const d=await api('/api/service/restart',{name:n});toast(d.error||('Restarted: '+n));setTimeout(()=>go('svc'),1500)}
V.domain=async()=>{const d=await api('/api/domain');if(d.error)return;
 show(`<div class="card"><h2>Domain &amp; SSL</h2><table><tr><td class="mut">Server IP</td><td>${esc(d.ip)}</td></tr><tr><td class="mut">Main Domain</td><td>${esc(d.domain||'Not-Set')} <span class="pill ${d.domain_status==='POINTED'?'on_':'warn_'}">${esc(d.domain_status)}</span></td></tr>
 <tr><td class="mut">SlowDNS NS</td><td>${esc(d.ns||'Not-Set')}</td></tr></table><pre style="margin-top:10px">${esc(d.cert||'No cert info')}</pre></div>
 <div class="card"><h3>Change domain (naya SSL + sab user files auto update)</h3><div class="row"><div><label>Main Domain</label><input id="dd" value="${esc(d.domain)}"></div><div><label>SlowDNS NS Domain</label><input id="dn" value="${esc(d.ns)}"></div></div>
 <div class="acts"><button class="btn" onclick="setDom()">Apply</button><button class="btn g" onclick="act('ssl','Current domain par SSL renew karein?')">Renew SSL</button></div>
 <p class="mut">Domain pehle is VPS IP par point hona chahiye warna self-signed SSL lagega.</p></div>`)};
async function setDom(){if(!confirm('Domain apply karein? Services kuch der restart hongi.'))return;const d=await api('/api/domain/set',{domain:$('dd').value,ns:$('dn').value});d.job?watch(d.job):toast(d.error)}
V.banner=async()=>{const d=await api('/api/banner');if(d.error)return;
 show(`<div class="card"><h2>SSH / Dropbear Banner (AliRaza-server)</h2><p class="mut">HTML tags (&lt;font&gt;, &lt;br&gt;) allowed hain. Save karne par OpenSSH aur Dropbear dono me apply hoga.</p><textarea id="bt" rows="14" style="font-family:monospace">${esc(d.banner)}</textarea>
 <div class="acts"><button class="btn" onclick="saveB()">Save &amp; Apply</button><button class="btn g" onclick="defB()">Restore Default</button></div></div>`)};
async function saveB(){const d=await api('/api/banner/set',{banner:$('bt').value});toast(d.error||'Banner applied')}
async function defB(){if(!confirm('Default banner restore karein?'))return;const d=await api('/api/banner/default',{});if(d.error)return toast(d.error);$('bt').value=d.banner;toast('Default banner applied')}
V.bunny=async()=>{const d=await api('/api/bunny');if(d.error)return;
 show(`<div class="card"><h2>Bunny CDN</h2><p class="mut">Origin VPS IP: ${esc(d.ip)} (port 80/443) · WebSockets ON, Forward Host Header ON</p><label>Pull Zone Hostname (e.g. name.b-cdn.net)</label><input id="bh" value="${esc(d.host)}">
 <div class="acts"><button class="btn" onclick="setB()">Set / Change</button><button class="btn g" onclick="act('bunny_regen')">Regenerate all user files</button></div></div>${d.guide?`<div class="card"><h3>Setup guide</h3><pre>${esc(d.guide)}</pre></div>`:''}`)};
async function setB(){const d=await api('/api/bunny/set',{host:$('bh').value});d.job?watch(d.job):toast(d.error)}
V.tg=async()=>{const d=await api('/api/telegram');if(d.error)return;
 show(`<div class="card"><h2>Telegram Bot</h2><p>Status: ${pill(d.active,'Running','Stopped')} ${d.configured?'· Owner UID: '+esc(d.admin):'· Not configured'}</p>
 <div class="row"><div><label>Bot Token (@BotFather)</label><input id="tt" placeholder="123456:ABC..."></div><div><label>Owner Telegram UID</label><input id="tu" placeholder="123456789"></div></div>
 <div class="acts"><button class="btn" onclick="setTG()">Connect Bot</button><button class="btn g" onclick="tgc('restart')">Restart</button><button class="btn g" onclick="tgc('stop')">Stop</button></div></div>`)};
async function setTG(){const d=await api('/api/telegram/set',{token:$('tt').value,uid:$('tu').value});toast(d.error||d.output);if(!d.error)go('tg')}
async function tgc(a){const d=await api('/api/telegram/ctl',{action:a});toast(d.error||('Bot '+a+' done'));setTimeout(()=>go('tg'),800)}
V.tools=()=>{show(`<div class="card"><h2>Tools</h2><div class="acts">
 <button class="btn g" onclick="act('autodoctor','Auto-Doctor chalayein?')">🩺 Auto-Doctor Fix</button><button class="btn g" onclick="act('restart_all','Restart all?')">♻ Restart All</button><button class="btn g" onclick="act('clean','Clean RAM/Logs?')">🧹 Clean RAM/Logs</button>
 <button class="btn g" onclick="act('speedtest')">🚀 VPS Speedtest</button><button class="btn g" onclick="act('udp_test','15 second UDP listen test shuru karein? Is dauran mobile se UDP app connect karein.')">📶 UDP Firewall Test</button></div></div>
 <div class="card"><h3>Fix UDP / SlowDNS (SlowDNS target)</h3><div class="acts"><button class="btn g" onclick="act('slowdns_1','SlowDNS -> SSH 22')">SSH 22</button><button class="btn g" onclick="act('slowdns_2','SlowDNS -> SSH 2222 (recommended)')">SSH 2222 (Recommended)</button><button class="btn g" onclick="act('slowdns_3','SlowDNS -> Xray VLESS 20010')">Xray 20010</button></div></div>
 <div class="card"><h3>Danger zone</h3><div class="acts"><button class="btn r" onclick="act('reinstall','Poora Re-Install chalayein? (users safe rehte hain)')">Re-Install All</button><button class="btn r" onclick="uninst()">Clean Uninstall</button></div></div>`)};
async function act(name,msg){if(msg&&!confirm(msg))return;let d;
 if(name==='ssl')d=await api('/api/ssl/renew',{});else if(name==='bunny_regen')d=await api('/api/bunny/regen',{});else d=await api('/api/action',{name});
 if(d.job)watch(d.job);else if(d.error)toast(d.error)}
async function uninst(){const c=prompt('Poora panel uninstall hoga. Confirm ke liye DELETE likhein:');if(c!=='DELETE')return;const d=await api('/api/action',{name:'uninstall',confirm:c});d.job?watch(d.job):toast(d.error)}
let wt=null;
function watch(id){openM(`<h2 id="jt">Running...</h2><pre id="jl">Starting...</pre>`);clearInterval(wt);
 const tick=async()=>{const d=await api('/api/job?id='+id);if(d.none||d.error)return;$('jt')&&($('jt').textContent=d.title+(d.running?' (running...)':d.exit===0?' ✔ Done':' ✘ Exit '+d.exit));
  const l=$('jl');if(l){l.textContent=d.log||'...';l.scrollTop=l.scrollHeight}if(!d.running){clearInterval(wt);if(d.exit===0)confetti(60)}};
 tick();wt=setInterval(tick,1500)}
V.themes=()=>{if(MODE==='user')return V.me();const cur_=ST.theme,fx=ST.fx,an=ST.an,c=ST.custom||{};
 const chips=(L,mode)=>L.map(a=>`<button class="btn s ${an===a[0]&&cur_==='custom'&&c.mode===mode?'':'g'}" onclick="customApply('${mode}','${a[0]}')">${a[1]}</button>`).join('');
 show(`${MODE==='user'?'<button class="btn s g" style="margin-bottom:10px" onclick="userGo(\'me\')">← Back</button>':''}<div class="card" style="border-color:#ff5a2866"><h2>🔥 AliRaza Flame UI</h2><p class="mut">Dark ember "Tunnel Command Center" look — naya login page + poora panel. Ek click se lagao, <b>sab users ko dikhega</b>. Pasand na aaye to purana UI wapas.</p><div class="acts"><button class="btn" onclick="alyanOn()">🔥 AliRaza Flame UI Lagao</button><button class="btn g" onclick="alyanOff()">↩ Purana UI (Fusion)</button></div></div>
 <div class="card"><h2>🎨 Themes</h2><p class="mut">Ready-made theme chunein — turant lag jati hai aur <b>sab users ke panel par wohi dikhti hai</b> (server par save hoti hai).</p><div class="themes">
 ${THEMES.map(t=>`<div class="th ${t.id===cur_?'on':''}" data-id="${t.id}" onclick="applyTheme('${t.id}')"><div class="sw" style="background:linear-gradient(135deg,${t.ac},${t.ac2})"></div><div class="nm">${t.n}</div></div>`).join('')}</div></div>
 <div class="card"><h3>🎯 Single Color + Animation</h3><p class="mut">Ek color chunein, phir animation tap karein.</p>
 <div style="display:flex;align-items:center;gap:10px;margin-bottom:10px"><label>Color</label><input id="c1single" type="color" value="${c.c1||'#4cc9ff'}" style="width:64px;height:40px;padding:2px;margin:0"></div><div class="acts">${chips(AN1,'single')}</div></div>
 <div class="card"><h3>🎭 Double Color + Animation</h3><p class="mut">Do colors chunein, phir animation tap karein.</p>
 <div style="display:flex;align-items:center;gap:10px;margin-bottom:10px"><label>Color 1</label><input id="c1double" type="color" value="${c.c1||'#4cc9ff'}" style="width:64px;height:40px;padding:2px;margin:0"><label>Color 2</label><input id="c2d" type="color" value="${c.c2||'#ff2d4a'}" style="width:64px;height:40px;padding:2px;margin:0"></div><div class="acts">${chips(AN2,'double')}</div></div>
 <div class="card"><h3>Animation Level</h3><div class="acts"><button class="btn s ${fx==='full'?'':'g'}" data-fx="full" onclick="applyFx('full')">✨ Full (animation on)</button><button class="btn s ${fx==='lite'?'':'g'}" data-fx="lite" onclick="applyFx('lite')">🌫 Lite (background off)</button><button class="btn s ${fx==='off'?'':'g'}" data-fx="off" onclick="applyFx('off')">⛔ Off (fastest)</button></div>
 <div class="acts" style="margin-top:10px"><button class="btn s g" onclick="setAn('none');toast('Background animation off')">Animation: None</button><button class="btn s g" onclick="applyTheme('fusion',false);setAn('fusion')">Default (Blue × Red Fusion)</button></div></div>`)};
V.set=async()=>{const d=await api('/api/users');if(d.error)return;const us=d.users||[];window._keys=Object.fromEntries(us.map(u=>[u.username,u.key||'']));
 const rows=us.map((u,k)=>{const e=esc(u.username),key=u.key||'';return `<div class="ai" style="animation-delay:${Math.min(k,14)*.05}s;flex-wrap:wrap;align-items:center"><span class="k"><b style="color:var(--tx)">${e}</b></span><span class="v" style="display:flex;gap:6px;flex-wrap:wrap;justify-content:flex-end;align-items:center">${key?`<code style="color:var(--ac2);letter-spacing:1px">${esc(key)}</code><button class="btn s g" onclick="skCopy('${e}')">Copy</button><button class="btn s g" onclick="skGen('${e}',1)">Regenerate</button><button class="btn s r" onclick="skRev('${e}')">Revoke</button>`:`<span class="mut">no key</span><button class="btn s" onclick="skGen('${e}',0)">🔑 Generate</button>`}</span></div>`}).join('')||'<div class="mut">Abhi koi account nahi. Pehle Users tab se account banayein.</div>';
 show(`<div class="card"><h2>🔑 User Panel Access Keys</h2><p class="mut">Yahan se kisi bhi account ka key banayein. Key se user apna <b>read-only</b> User Panel (<code>/u</code>) khol sakta hai — wo kuch change ya create nahi kar sakta.</p>
 <div class="row"><div><label>Account Username</label><input id="kuser" list="kul" placeholder="username likhein ya chunein" autocomplete="off"><datalist id="kul">${us.map(u=>`<option value="${esc(u.username)}">`).join('')}</datalist></div></div>
 <div class="acts" style="margin-bottom:12px"><button class="btn" onclick="skAdd()">🔑 Generate Key</button><button class="btn g" onclick="skAll()">⚡ Sab accounts ke keys banayein</button></div>${rows}</div>
 <div class="card"><h2>Panel Login Settings</h2><div class="row"><div><label>Current Password</label><input id="cp" type="password"></div><div><label>New Username (optional)</label><input id="cu"></div><div><label>New Password (min 6)</label><input id="cn" type="password"></div></div>
 <button class="btn" onclick="chPw()">Update</button></div><div id="vcard"></div><div class="card"><h3>Support</h3><a href="https://t.me/ar_tricks" target="_blank" rel="noopener">💬 t.me/ar_tricks</a></div>`);vcLoad()};
function skCopy(u){const k=(window._keys||{})[u]||'';copy('User Panel: '+location.origin+'/u#'+k+'\nKey: '+k)}
async function skGen(u,r,pop){const d=await api('/api/user/key',{username:u,regenerate:!!r});if(d.error)return toast(d.error);(window._keys=window._keys||{})[u]=d.key;toast(r?'Naya key ban gaya':'Key ready ✔');go('set');
 if(pop)setTimeout(()=>openM(`<h2>🔑 ${esc(u)} — User Panel Key</h2><div class="keybox"><div class="mut">Access Key (read-only panel)</div><code>${esc(d.key)}</code><div class="mut" style="margin:6px 0;word-break:break-all">${esc(location.origin+'/u#'+d.key)}</div><div class="acts" style="justify-content:center"><button class="btn s" onclick="skCopy('${esc(u)}')">Copy Link + Key</button></div></div>`),350)}
function skAdd(){const u=($('kuser').value||'').trim();if(!u)return toast('Username likhein');skGen(u,0,true)}
async function skRev(u){if(!confirm('Key revoke karein? User panel band ho jayega.'))return;const d=await api('/api/user/key/revoke',{username:u});toast(d.error||'Key revoked');go('set')}
async function skAll(){const d=await api('/api/user/key/all',{});toast(d.error||((d.created||0)+' naye keys bane'));go('set')}
async function chPw(){const d=await api('/api/password',{current:$('cp').value,new_username:$('cu').value,new:$('cn').value});toast(d.error||d.output);if(d.ok)setTimeout(showLogin,1200)}
/* ---------- VIEW-ONLY PANEL (admin ke banaye login: sirf dekh sakte hain) ---------- */
const VTABS=[['vdash','📊 Dashboard'],['vusers','👥 Users'],['vlive','📡 Live IPs']];
function lrTabs(){return '<div class="acts" style="margin-bottom:12px"><button class="btn s '+(LROLE==='admin'?'':'g')+'" onclick="setLR(\'admin\')">🛡 Admin</button><button class="btn s '+(LROLE==='viewer'?'':'g')+'" onclick="setLR(\'viewer\')">👁 User (view only)</button></div>'}
function setLR(r){LROLE=r;setupLogin()}
function viewerBoot(){VW=true;LROLE='viewer';$('nav').innerHTML='';$('thbtn').classList.add('hide');$('logo').textContent='★ ALIRAZA VIEW-ONLY';go('vdash')}
async function vget(){const d=await api('/api/v/data');if(!d.error){window._vc=d.contact;window._vleft=d.left;window._vd=d}return d}
const vbar=()=>{const l=window._vleft,c=window._vc||'https://t.me/ar_tricks';return `<div class="card" style="border-color:var(--ac2)"><b>🔒 View-only mode</b> · Aap sirf dekh sakte hain — VPS details, passwords aur settings hidden hain. Full panel ke liye admin se key len: <a href="${esc(c)}" target="_blank" rel="noopener">${esc(c.replace(/^https?:\/\//,''))}</a>${l==null?'':`<div class="mut" style="margin-top:4px">⏳ Aapki key: ${l<=0?'expired':Math.ceil(l/86400)+' din baqi'}</div>`}</div>`};
V.vdash=async()=>{let first=true;const render=async()=>{if(!first&&document.hidden)return;const d=await vget();if(d.error)return;
 const st=(k,v,x='')=>`<div class="card stat"><div class="k">${k}</div><div class="v">${v}</div>${x}</div>`;
 show(`${vbar()}<div class="grid">${st('Accounts',d.total)}${st('Online Now',d.online+' / '+d.total,'<div class="s">'+d.sessions+' sessions</div>')}${st('Live IPs',d.ip_count)}${st('Locked / Expired',d.locked)}${st('Total Data Used',fb(d.used_bytes))}</div>`,first);first=false};
 await render();poll=setInterval(render,8000)};
V.vusers=async()=>{const d=await vget();if(d.error)return;
 show(`${vbar()}<div class="card"><h2>Accounts <span class="mut" id="vcnt"></span></h2><div class="row"><div><input id="vq" placeholder="Search username / IP" oninput="vuPaint()" autocomplete="off"></div></div><div id="vl"></div></div>`);vuPaint();
 poll=setInterval(async()=>{if(document.hidden)return;const x=await vget();if(!x.error)vuPaint()},8000)};
function vuPaint(){const d=window._vd;if(!d||!$('vl'))return;const q=(($('vq')||{}).value||'').trim().toLowerCase();
 const L=d.users.filter(u=>!q||u.username.toLowerCase().includes(q)||u.conns.some(c=>c.ip.includes(q)));$('vcnt').textContent='('+L.length+')';
 $('vl').innerHTML=L.map(u=>`<div class="ai" style="opacity:1;transform:none;animation:none;flex-wrap:wrap"><span class="k"><b style="color:var(--tx)">${esc(u.username)}</b> ${pill(u.online,'ONLINE','OFFLINE')}</span><span class="v">${esc(u.status)} · exp ${esc(u.expiry)} · ${fb(u.used)}${+u.quota_gb?' / '+fq(u.quota_gb):''} · ${u.sessions} sess${u.conns.length?'<div class="mut">'+u.conns.map(c=>esc(c.ip)).join(', ')+'</div>':''}</span></div>`).join('')||'<div class="mut">Koi account nahi.</div>'}
V.vlive=async()=>{const d=await vget();if(d.error)return;show(`${vbar()}<div class="card"><h2>Live IPs <span class="mut" id="vlc"></span></h2><div id="vlv"></div></div>`);vlPaint();
 poll=setInterval(async()=>{if(document.hidden)return;const x=await vget();if(!x.error)vlPaint()},5000)};
function vlPaint(){const d=window._vd;if(!d||!$('vlv'))return;const on=d.users.filter(u=>u.online);$('vlc').textContent='('+d.ip_count+' IPs · '+on.length+' users)';
 $('vlv').innerHTML=on.map(u=>u.conns.map(c=>`<div class="ai" style="opacity:1;transform:none;animation:none"><span class="k"><b style="color:var(--tx)">${esc(u.username)}</b></span><span class="v">${esc(c.ip)} · ${esc((c.protos||[]).join(', '))}${c.n>1?' ×'+c.n:''}</span></div>`).join('')).join('')||'<div class="mut">Abhi koi online nahi.</div>'}
/* ---- admin: view-only logins banana / manage karna (Settings tab) ---- */
async function vcLoad(){const d=await api('/api/viewers');const el=$('vcard');if(!el||d.error)return;
 const fl=v=>v.left==null?'No expiry':v.expired?'Expired':Math.ceil(v.left/86400)+' din baqi';
 el.innerHTML=`<div class="card"><h2>👁 View-only Logins (User Panel)</h2><p class="mut">Yahan se view-only login banayein. User login page par <b>User (view only)</b> tab se login karta hai — sirf dekh sakta hai, VPS info / passwords / settings hidden. Validity khatam hote hi login khud band ho jata hai.</p>
 <div class="row"><div><label>Username</label><input id="vcu" autocomplete="off" placeholder="3-32 chars"></div><div><label>Password (blank = random)</label><input id="vcp" autocomplete="off"></div><div><label>Days (0 = no expiry)</label><input id="vcd" type="number" value="30"></div></div>
 <div class="acts" style="margin-bottom:12px"><button class="btn" onclick="vcAct('create')">＋ Create View-only Login</button></div>
 ${(d.viewers||[]).map(v=>`<div class="ai" style="opacity:1;transform:none;animation:none;flex-wrap:wrap;align-items:center"><span class="k"><b style="color:var(--tx)">${esc(v.username)}</b> <span class="pill ${v.expired?'off_':'on_'}">${fl(v)}</span></span><span class="v" style="display:flex;gap:6px;flex-wrap:wrap;justify-content:flex-end"><button class="btn s g" onclick="vcAct('extend','${esc(v.username)}')">+ Days</button><button class="btn s g" onclick="vcAct('noexpiry','${esc(v.username)}')">No expiry</button><button class="btn s g" onclick="vcAct('password','${esc(v.username)}')">New Password</button><button class="btn s r" onclick="vcAct('delete','${esc(v.username)}')">Delete</button></span></div>`).join('')||'<div class="mut">Abhi koi view-only login nahi.</div>'}</div>`}
async function vcAct(act,u){const b={act,username:u||(($('vcu')||{}).value||'').trim()};
 if(act==='create'){b.password=$('vcp').value;b.days=$('vcd').value}
 else if(act==='extend'){const x=prompt('Kitne din add karein?','30');if(!x)return;b.days=x}
 else if(act==='password'){const x=prompt('Naya password (blank = random):','');if(x===null)return;b.password=x}
 else if(act==='delete'){if(!confirm(u+' delete karein?'))return}
 const d=await api('/api/viewers/act',b);if(d.error)return toast(d.error);
 if(d.password){window._vcc={u:d.username,p:d.password};openM(`<h2>👁 View-only Login</h2><div class="keybox"><div class="mut">Username</div><code>${esc(d.username)}</code><div class="mut" style="margin-top:6px">Password</div><code>${esc(d.password)}</code><div class="mut" style="margin:6px 0;word-break:break-all">${esc(location.origin)} → <b>User (view only)</b> tab</div><div class="acts" style="justify-content:center"><button class="btn s" onclick="vcCopy()">Copy</button></div></div>`)}
 else toast('Done ✔');vcLoad()}
function vcCopy(){const c=window._vcc||{};copy('Panel: '+location.origin+'\nTab: User (view only)\nUsername: '+c.u+'\nPassword: '+c.p)}
/* ---------- user panel (read-only) ---------- */
V.me=async()=>{$('nav').classList.add('hide');$('burger').classList.add('hide');$('logo').textContent='★ ALIRAZA USER PANEL';let first=true;window._sig='';
 const render=async()=>{if(!first&&document.hidden)return;const i=await api('/api/u/me');if(i.error||!i.username)return;
  const sig=JSON.stringify(i);if(sig===window._sig)return;window._sig=sig;window._acc=i;
  const opened=[...document.querySelectorAll('#main details')].map(x=>x.open);
  const dl=(i.days_left===null||i.days_left===undefined)?null:+i.days_left,q=+i.quota_gb||0,used=+i.used||0,ipl=+i.ip_limit||0,live=+i.live||0;
  const pct=q?Math.min(100,Math.round(used*100/(q*2**30))):0,dpct=dl===null?0:Math.max(0,Math.min(100,Math.round(dl*100/Math.max(1,+i.total_days||30))));
  const act=isAct(i.status),stx=i.status==='EXPIRED'?'EXPIRED':'LOCKED';
  const prot=!i.protos||i.protos==='all'?'ALL':String(i.protos).toUpperCase().replace(/,/g,', ');
  const rows=[['👤 Username',i.username],['🔑 Password',i.password],['🌐 Domain',i.domain],['📡 NS Domain',i.ns],['🧩 Protocols',prot],['📅 Expiry',(i.expiry||'-')+(dl===null?'':dl<0?' (expired)':' ('+dl+' days left)')],['💾 Data Limit',fq(q)],['📶 Used',fb(used)],['📱 IP Limit',ipl||'-'],['🆔 UUID',i.uuid]];
  const ports=Array.isArray(i.ports)?i.ports:[];
  show(`<div class="card" style="text-align:center"><div class="mut">Welcome</div><h2 style="font-size:26px;margin:4px 0">${esc(i.username)}</h2>${pill(act,'ACTIVE',stx)}
  <p class="mut" style="margin:8px 0 0">🔒 Ye panel sirf dekhne ke liye hai — yahan se kuch change ya create nahi hota · Support: <a href="https://t.me/ar_tricks" target="_blank" rel="noopener">t.me/ar_tricks</a></p></div>
  ${act?'':`<div class="card" style="border-color:var(--bad)"><b>⚠ Account ${stx}</b><div class="mut">Renew / unlock ke liye support se rabta karein: <a href="https://t.me/ar_tricks" target="_blank" rel="noopener">t.me/ar_tricks</a></div></div>`}
  <div class="hero"><div class="card" style="text-align:center"><h3>Data Usage</h3>${ring(q?pct:0,q?pct+'%':'∞',fb(used))}<div class="mut" style="margin-top:6px">${q?'of '+fq(q):'Unlimited plan'}</div></div>
  <div class="card" style="text-align:center"><h3>Days Left</h3>${ring(dpct,dl===null?'?':'<span data-count="'+Math.max(dl,0)+'" data-f="dec">0</span>','days')}<div class="mut" style="margin-top:6px">Expiry: ${esc(i.expiry||'-')}</div></div>
  <div class="card" style="text-align:center"><h3>Connections</h3>${ring(ipl?Math.min(100,live*100/ipl):0,live+' / '+(ipl||'-'),'devices live')}<div class="mut" style="margin-top:6px">Live / IP limit</div></div></div>
  <div class="card"><h3>Account Details</h3>${rows.map((r,k)=>`<div class="ai" style="${first?'animation-delay:'+(.1+k*.06)+'s':'opacity:1;transform:none;animation:none'}"><span class="k">${r[0]}</span><span class="v">${esc(r[1])}</span></div>`).join('')}</div>
  <div class="card"><h3>Protocols &amp; Ports</h3><div class="chips">${ports.map((p,k)=>`<span class="chip" style="${first?'animation-delay:'+k*.05+'s':'opacity:1;animation:none'}">${esc(p[0])}: <b>${esc(p[1])}</b></span>`).join('')||'<span class="mut">-</span>'}</div></div>
  <div class="card"><h3>Config</h3><div class="acts" style="margin-bottom:8px"><button class="btn s" onclick="copy(summary(window._acc))">📋 Copy All</button><button class="btn s g" onclick="copy(window._acc.config||'')">Copy Config</button></div>
  <details><summary>Config dekhein</summary><pre>${esc(i.config||'Config file abhi maujood nahi.')}</pre></details>${i.bunny_config?`<details><summary>Bunny CDN config</summary><pre>${esc(i.bunny_config)}</pre></details>`:''}</div>`,first);
  document.querySelectorAll('#main details').forEach((x,k)=>{if(opened[k])x.open=true});
  runCounts($('main'),!first);fillRings($('main'));first=false};
 await render();poll=setInterval(render,15000)};
/* ---------- init ---------- */
applySrv({theme:'fusion',an:'fusion',fx:matchMedia('(prefers-reduced-motion:reduce)').matches?'lite':'full'});
if(MODE==='user'){const b=$('thbtn');if(b)b.classList.add('hide')}
(async()=>{await syncTheme(true);setInterval(()=>{if(!document.hidden)syncTheme(false)},15000);const d=await api(MODE==='user'?'/api/u/me':'/api/dashboard').catch(()=>null);
 if(d&&!d.error){$('login').classList.add('hide');$('app').classList.remove('hide');MODE==='user'?V.me():go('dash')}
 else if(MODE!=='user'){const v=await api('/api/v/me').catch(()=>null);if(v&&v.username){$('login').classList.add('hide');$('app').classList.remove('hide');viewerBoot()}else showLogin()}
 else showLogin()})();
</script></body></html>
'''
if __name__ == "__main__": main()

PANEL_PY_EOF
    chmod 700 "$PANEL_BIN"
    if [[ "$SELF_PATH" != "$CORE_PATH" && -f "$SELF_PATH" ]]; then
        cp -f "$SELF_PATH" "$CORE_PATH" 2>/dev/null && chmod 700 "$CORE_PATH" || true
    fi
    [[ ! -s "$CORE_PATH" ]] && echo -e "${RED}[!] Core script copy nahi ho saki ($CORE_PATH). Script ko file ke tor par chalayein (bash install.sh).${NC}"
    printf '#!/bin/bash\nexec bash %s "$@"\n' "$CORE_PATH" > /usr/bin/menu; chmod +x /usr/bin/menu
    cat << UNIT_EOF > /etc/systemd/system/aliraza-panel.service
[Unit]
Description=AliRaza Web Panel
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 ${PANEL_BIN}
Restart=always
RestartSec=3s
KillMode=process
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
UNIT_EOF
    local PP; PP=$(panel_conf_get PANEL_PORT)
    command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active" && ufw allow "${PP}/tcp" >/dev/null 2>&1 || true
    iptables -C INPUT -p tcp --dport "$PP" -j ACCEPT >/dev/null 2>&1 || iptables -I INPUT -p tcp --dport "$PP" -j ACCEPT >/dev/null 2>&1 || true
    if command -v ip6tables >/dev/null 2>&1; then
        ip6tables -C INPUT -p tcp --dport "$PP" -j ACCEPT >/dev/null 2>&1 || ip6tables -I INPUT -p tcp --dport "$PP" -j ACCEPT >/dev/null 2>&1 || true
    fi
    systemctl daemon-reload
    systemctl enable aliraza-panel >/dev/null 2>&1 || true
    systemctl restart aliraza-panel >/dev/null 2>&1 || true
    sleep 2
    systemctl is-active --quiet aliraza-panel && return 0
    echo -e "${RED}[!] Panel start nahi hua. Check: journalctl -u aliraza-panel -n 30${NC}"; return 1
}

show_panel_info() {
    local PU PP TLS DOM IP SCH
    PU=$(panel_conf_get PANEL_USER); PP=$(panel_conf_get PANEL_PORT); TLS=$(panel_conf_get PANEL_TLS)
    DOM=$(head -n1 "$DATA_DIR/domain.txt" 2>/dev/null | tr -d '[:space:]'); IP=$(get_vps_ip)
    SCH="http"; [[ "$TLS" != "0" && -s /etc/ssl/xray/fullchain.pem ]] && SCH="https"
    aliraza_banner 0
    echo -e "${PURPLE}╭──────────────────────────────────────────────────────╮${NC}"
    echo -e "${PURPLE}├──────────────────────────────────────────────────────┤${NC}"
    [[ -n "$DOM" ]] && echo -e "${PURPLE}│${NC} ${WHITE}Panel URL (NO PORT):${NC} ${GREEN}https://${DOM}${NC}"
    echo -e "${PURPLE}│${NC} ${WHITE}Panel URL (port)  :${NC} ${GREEN}${SCH}://${DOM:-$IP}:${PP}${NC} ${GRAY}(backup)${NC}"
    echo -e "${PURPLE}│${NC} ${WHITE}Panel URL (IP)    :${NC} ${CYAN}${SCH}://${IP}:${PP}${NC}"
    echo -e "${PURPLE}│${NC} ${WHITE}Username          :${NC} ${YELLOW}${PU}${NC}"
    [[ -n "${PANEL_PASS_IN:-}" ]] && echo -e "${PURPLE}│${NC} ${WHITE}Password          :${NC} ${YELLOW}${PANEL_PASS_IN}${NC}"
    echo -e "${PURPLE}├──────────────────────────────────────────────────────┤${NC}"
    echo -e "${PURPLE}│${NC} ${WHITE}User Panel        :${NC} ${CYAN}${SCH}://${DOM:-$IP}:${PP}/u${NC} ${GRAY}(key admin panel se banti hai)${NC}"
    echo -e "${PURPLE}│${NC} ${WHITE}Support           :${NC} ${CYAN}https://t.me/ar_tricks${NC}"
    echo -e "${PURPLE}│${NC} Cloud firewall me TCP port ${PP} OPEN karna na bhulen."
    echo -e "${PURPLE}│${NC} Terminal commands: ${CYAN}menu passwd${NC} | ${CYAN}menu port${NC} | ${CYAN}menu restart${NC} | ${CYAN}menu check${NC}"
    echo -e "${PURPLE}╰──────────────────────────────────────────────────────╯${NC}"
    echo ""
}

panel_diagnose() {
    local DOM IP PP DIP D6 ISS CODE
    DOM=$(head -n1 "$DATA_DIR/domain.txt" 2>/dev/null | tr -d '[:space:]'); IP=$(get_vps_ip); PP=$(panel_conf_get PANEL_PORT)
    echo -e "\n${PURPLE}━━━━━━━━━━━━━━  PANEL DOMAIN CHECK  ━━━━━━━━━━━━━━${NC}"
    [[ -z "$DOM" ]] && { echo -e " ${YELLOW}[!] Domain set nahi hai${NC}"; return 0; }
    DIP=$(resolve_domain_ip "$DOM")
    local CF_RE='^(104\.(1[6-9]|2[0-9]|3[01])\.|172\.(6[4-9]|7[01])\.|188\.114\.(9[6-9])\.|162\.15[89]\.|108\.162\.|141\.101\.|103\.(21|22|31)\.|173\.245\.|190\.93\.|197\.234\.|198\.41\.|131\.0\.)'
    if [[ -z "$DIP" ]]; then
        echo -e " ${RED}[X]${NC} Domain ${DOM} resolve nahi ho raha - DNS me A record banayein: ${GREEN}${IP}${NC}"
    elif [[ "$DIP" == "$IP" ]]; then
        echo -e " ${GREEN}[OK]${NC} DNS: ${DOM} -> ${IP}"
    elif [[ "$DIP" =~ $CF_RE ]]; then
        echo -e " ${GREEN}[OK]${NC} ${DOM} Cloudflare proxy (orange cloud) par hai (${DIP}) - bina port wala link ${GREEN}https://${DOM}${NC} chalega."
        echo -e "     ${GRAY}Note: port wala link (:${PP}) Cloudflare se nahi guzarta, sirf no-port link use karein. Cloudflare SSL mode = Full (Strict nahi) rakhein.${NC}"
    else
        echo -e " ${RED}[X]${NC} ${DOM} -> ${DIP}, lekin VPS IP ${IP} hai. DNS A record ko ${GREEN}${IP}${NC} par point karein."
    fi
    local NSD NSH NSIP; NSD=$(head -n1 "$DATA_DIR/ns_domain.txt" 2>/dev/null | tr -d '[:space:]')
    [[ -n "$NSD" && "$NSD" == "$DOM" ]] && echo -e " ${RED}[X]${NC} NS Domain aur Main Domain ek hi hain ($DOM). SlowDNS NS domain alag subdomain hona chahiye (e.g. ns.$DOM)."
    for NSH in $(dig +short +time=3 +tries=1 NS "$DOM" @8.8.8.8 2>/dev/null | sed 's/\.$//'); do
        NSIP=$(resolve_domain_ip "$NSH")
        if [[ "$NSH" == "$NSD" || ( -n "$NSIP" && "$NSIP" == "$IP" ) ]]; then
            echo -e " ${RED}[X]${NC} Main domain ${DOM} ka NS record aapke VPS (${NSH}) ko delegate hua hai - isliye domain resolve nahi hota."
            echo -e "     Fix: NS record sirf SlowDNS wale subdomain (${NSD:-ns.$DOM}) par lagayein, main domain par nahi. Main domain par sirf A record ${GREEN}${IP}${NC} rakhein."
        fi
    done
    D6=""; for _r in 8.8.8.8 1.1.1.1 9.9.9.9; do D6=$(dig +short +time=3 +tries=1 AAAA "$DOM" @"$_r" 2>/dev/null | grep -E '^[0-9a-fA-F:]+$' | grep ':' | head -n1); dig +short +time=3 +tries=1 AAAA "$DOM" @"$_r" >/dev/null 2>&1 && break; done
    if [[ -n "$D6" ]] && ! [[ "$D6" =~ ^(2606:4700|2803:f800|2405:b500|2405:8100|2a06:98c|2c0f:f248) ]]; then
        echo -e " ${YELLOW}[!]${NC} Domain par AAAA (IPv6) record ${D6} hai. Ye script sirf IPv4 par chalti hai - Cloudflare DNS me AAAA record DELETE kar dein."
    fi
    if _dropbear_ok; then
        echo -e " ${GREEN}[OK]${NC} Dropbear SSH chal raha hai (port 80, OpenSSH removed)"
    else
        echo -e " ${RED}[X]${NC} Dropbear port 80 DOWN - auto-repair chal raha hai..."
        fix_dropbear_core >/dev/null 2>&1 || true
    fi
    CODE=$(curl -sk --max-time 6 --resolve "${DOM}:${PP}:127.0.0.1" -o /dev/null -w '%{http_code}' "https://${DOM}:${PP}/" 2>/dev/null)
    if [[ "$CODE" =~ ^(200|301|302|401|403)$ ]]; then echo -e " ${GREEN}[OK]${NC} Panel VPS ke andar HTTPS par chal raha hai (port ${PP})"
    else echo -e " ${RED}[X]${NC} Panel local test fail (code ${CODE:-000}) -> chalayein: ${CYAN}journalctl -u aliraza-panel -n 30${NC}"; fi
    CODE=$(curl -sk --max-time 6 --resolve "${DOM}:443:127.0.0.1" -H 'Accept: text/html' -o /dev/null -w '%{http_code}' "https://${DOM}/" 2>/dev/null)
    if [[ "$CODE" == "200" ]]; then echo -e " ${GREEN}[OK]${NC} Panel bina port ke chal raha hai: https://${DOM}"
    else echo -e " ${YELLOW}[!]${NC} https://${DOM} (no port) test fail (code ${CODE:-000}) - ${CYAN}menu update${NC} chalayein"; fi
    ISS=$(openssl x509 -in /etc/ssl/xray/fullchain.pem -noout -issuer 2>/dev/null)
    if echo "$ISS" | grep -qiE "Let's Encrypt|ISRG"; then echo -e " ${GREEN}[OK]${NC} SSL: Let's Encrypt (real)"
    else echo -e " ${YELLOW}[!]${NC} SSL self-signed hai - browser warning par 'Advanced -> Proceed' karein, ya domain point kar ke Panel -> Domain & SSL -> Renew SSL."; fi
    echo -e " ${GRAY}Link: https://${DOM}:${PP}  (http:// likhne par bhi auto https par chala jata hai)${NC}"
    echo -e " ${GRAY}Cloud firewall me TCP ${PP} OPEN hona zaroori hai. Dobara check: menu check${NC}\n"
}

panel_reset_credentials() {
    local PP; PP=$(panel_conf_get PANEL_PORT); PP="${PP:-2026}"
    local IN_USER IN_P1
    while true; do read -rp " • Naya Panel Username [$(panel_conf_get PANEL_USER)]: " IN_USER || return 1
        IN_USER="${IN_USER:-$(panel_conf_get PANEL_USER)}"; [[ "$IN_USER" =~ ^[a-zA-Z0-9_-]{3,32}$ ]] && break; echo "   Username galat hai"; done
    while true; do read -rp " • Naya Password (min 6): " IN_P1 || return 1
        [[ ${#IN_P1} -lt 6 ]] && { echo "   Kam az kam 6 characters"; continue; }
        break; done
    panel_save_conf "$IN_USER" "$PP" "$IN_P1"; PANEL_PASS_IN="$IN_P1"
    systemctl restart aliraza-panel >/dev/null 2>&1 || true
    echo -e "${GREEN}[✔] Panel credentials update ho gaye.${NC}"; show_panel_info
}

panel_change_port() {
    local NP MSG PU
    while true; do read -rp " • Naya Panel Port: " NP || return 1; MSG=$(panel_port_ok "$NP") && break; echo -e "   ${RED}[!] ${MSG}${NC}"; done
    sed -i "s/^PANEL_PORT=.*/PANEL_PORT=${NP}/" "$PANEL_CONF"
    command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active" && ufw allow "${NP}/tcp" >/dev/null 2>&1 || true
    iptables -C INPUT -p tcp --dport "$NP" -j ACCEPT >/dev/null 2>&1 || iptables -I INPUT -p tcp --dport "$NP" -j ACCEPT >/dev/null 2>&1 || true
    systemctl restart aliraza-panel >/dev/null 2>&1 || true
    echo -e "${GREEN}[✔] Panel port ${NP} par chal raha hai.${NC}"; show_panel_info
}

# ---------------- functions called by the web panel (no prompts) ----------------
panel_renew_user() { # user gb ip days reset(1/0)
    local R_USER="$1" NEW_GB="$2" NEW_IP="$3" NEW_DAYS="$4" RST_GB="${5:-1}"
    [[ "$R_USER" =~ ^[a-zA-Z0-9_-]+$ && "$NEW_GB" =~ ^[0-9]+(\.[0-9]+)?$ && "$NEW_IP" =~ ^[0-9]+$ && "$NEW_DAYS" =~ ^[0-9]+$ ]] || { echo "Invalid input"; return 1; }
    is_protected_system_user "$R_USER" && { echo "[!] Protected system user"; return 1; }
    local LINE; LINE=$(grep "^${R_USER}|" "$USERS_DB" 2>/dev/null | head -n1 || true)
    [[ -z "$LINE" ]] && { echo "[!] User nahi mila"; return 1; }
    local UPASS UUID NEW_EXP RPROTOS
    UPASS=$(echo "$LINE" | cut -d'|' -f2); UUID=$(echo "$LINE" | cut -d'|' -f3)
    RPROTOS=$(echo "$LINE" | cut -d'|' -f8); RPROTOS="${RPROTOS:-all}"
    NEW_EXP=$(date -d "+${NEW_DAYS} days" +"%Y-%m-%d")
    [[ "$RST_GB" == "1" ]] && echo "0" > "$USAGE_DIR/${R_USER}.bytes"
    usermod -s /bin/bash -p "$(openssl passwd -6 "$UPASS")" "$R_USER" >/dev/null 2>&1 || true
    chage -E "$(date -d "$NEW_EXP + 1 day" +"%Y-%m-%d" 2>/dev/null || echo "$NEW_EXP")" "$R_USER" >/dev/null 2>&1 || true
    passwd -u "$R_USER" >/dev/null 2>&1 || true
    [[ "$RPROTOS" == "all" || ",$RPROTOS," == *",ssh,"* || ",$RPROTOS," == *",slowdns,"* ]] || { passwd -l "$R_USER" >/dev/null 2>&1 || true; usermod -s /usr/sbin/nologin "$R_USER" >/dev/null 2>&1 || true; }
    sed -i "s/^${R_USER}|.*/${R_USER}|${UPASS}|${UUID}|${NEW_GB}|${NEW_IP}|${NEW_EXP}|UNLOCKED|${RPROTOS}/" "$USERS_DB"
    sync_all_users_to_engines
    /usr/local/bin/aliraza-cli regen "$R_USER" "$UPASS" "$NEW_GB" "$NEW_IP" >/dev/null 2>&1 || true
    echo "[✔] Account updated (Expiry: ${NEW_EXP})"
}

panel_apply_domain() { # domain ns
    local IN_D="$1" IN_N="$2" CUR_D CUR_N CHG_DOM=0 CHG_NS=0
    CUR_D=$(head -n1 "$DATA_DIR/domain.txt" 2>/dev/null | tr -d '[:space:]'); CUR_N=$(head -n1 "$DATA_DIR/ns_domain.txt" 2>/dev/null | tr -d '[:space:]')
    [[ -n "$IN_D" && "$IN_D" != "$CUR_D" ]] && CHG_DOM=1
    [[ -n "$IN_N" && "$IN_N" != "$CUR_N" ]] && CHG_NS=1
    if [[ "$CHG_DOM" == "0" && "$CHG_NS" == "0" ]]; then
        echo "[*] Domain/NS same hain - sirf SSL renew ho raha hai..."
        [[ -n "$CUR_D" ]] && issue_ssl_cert "$CUR_D"; return 0
    fi
    [[ "$CHG_DOM" == "1" ]] && echo "$IN_D" > "$DATA_DIR/domain.txt"
    [[ "$CHG_NS" == "1" ]] && echo "$IN_N" > "$DATA_DIR/ns_domain.txt"
    rm -f /run/aliraza_dom_* /run/aliraza_ns_* 2>/dev/null || true
    if [[ "$CHG_DOM" == "1" ]]; then issue_ssl_cert "$IN_D"; configure_nginx_mux; install_ws_ssh_engine; fi
    [[ "$CHG_NS" == "1" ]] && configure_slowdns_service 0
    sync_all_users_to_engines; regenerate_all_user_files
    systemctl restart haproxy 2>/dev/null || true
    echo "[OK] Apply ho gaya! Sab users ki config files naye domain/NS se update ho gayin."
}

panel_renew_ssl() {
    local CUR_D; CUR_D=$(head -n1 "$DATA_DIR/domain.txt" 2>/dev/null | tr -d '[:space:]')
    [[ -z "$CUR_D" ]] && { echo "[!] Pehle domain set karein"; return 1; }
    issue_ssl_cert "$CUR_D"
}

panel_apply_banner() { fix_ssh_auth_and_banner; fix_dropbear_core; echo "[✔] Banner applied (SSH + Dropbear)"; }
panel_default_banner() { write_aliraza_vip_banner; fix_ssh_auth_and_banner; fix_dropbear_core; echo "[✔] Default AliRaza-server banner applied"; }

panel_set_bunny() {
    local NEW_BH="$1" MY_IP; MY_IP=$(get_vps_ip)
    [[ -z "$NEW_BH" ]] && return 1
    echo "$NEW_BH" > "$DATA_DIR/bunny_host.txt"; rm -f /run/aliraza_dom_* 2>/dev/null || true
    {
        echo "============================================================"
        echo "ALIRAZA - BUNNY CDN PULL ZONE SETUP GUIDE"
        echo "============================================================"
        echo "1. Bunny.net Dashboard -> Pull Zones -> Add Pull Zone"
        echo "   - Pull Zone Hostname : ${NEW_BH}"
        echo "   - Origin Type        : Origin URL"
        echo "   - Origin URL         : http://${MY_IP}:80  (ya https://${MY_IP}:443)"
        echo "2. Pull Zone Settings -> Enable WebSockets: ON | Forward Host Header: ON | Add Canonical Header: OFF"
        echo "3. Har user ki alag Bunny config: /root/aliraza-configs/bunnycdn/USERNAME-bunnycdn.txt"
        echo "============================================================"
    } > "$BUNNY_CONF"
    configure_nginx_mux; regenerate_all_user_files
    echo "[✔] Bunny CDN Host (${NEW_BH}) configured & user files generated!"
}

panel_regen_files() { regenerate_all_user_files; echo "[✔] Sab users ki config files regenerate ho gayin."; }

panel_set_tg() {
    local TOK="$1" UID_="$2"
    [[ -z "$TOK" || -z "$UID_" ]] && return 1
    setup_cli_account_helper; setup_telegram_bot_daemon
    echo "TOKEN=${TOK}" > "$TG_CONF"; chmod 600 "$TG_CONF"; echo "$UID_" > "$TG_ADMINS"
    systemctl enable aliraza-tgbot >/dev/null 2>&1 || true; systemctl restart aliraza-tgbot >/dev/null 2>&1 || true
    echo "[✔] Telegram bot connected."
}

panel_slowdns_target() {
    case "$1" in
        1) echo "127.0.0.1:10022" > "$DATA_DIR/slowdns_target.txt" ;;
        2) echo "127.0.0.1:10022" > "$DATA_DIR/slowdns_target.txt" ;;
        3) echo "127.0.0.1:20010" > "$DATA_DIR/slowdns_target.txt" ;;
        *) return 1 ;;
    esac
    install_udp_custom 0; install_badvpn_gateway 0; configure_slowdns_service 0
    echo "[✔] SlowDNS, ZiVPN, Hysteria2 & UDP updated!"
}

panel_udp_test() {
    echo "[*] 15s listening... mobile se UDP app (HTTP Custom / NetMod) connect karein"
    local out; out=$(timeout 15 tcpdump -U -l -ni any "udp and (dst port 5667 or dst port 36712 or dst port 20800 or dst port 5300 or dst port 53)" -c 8 2>/dev/null || true)
    if [[ -n "$out" ]]; then echo "$out"; echo "[✔] UDP PACKETS VPS TAK AA RAHE HAIN (Cloud Firewall Open)"
    else echo "[✘] 0 UDP PACKETS RECEIVED - cloud firewall (Security Group) me Inbound All UDP 0.0.0.0/0 allow karein."; fi
}

panel_speedtest() { speedtest-cli --simple 2>/dev/null || curl -sL https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 - --simple; }

panel_uninstall() {
    systemctl stop haproxy aliraza-ws aliraza-monitor aliraza-tgbot aliraza-firewall zivpn hysteria udp-custom badvpn slowdns xray nginx dropbear stunnel4 2>/dev/null || true
    # OpenSSH wapas lao (warna uninstall ke baad server login band ho jata)
    rm -f /etc/apt/preferences.d/aliraza-no-openssh /etc/aliraza/.openssh_off /etc/aliraza/.openssh_removed 2>/dev/null || true
    systemctl unmask ssh ssh.service sshd ssh.socket 2>/dev/null || true
    dpkg -s openssh-server >/dev/null 2>&1 || DEBIAN_FRONTEND=noninteractive apt-get install -y openssh-server >/dev/null 2>&1 || true
    [[ -f "$BACKUP_DIR/sshd_config.orig" ]] && cp -pf "$BACKUP_DIR/sshd_config.orig" /etc/ssh/sshd_config 2>/dev/null || true
    systemctl enable ssh >/dev/null 2>&1 || systemctl enable sshd >/dev/null 2>&1 || true
    systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || true
    rm -rf "$WS_DIR" "$SLOWDNS_DIR" "$UDP_DIR" "$ZIVPN_DIR" "$HY2_DIR" "$CLIENTS_DIR" "$DATA_DIR" /usr/bin/menu /root/install.sh 2>/dev/null || true
    echo "[✔] Uninstall complete. Panel ab band ho raha hai."
    systemctl disable --now aliraza-panel >/dev/null 2>&1 || true
    rm -f /etc/systemd/system/aliraza-panel.service "$PANEL_BIN" "$CORE_PATH" 2>/dev/null || true
    systemctl daemon-reload >/dev/null 2>&1 || true
}

force_ipv4_only() {
    cat > /etc/sysctl.d/98-aliraza-ipv4.conf << 'V4EOF'
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
V4EOF
    sysctl -w net.ipv6.conf.all.disable_ipv6=1 net.ipv6.conf.default.disable_ipv6=1 net.ipv6.conf.lo.disable_ipv6=1 >/dev/null 2>&1 || true
    sed -i '/^precedence ::ffff:0:0\/96/d' /etc/gai.conf 2>/dev/null || true
    echo "precedence ::ffff:0:0/96  100" >> /etc/gai.conf 2>/dev/null || true
    # apt/curl/dig sab IPv4 par
    echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99-aliraza-ipv4 2>/dev/null || true
}

# ---------------- installer ----------------
_step_ssh_core() { write_aliraza_vip_banner; fix_ssh_auth_and_banner; fix_dropbear_core; }
_step_xray_cfg() { write_base_xray_config; fix_xray_systemd_unit; sync_all_users_to_engines; systemctl enable xray 2>/dev/null; timeout 30 systemctl restart xray 2>/dev/null || true; }
_step_misc() { setup_cli_account_helper; regenerate_all_user_files; setup_realtime_monitor_service; setup_telegram_bot_daemon; install_liveips_helper; }

run_full_install() {
    local DOMAIN; DOMAIN=$(head -n1 "$DATA_DIR/domain.txt" 2>/dev/null | tr -d '[:space:]')
    [[ -z "$DOMAIN" ]] && { echo "[!] Domain set nahi hai"; return 1; }
    rm -f /run/aliraza_dom_* /run/aliraza_ns_* 2>/dev/null || true
    fix_dns_resolver >/dev/null 2>&1 || true
    run_step "[1/16] Base packages" ensure_base_packages
    force_ipv4_only
    run_step "[2/16] DNS resolver" fix_dns_resolver
    run_step "[3/16] NAT / firewall" setup_slowdns_and_udp_nat
    get_vps_ip >/dev/null; get_vps_provider >/dev/null
    run_step "[4/16] SSH + Dropbear + banner" _step_ssh_core
    run_step "[5/16] SSL certificate" issue_ssl_cert "$DOMAIN"
    run_step "[6/16] OpenVPN" setup_openvpn_server
    run_step "[7/16] NGINX + HAProxy mux" configure_nginx_mux
    run_step "[8/16] Go WS engine (1-4 min)" install_ws_ssh_engine
    run_step "[9/16] Stunnel" fix_stunnel_core
    run_step "[10/16] Xray download (1-3 min)" install_xray_binary
    run_step "[11/16] Xray config + users" _step_xray_cfg
    run_step "[12/16] UDP-Custom" install_udp_custom 0
    run_step "[13/16] BadVPN" install_badvpn_gateway 0
    run_step "[14/16] SlowDNS (1-4 min)" configure_slowdns_service 0
    setup_slowdns_and_udp_nat
    run_step "[15/16] HAProxy mux" configure_haproxy_c_mux
    run_step "[16/16] CLI helper, monitor, bot" _step_misc
    echo "INSTALLED" > "$INSTALLED_FLAG"; echo "READY" > "$V55_FLAG"; echo "READY" > "$V554_FLAG"
    echo ""
    echo -e "${CYAN}[*] FINAL LIVE PORTS VERIFICATION:${NC}"
    for chk in "443:tcp:HAProxy-TLS-Mux" "80:tcp:HAProxy-HTTP-Mux" "8442:tcp:TLS-Terminator" "10010:tcp:Xray-XHTTP" "10013:tcp:Xray-Reality" "10014:udp:Xray-mKCP" "10015:tcp:Shadowsocks-2022" "10808:tcp:Socks5" "1194:tcp:OpenVPN-TCP" "2200:udp:OpenVPN-UDP" "5667:udp:ZiVPN" "36712:udp:UDP-Custom" "20800:udp:Hysteria2" "5300:udp:SlowDNS" "444:tcp:Stunnel" "10022:tcp:Dropbear"; do
        IFS=':' read -r cport cproto clabel <<< "$chk"
        cflg="-tln"; [[ "$cproto" == "udp" ]] && cflg="-uln"
        if ss "$cflg" 2>/dev/null | grep -qE ":${cport}\b"; then echo -e "  ${GREEN}[ON ]${NC} ${clabel} (${cport}/${cproto})"
        else echo -e "  ${RED}[OFF]${NC} ${clabel} (${cport}/${cproto}) -> Panel me Auto-Doctor chalayein"; fi
    done
    install_port_watchdog
    install_stable_watchdog
    self_test_tls_and_repair
}

panel_reinstall() { run_full_install; echo "[OK] Re-install complete."; }

full_auto_installer() {
    clear_screen
    aliraza_banner 1
    echo -e " ${PURPLE}━━━━━━━━━━━━━━━━━━  INSTALLER SETUP  ━━━━━━━━━━━━━━━━━━${NC}\n"
    local CUR_D CUR_N DOMAIN NS_DOMAIN
    CUR_D=$(head -n1 "$DATA_DIR/domain.txt" 2>/dev/null | tr -d '[:space:]')
    CUR_N=$(head -n1 "$DATA_DIR/ns_domain.txt" 2>/dev/null | tr -d '[:space:]')
    while true; do
        read -rp " • Main VPS Domain${CUR_D:+ [$CUR_D]}: " DOMAIN || exit 1
        DOMAIN="${DOMAIN:-$CUR_D}"
        [[ "$DOMAIN" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]{0,250}[A-Za-z0-9])?$ ]] && break
        echo -e "   ${RED}[!] Valid domain likhein (e.g. vpn.example.com)${NC}"
    done
    while true; do
        read -rp " • SlowDNS NS Domain [${CUR_N:-ns.$DOMAIN}]: " NS_DOMAIN || exit 1
        NS_DOMAIN="${NS_DOMAIN:-${CUR_N:-ns.$DOMAIN}}"
        [[ "$NS_DOMAIN" != "$DOMAIN" ]] && break
        echo -e "   ${RED}[!] NS Domain main domain se alag hona chahiye (e.g. ns.$DOMAIN)${NC}"
    done
    ask_panel_credentials
    echo "$DOMAIN" > "$DATA_DIR/domain.txt"; echo "$NS_DOMAIN" > "$DATA_DIR/ns_domain.txt"; echo "$DOMAIN" > "$DATA_DIR/bunny_host.txt"
    echo ""; echo -e " ${CYAN}Installation shuru... (kuch minute lagenge, log: $AR_LOG)${NC}\n"
    run_full_install || exit 1
    install_web_panel
    echo "$SCRIPT_VER" > "$VER_FLAG"
    echo -e "${GREEN}[OK] INSTALL COMPLETE!${NC}"
    show_panel_info
    panel_diagnose
}








enforce_user_protocols() {
    # Jin users ke protocols me ssh/slowdns nahi, un ka Linux login lock (SSH/Dropbear/WS/SSL/UDP/OpenVPN band)
    local u p
    [[ -s "$USERS_DB" ]] || return 0
    while IFS='|' read -r u _ _ _ _ _ _ p; do
        [[ -z "$u" || -z "$p" || "$p" == "all" ]] && continue
        [[ ",$p," == *",ssh,"* || ",$p," == *",slowdns,"* ]] && continue
        is_protected_system_user "$u" && continue
        id "$u" >/dev/null 2>&1 || continue
        passwd -l "$u" >/dev/null 2>&1 || true
        usermod -s /usr/sbin/nologin "$u" >/dev/null 2>&1 || true
        pkill -9 -u "$u" >/dev/null 2>&1 || true
        /usr/local/bin/aliraza-kick "$u" >/dev/null 2>&1 || true
    done < "$USERS_DB"
}

upgrade_to_current() {
    echo -e "${CYAN}[*] Script update lag rahi hai (${SCRIPT_VER}) - users/data safe rahenge...${NC}"
    systemctl stop aliraza-panel >/dev/null 2>&1 || true
    setup_cli_account_helper
    force_ipv4_only
    enable_bbr_and_kernel_speed
    fix_ssh_auth_and_banner
    fix_dropbear_core
    install_ssl_autorenew
    install_stable_watchdog
    install_web_panel
    install_liveips_helper
    setup_realtime_monitor_service
    configure_nginx_mux
    install_ws_ssh_engine
    sync_all_users_to_engines
    enforce_user_protocols
    setup_slowdns_and_udp_nat
    install_zivpn_and_hysteria 0
    install_port_watchdog
    systemctl restart aliraza-monitor >/dev/null 2>&1 || true
    regenerate_all_user_files >/dev/null 2>&1 || true
    echo "$SCRIPT_VER" > "$VER_FLAG"
    echo -e "${GREEN}[OK] Update complete - protocol isolation + domain checks active.${NC}"
}

# v59.6: sirf panel + live-IP engine badalta hai (nginx/xray/ssh/users ko touch nahi karta). Fail ho to purani files wapas.
panel_hotpatch() {
    if [[ ! -f "$PANEL_CONF" || ! -f "$PANEL_BIN" ]]; then
        echo -e "${RED}[!] Web Panel installed nahi mila - pehle normal install chalayein.${NC}"; return 1
    fi
    local BK="$BACKUP_DIR/hotpatch-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BK"
    cp -a "$PANEL_BIN" "$BK/aliraza-panel.py" 2>/dev/null || true
    cp -a /usr/local/bin/aliraza-liveips.py "$BK/aliraza-liveips.py" 2>/dev/null || true
    cp -a "$CORE_PATH" "$BK/core.sh" 2>/dev/null || true
    cp -a /usr/local/bin/aliraza-cli "$BK/aliraza-cli" 2>/dev/null || true
    cp -a /usr/local/bin/aliraza-enforcer "$BK/aliraza-enforcer" 2>/dev/null || true
    echo -e "${CYAN}[*] Hot-patch: Lock/Kick fix + IP-limit + fast Live IP lag raha hai (backup: $BK)${NC}"
    setup_cli_account_helper
    setup_realtime_monitor_service
    install_liveips_helper
    if ! python3 -m py_compile /usr/local/bin/aliraza-liveips.py 2>/dev/null; then
        echo -e "${RED}[!] liveips syntax check fail - purani file wapas.${NC}"
        cp -a "$BK/aliraza-liveips.py" /usr/local/bin/aliraza-liveips.py 2>/dev/null; return 1
    fi
    if ! install_web_panel || ! python3 -m py_compile "$PANEL_BIN" 2>/dev/null; then
        echo -e "${RED}[!] Panel start/syntax fail - purana panel wapas ho raha hai.${NC}"
        cp -a "$BK/aliraza-panel.py" "$PANEL_BIN" 2>/dev/null
        cp -a "$BK/aliraza-liveips.py" /usr/local/bin/aliraza-liveips.py 2>/dev/null
        [[ -f "$BK/core.sh" ]] && cp -a "$BK/core.sh" "$CORE_PATH" 2>/dev/null
        systemctl restart aliraza-panel >/dev/null 2>&1 || true
        return 1
    fi
    rm -f /run/aliraza_liveips.cache 2>/dev/null || true
    systemctl restart aliraza-monitor >/dev/null 2>&1 || true
    echo "$SCRIPT_VER" > "$VER_FLAG"
    echo -e "${GREEN}[OK] Hot-patch complete - panel ab ${SCRIPT_VER} par hai. Browser mein Ctrl+F5 karein.${NC}"
}

smart_auto_doctor() {
    clear_screen
    echo -e "${BG_PURPLE}   ★ REAL AUTO-DOCTOR & DEEP VERIFICATION (v55.4) ★ ${NC}"
    rm -f /run/aliraza_dom_* /run/aliraza_ns_* 2>/dev/null || true
    echo -e " ${CYAN}[1/6]${NC} Checking Kernel BBR, Firewall NAT & Base Tools..."
    enable_bbr_and_kernel_speed
    setup_slowdns_and_udp_nat
    echo -e " ${CYAN}[2/6]${NC} Dropbear (port 80, OpenSSH removed) & Stunnel (444/8443)..."
    write_aliraza_vip_banner; fix_ssh_auth_and_banner; fix_dropbear_core; setup_openvpn_server; fix_stunnel_core
    echo -e " ${CYAN}[3/6]${NC} Verifying SlowDNS (5300), ZiVPN (5667), Hysteria2 (20800) & UDP-Custom (36712)..."
    configure_slowdns_service 0; install_udp_custom 0; install_badvpn_gateway 0
    echo -e " ${CYAN}[4/6]${NC} Repairing Xray Multi-Protocol Core (WS, gRPC, HUP, XHTTP, Vision, Reality, mKCP)..."
    write_base_xray_config; fix_xray_systemd_unit; sync_all_users_to_engines
    systemctl restart xray 2>/dev/null || true
    echo -e " ${CYAN}[5/6]${NC} Repairing Nginx, Golang WS Engine (10000), Real SIM IP Engine & HAProxy 80/443 Mux..."
    configure_nginx_mux; install_ws_ssh_engine; install_liveips_helper
    echo -e " ${CYAN}[6/6]${NC} Tracker/Bot Sync + Watchdog + 443 TLS Self-Test..."
    setup_cli_account_helper; regenerate_all_user_files; setup_realtime_monitor_service; setup_telegram_bot_daemon
    systemctl restart xray nginx aliraza-ws haproxy 2>/dev/null || true
    install_port_watchdog
    self_test_tls_and_repair
    echo "READY" > "$V55_FLAG"
    echo -e "\n${GREEN}[✔] MUBARAK HO! All 17 Services + Zero-Ghost-KB Data Tracker + Real SIM IP Engine 100% LIVE!${NC}"
    read -rp "Enter dabayein..." || true
}








restart_all_services_menu() {
    clear_screen; enable_bbr_and_kernel_speed; generate_fallback_cert
    rm -f /run/aliraza_dom_* /run/aliraza_ns_* 2>/dev/null || true
    /usr/local/bin/aliraza-firewall-restore >/dev/null 2>&1 || true
    configure_haproxy_c_mux
    systemctl restart dropbear nginx aliraza-ws haproxy xray openvpn-server@server-tcp openvpn-server@server-udp zivpn hysteria udp-custom badvpn slowdns stunnel4 aliraza-monitor aliraza-tgbot aliraza-watchdog 2>/dev/null || true
    install_port_watchdog
    echo -e "${GREEN}[✔] All Services (HAProxy 80/443 + Watchdog) Restarted!${NC}"; read -rp "Enter dabayein..." || true
}

clean_ram_and_logs() {
    clear_screen; sync; echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
    if [[ -s /var/log/xray/access.log ]]; then
        tail -n 100 /var/log/xray/access.log > /tmp/.xlog_keep 2>/dev/null && cat /tmp/.xlog_keep > /var/log/xray/access.log 2>/dev/null || true
        rm -f /tmp/.xlog_keep 2>/dev/null || true
    fi
    echo -e "${GREEN}[✔] RAM Cache & Logs safely clean ho gaye (User Data & Active SIM IPs 100% Safe)!${NC}"
    read -rp "Enter dabayein..." || true
}


install_stable_watchdog() {
    # v58.3: duplicate watchdog hata diya (do watchdog ek doosre ke saath haproxy restart kar ke users disconnect karte the)
    systemctl stop aliraza-stable-wd >/dev/null 2>&1 || true
    systemctl disable aliraza-stable-wd >/dev/null 2>&1 || true
    rm -f /etc/systemd/system/aliraza-stable-wd.service /usr/local/bin/aliraza-stable-wd.sh
    systemctl daemon-reload >/dev/null 2>&1 || true
}

case "${1:-}" in
    --fn)
        shift; FN="${1:-}"; shift || true
        if [[ "$FN" =~ ^(panel_|restart_all_services_menu$|smart_auto_doctor$|clean_ram_and_logs$) ]] && declare -F "$FN" >/dev/null 2>&1; then
            "$FN" "$@"; exit $?
        fi
        echo "Invalid function"; exit 2 ;;
    passwd|password|reset) panel_reset_credentials; exit 0 ;;
    port)                  panel_change_port; exit 0 ;;
    check|doctor-panel)    panel_diagnose; exit 0 ;;
    upgrade|update)        upgrade_to_current; show_panel_info; panel_diagnose; exit 0 ;;
    restart)               systemctl restart aliraza-panel; show_panel_info; exit 0 ;;
    hotpatch|livefix)      panel_hotpatch; exit $? ;;
esac

fix_hostname_resolution >/dev/null 2>&1 || true
if [[ ! -f "$INSTALLED_FLAG" || ! -x /usr/local/bin/xray ]]; then
    full_auto_installer
else
    if [[ ! -f "$PANEL_CONF" ]]; then
        echo -e "${CYAN}[*] Purani terminal-panel install mili - ab Web Panel me convert ho rahi hai...${NC}"
        ask_panel_credentials
        write_aliraza_vip_banner; fix_ssh_auth_and_banner; fix_dropbear_core
        setup_cli_account_helper; install_liveips_helper
        install_web_panel
    fi
    if [[ "$(cat "$VER_FLAG" 2>/dev/null)" != "$SCRIPT_VER" ]]; then upgrade_to_current; fi
    show_panel_info
    panel_diagnose
fi
