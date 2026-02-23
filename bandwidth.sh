#!/bin/bash

# =============================================================================
# bandwidth.sh  –  Monitoraggio Banda per Livello Utente
# Incrocia il log con il CSV utenti per sapere il livello di ogni IP.
# Ogni accesso (cod. 200) = BYTES_PER_ACCESS byte consumati.
# Soglie diverse per livello -> alert email se superata.
#
# Formato log:  DATA|ORA|IP|CODICE_ERRORE|PID
# Formato CSV:  id,name_surname,mail,password,level,ip_address
#
# Soglie:
#   Level 3 = admin       -> 200 MB/giorno
#   Level 2 = power_user  -> 100 MB/giorno
#   Level 1 = guest       ->  30 MB/giorno
#   Level 0 = disabled    ->   0 MB  (alert immediato se accede)
# =============================================================================

ROOT_DIR="/workspaces/codespaces-blank/progetto-Bottarelli-Di_Landro-Suardi/intranet_sim"
LOG_FILE="$ROOT_DIR/logs/access.log"
USERS_CSV="$ROOT_DIR/data/users.csv"
OUT_DIR="$ROOT_DIR/logs_output"
REPORT="$OUT_DIR/bandwidth_report.txt"
ADMIN_MAIL="admin@intranet.local"

BYTES_PER_ACCESS=524288   # 512 KB per accesso simulato

# Soglie in MB per livello (0=disabled, 1=guest, 2=power_user, 3=admin)
SOGLIA_0=0
SOGLIA_1=30
SOGLIA_2=100
SOGLIA_3=200

DATE_FILTER="$1"   # opzionale: YYYY-MM-DD

mkdir -p "$OUT_DIR"

[[ "$1" == "-h" || "$1" == "--help" ]] && {
    echo "Uso: ./bandwidth.sh [YYYY-MM-DD]"
    echo "     Senza argomenti analizza l'intero log."
    echo ""
    echo "Soglie per livello:"
    echo "  Level 3 (admin)      : ${SOGLIA_3} MB/giorno"
    echo "  Level 2 (power_user) : ${SOGLIA_2} MB/giorno"
    echo "  Level 1 (guest)      : ${SOGLIA_1} MB/giorno"
    echo "  Level 0 (disabled)   : accesso vietato, alert immediato"
    exit 0
}

echo "[*] Monitoraggio Banda per Livello Utente"
echo "    Soglie -> admin: ${SOGLIA_3} MB | power_user: ${SOGLIA_2} MB | guest: ${SOGLIA_1} MB | disabled: 0 MB"
[ -n "$DATE_FILTER" ] && echo "    Filtro data: $DATE_FILTER"
echo ""

{
    echo "=================================================="
    echo "  REPORT CONSUMO BANDA PER LIVELLO UTENTE"
    echo "  Generato: $(date '+%Y-%m-%d %H:%M:%S')"
    [ -n "$DATE_FILTER" ] && echo "  Data: $DATE_FILTER" || echo "  Periodo: intero log"
    echo ""
    echo "  Soglie giornaliere:"
    echo "    Level 3 (admin)      : ${SOGLIA_3} MB"
    echo "    Level 2 (power_user) : ${SOGLIA_2} MB"
    echo "    Level 1 (guest)      : ${SOGLIA_1} MB"
    echo "    Level 0 (disabled)   : 0 MB (vietato)"
    echo "=================================================="
    echo ""
} > "$REPORT"

ALERT_COUNT=0

# Ottieni le date da analizzare
if [ -n "$DATE_FILTER" ]; then
    DATES="$DATE_FILTER"
else
    DATES=$(awk -F"|" '{print $1}' "$LOG_FILE" | sort -u)
fi

while IFS= read -r giorno; do

    echo "--- $giorno ---" >> "$REPORT"

    # Per ogni utente nel CSV, calcola i MB consumati in questo giorno
    while IFS="," read -r uid nome mail pass level ip; do
        ip=$(echo "$ip" | tr -d ' \r')
        level=$(echo "$level" | tr -d ' \r')
        nome=$(echo "$nome" | tr -d '\r')

        # Conta accessi cod.200 dal suo IP in questo giorno
        accessi=$(awk -F"|" -v d="$giorno" -v uip="$ip" \
            '$1==d && $3==uip && $4=="200"' "$LOG_FILE" | wc -l)

        # Conta anche eventuali accessi 400 (per disabled)
        accessi_400=$(awk -F"|" -v d="$giorno" -v uip="$ip" \
            '$1==d && $3==uip && $4=="400"' "$LOG_FILE" | wc -l)

        totale_accessi=$(( accessi + accessi_400 ))
        [ "$totale_accessi" -eq 0 ] && continue   # utente non attivo oggi

        # Calcola MB consumati (solo accessi 200)
        mb=$(echo "scale=2; ($accessi * $BYTES_PER_ACCESS) / (1024 * 1024)" | bc)
        mb_int=$(echo "$mb" | awk -F'.' '{print ($1+0)}')
        mb_int=${mb_int:-0}

        # Determina soglia e nome livello in base al level
        case "$level" in
            3) soglia=$SOGLIA_3; nome_level="admin"      ;;
            2) soglia=$SOGLIA_2; nome_level="power_user" ;;
            1) soglia=$SOGLIA_1; nome_level="guest"      ;;
            0) soglia=$SOGLIA_0; nome_level="disabled"   ;;
            *) soglia=$SOGLIA_1; nome_level="unknown"    ;;
        esac

        # Utente disabled: alert se ha fatto QUALSIASI accesso
        if [ "$level" -eq 0 ] && [ "$totale_accessi" -gt 0 ]; then
            msg="  [CRITICAL] $giorno | $nome (disabled) | IP: $ip | Accessi: $totale_accessi (account disabilitato!)"
            echo "$msg" | tee -a "$REPORT"

            echo -e "ATTENZIONE: L'account DISABILITATO '$nome' (IP: $ip)\nha effettuato $totale_accessi accessi in data $giorno.\n\nQuesto account non dovrebbe avere accesso alla rete.\nVerificare immediatamente.\n\n-- Sistema Automatico Intranet --" \
                | mail -s "[INTRANET CRITICAL] Accesso account disabilitato: $nome" "$ADMIN_MAIL" 2>/dev/null

            (( ALERT_COUNT++ ))
            continue
        fi

        # Utenti normali: controlla soglia MB
        if (( mb_int >= soglia )); then
            msg="  [ALERT] $giorno | $nome ($nome_level) | IP: $ip | ${mb} MB / soglia ${soglia} MB ($accessi accessi)"
            echo "$msg" | tee -a "$REPORT"

            echo -e "L'utente '$nome' (livello: $nome_level, IP: $ip)\nha consumato ${mb} MB in data $giorno,\nsuperando la soglia consentita di ${soglia} MB/giorno.\nAccessi registrati (cod. 200): $accessi\n\n-- Sistema Automatico Intranet --" \
                | mail -s "[INTRANET ALERT] Banda superata: $nome ($nome_level) il $giorno" "$ADMIN_MAIL" 2>/dev/null

            (( ALERT_COUNT++ ))
        else
            printf "  [OK] %s | %-25s (%-11s) | %s MB / %s MB\n" \
                "$giorno" "$nome" "$nome_level" "$mb" "$soglia" >> "$REPORT"
        fi

    done < <(tail -n +2 "$USERS_CSV")

    echo "" >> "$REPORT"

done <<< "$DATES"

{
    echo "=================================================="
    echo "  Totale alert generati: $ALERT_COUNT"
    echo "=================================================="
} | tee -a "$REPORT"

echo ""
echo "[OK] Report salvato in: $REPORT"
