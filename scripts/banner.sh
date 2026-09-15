#!/usr/bin/env bash
# =============================================================================
#  Agility Shell -- Banner Helper
# =============================================================================

show_agility_banner() {
    local subtitle="${1:-}"
    local CYAN='\033[1;36m'
    local BLUE='\033[0;34m'
    local BOLD='\033[1m'
    local RESET='\033[0m'

    echo ""
    echo -e "                                    ${BLUE}~${RESET}"
    echo -e "                                   ${BLUE}x:${RESET}"
    echo -e "                                  ${BLUE}*#${RESET}"
    echo -e "                                  ${BLUE}##:${RESET}"
    echo -e "                                  ${BLUE}*##~${RESET}"
    echo -e "                            ${BLUE}:${RESET}      ${BLUE}x##x+${RESET}"
    echo -e "                          ${BLUE}:x${RESET}        ${BLUE}+####*.${RESET}"
    echo -e "                          ${BLUE}#x${RESET}          ${BLUE}*####~${RESET}"
    echo -e "                         ${BLUE}:##*.${RESET}         ${BLUE}:####.${RESET}     ${BLUE}*${RESET}"
    echo -e "                          ${BLUE}x###x+.${RESET}       ${BLUE}+###.${RESET}     ${BLUE}x*${RESET}"
    echo -e "                          ${BLUE}.x#####*.${RESET}     ${BLUE}~##+${RESET}     ${BLUE}~#x${RESET}"
    echo -e "                    ${CYAN}=+${RESET}      ${BLUE}:*#####${RESET}     ${BLUE}xx:${RESET}    ${BLUE}.*##*${RESET}"
    echo -e "                    ${CYAN}%%${RESET}         ${BLUE}+###~${RESET}   ${BLUE}::${RESET}    ${BLUE}~*###x${RESET}"
    echo -e "                    ${CYAN}%@%=${RESET}        ${BLUE}.x#.${RESET}       ${BLUE}+####x~${RESET}   ${CYAN}+${RESET}"
    echo -e "                    ${CYAN}+@@@@#+:${RESET}      ${BLUE}+${RESET}      ${BLUE}+####*~${RESET}    ${CYAN}#@${RESET}"
    echo -e "                     ${CYAN}+@@@@@@@#+${RESET}         ${BLUE}*###*.${RESET}  ${CYAN}.=#@@*${RESET}"
    echo -e "                       ${CYAN}+%@@@@@@@*${RESET}      ${BLUE}*##x:${CYAN}:+#@@@@@#${RESET}"
    echo -e "                         ${CYAN}:+#@@@@@#${RESET}    ${BLUE}:##*${CYAN}+%@@@@@@#:${RESET}"
    echo -e "                             ${CYAN}+%@@@=${RESET}   ${BLUE}~+${CYAN}*%@@@@#+:${RESET}"
    echo -e "                               ${CYAN}=@@*${RESET}   ${CYAN}#@@@#+:${RESET}"
    echo -e "                                ${CYAN}.%*${RESET}   ${CYAN}#@#:${RESET}"
    echo -e "                                 ${CYAN}.+${RESET}   ${CYAN}*:${RESET}"
    echo ""
    if [[ -n "$subtitle" ]]; then
        echo -e "                     ${CYAN}${BOLD}Agility Shell${RESET} ${BLUE}--${RESET} ${BOLD}${subtitle}${RESET}"
        echo ""
    else
        echo -e "                             ${CYAN}${BOLD}Agility Shell${RESET}"
        echo ""
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    show_agility_banner "$@"
fi
