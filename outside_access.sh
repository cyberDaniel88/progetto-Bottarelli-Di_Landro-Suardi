#!/bin/bash

# =============================================================================
# outside_access.sh  –  Controllo Accessi Fuori Sede
# Rileva accessi nel log da IP che non appartengono alla subnet 192.168.x.x
# (la subnet interna aziendale). Qualsiasi altro IP è considerato esterno
# e quindi sospetto in una rete intranet chiusa.
# Formato log: DATA|ORA|IP|CODICE_ERRORE|PID
# =============================================================================

ROOT_DIR="/workspaces/progetto-Bottarelli-Di_Landro-Suardi/intranet_sim"
LOG_FILE="$ROOT_DIR/logs/access.log"
OUT_DIR="$ROOT_DIR/logs_output"
REPORT="$OUT_DIR/outside_access.log"

DATE_FILTER="$1"

mkdir -p "$OUT_DIR"

[[ "$1" == "-h" || "$1" == "--help" ]] && {
    echo "Uso: ./outside_access.sh [YYYY-MM-DD]"
    echo "     Senza argomenti analizza l'intero log."
    exit 0
}

if [ ! -f "$LOG_FILE" ]; then
    echo "ERRORE: log non trovato in $LOG_FILE"
    exit 1
fi

echo "[*] Controllo accessi fuori sede (subnet attesa: 192.168.x.x)"
[ -n "$DATE_FILTER" ] && echo "    Filtro data: $DATE_FILTER"
echo ""

{
    echo "=================================================="
    echo "  REPORT ACCESSI FUORI SEDE"
    echo "  Generato: $(date '+%Y-%m-%d %H:%M:%S')"
    [ -n "$DATE_FILTER" ] && echo "  Data: $DATE_FILTER" || echo "  Periodo: intero log"
    echo "  Subnet interna: 192.168.0.0/16"
    echo "=================================================="
    echo ""
} > "$REPORT"

# Filtra per data se specificata, poi cerca IP non nella subnet 192.168.x.x
TROVATI=$(awk -F"|" \
    -v df="$DATE_FILTER" '
    (df == "" || $1 == df) &&
    $3 !~ /^192\.168\./ {
        print "  [ALERT] " $1 " " $2 " | IP esterno: " $3 " | Codice: " $4 " | PID: " $5
    }
' "$LOG_FILE")

if [ -z "$TROVATI" ]; then
    echo "  Nessun accesso esterno rilevato." | tee -a "$REPORT"
else
    echo "$TROVATI" | tee -a "$REPORT"
    COUNT=$(echo "$TROVATI" | wc -l)

    # Top IP esterni più frequenti
    {
        echo ""
        echo "--- TOP IP ESTERNI PIÙ FREQUENTI ---"
        awk -F"|" -v df="$DATE_FILTER" \
            '(df=="" || $1==df) && $3 !~ /^192\.168\./ {print $3}' "$LOG_FILE" \
            | sort | uniq -c | sort -nr | head -5 \
            | awk '{printf "  %s accessi -> IP: %s\n", $1, $2}'
        echo ""
        echo "=================================================="
        echo "  Totale accessi esterni rilevati: $COUNT"
        echo "=================================================="
    } | tee -a "$REPORT"
fi

echo ""
echo "[OK] Report salvato in: $REPORT"