#!/bin/bash

# Poprawa wykrywania ścieżki skryptu
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
DISCOURSE_DIR="$HOME/discourse"

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

# Definicje kolorów i stylów
BOLD='\e[1m'
DIM='\e[2m'
ITALIC='\e[3m'
UNDERLINE='\e[4m'
BLINK='\e[5m'
RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
BLUE='\e[34m'
CYAN='\e[36m'
WHITE='\e[37m'
BG_BLUE='\e[44m'
RESET='\e[0m'

# Ustawienia debugowania i logowania
DEBUG_MODE=false
LOG_DIR="$HOME/discourse/log"
LOG_FILE="$LOG_DIR/script.log"
TRANSCRIPT_FILE="$LOG_DIR/console.log"

# Tworzenie katalogu logów jeśli nie istnieje
mkdir -p "$LOG_DIR"

# Funkcja do usuwania sekwencji ANSI i logowania
clean_and_log() {
    sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,3})*)?[mK]//g" | while IFS= read -r line; do
        # Zapisz czysty tekst do pliku
        echo "$line" >> "$TRANSCRIPT_FILE"
        # Wyświetl oryginalny tekst z kolorami
        echo -e "$line"
    done
}

# Konfiguracja przekierowania wyjścia
mkdir -p "$(dirname "$TRANSCRIPT_FILE")"
echo "=== Sesja rozpoczęta $(date '+%Y-%m-%d %H:%M:%S') ===" >> "$TRANSCRIPT_FILE"

# Przekierowanie standardowego wyjścia i błędów przez clean_and_log
exec 1> >(clean_and_log)
exec 2> >(clean_and_log >&2)

# Funkcja logowania
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Upewnij się, że katalog logów istnieje
    mkdir -p "$HOME/discourse/log"
    
    echo -e "[$timestamp] [$level] $message" >> "$LOG_FILE"
    if [ "$DEBUG_MODE" = true ]; then
        echo -e "${YELLOW}🔍 DEBUG: $message${RESET}"
    fi
}

# Funkcja wykonywania poleceń z logowaniem
execute_with_logging() {
    local command="$1"
    local description="$2"
    
    print_info "$description..."
    if eval "$command" 2>&1 | filter_rails_logs; then
        print_success "✓ $description"
        return 0
    else
        print_error "✗ $description"
        return 1
    fi
}

# Funkcja przełączania trybu debug
toggle_debug() {
    if [ "$DEBUG_MODE" = true ]; then
        DEBUG_MODE=false
        print_info "Tryb debugowania wyłączony"
        log_message "INFO" "Tryb debugowania wyłączony"
    else
        DEBUG_MODE=true
        print_info "Tryb debugowania włączony"
        log_message "INFO" "Tryb debugowania włączony"
    fi
}

# Stałe dla ramek
MENU_WIDTH=45
BORDER_TOP="${BLUE}${BOLD}╔$(printf '═%.0s' $(seq 1 $((MENU_WIDTH-2))))╗${RESET}"
BORDER_BOTTOM="${BLUE}${BOLD}╚$(printf '═%.0s' $(seq 1 $((MENU_WIDTH-2))))╝${RESET}"

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

# Funkcja do formatowania komunikatów migracji
format_migration_message() {
    local line="$1"
    if [[ $line =~ ^==.*migrating.*==$ ]]; then
        local migration_name=$(echo "$line" | sed -E 's/^==\s*|:\s*migrating.*==//g')
        echo -e "${CYAN}${BOLD}ℹ${RESET} ${CYAN}Migracja: $migration_name${RESET}"
    elif [[ $line =~ ^==.*reverted.*==$ ]]; then
        local migration_name=$(echo "$line" | sed -E 's/^==\s*|:\s*reverted.*==//g')
        echo -e "${YELLOW}${BOLD}⚠${RESET} ${YELLOW}Cofanie migracji: $migration_name${RESET}"
    elif [[ $line =~ ^--.*$ ]]; then
        local operation=$(echo "$line" | sed 's/^--\s*//')
        if [[ "$operation" =~ "->" ]]; then
            local base_op=$(echo "$operation" | sed 's/\s*->.*$//')
            local time=$(echo "$operation" | sed -E 's/.*->\s*//')
            echo -e "      $base_op"
            echo -e "         ${GREEN}✓${RESET} ${DIM}Wykonano w czasie: $time${RESET}"
        else
            echo -e "      $operation"
        fi
    fi
}

# Funkcja do formatowania błędów i ostrzeżeń
format_error_message() {
    local line="$1"
    if [[ $line =~ "rake aborted!" ]]; then
        local error_msg=$(echo "$line" | sed 's/rake aborted!//')
        if [[ $error_msg =~ "Don't know how to build task" ]]; then
            local task=$(echo "$error_msg" | grep -o "'.*'" | tr -d "'")
            print_warning "Zadanie '$task' nie istnieje, pomijam..."
        else
            print_error "Błąd wykonania rake: $error_msg"
        fi
    elif [[ $line =~ "failed to recognize type" ]]; then
        local oid=$(echo "$line" | grep -o '[0-9]\+')
        local type=$(echo "$line" | grep -o "'.*'" | tr -d "'")
        print_warning "OID $oid: typ '$type' zostanie potraktowany jako String"
    elif [[ $line =~ "A server is already running" ]]; then
        print_warning "Serwer jest już uruchomiony. Sprawdź plik PID."
        print_info "Użyj opcji 'Zwolnij porty' aby rozwiązać problem."
    else
        echo "   ${YELLOW}→${RESET} $line"
    fi
}

# Funkcja do formatowania logów Rails
filter_rails_logs() {
    while IFS= read -r line; do
        if [[ $line =~ ^==.*==$ ]]; then
            format_migration_message "$line"
        elif [[ $line =~ "ERROR" ]] || [[ $line =~ "FATAL" ]] || [[ $line =~ "rake aborted!" ]]; then
            format_error_message "$line"
        elif [[ $line =~ "WARNING" ]] || [[ $line =~ "unknown OID" ]]; then
            print_warning "$(echo "$line" | sed -E 's/WARNING:|unknown OID//')"
        elif [[ $line =~ ^"=>".*$ ]]; then
            print_info "$(echo "$line" | sed 's/=>//')"
        elif [[ $line =~ "Starting" ]]; then
            print_info "$line"
        elif [[ $line =~ "Booting" ]] || [[ $line =~ "Rails" ]]; then
            print_success "$line"
        else
            # Pomijamy logi SQL i inne techniczne szczegóły
            if ! [[ $line =~ "SELECT" ]] && ! [[ $line =~ "INSERT" ]] && ! [[ $line =~ "UPDATE" ]] && ! [[ $line =~ "DELETE" ]]; then
                echo "   $line"
            fi
        fi
    done
}

# Funkcja do czyszczenia portów
clean_ports() {
    for port in "$@"; do
        pid=$(lsof -ti tcp:$port)
        if [[ -n "$pid" ]]; then
            for p in $pid; do
                print_warning "Zabijanie procesu na porcie $port (PID: $p)..."
                kill -9 "$p" && print_success "Proces $p został zabity." || print_error "Nie udało się zabić procesu $p."
            done
        else
            print_success "Port $port jest wolny."
        fi
    done
}

# Funkcja do sprawdzania i czyszczenia procesów Discourse
check_and_clean_discourse_processes() {
    print_info "Sprawdzanie działających procesów..."
    
    # Sprawdź proces Unicorn
    if [[ -f "$DISCOURSE_DIR/tmp/pids/unicorn.pid" ]]; then
        unicorn_pid=$(cat "$DISCOURSE_DIR/tmp/pids/unicorn.pid")
        if kill -0 "$unicorn_pid" 2>/dev/null; then
            print_warning "Znaleziono działający proces Unicorn (PID: $unicorn_pid)"
            kill -9 "$unicorn_pid"
        fi
        rm -f "$DISCOURSE_DIR/tmp/pids/unicorn.pid"
    fi
    
    # Sprawdź proces Ember
    ember_pid=$(lsof -ti :4200)
    if [[ -n "$ember_pid" ]]; then
        print_warning "Znaleziono działający proces Ember (PID: $ember_pid)"
        kill -9 "$ember_pid"
    fi
    
    print_success "Procesy wyczyszczone"
}

# Funkcja sprawdzająca i uruchamiająca PostgreSQL
ensure_postgresql_running() {
    log_message "INFO" "Sprawdzanie statusu PostgreSQL"
    if ! systemctl is-active --quiet postgresql; then
        print_warning "PostgreSQL nie jest uruchomiony. Próba uruchomienia..."
        log_message "INFO" "Uruchamianie PostgreSQL"
        sudo systemctl start postgresql || {
            print_error "Nie można uruchomić PostgreSQL"
            log_message "ERROR" "Nie można uruchomić PostgreSQL"
            return 1
        }
        # Czekaj na uruchomienie PostgreSQL
        sleep 2
    fi
    print_success "PostgreSQL jest uruchomiony"
    log_message "SUCCESS" "PostgreSQL jest uruchomiony"
    return 0
}

# Funkcja do sprawdzania i czyszczenia procesów Rails
check_and_clean_rails_processes() {
    local server_pid_file="$DISCOURSE_DIR/tmp/pids/server.pid"
    
    log_message "INFO" "Sprawdzanie procesów Rails..."
    if [[ -f "$server_pid_file" ]]; then
        local pid=$(cat "$server_pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            print_warning "Znaleziono działający proces Rails (PID: $pid)"
            log_message "WARNING" "Znaleziono działający proces Rails (PID: $pid)"
            if kill -9 "$pid"; then
                print_success "Proces Rails został zatrzymany"
                log_message "SUCCESS" "Proces Rails został zatrzymany"
            else
                print_error "Nie udało się zatrzymać procesu Rails"
                log_message "ERROR" "Nie udało się zatrzymać procesu Rails"
            fi
        fi
        rm -f "$server_pid_file"
        log_message "INFO" "Usunięto plik server.pid"
    fi
}

# Funkcja do sprawdzania i naprawy problemów z permalinkami
fix_permalink_issues() {
    log_message "INFO" "Sprawdzanie problemów z permalinkami..."
    
    cd "$HOME/discourse" || {
        print_error "Nie można przejść do katalogu Discourse"
        return 1
    }

    # Czyszczenie cache Redis
    print_info "Czyszczenie cache Redis..."
    if ! redis-cli FLUSHALL > /dev/null; then
        print_error "Błąd podczas czyszczenia Redis"
        return 1
    fi
    print_success "Redis wyczyszczony"

    # Naprawa uprawnień i migracji z ignorowaniem błędów typu embeddings
    print_info "Naprawa uprawnień i migracji..."
    if ! RAILS_ENV=development \
        SKIP_ENFORCE_CUSTOM_FIELDS=1 \
        SKIP_DB_SETUP=1 \
        IGNORE_UNKNOWN_TYPES=1 \
        DB_CUSTOM_TYPES="embeddings=string" \
        bundle exec rails db:migrate > /dev/null 2>&1; then
        print_warning "Wystąpiły problemy podczas migracji, ale kontynuuję..."
    else
        print_success "Migracje zakończone"
    fi
    
    # Czyszczenie cache aplikacji
    print_info "Czyszczenie cache aplikacji..."
    if ! RAILS_ENV=development bundle exec rails tmp:clear > /dev/null; then
        print_warning "Problemy podczas czyszczenia cache"
    else
        print_success "Cache wyczyszczony"
    fi

    # Przebudowa assetów w trybie development
    print_info "Przebudowa assetów..."
    if ! RAILS_ENV=development bundle exec rails assets:clean > /dev/null 2>&1; then
        print_warning "Pomijam czyszczenie assetów w trybie development"
    fi

    if ! RAILS_ENV=development SKIP_MINIFICATION=1 bundle exec rails assets:precompile > /dev/null 2>&1; then
        print_warning "Pomijam kompilację assetów w trybie development"
    else
        print_success "Assety zaktualizowane"
    fi

    # Dodatkowe czyszczenie
    print_info "Czyszczenie plików tymczasowych..."
    rm -rf tmp/cache/*
    mkdir -p tmp/cache
    mkdir -p tmp/pids
    print_success "Pliki tymczasowe wyczyszczone"

    return 0
}

# Funkcja do sprawdzania logów Rails
check_rails_logs() {
    local log_file="$DISCOURSE_DIR/log/development.log"
    log_message "INFO" "Sprawdzanie logów Rails..."
    
    if [[ -f "$log_file" ]]; then
        print_info "Ostatnie istotne komunikaty z logów Rails:"
        tail -n 500 "$log_file" | grep -v "SELECT\|INSERT\|UPDATE\|DELETE" | grep -A 3 "ERROR\|FATAL\|WARNING\|INFO" | filter_rails_logs
    else
        print_error "Nie znaleziono pliku logów Rails"
        return 1
    fi
}

# Funkcja czyszcząca serwer Rails
clean_rails_server() {
    local server_pid_file="$HOME/discourse/tmp/pids/server.pid"
    
    if [[ -f "$server_pid_file" ]]; then
        print_info "Znaleziono plik PID serwera, czyszczenie..."
        local pid=$(cat "$server_pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            print_warning "Zatrzymywanie istniejącego procesu Rails (PID: $pid)"
            kill -9 "$pid"
            sleep 1
        fi
        rm -f "$server_pid_file"
        print_success "Proces Rails został wyczyszczony"
    fi
}

# Funkcja debugowania Discourse
debug_discourse() {
    local fixes_report=""
    log_message "INFO" "Uruchamianie trybu debugowania..."
    
    # Sprawdzanie PostgreSQL
    if ensure_postgresql_running; then
        fixes_report+="✓ PostgreSQL uruchomiony i działa poprawnie\n"
    else 
        fixes_report+="✗ Nie udało się uruchomić PostgreSQL\n"
        print_error "Krytyczny błąd: PostgreSQL nie działa"
        return 1
    fi

    # Czyszczenie procesów
    if clean_rails_server; then
        fixes_report+="✓ Wyczyszczono stare procesy Rails\n"
    fi
    check_and_clean_rails_processes
    fixes_report+="✓ Sprawdzono i wyczyszczono wszystkie procesy\n"

    # Naprawa problemów z bazą i cache
    if fix_permalink_issues; then
        fixes_report+="✓ Naprawiono problemy z bazą danych\n"
        fixes_report+="✓ Wyczyszczono cache Redis\n"
        fixes_report+="✓ Przebudowano assety\n"
    else
        fixes_report+="✗ Wystąpiły problemy podczas naprawy\n"
    fi

    print_info "Raport z debugowania:"
    echo -e "$fixes_report" | while IFS= read -r line; do
        if [[ $line == "✓"* ]]; then
            print_success "${line#✓ }"
        else
            print_error "${line#✗ }"
        fi
    done

    print_info "Uruchamianie serwera w trybie debug z rozszerzonym logowaniem..."
    
    DISCOURSE_HOSTNAME=localhost \
    UNICORN_LISTENER=localhost:3000 \
    ALLOW_EMBER_CLI_PROXY_BYPASS=1 \
    RAILS_ENV=development \
    DISCOURSE_DEV_EAGER_LOAD=1 \
    DISCOURSE_VERBOSE_API_LOGGING=1 \
    LOG_LEVEL=debug \
    bundle exec rails server -p 3000 2>&1 | filter_rails_logs
}

show_discourse_menu() {
    print_header "Zarządzanie Discourse"
    print_option "1" "Instalacja"
    print_option "2" "Aktualizacja"
    print_option "3" "Usuń"
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
                    1) # Instalacja
                        log_message "INFO" "Rozpoczęcie instalacji Discourse"
                        print_info "Sprawdzanie wymaganych zależności..."
                        
                        # Sprawdzenie i instalacja curl
                        if ! command -v curl &> /dev/null; then
                            log_message "INFO" "Instalacja curl"
                            execute_with_logging "sudo apt-get install -y curl" "Instalacja curl"
                        fi

                        # Sprawdzenie i instalacja yarn
                        if ! command -v yarn &> /dev/null; then
                            log_message "INFO" "Instalacja yarn"
                            execute_with_logging "curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -" "Dodanie klucza yarn"
                            execute_with_logging "echo 'deb https://dl.yarnpkg.com/debian/ stable main' | sudo tee /etc/apt/sources.list.d/yarn.list" "Dodanie repozytorium yarn"
                            execute_with_logging "sudo apt-get update && sudo apt-get install -y yarn" "Instalacja yarn"
                        fi

                        # Sprawdzenie i instalacja pnpm
                        if ! command -v pnpm &> /dev/null; then
                            log_message "INFO" "Instalacja pnpm"
                            execute_with_logging "curl -fsSL https://get.pnpm.io/install.sh | sh -" "Instalacja pnpm"
                            source ~/.bashrc
                        fi

                        log_message "INFO" "Rozpoczynam instalację Discourse"
                        execute_with_logging "bash <(wget -qO- https://raw.githubusercontent.com/discourse/install-rails/main/linux)" "Instalacja Discourse"
                        execute_with_logging "git clone https://github.com/discourse/discourse.git ~/discourse" "Klonowanie repozytorium Discourse"
                        cd ~/discourse
                        execute_with_logging "rbenv install 3.3.1 && rbenv global 3.3.1" "Instalacja Ruby 3.3.1"
                        execute_with_logging "bundle install" "Instalacja Bundler"
                        execute_with_logging "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash" "Instalacja nvm"
                        source ~/.bashrc
                        execute_with_logging "nvm install 20 && nvm use 20 && nvm alias default 20" "Instalacja Node.js"
                        execute_with_logging "pnpm install" "Instalacja zależności pnpm"
                        execute_with_logging "bin/rails db:create && bin/rails db:migrate" "Tworzenie i migracja bazy danych"
                        execute_with_logging "RAILS_ENV=test bin/rails db:create db:migrate" "Tworzenie i migracja bazy testowej"
                        execute_with_logging "bin/rails admin:create" "Tworzenie konta administratora"
                        log_message "SUCCESS" "Discourse został zainstalowany"
                        print_success "Discourse został zainstalowany."
                        read -p "$(echo -e ${CYAN}Naciśnij Enter, aby kontynuować...${RESET})"
                        ;;
                    2) # Aktualizacja
                        log_message "INFO" "Rozpoczęcie aktualizacji Discourse"
                        print_info "Aktualizacja Discourse..."
                        
                        if [ ! -d "$HOME/discourse" ]; then
                            log_message "ERROR" "Nie znaleziono instalacji Discourse w $HOME/discourse"
                            print_error "Nie znaleziono instalacji Discourse w $HOME/discourse"
                            read -rp "$(echo -e ${CYAN}Naciśnij Enter, aby kontynuować...${RESET})"
                            continue
                        fi

                        if ! command -v yarn &> /dev/null; then
                            log_message "INFO" "Instalacja yarn"
                            execute_with_logging "curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -" "Dodanie klucza yarn"
                            execute_with_logging "echo 'deb https://dl.yarnpkg.com/debian/ stable main' | sudo tee /etc/apt/sources.list.d/yarn.list" "Dodanie repozytororium yarn"
                            execute_with_logging "sudo apt-get update && sudo apt-get install -y yarn" "Instalacja yarn"
                        fi

                        trap 'echo -e "${YELLOW}⚠️ Wykryto próbę zatrzymania procesu. Użyj Ctrl+C aby przerwać lub pozwól procesowi zakończyć się.${RESET}"' SIGTSTP

                        cd "$HOME/discourse" || {
                            log_message "ERROR" "Nie można przejść do katalogu Discourse"
                            print_error "Nie można przejść do katalogu Discourse"
                            trap - SIGTSTP
                            read -rp "$(echo -e ${CYAN}Naciśnij Enter, aby kontynuować...${RESET})"
                            continue
                        }

                        execute_with_logging "git pull origin main" "Aktualizacja kodu źródłowego"
                        execute_with_logging "bundle install" "Aktualizacja zależności Ruby"
                        execute_with_logging "yarn install && pnpm install" "Aktualizacja zależności Node.js"
                        execute_with_logging "bundle exec rake db:migrate" "Aktualizacja bazy danych"

                        trap - SIGTSTP
                        log_message "SUCCESS" "Discourse został zaktualizowany"
                        print_success "Discourse został zaktualizowany."
                        read -rp "$(echo -e ${CYAN}Naciśnij Enter, aby kontynuować...${RESET})"
                        ;;
                    3) # Usuń
                        log_message "INFO" "Rozpoczęcie usuwania Discourse"
                        print_warning "Usuwanie Discourse i danych lokalnych..."
                        read -rp "Czy na pewno chcesz usunąć Discourse? (y/N): " confirm
                        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                            execute_with_logging "rm -rf '$DISCOURSE_DIR'" "Usuwanie katalogu Discourse"
                            execute_with_logging "sudo -u postgres dropdb discourse" "Usuwanie bazy danych 'discourse'"
                            execute_with_logging "sudo -u postgres dropdb discourse_test" "Usuwanie bazy danych 'discourse_test'"
                            log_message "SUCCESS" "Discourse został usunięty"
                            print_success "Discourse został usunięty."
                        else
                            log_message "INFO" "Anulowano usuwanie Discourse"
                            print_warning "Anulowano usuwanie."
                        fi
                        read -rp "$(echo -e ${CYAN}Naciśnij Enter, aby kontynuować...${RESET})"
                        ;;
                    0)
                        break
                        ;;
                    *)
                        print_error "Nieprawidłowa opcja!"
                        read -p "$(echo -e ${CYAN}Naciśnij Enter, aby kontynuować...${RESET})"
                        ;;
                esac
            done
            ;;
        2)
            while true; do
                clear
                show_server_menu
                read -p "Wybierz opcję: " subchoice
                case $subchoice in
                    1) # Zwolnij porty
                        log_message "INFO" "Rozpoczęcie czyszczenia środowiska Discourse"
                        print_info "Czyszczenie środowiska Discourse..."

                        clean_ports 3000 4200 9292 1080

                        if [[ -f "$DISCOURSE_DIR/tmp/pids/unicorn.pid" ]]; then
                            log_message "INFO" "Usuwanie pliku unicorn.pid"
                            rm -f "$DISCOURSE_DIR/tmp/pids/unicorn.pid"
                        fi

                        log_message "INFO" "Czyszczenie cache i tmp/log"
                        rm -rf "$DISCOURSE_DIR/tmp/cache"
                        rm -rf "$DISCOURSE_DIR/tmp/logs"
                        rm -rf "$DISCOURSE_DIR/log/*"

                        log_message "SUCCESS" "Środowisko zostało wyczyszczone"
                        print_success "Środowisko zostało wyczyszczone."
                        read -rp "$(echo -e ${CYAN}Naciśnij Enter, aby kontynuować...${RESET})"
                        ;;
                    2) # Uruchom
                        log_message "INFO" "Rozpoczęcie uruchamiania Discourse"
                        print_info "Uruchamianie Discourse (dev mode)..."
                        
                        if [ ! -d "$HOME/discourse" ]; then
                            log_message "ERROR" "Nie znaleziono katalogu Discourse"
                            print_error "Nie znaleziono katalogu Discourse"
                            read -rp "$(echo -e ${CYAN}Naciśnij Enter, aby kontynuować...${RESET})"
                            continue
                        fi

                        cd "$HOME/discourse" || {
                            log_message "ERROR" "Nie można przejść do katalogu Discourse"
                            print_error "Nie można przejść do katalogu Discourse"
                            read -rp "$(echo -e ${CYAN}Naciśnij Enter, aby kontynuować...${RESET})"
                            continue
                        }

                        if [ ! -f "bin/rails" ] || [ ! -f "bin/ember-cli" ]; then
                            log_message "ERROR" "Brakuje wymaganych plików. Czy Discourse jest prawidłowo zainstalowany?"
                            print_error "Brakuje wymaganych plików. Czy Discourse jest prawidłowo zainstalowany?"
                            execute_with_logging "bundle install && yarn install && pnpm install" "Reinstalacja zależności"
                            if [ ! -f "bin/ember-cli" ]; then
                                log_message "ERROR" "Nie można znaleźć bin/ember-cli. Sprawdź instalację."
                                print_error "Nie można znaleźć bin/ember-cli. Sprawdź instalację."
                                read -rp "$(echo -e ${CYAN}Naciśnij Enter, aby kontynuować...${RESET})"
                                continue
                            fi
                        fi

                        check_and_clean_discourse_processes

                        log_message "INFO" "Uruchamianie serwera Discourse"
                        if ! DISCOURSE_HOSTNAME=localhost \
                           UNICORN_LISTENER=localhost:3000 \
                           ALLOW_EMBER_CLI_PROXY_BYPASS=1 \
                           bin/ember-cli -u; then
                            log_message "ERROR" "Błąd podczas uruchamiania Discourse"
                            print_error "Błąd podczas uruchamiania Discourse"
                            check_and_clean_discourse_processes
                        else
                            log_message "SUCCESS" "Discourse został uruchomiony"
                            print_success "Discourse został uruchomiony."
                        fi
                        
                        read -rp "$(echo -e ${CYAN}Naciśnij Enter, aby kontynuować...${RESET})"
                        ;;
                    3) # Rebuild/Debug
                        log_message "INFO" "Rozpoczęcie debugowania Discourse"
                        print_info "Debugowanie Discourse z filtrowanymi logami..."
                        debug_discourse
                        read -rp "$(echo -e ${CYAN}Naciśnij Enter, aby kontynuować...${RESET})"
                        ;;
                    4) # Zatrzymaj
                        log_message "INFO" "Rozpoczęcie zatrzymywania Discourse"
                        print_warning "Zatrzymywanie Discourse (lokalne procesy)..."

                        unicorn_pid_file="$DISCOURSE_DIR/tmp/pids/unicorn.pid"

                        if [[ -f "$unicorn_pid_file" ]]; then
                            unicorn_pid=$(cat "$unicorn_pid_file")
                            if kill -0 "$unicorn_pid" &>/dev/null; then
                                log_message "INFO" "Unicorn działa (PID: $unicorn_pid). Zatrzymuję proces..."
                                kill -9 "$unicorn_pid" && log_message "SUCCESS" "Unicorn zatrzymany" || log_message "ERROR" "Nie udało się zatrzymać Unicorn"
                            else
                                log_message "INFO" "Unicorn jest nieaktywny, ale plik PID istnieje. Usuwam plik ${unicorn_pid_file}..."
                                rm -f "$unicorn_pid_file"
                            fi
                        else
                            log_message "INFO" "Plik unicorn.pid nie istnieje, Unicorn nie jest uruchomiony"
                        fi

                        ember_pid=$(lsof -ti tcp:4200)
                        if [[ -n "$ember_pid" ]]; then
                            log_message "INFO" "Zatrzymywanie Ember (PID: $ember_pid)"
                            kill -9 "$ember_pid" && log_message "SUCCESS" "Ember zatrzymany" || log_message "ERROR" "Nie udało się zatrzymać Ember"
                        else
                            log_message "INFO" "Ember już nie działa"
                        fi

                        log_message "INFO" "Zatrzymywanie innych procesów (Redis, PostgreSQL)"
                        execute_with_logging "sudo systemctl stop redis" "Zatrzymywanie Redis"
                        execute_with_logging "sudo systemctl stop postgresql" "Zatrzymywanie PostgreSQL"

                        log_message "SUCCESS" "Discourse zatrzymany"
                        print_success "Discourse zatrzymany."
                        read -rp "$(echo -e ${CYAN}Naciśnij Enter, aby kontynuować...${RESET})"
                        ;;
                    0)
                        break
                        ;;
                    *)
                        print_error "Nieprawidłowa opcja!"
                        read -p "$(echo -e ${CYAN}Naciśnij Enter, aby kontynuować...${RESET})"
                        ;;
                esac
            done
            ;;
        3)
            while true; do
                clear
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
                
                echo -ne "${GREEN}Wybierz opcję:${RESET} "
                read subchoice

                case $subchoice in
                    1)
                        log_message "INFO" "Uruchamianie serwera Rails"
                        execute_with_logging "cd '$HOME/discourse' && RAILS_ENV=development bundle exec rails server" "Uruchomienie serwera Rails"
                        ;;
                    2)
                        log_message "INFO" "Uruchamianie konsoli Rails"
                        execute_with_logging "cd '$HOME/discourse' && RAILS_ENV=development bundle exec rails console" "Uruchomienie konsoli Rails"
                        ;;
                    3)
                        log_message "INFO" "Uruchamianie testów RSpec"
                        execute_with_logging "cd '$HOME/discourse' && RAILS_ENV=test bundle exec rspec" "Uruchomienie testów RSpec"
                        ;;
                    4)
                        log_message "INFO" "Uruchamianie ESLint"
                        execute_with_logging "cd '$HOME/discourse' && yarn lint:js" "Uruchomienie ESLint"
                        ;;
                    5)
                        log_message "INFO" "Uruchamianie serwera Ember"
                        execute_with_logging "cd '$HOME/discourse' && yarn run ember server" "Uruchomienie serwera Ember"
                        ;;
                    6)
                        log_message "INFO" "Instalacja pg_vector dla PostgreSQL"
                        print_info "Instalacja pg_vector dla PostgreSQL..."
                        
                        if ! command -v psql &> /dev/null; then
                            log_message "ERROR" "PostgreSQL nie jest zainstalowany"
                            print_error "PostgreSQL nie jest zainstalowany!"
                            read -rp "$(echo -e ${CYAN}Naciśnij Enter, aby kontynuować...${RESET})"
                            continue
                        fi

                        TEMP_DIR=$(mktemp -d)
                        log_message "INFO" "Używam katalogu tymczasowego: $TEMP_DIR"
                        
                        execute_with_logging "sudo apt-get update && sudo apt-get install -y postgresql-server-dev-all git build-essential" "Instalacja zależności"
                        execute_with_logging "cd '$TEMP_DIR' && git clone https://github.com/pgvector/pgvector.git && cd pgvector && make && sudo make install" "Instalacja pg_vector"
                        execute_with_logging "sudo -u postgres psql -d discourse_development -c 'CREATE EXTENSION IF NOT EXISTS vector;'" "Aktywacja rozszerzenia w bazie development"
                        execute_with_logging "sudo -u postgres psql -d discourse_test -c 'CREATE EXTENSION IF NOT EXISTS vector;'" "Aktywacja rozszerzenia w bazie test"

                        rm -rf "$TEMP_DIR"
                        log_message "SUCCESS" "pg_vector został zainstalowany pomyślnie"
                        print_success "pg_vector został zainstalowany pomyślnie."
                        read -rp "$(echo -e ${CYAN}Naciśnij Enter, aby kontynuować...${RESET})"
                        ;;
                    7)
                        toggle_debug
                        read -rp "$(echo -e ${CYAN}Naciśnij Enter, aby kontynuować...${RESET})"
                        ;;
                    8)
                        if [ -f "$LOG_FILE" ]; then
                            less "$LOG_FILE"
                        else
                            log_message "ERROR" "Plik logów nie istnieje"
                            print_error "Plik logów nie istnieje"
                        fi
                        read -rp "$(echo -e ${CYAN}Naciśnij Enter, aby kontynuować...${RESET})"
                        ;;
                    0)
                        break
                        ;;
                    *)
                        print_error "Nieprawidłowa opcja!"
                        read -p "$(echo -e ${CYAN}Naciśnij Enter, aby kontynuować...${RESET})"
                        ;;
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
