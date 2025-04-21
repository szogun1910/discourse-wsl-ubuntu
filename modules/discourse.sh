#!/bin/bash

# Funkcja instalacji Discourse
install_discourse() {
    log_message "INFO" "Rozpoczynanie instalacji Discourse"
    ensure_postgresql_running || return 1

    if [ -d "$HOME/discourse" ]; then
        print_warning "Katalog discourse już istnieje"
        return 1
    fi

    execute_with_logging "git clone https://github.com/discourse/discourse.git $HOME/discourse" "Klonowanie repozytorium"
    execute_with_logging "cd '$HOME/discourse' && bundle install" "Instalacja gemów"
    execute_with_logging "cd '$HOME/discourse' && yarn install" "Instalacja zależności npm"
    execute_with_logging "cd '$HOME/discourse' && bundle exec rake db:create" "Tworzenie bazy danych"
    execute_with_logging "cd '$HOME/discourse' && bundle exec rake db:migrate" "Migracja bazy danych"
}

# Funkcja aktualizacji Discourse
update_discourse() {
    log_message "INFO" "Aktualizacja Discourse"
    ensure_postgresql_running || return 1

    execute_with_logging "cd '$HOME/discourse' && git pull" "Aktualizacja kodu"
    execute_with_logging "cd '$HOME/discourse' && bundle install" "Aktualizacja gemów"
    execute_with_logging "cd '$HOME/discourse' && yarn install" "Aktualizacja zależności npm"
    execute_with_logging "cd '$HOME/discourse' && bundle exec rake db:migrate" "Migracja bazy danych"
}

# Funkcja usuwania Discourse
remove_discourse() {
    log_message "INFO" "Usuwanie Discourse"
    stop_discourse

    if [ -d "$HOME/discourse" ]; then
        execute_with_logging "rm -rf '$HOME/discourse'" "Usuwanie katalogu discourse"
        execute_with_logging "sudo -u postgres dropdb discourse_development" "Usuwanie bazy development"
        execute_with_logging "sudo -u postgres dropdb discourse_test" "Usuwanie bazy test"
        print_success "Discourse został usunięty"
    else
        print_warning "Katalog discourse nie istnieje"
    fi
}

# Funkcja instalacji pluginu
install_plugin() {
    log_message "INFO" "Instalacja pluginu"
    read -p "Podaj URL repozytorium pluginu: " plugin_url

    if [ -z "$plugin_url" ]; then
        print_error "URL nie może być pusty"
        return 1
    fi

    plugin_name=$(basename "$plugin_url" .git)
    execute_with_logging "cd '$HOME/discourse/plugins' && git clone $plugin_url" "Klonowanie pluginu $plugin_name"
    execute_with_logging "cd '$HOME/discourse' && bundle install" "Instalacja zależności"
    execute_with_logging "cd '$HOME/discourse' && bundle exec rake plugin:install_all_gems" "Instalacja gemów pluginu"
}