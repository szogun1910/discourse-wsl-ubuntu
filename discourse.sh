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
         1) show_discourse_menu ;;
         2) show_server_menu ;;
         3) show_dev_tools_menu ;;
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
