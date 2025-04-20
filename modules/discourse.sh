#!/bin/bash

# Funkcje instalacji i zarządzania Discourse
install_discourse() {
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
}

update_discourse() {
    log_message "INFO" "Rozpoczęcie aktualizacji Discourse"
    print_info "Aktualizacja Discourse..."
    
    if [ ! -d "$HOME/discourse" ]; then
        log_message "ERROR" "Nie znaleziono instalacji Discourse w $HOME/discourse"
        print_error "Nie znaleziono instalacji Discourse w $HOME/discourse"
        return 1
    fi

    if ! command -v yarn &> /dev/null; then
        log_message "INFO" "Instalacja yarn"
        execute_with_logging "curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -" "Dodanie klucza yarn"
        execute_with_logging "echo 'deb https://dl.yarnpkg.com/debian/ stable main' | sudo tee /etc/apt/sources.list.d/yarn.list" "Dodanie repozytorium yarn"
        execute_with_logging "sudo apt-get update && sudo apt-get install -y yarn" "Instalacja yarn"
    fi

    trap 'echo -e "${YELLOW}⚠️ Wykryto próbę zatrzymania procesu. Użyj Ctrl+C aby przerwać lub pozwól procesowi zakończyć się.${RESET}"' SIGTSTP

    cd "$HOME/discourse" || {
        log_message "ERROR" "Nie można przejść do katalogu Discourse"
        print_error "Nie można przejść do katalogu Discourse"
        trap - SIGTSTP
        return 1
    }

    execute_with_logging "git pull origin main" "Aktualizacja kodu źródłowego"
    execute_with_logging "bundle install" "Aktualizacja zależności Ruby"
    execute_with_logging "yarn install && pnpm install" "Aktualizacja zależności Node.js"
    execute_with_logging "bundle exec rake db:migrate" "Aktualizacja bazy danych"

    trap - SIGTSTP
    log_message "SUCCESS" "Discourse został zaktualizowany"
    print_success "Discourse został zaktualizowany."
}

remove_discourse() {
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
}

install_plugin() {
    log_message "INFO" "Rozpoczęcie instalacji pluginu"
    print_info "Instalacja pluginu Discourse..."
    
    if [ ! -d "$HOME/discourse/plugins" ]; then
        log_message "INFO" "Tworzenie katalogu plugins"
        mkdir -p "$HOME/discourse/plugins"
    fi

    cd "$HOME/discourse/plugins" || {
        log_message "ERROR" "Nie można przejść do katalogu plugins"
        print_error "Nie można przejść do katalogu plugins"
        return 1
    }

    print_info "Dostępne oficjalne pluginy:"
    print_option "1" "discourse-solved (oznaczanie rozwiązanych tematów)"
    print_option "2" "discourse-voting (system głosowania)"
    print_option "3" "discourse-chat-integration (integracja z czatami)"
    print_option "4" "discourse-math (wsparcie dla wzorów matematycznych)"
    print_option "5" "Własny plugin (podaj URL)"
    print_separator
    
    read -p "Wybierz plugin do instalacji: " plugin_choice
    
    case $plugin_choice in
        1)
            plugin_url="https://github.com/discourse/discourse-solved.git"
            plugin_name="discourse-solved"
            ;;
        2)
            plugin_url="https://github.com/discourse/discourse-voting.git"
            plugin_name="discourse-voting"
            ;;
        3)
            plugin_url="https://github.com/discourse/discourse-chat-integration.git"
            plugin_name="discourse-chat-integration"
            ;;
        4)
            plugin_url="https://github.com/discourse/discourse-math.git"
            plugin_name="discourse-math"
            ;;
        5)
            read -p "Podaj URL do repozytorium pluginu: " plugin_url
            plugin_name=$(basename "$plugin_url" .git)
            ;;
        *)
            print_error "Nieprawidłowa opcja!"
            return 1
            ;;
    esac

    if [ -d "$plugin_name" ]; then
        print_warning "Plugin $plugin_name już istnieje"
        read -rp "Czy chcesz go zaktualizować? (y/N): " update_choice
        if [[ "$update_choice" == "y" || "$update_choice" == "Y" ]]; then
            cd "$plugin_name" && {
                execute_with_logging "git pull" "Aktualizacja pluginu $plugin_name"
                cd ..
            }
        fi
    else
        execute_with_logging "git clone $plugin_url" "Instalacja pluginu $plugin_name"
    fi

    cd "$HOME/discourse" && {
        print_info "Przebudowa aplikacji z nowym pluginem..."
        execute_with_logging "RAILS_ENV=development bundle exec rake assets:clean" "Czyszczenie assetów"
        execute_with_logging "RAILS_ENV=development bundle exec rake assets:precompile" "Kompilacja assetów"
    }

    print_success "Plugin został zainstalowany. Uruchom ponownie serwer Discourse aby aktywować zmiany."
}