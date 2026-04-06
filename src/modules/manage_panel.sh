#!/bin/bash
# Module: Manage Panel

show_manage_panel_menu() {
    local sync_ufw_label="${LANG[SYNC_UFW_FROM_PROFILE]:-Sync UFW ports from config profile}"
    local manage_prompt="${LANG[MANAGE_PANEL_NODE_PROMPT]:-Select action (0-7):}"
    local manage_invalid_choice="${LANG[MANAGE_PANEL_NODE_INVALID_CHOICE]:-Invalid choice. Please select 0-7.}"

    echo -e ""
    echo -e "${COLOR_GREEN}${LANG[MENU_3]}${COLOR_RESET}"
    echo -e ""
    echo -e "${COLOR_YELLOW}1. ${LANG[START_PANEL_NODE]}${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}2. ${LANG[STOP_PANEL_NODE]}${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}3. ${LANG[UPDATE_PANEL_NODE]}${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}4. ${LANG[VIEW_LOGS]}${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}5. ${LANG[REMNAWAVE_CLI]}${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}6. ${LANG[ACCESS_PANEL]}${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}7. ${sync_ufw_label}${COLOR_RESET}"
    echo -e ""
    echo -e "${COLOR_YELLOW}0. ${LANG[EXIT]}${COLOR_RESET}"
    echo -e ""
    reading "${manage_prompt}" SUB_OPTION

    case $SUB_OPTION in
        1)
            start_panel_node
            sleep 2
            log_clear
            show_manage_panel_menu
            ;;
        2)
            stop_panel_node
            sleep 2
            log_clear
            show_manage_panel_menu
            ;;
        3)
            update_panel_node
            sleep 2
            log_clear
            show_manage_panel_menu
            ;;
        4)
            view_logs
            sleep 2
            log_clear
            show_manage_panel_menu
            ;;
        5)
            run_remnawave_cli
            sleep 2
            log_clear
            show_manage_panel_menu
            ;;
        6)
            manage_panel_access
            sleep 2
            log_clear
            show_manage_panel_menu
            ;;
        7)
            sync_ufw_ports_from_profile
            sleep 2
            log_clear
            show_manage_panel_menu
            ;;
        0)
            remnawave_reverse
            ;;
        *)
            echo -e "${COLOR_YELLOW}${manage_invalid_choice}${COLOR_RESET}"
            sleep 1
            show_manage_panel_menu
            ;;
    esac
}

run_remnawave_cli() {
    if ! docker ps --format '{{.Names}}' | grep -q '^remnawave$'; then
        echo -e "${COLOR_YELLOW}${LANG[CONTAINER_NOT_RUNNING]}${COLOR_RESET}"
        return 1
    fi

    exec 3>&1 4>&2
    exec > /dev/tty 2>&1

    echo -e "${COLOR_YELLOW}${LANG[RUNNING_CLI]}${COLOR_RESET}"
    if docker exec -it -e TERM=xterm-256color remnawave remnawave; then
        echo -e "${COLOR_GREEN}${LANG[CLI_SUCCESS]}${COLOR_RESET}"
    else
        echo -e "${COLOR_RED}${LANG[CLI_FAILED]}${COLOR_RESET}"
        exec 1>&3 2>&4
        return 1
    fi

    exec 1>&3 2>&4
}

start_panel_node() {
    local dir=""
    if [ -d "/opt/remnawave" ]; then
        dir="/opt/remnawave"
    elif [ -d "/opt/remnanode" ]; then
        dir="/opt/remnanode"
    else
        echo -e "${COLOR_RED}${LANG[DIR_NOT_FOUND]}${COLOR_RESET}"
        exit 1
    fi

    cd "$dir" || { echo -e "${COLOR_RED}${LANG[CHANGE_DIR_FAILED]} $dir${COLOR_RESET}"; exit 1; }

    if docker ps -q --filter "ancestor=remnawave/backend:latest" | grep -q . || docker ps -q --filter "ancestor=remnawave/node:latest" | grep -q . || docker ps -q --filter "ancestor=remnawave/backend:2" | grep -q .; then
        echo -e "${COLOR_GREEN}${LANG[PANEL_RUNNING]}${COLOR_RESET}"
    else
        echo -e "${COLOR_YELLOW}${LANG[STARTING_PANEL_NODE]}...${COLOR_RESET}"
        sleep 1
        docker compose up -d > /dev/null 2>&1 &
        spinner $! "${LANG[WAITING]}"
        echo -e "${COLOR_GREEN}${LANG[PANEL_RUN]}${COLOR_RESET}"
    fi
}

stop_panel_node() {
    local dir=""
    if [ -d "/opt/remnawave" ]; then
        dir="/opt/remnawave"
    elif [ -d "/opt/remnanode" ]; then
        dir="/opt/remnanode"
    else
        echo -e "${COLOR_RED}${LANG[DIR_NOT_FOUND]}${COLOR_RESET}"
        exit 1
    fi

    cd "$dir" || { echo -e "${COLOR_RED}${LANG[CHANGE_DIR_FAILED]} $dir${COLOR_RESET}"; exit 1; }
    if ! docker ps -q --filter "ancestor=remnawave/backend:latest" | grep -q . && ! docker ps -q --filter "ancestor=remnawave/node:latest" | grep -q . && ! docker ps -q --filter "ancestor=remnawave/backend:2" | grep -q .; then
        echo -e "${COLOR_GREEN}${LANG[PANEL_STOPPED]}${COLOR_RESET}"
    else
        echo -e "${COLOR_YELLOW}${LANG[STOPPING_REMNAWAVE]}...${COLOR_RESET}"
        sleep 1
        docker compose down > /dev/null 2>&1 &
        spinner $! "${LANG[WAITING]}"
        echo -e "${COLOR_GREEN}${LANG[PANEL_STOP]}${COLOR_RESET}"
    fi
}

update_panel_node() {
    local dir=""
    if [ -d "/opt/remnawave" ]; then
        dir="/opt/remnawave"
    elif [ -d "/opt/remnanode" ]; then
        dir="/opt/remnanode"
    else
        echo -e "${COLOR_RED}${LANG[DIR_NOT_FOUND]}${COLOR_RESET}"
        exit 1
    fi

    cd "$dir" || { echo -e "${COLOR_RED}${LANG[CHANGE_DIR_FAILED]} $dir${COLOR_RESET}"; exit 1; }
    echo -e "${COLOR_YELLOW}${LANG[UPDATING]}${COLOR_RESET}"
    sleep 1

    images_before=$(docker compose config --images | sort -u)
    if [ -n "$images_before" ]; then
        before=$(echo "$images_before" | xargs -I {} docker images -q {} | sort -u)
    else
        before=""
    fi

    tmpfile=$(mktemp)
    docker compose pull > "$tmpfile" 2>&1 &
    spinner $! "${LANG[WAITING]}"
    pull_output=$(cat "$tmpfile")
    rm -f "$tmpfile"

    images_after=$(docker compose config --images | sort -u)
    if [ -n "$images_after" ]; then
        after=$(echo "$images_after" | xargs -I {} docker images -q {} | sort -u)
    else
        after=""
    fi

    if [ "$before" != "$after" ] || echo "$pull_output" | grep -q "Pull complete"; then
        echo -e ""
	echo -e "${COLOR_YELLOW}${LANG[IMAGES_DETECTED]}${COLOR_RESET}"
        docker compose down > /dev/null 2>&1 &
        spinner $! "${LANG[WAITING]}"
        sleep 5
        docker compose up -d > /dev/null 2>&1 &
        spinner $! "${LANG[WAITING]}"
        sleep 1
        docker image prune -f > /dev/null 2>&1
        echo -e "${COLOR_GREEN}${LANG[UPDATE_SUCCESS1]}${COLOR_RESET}"
    else
        echo -e "${COLOR_YELLOW}${LANG[NO_UPDATE]}${COLOR_RESET}"
    fi
}

view_logs() {
    local dir=""
    if [ -d "/opt/remnawave" ]; then
        dir="/opt/remnawave"
    elif [ -d "/opt/remnanode" ]; then
        dir="/opt/remnanode"
    else
        echo -e "${COLOR_RED}${LANG[DIR_NOT_FOUND]}${COLOR_RESET}"
        exit 1
    fi

    cd "$dir" || { echo -e "${COLOR_RED}${LANG[CHANGE_DIR_FAILED]} $dir${COLOR_RESET}"; exit 1; }

    if ! docker ps -q --filter "ancestor=remnawave/backend:latest" | grep -q . && ! docker ps -q --filter "ancestor=remnawave/node:latest" | grep -q . && ! docker ps -q --filter "ancestor=remnawave/backend:2" | grep -q .; then
        echo -e "${COLOR_RED}${LANG[CONTAINER_NOT_RUNNING]}${COLOR_RESET}"
        exit 1
    fi

    echo -e "${COLOR_YELLOW}${LANG[VIEW_LOGS]}${COLOR_RESET}"
    docker compose logs -f -t
}

sync_ufw_ports_from_profile() {
    local sync_ufw_start="${LANG[SYNC_UFW_START]:-Starting UFW sync...}"
    local sync_ufw_fetch_profiles="${LANG[SYNC_UFW_FETCH_PROFILES]:-Loading config profiles from panel...}"
    local sync_ufw_fetch_profile="${LANG[SYNC_UFW_FETCH_PROFILE]:-Loading selected profile: %s}"
    local sync_ufw_found_ports="${LANG[SYNC_UFW_FOUND_PORTS]:-Found %s external inbound port(s) in source %s}"
    local sync_ufw_summary="${LANG[SYNC_UFW_SUMMARY]:-UFW sync summary for %s: added=%s, existing=%s, failed=%s}"
    local sync_ufw_node_scan="${LANG[SYNC_UFW_NODE_SCAN]:-Inspecting remnanode runtime listeners...}"
    local sync_ufw_node_source="${LANG[SYNC_UFW_NODE_SOURCE]:-remnanode runtime}"
    local sync_ufw_panel_source="${LANG[SYNC_UFW_PANEL_SOURCE]:-panel profile %s}"
    local sync_ufw_no_node_ports="${LANG[SYNC_UFW_NO_NODE_PORTS]:-No external rw-core listeners found on remnanode.}"
    local sync_ufw_source_required="${LANG[SYNC_UFW_SOURCE_REQUIRED]:-This action requires a local remnanode or remnawave installation.}"

    if ! command -v ufw >/dev/null 2>&1; then
        echo -e "${COLOR_RED}${LANG[ERROR_CONFIGURE_UFW]}${COLOR_RESET}"
        return 1
    fi

    echo -e "${COLOR_YELLOW}${sync_ufw_start}${COLOR_RESET}"

    local inbound_entries
    local selected_name=""

    if [ -d "/opt/remnanode" ] && command -v ss >/dev/null 2>&1; then
        echo -e "${COLOR_YELLOW}${sync_ufw_node_scan}${COLOR_RESET}"
        inbound_entries=$(ss -H -lntup 2>/dev/null | awk '
            /rw-core/ {
                proto=$1
                local_addr=$5
                if (local_addr ~ /^127\.0\.0\.1:/ || local_addr ~ /^\[::1\]:/ || local_addr ~ /^localhost:/) next
                port=local_addr
                sub(/^.*:/, "", port)
                if (port ~ /^[0-9]+$/) print "rw-core\t" port "\t" proto
            }
        ' | sort -u)

        if [ -n "$inbound_entries" ]; then
            selected_name="${sync_ufw_node_source}"
        else
            echo -e "${COLOR_YELLOW}${sync_ufw_no_node_ports}${COLOR_RESET}"
        fi
    fi

    if [ -z "$inbound_entries" ] && [ -d "/opt/remnawave" ]; then
        local domain_url="127.0.0.1:3000"
        load_api_module
        get_panel_token || return 1

        local token
        token=$(cat "$TOKEN_FILE")
        echo -e "${COLOR_YELLOW}${sync_ufw_fetch_profiles}${COLOR_RESET}"

        local config_response
        config_response=$(make_api_request "GET" "${domain_url}/api/config-profiles" "$token")
        if [ -z "$config_response" ] || ! echo "$config_response" | jq -e '.' > /dev/null 2>&1; then
            echo -e "${COLOR_RED}${LANG[WARP_NO_CONFIGS]}: Invalid response${COLOR_RESET}"
            return 1
        fi

        if ! echo "$config_response" | jq -e '.response.configProfiles | type == "array"' > /dev/null 2>&1; then
            echo -e "${COLOR_RED}${LANG[WARP_NO_CONFIGS]}: Response does not contain configProfiles array${COLOR_RESET}"
            return 1
        fi

        local config_count
        config_count=$(echo "$config_response" | jq '.response.configProfiles | length')
        if [ "$config_count" -eq 0 ]; then
            echo -e "${COLOR_RED}${LANG[WARP_NO_CONFIGS]}: Empty configuration list${COLOR_RESET}"
            return 1
        fi

        local configs
        configs=$(echo "$config_response" | jq -r '.response.configProfiles[] | select(.uuid and .name) | [.name, .uuid] | @tsv' 2>/dev/null)
        if [ -z "$configs" ]; then
            echo -e "${COLOR_RED}${LANG[WARP_NO_CONFIGS]}: No valid configurations found in response${COLOR_RESET}"
            return 1
        fi

        echo -e ""
        echo -e "${COLOR_YELLOW}${LANG[SYNC_UFW_SELECT_CONFIG]}${COLOR_RESET}"
        echo -e ""

        local i=1
        declare -A config_map
        declare -A config_name_map
        while IFS=$'\t' read -r name uuid; do
            echo -e "${COLOR_YELLOW}$i. $name${COLOR_RESET}"
            config_map[$i]="$uuid"
            config_name_map[$i]="$name"
            ((i++))
        done <<< "$configs"

        echo -e ""
        echo -e "${COLOR_YELLOW}0. ${LANG[EXIT]}${COLOR_RESET}"
        echo -e ""
        reading "${LANG[WARP_PROMPT1]}" CONFIG_OPTION

        if [ "$CONFIG_OPTION" == "0" ]; then
            echo -e "${COLOR_YELLOW}${LANG[EXIT]}${COLOR_RESET}"
            return 0
        fi

        if [ -z "${config_map[$CONFIG_OPTION]}" ]; then
            echo -e "${COLOR_RED}${LANG[WARP_INVALID_CHOICE2]}${COLOR_RESET}"
            return 1
        fi

        local selected_uuid=${config_map[$CONFIG_OPTION]}
        selected_name=${config_name_map[$CONFIG_OPTION]}
        printf "${COLOR_YELLOW}${sync_ufw_fetch_profile}${COLOR_RESET}\n" "$selected_name"

        local config_data
        config_data=$(make_api_request "GET" "${domain_url}/api/config-profiles/$selected_uuid" "$token")
        if [ -z "$config_data" ] || ! echo "$config_data" | jq -e '.' > /dev/null 2>&1; then
            echo -e "${COLOR_RED}${LANG[WARP_UPDATE_FAIL]}: Invalid response${COLOR_RESET}"
            return 1
        fi

        local config_json
        if echo "$config_data" | jq -e '.response.config' > /dev/null 2>&1; then
            config_json=$(echo "$config_data" | jq -r '.response.config')
        else
            config_json=$(echo "$config_data" | jq -r '.config // ""')
        fi

        if [ -z "$config_json" ] || [ "$config_json" == "null" ]; then
            echo -e "${COLOR_RED}${LANG[WARP_UPDATE_FAIL]}: No config found in response${COLOR_RESET}"
            return 1
        fi

        inbound_entries=$(echo "$config_json" | jq -r '
            (.inbounds // [])
            | map(select((.port // null) != null))
            | map(select(((.listen // "") != "127.0.0.1") and ((.listen // "") != "::1") and ((.listen // "") != "localhost")))
            | map({
                tag: (.tag // "inbound"),
                port: (.port | tostring),
                ufwProto: (
                    if .protocol == "wireguard" or ((.streamSettings.network // "") == "quic") or ((.streamSettings.network // "") == "kcp")
                    then "udp"
                    else "tcp"
                    end
                )
            })
            | .[]
            | [.tag, .port, .ufwProto] | @tsv
        ' 2>/dev/null)
    fi

    if [ -z "$inbound_entries" ]; then
        echo -e "${COLOR_RED}${sync_ufw_source_required}${COLOR_RESET}"
        return 1
    fi

    local inbound_count
    inbound_count=$(printf '%s\n' "$inbound_entries" | sed '/^[[:space:]]*$/d' | wc -l | tr -d ' ')
    printf "${COLOR_YELLOW}${sync_ufw_found_ports}${COLOR_RESET}\n" "$inbound_count" "$selected_name"
    printf "${COLOR_YELLOW}${LANG[SYNC_UFW_APPLYING_RULE]}${COLOR_RESET}\n" "$selected_name"

    local changes_made=0
    local add_failed=0
    local rules_added=0
    local rules_existing=0
    while IFS=$'\t' read -r inbound_tag inbound_port inbound_proto; do
        [ -z "$inbound_port" ] && continue

        if ufw status | grep -q "${inbound_port}/${inbound_proto}"; then
            printf "${COLOR_YELLOW}${LANG[SYNC_UFW_RULE_EXISTS]}${COLOR_RESET}\n" "$inbound_port" "$inbound_proto" "$inbound_tag"
            rules_existing=$((rules_existing + 1))
            continue
        fi

        if ufw allow "${inbound_port}/${inbound_proto}" comment "Remnawave ${inbound_tag}" > /dev/null 2>&1; then
            printf "${COLOR_GREEN}${LANG[SYNC_UFW_RULE_ADDED]}${COLOR_RESET}\n" "$inbound_port" "$inbound_proto" "$inbound_tag"
            changes_made=1
            rules_added=$((rules_added + 1))
        else
            printf "${COLOR_RED}${LANG[SYNC_UFW_RULE_ADD_FAILED]}${COLOR_RESET}\n" "$inbound_port" "$inbound_proto" "$inbound_tag"
            add_failed=1
        fi
    done <<< "$inbound_entries"

    if [ "$changes_made" -eq 1 ]; then
        ufw reload > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo -e "${COLOR_RED}${LANG[UFW_RELOAD_FAILED]}${COLOR_RESET}"
            return 1
        fi
        echo -e "${COLOR_GREEN}${LANG[SYNC_UFW_RELOAD_OK]}${COLOR_RESET}"
    else
        echo -e "${COLOR_YELLOW}${LANG[SYNC_UFW_NO_CHANGES]}${COLOR_RESET}"
    fi

    printf "${COLOR_YELLOW}${sync_ufw_summary}${COLOR_RESET}\n" "$selected_name" "$rules_added" "$rules_existing" "$add_failed"

    if [ "$add_failed" -eq 1 ]; then
        return 1
    fi
}

#Manage Panel Access
show_panel_access() {
    echo -e ""
    echo -e "${COLOR_GREEN}${LANG[MENU_9]}${COLOR_RESET}"
    echo -e ""
    echo -e "${COLOR_YELLOW}1. ${LANG[PORT_8443_OPEN]}${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}2. ${LANG[PORT_8443_CLOSE]}${COLOR_RESET}"
    echo -e ""
    echo -e "${COLOR_YELLOW}0. ${LANG[EXIT]}${COLOR_RESET}"
    echo -e ""
}

manage_panel_access() {
    show_panel_access
    reading "${LANG[IPV6_PROMPT]}" ACCESS_OPTION
    case $ACCESS_OPTION in
        1)
            open_panel_access
            ;;
        2)
            close_panel_access
            ;;
        0)
            echo -e "${COLOR_YELLOW}${LANG[EXIT]}${COLOR_RESET}"
            sleep 2
            log_clear
            remnawave_reverse
            ;;
        *)
            echo -e "${COLOR_YELLOW}${LANG[IPV6_INVALID_CHOICE]}${COLOR_RESET}"
            ;;
    esac
    sleep 2
    log_clear
    manage_panel_access
}

open_panel_access() {
    local dir=""
    if [ -d "/opt/remnawave" ]; then
        dir="/opt/remnawave"
    elif [ -d "/opt/remnanode" ]; then
        dir="/opt/remnanode"
    else
        echo -e "${COLOR_RED}${LANG[DIR_NOT_FOUND]}${COLOR_RESET}"
        exit 1
    fi

    cd "$dir" || { echo -e "${COLOR_RED}${LANG[CHANGE_DIR_FAILED]} $dir${COLOR_RESET}"; exit 1; }

    local webserver=""
    if [ -f "nginx.conf" ]; then
        webserver="nginx"
    elif [ -f "Caddyfile" ]; then
        webserver="caddy"
    else
        echo -e "${COLOR_RED}${LANG[CONFIG_NOT_FOUND]}${COLOR_RESET}"
        exit 1
    fi

    if [ "$webserver" = "nginx" ]; then
        PANEL_DOMAIN=$(grep -B 20 "proxy_pass http://remnawave" "$dir/nginx.conf" | grep "server_name" | grep -v "server_name _" | awk '{print $2}' | sed 's/;//' | head -n 1)

        cookie_line=$(grep -A 2 "map \$http_cookie \$auth_cookie" "$dir/nginx.conf" | grep "~*\w\+.*=")
        cookies_random1=$(echo "$cookie_line" | grep -oP '~*\K\w+(?==)')
        cookies_random2=$(echo "$cookie_line" | grep -oP '=\K\w+(?=")')

        if [ -z "$PANEL_DOMAIN" ] || [ -z "$cookies_random1" ] || [ -z "$cookies_random2" ]; then
            echo -e "${COLOR_RED}${LANG[NGINX_CONF_ERROR]}${COLOR_RESET}"
            exit 1
        fi

        if command -v ss >/dev/null 2>&1; then
            if ss -tuln | grep -q ":8443"; then
                echo -e "${COLOR_RED}${LANG[PORT_8443_IN_USE]}${COLOR_RESET}"
                exit 1
            fi
        elif command -v netstat >/dev/null 2>&1; then
            if netstat -tuln | grep -q ":8443"; then
                echo -e "${COLOR_RED}${LANG[PORT_8443_IN_USE]}${COLOR_RESET}"
                exit 1
            fi
        else
            echo -e "${COLOR_RED}${LANG[NO_PORT_CHECK_TOOLS]}${COLOR_RESET}"
            exit 1
        fi

        sed -i "/server_name $PANEL_DOMAIN;/,/}/{/^[[:space:]]*$/d; s/listen 8443 ssl;//}" "$dir/nginx.conf"
        sed -i "/server_name $PANEL_DOMAIN;/a \    listen 8443 ssl;" "$dir/nginx.conf"
        if [ $? -ne 0 ]; then
            echo -e "${COLOR_RED}${LANG[NGINX_CONF_MODIFY_FAILED]}${COLOR_RESET}"
            exit 1
        fi

        docker compose down remnawave-nginx > /dev/null 2>&1 &
        spinner $! "${LANG[WAITING]}"

        docker compose up -d remnawave-nginx > /dev/null 2>&1 &
        spinner $! "${LANG[WAITING]}"

        ufw allow from 0.0.0.0/0 to any port 8443 proto tcp > /dev/null 2>&1
        ufw reload > /dev/null 2>&1
        sleep 1

        local panel_link="https://${PANEL_DOMAIN}:8443/auth/login?${cookies_random1}=${cookies_random2}"
        echo -e "${COLOR_YELLOW}${LANG[OPEN_PANEL_LINK]}${COLOR_RESET}"
        echo -e "${COLOR_WHITE}${panel_link}${COLOR_RESET}"
        echo -e "${COLOR_RED}${LANG[PORT_8443_WARNING]}${COLOR_RESET}"
    elif [ "$webserver" = "caddy" ]; then
        PANEL_DOMAIN=$(grep 'PANEL_DOMAIN=' "$dir/docker-compose.yml" | head -n 1 | sed 's/.*PANEL_DOMAIN=//; s/[[:space:]]*$//')

        if [ -z "$PANEL_DOMAIN" ]; then
            echo -e "${COLOR_RED}${LANG[CADDY_CONF_ERROR]}${COLOR_RESET}"
            exit 1
        fi

        if grep -q "https://{\$PANEL_DOMAIN}:8443 {" "$dir/Caddyfile"; then
            echo -e "${COLOR_YELLOW}${LANG[PORT_8443_ALREADY_CONFIGURED]}${COLOR_RESET}"
            return 0
        fi

        if command -v ss >/dev/null 2>&1; then
            if ss -tuln | grep -q ":8443"; then
                echo -e "${COLOR_RED}${LANG[PORT_8443_IN_USE]}${COLOR_RESET}"
                exit 1
            fi
        elif command -v netstat >/dev/null 2>&1; then
            if netstat -tuln | grep -q ":8443"; then
                echo -e "${COLOR_RED}${LANG[PORT_8443_IN_USE]}${COLOR_RESET}"
                exit 1
            fi
        else
            echo -e "${COLOR_RED}${LANG[NO_PORT_CHECK_TOOLS]}${COLOR_RESET}"
            exit 1
        fi

        sed -i "s|redir https://{\$PANEL_DOMAIN}{uri} permanent|redir https://{\$PANEL_DOMAIN}:8443{uri} permanent|g" "$dir/Caddyfile"

        sed -i "s|https://{\$PANEL_DOMAIN} {|https://{\$PANEL_DOMAIN}:8443 {|g" "$dir/Caddyfile"
        sed -i "/https:\/\/{\$PANEL_DOMAIN}:8443 {/,/^}/ { /bind unix\/{\$CADDY_SOCKET_PATH}/d }" "$dir/Caddyfile"

        docker compose down remnawave-caddy > /dev/null 2>&1 &
        spinner $! "${LANG[WAITING]}"

        docker compose up -d remnawave-caddy > /dev/null 2>&1 &
        spinner $! "${LANG[WAITING]}"

        ufw allow from 0.0.0.0/0 to any port 8443 proto tcp > /dev/null 2>&1
        ufw reload > /dev/null 2>&1
        sleep 1

        local cookie_line=$(grep 'header +Set-Cookie' "$dir/Caddyfile" | head -n 1)
        local cookies_random1=$(echo "$cookie_line" | grep -oP 'Set-Cookie "\K[^=]+')
        local cookies_random2=$(echo "$cookie_line" | grep -oP 'Set-Cookie "[^=]+=\K[^;]+')

        local panel_link="https://${PANEL_DOMAIN}:8443/auth/login"
        if [ -n "$cookies_random1" ] && [ -n "$cookies_random2" ]; then
            panel_link="${panel_link}?${cookies_random1}=${cookies_random2}"
        fi
        echo -e "${COLOR_YELLOW}${LANG[OPEN_PANEL_LINK]}${COLOR_RESET}"
        echo -e "${COLOR_WHITE}${panel_link}${COLOR_RESET}"
        echo -e "${COLOR_RED}${LANG[PORT_8443_WARNING]}${COLOR_RESET}"
    fi
}

close_panel_access() {
    local dir=""
    if [ -d "/opt/remnawave" ]; then
        dir="/opt/remnawave"
    elif [ -d "/opt/remnanode" ]; then
        dir="/opt/remnanode"
    else
        echo -e "${COLOR_RED}${LANG[DIR_NOT_FOUND]}${COLOR_RESET}"
        exit 1
    fi

    cd "$dir" || { echo -e "${COLOR_RED}${LANG[CHANGE_DIR_FAILED]} $dir${COLOR_RESET}"; exit 1; }

    echo -e "${COLOR_YELLOW}${LANG[PORT_8443_CLOSE]}${COLOR_RESET}"

    local webserver=""
    if [ -f "nginx.conf" ]; then
        webserver="nginx"
    elif [ -f "Caddyfile" ]; then
        webserver="caddy"
    else
        echo -e "${COLOR_RED}${LANG[CONFIG_NOT_FOUND]}${COLOR_RESET}"
        exit 1
    fi

    if [ "$webserver" = "nginx" ]; then
        PANEL_DOMAIN=$(grep -B 20 "proxy_pass http://remnawave" "$dir/nginx.conf" | grep "server_name" | grep -v "server_name _" | awk '{print $2}' | sed 's/;//' | head -n 1)

        if [ -z "$PANEL_DOMAIN" ]; then
            echo -e "${COLOR_RED}${LANG[NGINX_CONF_ERROR]}${COLOR_RESET}"
            exit 1
        fi

        if grep -A 10 "server_name $PANEL_DOMAIN;" "$dir/nginx.conf" | grep -q "listen 8443 ssl;"; then
            sed -i "/server_name $PANEL_DOMAIN;/,/}/{/^[[:space:]]*$/d; s/listen 8443 ssl;//}" "$dir/nginx.conf"
            if [ $? -ne 0 ]; then
                echo -e "${COLOR_RED}${LANG[NGINX_CONF_MODIFY_FAILED]}${COLOR_RESET}"
                exit 1
            fi

            docker compose down remnawave-nginx > /dev/null 2>&1 &
            spinner $! "${LANG[WAITING]}"
            docker compose up -d remnawave-nginx > /dev/null 2>&1 &
            spinner $! "${LANG[WAITING]}"
        else
            echo -e "${COLOR_YELLOW}${LANG[PORT_8443_NOT_CONFIGURED]}${COLOR_RESET}"
        fi

        if ufw status | grep -q "8443.*ALLOW"; then
            ufw delete allow from 0.0.0.0/0 to any port 8443 proto tcp > /dev/null 2>&1
            ufw reload > /dev/null 2>&1
            if [ $? -ne 0 ]; then
                echo -e "${COLOR_RED}${LANG[UFW_RELOAD_FAILED]}${COLOR_RESET}"
                exit 1
            fi
            echo -e "${COLOR_GREEN}${LANG[PORT_8443_CLOSED]}${COLOR_RESET}"
        else
            echo -e "${COLOR_YELLOW}${LANG[PORT_8443_ALREADY_CLOSED]}${COLOR_RESET}"
        fi
    elif [ "$webserver" = "caddy" ]; then
        PANEL_DOMAIN=$(grep 'PANEL_DOMAIN=' "$dir/docker-compose.yml" | head -n 1 | sed 's/.*PANEL_DOMAIN=//; s/[[:space:]]*$//')

        if [ -z "$PANEL_DOMAIN" ]; then
            echo -e "${COLOR_RED}${LANG[CADDY_CONF_ERROR]}${COLOR_RESET}"
            exit 1
        fi

        if grep -q "https://{\$PANEL_DOMAIN}:8443 {" "$dir/Caddyfile"; then
            sed -i "s|https://{\$PANEL_DOMAIN}:8443 {|https://{\$PANEL_DOMAIN} {|g" "$dir/Caddyfile"

            sed -i "/https:\/\/{\$PANEL_DOMAIN} {/a \    bind unix/{\$CADDY_SOCKET_PATH}" "$dir/Caddyfile"

            sed -i "s|redir https://{\$PANEL_DOMAIN}:8443{uri} permanent|redir https://{\$PANEL_DOMAIN}{uri} permanent|g" "$dir/Caddyfile"

            docker compose down remnawave-caddy > /dev/null 2>&1 &
            spinner $! "${LANG[WAITING]}"
            docker compose up -d remnawave-caddy > /dev/null 2>&1 &
            spinner $! "${LANG[WAITING]}"
        else
            echo -e "${COLOR_YELLOW}${LANG[PORT_8443_NOT_CONFIGURED]}${COLOR_RESET}"
        fi

        if ufw status | grep -q "8443.*ALLOW"; then
            ufw delete allow from 0.0.0.0/0 to any port 8443 proto tcp > /dev/null 2>&1
            ufw reload > /dev/null 2>&1
            if [ $? -ne 0 ]; then
                echo -e "${COLOR_RED}${LANG[UFW_RELOAD_FAILED]}${COLOR_RESET}"
                exit 1
            fi
            echo -e "${COLOR_GREEN}${LANG[PORT_8443_CLOSED]}${COLOR_RESET}"
        else
            echo -e "${COLOR_YELLOW}${LANG[PORT_8443_ALREADY_CLOSED]}${COLOR_RESET}"
        fi
    fi
}
