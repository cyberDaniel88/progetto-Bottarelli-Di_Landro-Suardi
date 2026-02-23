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

ROOT_DIR="/workspaces/progetto-Bottarelli-Di_Landro-Suardi/intranet_sim"
LOG_FILE="$ROOT_DIR/logs/access.log"
USERS_CSV="$ROOT_DIR/data/users.csv"
OUT_DIR="$ROOT_DIR/logs_output"
MAIL_DIR="$ROOT_DIR/mail"
REPORT="$OUT_DIR/bandwidth_report.txt"

DESTINATARI="daniel.dilan2006@gmail.com, luca.bottarelli03@gmail.com, lucrezia.suardi.98@gmail.com"

BYTES_PER_ACCESS=524288   # 512 KB per accesso simulato

# Soglie in MB per livello (0=disabled, 1=guest, 2=power_user, 3=admin)
SOGLIA_0=0
SOGLIA_1=30
SOGLIA_2=100
SOGLIA_3=200

DATE_FILTER="$1"   # opzionale: YYYY-MM-DD

mkdir -p "$OUT_DIR" "$MAIL_DIR"

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

# ── Funzione per scrivere una mail fittizia in MAIL_DIR ──────────────────────
send_mail() {
    local subject="$1"
    local body="$2"
    local tipo="$3"   # ALERT o CRITICAL
    local ts
    ts=$(date '+%Y%m%d_%H%M%S')
    local filename="$MAIL_DIR/${tipo}_${ts}.txt"

    {
        echo "=================================================="
        echo "  DA      : sistema@intranet.local"
        echo "  A       : $DESTINATARI"
        echo "  DATA    : $(date '+%Y-%m-%d %H:%M:%S')"
        echo "  OGGETTO : $subject"
        echo "=================================================="
        echo ""
        echo "$body"
        echo ""
        echo "-- Sistema Automatico Intranet --"
    } > "$filename"

    echo "         [MAIL] Notifica salvata in: $(basename "$filename")"
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

    while IFS="," read -r uid nome mail pass level ip; do
        ip=$(echo "$ip" | tr -d ' \r')
        level=$(echo "$level" | tr -d ' \r')
        nome=$(echo "$nome" | tr -d '\r')

        accessi=$(awk -F"|" -v d="$giorno" -v uip="$ip" \
            '$1==d && $3==uip && $4=="200"' "$LOG_FILE" | wc -l)
        accessi_400=$(awk -F"|" -v d="$giorno" -v uip="$ip" \
            '$1==d && $3==uip && $4=="400"' "$LOG_FILE" | wc -l)

        totale_accessi=$(( accessi + accessi_400 ))
        [ "$totale_accessi" -eq 0 ] && continue

        mb=$(echo "scale=2; ($accessi * $BYTES_PER_ACCESS) / (1024 * 1024)" | bc)
        mb_int=$(echo "$mb" | awk -F'.' '{print ($1+0)}')
        mb_int=${mb_int:-0}

        case "$level" in
            3) soglia=$SOGLIA_3; nome_level="admin"      ;;
            2) soglia=$SOGLIA_2; nome_level="power_user" ;;
            1) soglia=$SOGLIA_1; nome_level="guest"      ;;
            0) soglia=$SOGLIA_0; nome_level="disabled"   ;;
            *) soglia=$SOGLIA_1; nome_level="unknown"    ;;
        esac

        # Utente disabled
        if [ "$level" -eq 0 ] && [ "$totale_accessi" -gt 0 ]; then
            msg="  [CRITICAL] $giorno | $nome (disabled) | IP: $ip | Accessi: $totale_accessi (account disabilitato!)"
            echo "$msg" | tee -a "$REPORT"
            send_mail \
                "[INTRANET CRITICAL] Accesso account disabilitato: $nome" \
                "ATTENZIONE: L'account DISABILITATO '$nome' (IP: $ip) ha effettuato $totale_accessi accessi in data $giorno. Questo account non dovrebbe avere accesso alla rete. Verificare immediatamente." \
                "CRITICAL"
            (( ALERT_COUNT++ ))
            continue
        fi

        # Utenti normali
        if (( mb_int >= soglia )); then
            msg="  [ALERT] $giorno | $nome ($nome_level) | IP: $ip | ${mb} MB / soglia ${soglia} MB ($accessi accessi)"
            echo "$msg" | tee -a "$REPORT"
            send_mail \
                "[INTRANET ALERT] Banda superata: $nome ($nome_level) il $giorno" \
                "L'utente '$nome' (livello: $nome_level, IP: $ip) ha consumato ${mb} MB in data $giorno, superando la soglia consentita di ${soglia} MB/giorno. Accessi registrati (cod. 200): $accessi" \
                "ALERT"
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
[ "$ALERT_COUNT" -gt 0 ] && echo "[OK] $ALERT_COUNT notifiche salvate in: $MAIL_DIR"