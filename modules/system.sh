#!/bin/bash

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