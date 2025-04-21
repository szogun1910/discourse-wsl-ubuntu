#!/bin/bash

# Poziomy debugowania
DEBUG_LEVELS=(
    "NONE"      # 0: Brak debugowania
    "ERROR"     # 1: Tylko błędy
    "WARN"      # 2: Błędy i ostrzeżenia
    "INFO"      # 3: Standardowe informacje
    "DEBUG"     # 4: Szczegółowe informacje debugowania
    "TRACE"     # 5: Pełne śledzenie
)

# Domyślny poziom debugowania
DEBUG_LEVEL=3

# Funkcje debugowania
debug() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local calling_function="${FUNCNAME[1]:-main}"
    local line_number="${BASH_LINENO[0]}"

    # Usuń znaczniki kolorów z wiadomości
    message=$(echo "$message" | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,3})*)?[mGK]//g")
    local debug_info="[$timestamp][$calling_function:$line_number][${DEBUG_LEVELS[$level]}] $message"

    if [ "$DEBUG_LEVEL" -ge "$level" ]; then
        echo "$debug_info" >> "$DEBUG_LOG"
        echo "$debug_info" >> "$TRACE_LOG"
        [ "$DEBUG_MODE" = true ] && echo -e "${BLUE}${BOLD}\u1F50D${RESET} $debug_info"
    fi
}

# Funkcja śledzenia wykonania
trace_execution() {
    if [ "$DEBUG_LEVEL" -ge 5 ]; then
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        local trace_info="[$timestamp][TRACE] Entering ${FUNCNAME[1]}"
        echo "$trace_info" >> "$TRACE_LOG"
        [ "$DEBUG_MODE" = true ] && echo "$trace_info" >> "$DEBUG_LOG"
        set -x
    fi
    "$@"
    local result=$?
    if [ "$DEBUG_LEVEL" -ge 5 ]; then
        set +x
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        local trace_info="[$timestamp][TRACE] Exiting ${FUNCNAME[1]} with status $result"
        echo "$trace_info" >> "$TRACE_LOG"
        [ "$DEBUG_MODE" = true ] && echo "$trace_info" >> "$DEBUG_LOG"
    fi
    return $result
}

# Przełączanie trybu debugowania
toggle_debug() {
    if [ "$DEBUG_MODE" = true ]; then
        DEBUG_MODE=false
        log_message "INFO" "Tryb debug wyłączony"
        # Przywróć standardowe wyjście
        exec 1> /dev/tty
        exec 2> /dev/tty
    else
        DEBUG_MODE=true
        log_message "INFO" "Tryb debug włączony"
        # Przekieruj wyjście do console.log
        exec 1> >(tee -a "$CONSOLE_LOG")
        exec 2> >(tee -a "$CONSOLE_LOG" >&2)
    fi
}