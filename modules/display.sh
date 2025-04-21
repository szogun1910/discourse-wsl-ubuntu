#!/bin/bash

# Upewnij się, że kolory są zdefiniowane
if [ -z "$GREEN" ] || [ -z "$RESET" ]; then
    echo "ERROR: Moduł colors.sh musi być załadowany przed display.sh"
    exit 1
fi

# Stałe dla menu
MENU_WIDTH=45
BORDER_TOP="${BLUE}${BOLD}\u2554$(printf '\u2550%.0s' $(seq 1 $((MENU_WIDTH-2))))\u2557${RESET}"
BORDER_BOTTOM="${BLUE}${BOLD}\u255a$(printf '\u2550%.0s' $(seq 1 $((MENU_WIDTH-2))))\u255d${RESET}"

# Podstawowe funkcje wyświetlania
print_header() {
    local title="$1"
    local title_length=${#title}
    local padding=$(( (MENU_WIDTH - 2 - title_length) / 2 ))
    local left_padding=$padding
    local right_padding=$padding

    echo -e "$BORDER_TOP"
    echo -e "${BLUE}${BOLD}\u2551${RESET}$(printf ' %.0s' $(seq 1 $left_padding))${CYAN}${BOLD}${title}${RESET}$(printf ' %.0s' $(seq 1 $right_padding))${BLUE}${BOLD}\u2551${RESET}"
    echo -e "$BORDER_BOTTOM"
}

print_option() {
    local number="$1"
    local text="$2"
    echo -e "${YELLOW}${BOLD}$number.${RESET} ${WHITE}$text${RESET}"
}

print_separator() {
    echo -e "${BLUE}${BOLD}$(printf '%.0s\u2500' $(seq 1 $MENU_WIDTH))${RESET}"
}

# Menu systemowe
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
    print_option "1" "Uruchom serwer Rails"
    print_option "2" "Uruchom konsolę Rails"
    print_option "3" "Uruchom testy RSpec"
    print_option "4" "Uruchom ESLint"
    print_option "5" "Uruchom Ember server"
    print_option "6" "Zainstaluj pg_vector"
    print_option "7" "Debug mode (${DEBUG_MODE:-false})"
    print_option "8" "Pokaż logi"
    print_option "0" "Powrót"
    print_separator
}