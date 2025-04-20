#!/bin/bash

# Ustawienia debugowania i logowania
DEBUG_MODE=false
LOG_DIR="$HOME/discourse/log"
LOG_FILE="$LOG_DIR/script.log"
TRANSCRIPT_FILE="$LOG_DIR/console.log"

# Tworzenie katalogu logów
mkdir -p "$LOG_DIR"

# Funkcja do usuwania sekwencji ANSI i logowania
clean_and_log() {
    while IFS= read -r line; do
        # Zapisz czysty tekst do pliku
        echo "$line" >> "$TRANSCRIPT_FILE"
        # Wyświetl oryginalny tekst
        echo "$line"
    done
}

# Konfiguracja przekierowania wyjścia
mkdir -p "$(dirname "$TRANSCRIPT_FILE")"
echo "=== Sesja rozpoczęta $(date '+%Y-%m-%d %H:%M:%S') ===" >> "$TRANSCRIPT_FILE"

# Przekierowanie standardowego wyjścia i błędów
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

# Funkcje formatowania komunikatów
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