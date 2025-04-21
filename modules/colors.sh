#!/bin/bash

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

# Stałe dla ramek
MENU_WIDTH=45
BORDER_TOP="${BLUE}${BOLD}╔$(printf '═%.0s' $(seq 1 $((MENU_WIDTH-2))))╗${RESET}"
BORDER_BOTTOM="${BLUE}${BOLD}╚$(printf '═%.0s' $(seq 1 $((MENU_WIDTH-2))))╝${RESET}"
w_\Q8L.bM-