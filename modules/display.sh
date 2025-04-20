#!/bin/bash

# Funkcje pomocnicze do formatowania
print_header() {
    local title="$1"
    local title_length=${#title}
    local padding=$(( (MENU_WIDTH - 2 - title_length) / 2 ))
    local left_padding=$padding
    local right_padding=$padding
    
    # Korekta dla nieparzystej długości
    if (( (MENU_WIDTH - 2 - title_length) % 2 != 0 )); then
        right_padding=$((right_padding + 1))
    fi
    
    echo -e "$BORDER_TOP"
    echo -e "${BLUE}${BOLD}║${RESET}$(printf ' %.0s' $(seq 1 $left_padding))${CYAN}${BOLD}${title}${RESET}$(printf ' %.0s' $(seq 1 $right_padding))${BLUE}${BOLD}║${RESET}"
    echo -e "$BORDER_BOTTOM"
}

print_option() {
    local number="$1"
    local text="$2"
    echo -e "${YELLOW}${BOLD}$number.${RESET} ${WHITE}$text${RESET}"
}

print_separator() {
    echo -e "${BLUE}${BOLD}$(printf '%.0s─' $(seq 1 $MENU_WIDTH))${RESET}"
}

print_success() {
    echo -e "${GREEN}${BOLD}✓${RESET} ${GREEN}$1${RESET}"
}

print_error() {
    echo -e "${RED}${BOLD}✗${RESET} ${RED}$1${RESET}"
}

print_warning() {
    echo -e "${YELLOW}${BOLD}⚠${RESET} ${YELLOW}$1${RESET}"
}

print_info() {
    echo -e "${CYAN}${BOLD}ℹ${RESET} ${CYAN}$1${RESET}"
}

print_loading() {
    local text="$1"
    echo -ne "${BLUE}${BOLD}⟳${RESET} ${BLUE}$text...${RESET}\r"
}

# Funkcje menu
show_discourse_menu() {
    print_header "Zarządzanie Discourse"
    print_option "1" "Instalacja"
    print_option "2" "Aktualizacja"
    print_option "3" "Usuń"
    print_option "4" "Instaluj plugin"
    print_option "0" "Powrót"
    print_separator
}

show_server_menu() {
    print_header "Zarządzanie serwerem"
    print_option "1" "Zwolnij porty"
    print_option "2" "Uruchom Discourse"
    print_option "3" "Debugowanie Discourse"
    print_option "4" "Zatrzymaj Discourse"
    print_option "0" "Powrót"
    print_separator
}

show_dev_tools_menu() {
    print_header "Narzędzia developerskie"
    print_option "1" "Uruchom serwer Rails (rails s)"
    print_option "2" "Uruchom konsolę Rails"
    print_option "3" "Uruchom testy RSpec"
    print_option "4" "Uruchom ESLint"
    print_option "5" "Uruchom Ember server"
    print_option "6" "Zainstaluj pg_vector"
    print_option "7" "Debug mode (${DEBUG_MODE})"
    print_option "8" "Pokaż logi"
    print_option "0" "Powrót"
    print_separator
}