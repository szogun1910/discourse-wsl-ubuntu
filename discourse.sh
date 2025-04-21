#!/bin/bash

# Poprawa wykrywania ścieżki skryptu
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
DISCOURSE_DIR="$HOME/discourse"

# Importowanie modułów
source "$SCRIPT_DIR/modules/colors.sh"
source "$SCRIPT_DIR/modules/logging.sh"
source "$SCRIPT_DIR/modules/display.sh"
source "$SCRIPT_DIR/modules/system.sh"
source "$SCRIPT_DIR/modules/discourse.sh"
source "$SCRIPT_DIR/modules/server.sh"
source "$SCRIPT_DIR/modules/debug.sh"

# Sprawdzenie i naprawa uprawnień
if [ ! -x "$SCRIPT_PATH" ]; then
    chmod +x "$SCRIPT_PATH" || {
        echo "Błąd: Nie można ustawić uprawnień wykonywania dla skryptu"
        echo "Spróbuj ręcznie: chmod +x $SCRIPT_PATH"
        exit 1
    }
fi

# Sprawdzenie czy skrypt jest uruchamiany jako skrypt powłoki
if [ -z "$BASH" ]; then
    echo "Ten skrypt wymaga powłoki Bash"
    echo "Uruchom: bash $SCRIPT_PATH"
    exit 1
fi

# Tworzenie katalogów jeśli nie istnieją
mkdir -p "$DISCOURSE_DIR"
mkdir -p "$DISCOURSE_DIR/log"

# Sprawdzenie czy skrypt jest uruchamiany z właściwego katalogu
if [ "$PWD" != "$SCRIPT_DIR" ]; then
    cd "$SCRIPT_DIR" || {
        echo "Nie można przejść do katalogu skryptu: $SCRIPT_DIR"
        exit 1
    }
fi

# Główna pętla menu
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
                    1) install_discourse; read -p "$(echo -e ${CYAN}Naciśnij Enter, aby kontynuować...${RESET})" ;;
                    2) update_discourse; read -p "$(echo -e ${CYAN}Naciśnij Enter, aby kontynuować...${RESET})" ;;
                    3) remove_discourse; read -p "$(echo -e ${CYAN}Naciśnij Enter, aby kontynuować...${RESET})" ;;
                    4) install_plugin; read -p "$(echo -e ${CYAN}Naciśnij Enter, aby kontynuować...${RESET})" ;;
                    0) break ;;
                    *) print_error "Nieprawidłowa opcja!"; read -p "$(echo -e ${CYAN}Naciśnij Enter, aby kontynuować...${RESET})" ;;
                esac
            done
            ;;
        2)
            while true; do
                clear
                show_server_menu
                read -p "Wybierz opcję: " subchoice
                case $subchoice in
                    1) clean_ports 3000 4200 9292 1080; read -p "$(echo -e ${CYAN}Naciśnij Enter, aby kontynuować...${RESET})" ;;
                    2) start_discourse; read -p "$(echo -e ${CYAN}Naciśnij Enter, aby kontynuować...${RESET})" ;;
                    3) debug_discourse; read -p "$(echo -e ${CYAN}Naciśnij Enter, aby kontynuować...${RESET})" ;;
                    4) stop_discourse; read -p "$(echo -e ${CYAN}Naciśnij Enter, aby kontynuować...${RESET})" ;;
                    0) break ;;
                    *) print_error "Nieprawidłowa opcja!"; read -p "$(echo -e ${CYAN}Naciśnij Enter, aby kontynuować...${RESET})" ;;
                esac
            done
            ;;
        3)
            while true; do
                clear
                show_dev_tools_menu
                echo -ne "${GREEN}Wybierz opcję:${RESET} "
                read subchoice

                case $subchoice in
                    1) execute_with_logging "cd '$HOME/discourse' && RAILS_ENV=development bundle exec rails server" "Uruchomienie serwera Rails" ;;
                    2) execute_with_logging "cd '$HOME/discourse' && RAILS_ENV=development bundle exec rails console" "Uruchomienie konsoli Rails" ;;
                    3) execute_with_logging "cd '$HOME/discourse' && RAILS_ENV=test bundle exec rspec" "Uruchomienie testów RSpec" ;;
                    4) execute_with_logging "cd '$HOME/discourse' && yarn lint:js" "Uruchomienie ESLint" ;;
                    5) execute_with_logging "cd '$HOME/discourse' && yarn run ember server" "Uruchomienie serwera Ember" ;;
                    6)
                        log_message "INFO" "Instalacja pg_vector dla PostgreSQL"
                        if ! command -v psql &> /dev/null; then
                            print_error "PostgreSQL nie jest zainstalowany!"
                            read -rp "$(echo -e ${CYAN}Naciśnij Enter, aby kontynuować...${RESET})"
                            continue
                        fi
                        TEMP_DIR=$(mktemp -d)
                        execute_with_logging "sudo apt-get update && sudo apt-get install -y postgresql-server-dev-all git build-essential" "Instalacja zależności"
                        execute_with_logging "cd '$TEMP_DIR' && git clone https://github.com/pgvector/pgvector.git && cd pgvector && make && sudo make install" "Instalacja pg_vector"
                        execute_with_logging "sudo -u postgres psql -d discourse_development -c 'CREATE EXTENSION IF NOT EXISTS vector;'" "Aktywacja rozszerzenia w bazie development"
                        execute_with_logging "sudo -u postgres psql -d discourse_test -c 'CREATE EXTENSION IF NOT EXISTS vector;'" "Aktywacja rozszerzenia w bazie test"
                        rm -rf "$TEMP_DIR"
                        print_success "pg_vector został zainstalowany pomyślnie."
                        read -rp "$(echo -e ${CYAN}Naciśnij Enter, aby kontynuować...${RESET})"
                        ;;
                    7) toggle_debug; read -rp "$(echo -e ${CYAN}Naciśnij Enter, aby kontynuować...${RESET})" ;;
                    8) 
                        if [ -f "$LOG_FILE" ]; then
                            less "$LOG_FILE"
                        else
                            print_error "Plik logów nie istnieje"
                        fi
                        read -rp "$(echo -e ${CYAN}Naciśnij Enter, aby kontynuować...${RESET})"
                        ;;
                    0) break ;;
                    *) print_error "Nieprawidłowa opcja!"; read -p "$(echo -e ${CYAN}Naciśnij Enter, aby kontynuować...${RESET})" ;;
                esac
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
