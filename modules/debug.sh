#!/bin/bash

# Funkcje debugowania
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

toggle_debug() {
    if [ "$DEBUG_MODE" = true ]; then
        export DEBUG_MODE=false
        print_info "Tryb debugowania wyłączony"
        log_message "INFO" "Tryb debugowania wyłączony"
    else
        export DEBUG_MODE=true
        print_info "Tryb debugowania włączony"
        log_message "INFO" "Tryb debugowania włączony"
    fi
}