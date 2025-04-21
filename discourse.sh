#!/bin/bash

###############################################################################
# Wymaga załadowania modułów z katalogu ./modules/
# modules/colors.sh     # moduł kolorów (wymagany przez wszystkie inne)
# modules/config.sh     # moduł konfiguracji (wymagany przez system.sh)
# modules/debug.sh      # moduł debugowania (wymagany przez system.sh)
# modules/discourse.sh  # moduł zarządzania Discourse
# modules/logging.sh    # moduł logowania
# modules/server.sh     # moduł zarządzania serwerem
# modules/system.sh     # moduł systemowy (wymagany przez wszystkie inne)
# modules/display.sh    # moduł wyświetlania (wymagany przez menu)
###############################################################################

# Ścieżki
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
MODULE_DIR="$SCRIPT_DIR/modules"
LOGS_DIR="$SCRIPT_DIR/logs"

# Inicjalizacja katalogów
mkdir -p "$LOGS_DIR"
chmod 755 "$LOGS_DIR"

# Export ścieżek logów
export SCRIPT_LOG_DIR="$LOGS_DIR"
export LOG_FILE="$LOGS_DIR/script.log"
export DEBUG_LOG="$LOGS_DIR/debug.log"
export TRACE_LOG="$LOGS_DIR/trace.log"
export PERFORMANCE_LOG="$LOGS_DIR/performance.log"
export TRANSCRIPT_FILE="$LOGS_DIR/console.log"

# Inicjalizacja plików logów
for log_file in "$LOG_FILE" "$DEBUG_LOG" "$TRACE_LOG" "$PERFORMANCE_LOG" "$TRANSCRIPT_FILE"; do
    touch "$log_file"
    chmod 644 "$log_file"
done

# Włączamy debugowanie powłoki
set -x

# Ładowanie modułów w prawidłowej kolejności
CORE_MODULES=(
    "colors.sh"    # Podstawowe kolory
    "logging.sh"   # Podstawowe logowanie
    "display.sh"   # Interfejs użytkownika
)

SYSTEM_MODULES=(
    "config.sh"    # Konfiguracja systemu
    "system.sh"    # Funkcje systemowe
    "server.sh"    # Zarządzanie serwerem
    "debug.sh"     # Debugowanie
    "discourse.sh" # Zarządzanie Discourse
)

# Ładowanie modułów podstawowych
for module in "${CORE_MODULES[@]}"; do
    if ! source "$MODULE_DIR/$module" 2>/dev/null; then
        echo "ERROR: Nie można załadować podstawowego modułu $module"
        exit 1
    fi
done

# Ładowanie modułów systemowych
for module in "${SYSTEM_MODULES[@]}"; do
    if ! source "$MODULE_DIR/$module" 2>/dev/null; then
        echo "ERROR: Nie można załadować modułu systemowego $module"
        exit 1
    fi
done

# Wyłączamy debugowanie powłoki
set +x

# Inicjalizacja logowania
if type init_logging &>/dev/null; then
    init_logging
else
    echo "ERROR: Funkcja init_logging nie jest dostępna"
    exit 1
fi

# Główne menu
while true; do
    clear
    print_header "Panel zarządzania Discourse"
    echo
    print_option "1" "Zarządzanie Discourse"
    print_option "2" "Zarządzanie serwerem"
    print_option "3" "Narzędzia developerskie"
    print_option "0" "Wyjście"
    print_separator

    echo -ne "${GREEN}Wybierz opcję:${RESET} "
    read choice

    case $choice in
        1)
            while true; do
                clear
                show_discourse_menu
                read -p "Wybierz opcję: " subchoice
                case $subchoice in
                    1) 
                        log_message "INFO" "Rozpoczęcie instalacji Discourse"
                        install_discourse
                        ;;
                    2)
                        log_message "INFO" "Rozpoczęcie aktualizacji Discourse"
                        update_discourse
                        ;;
                    3)
                        log_message "INFO" "Rozpoczęcie usuwania Discourse"
                        remove_discourse
                        ;;
                    4)
                        log_message "INFO" "Rozpoczęcie instalacji pluginu"
                        install_plugin
                        ;;
                    0)
                        break
                        ;;
                    *)
                        print_error "Nieprawidłowa opcja!"
                        ;;
                esac
                read -rp "$(echo -e ${CYAN}Naciśnij Enter, aby kontynuować...${RESET})"
            done
            ;;
        2)
            while true; do
                clear
                show_server_menu
                read -p "Wybierz opcję: " subchoice
                case $subchoice in
                    1)
                        log_message "INFO" "Czyszczenie portów"
                        clean_ports "${DISCOURSE_PORTS[@]}"
                        ;;
                    2)
                        log_message "INFO" "Uruchamianie Discourse"
                        start_discourse
                        ;;
                    3)
                        log_message "INFO" "Uruchamianie w trybie debug"
                        start_debug_discourse
                        ;;
                    4)
                        log_message "INFO" "Zatrzymywanie Discourse"
                        stop_discourse
                        ;;
                    0)
                        break
                        ;;
                    *)
                        print_error "Nieprawidłowa opcja!"
                        ;;
                esac
                read -rp "$(echo -e ${CYAN}Naciśnij Enter, aby kontynuować...${RESET})"
            done
            ;;
        3)
            while true; do
                clear
                show_dev_tools_menu
                echo -ne "${GREEN}Wybierz opcję:${RESET} "
                read subchoice

                case $subchoice in
                     1)
                        execute_with_logging "cd '$HOME/discourse' && RAILS_ENV=development bundle exec rails server" "Uruchomienie serwera Rails"
                        ;;
                    2)
                        execute_with_logging "cd '$HOME/discourse' && RAILS_ENV=development bundle exec rails console" "Uruchomienie konsoli Rails"
                        ;;
                    3)
                        execute_with_logging "cd '$HOME/discourse' && RAILS_ENV=test bundle exec rspec" "Uruchomienie testów RSpec"
                        ;;
                    4)
                        execute_with_logging "cd '$HOME/discourse' && yarn lint:js" "Uruchomienie ESLint"
                        ;;
                    5)
                        execute_with_logging "cd '$HOME/discourse' && yarn run ember server" "Uruchomienie serwera Ember"
                        ;;
                    6)
                        install_pgvector
                        ;;
                    7)
                        toggle_debug
                        ;;
                    8)
                        if [ -f "$LOG_FILE" ]; then
                            less "$LOG_FILE"
                        else
                            print_error "Plik logów nie istnieje"
                        fi
                        ;;
                    0)
                        break
                        ;;
                    *)
                        print_error "Nieprawidłowa opcja!"
                        ;;
                esac
                read -rp "$(echo -e ${CYAN}Naciśnij Enter, aby kontynuować...${RESET})"
            done
            ;;
        0)
            log_message "INFO" "Zamykanie programu"
            print_info "Zamykanie programu..."
            exit 0
            ;;
        *)
            print_error "Nieprawidłowa opcja!"
            read -p "$(echo -e ${CYAN}Naciśnij Enter, aby kontynuować...${RESET})"
            ;;
    esac
done