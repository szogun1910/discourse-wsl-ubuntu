#!/bin/bash

# Funkcje zarządzania serwerem
start_discourse() {
    log_message "INFO" "Rozpoczęcie uruchamiania Discourse"
    print_info "Uruchamianie Discourse (dev mode)..."
    
    if [ ! -d "$HOME/discourse" ]; then
        log_message "ERROR" "Nie znaleziono katalogu Discourse"
        print_error "Nie znaleziono katalogu Discourse"
        return 1
    fi

    cd "$HOME/discourse" || {
        log_message "ERROR" "Nie można przejść do katalogu Discourse"
        print_error "Nie można przejść do katalogu Discourse"
        return 1
    }

    if [ ! -f "bin/rails" ] || [ ! -f "bin/ember-cli" ]; then
        log_message "ERROR" "Brakuje wymaganych plików. Czy Discourse jest prawidłowo zainstalowany?"
        print_error "Brakuje wymaganych plików. Czy Discourse jest prawidłowo zainstalowany?"
        execute_with_logging "bundle install && yarn install && pnpm install" "Reinstalacja zależności"
        if [ ! -f "bin/ember-cli" ]; then
            log_message "ERROR" "Nie można znaleźć bin/ember-cli. Sprawdź instalację."
            print_error "Nie można znaleźć bin/ember-cli. Sprawdź instalację."
            return 1
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
        return 1
    else
        log_message "SUCCESS" "Discourse został uruchomiony"
        print_success "Discourse został uruchomiony."
    fi
}

stop_discourse() {
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
}

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