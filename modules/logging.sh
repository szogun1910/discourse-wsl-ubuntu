#!/bin/bash

# Konfiguracja logowania
LOGS_DIR="$HOME/discourse-wsl-ubuntu/logs"
LOG_FILE="$LOGS_DIR/script.log"
DEBUG_LOG="$LOGS_DIR/debug.log"
CONSOLE_LOG="$LOGS_DIR/console.log"
COMMANDS_LOG="$LOGS_DIR/commands.log"

# Inicjalizacja logowania
init_logging() {
    # Tworzenie katalogu logów jeśli nie istnieje
    mkdir -p "$LOGS_DIR"

    # Inicjalizacja plików logów
    for log_file in "$LOG_FILE" "$DEBUG_LOG" "$CONSOLE_LOG" "$COMMANDS_LOG"; do
        [ ! -f "$log_file" ] && {
            touch "$log_file"
            chmod 644 "$log_file"
        }
    done

    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}][INFO][init_logging] === Nowa sesja rozpoczęta ===" | tee -a "$LOG_FILE" "$CONSOLE_LOG" >/dev/null

    if [ "$DEBUG_MODE" = true ]; then
        # Przekierowanie stdout i stderr do console.log w trybie debug
        exec 1> >(tee -a "$CONSOLE_LOG")
        exec 2> >(tee -a "$CONSOLE_LOG" >&2)
    fi
}

# Funkcja logowania
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local calling_function="${FUNCNAME[1]:-main}"

    # Format podstawowy logu
    local log_entry="[${timestamp}][${level}][${calling_function}] ${message}"

    # Zapisz do głównego logu
    echo "$log_entry" >> "$LOG_FILE"

    # W trybie debug zapisuj wszystko do debug.log i console.log
    if [ "$DEBUG_MODE" = true ]; then
        echo "$log_entry" >> "$DEBUG_LOG"
        echo "$log_entry" >> "$CONSOLE_LOG"
    fi

    # Wyświetl komunikat na konsoli w zależności od poziomu
    case "$level" in
        "ERROR")
            print_error "$message"
            ;;
        "WARNING")
            print_warning "$message"
            ;;
        "INFO")
            print_info "$message"
            ;;
        "SUCCESS")
            print_success "$message"
            ;;
    esac
}