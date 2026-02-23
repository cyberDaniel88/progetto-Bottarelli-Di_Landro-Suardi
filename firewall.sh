#!/bin/bash

# =============================================================================
# firewall.sh  –  Analisi di sicurezza della rete intranet
# Formato log: DATA|ORA|IP|CODICE_ERRORE|PID
#   $1 = DATA        $2 = ORA        $3 = IP
#   $4 = CODICE_ERRORE (200/400)     $5 = PID
# =============================================================================

ROOT_DIR="/workspaces/progetto-Bottarelli-Di_Landro-Suardi/intranet_sim"
LOG_FILE="$ROOT_DIR/logs/access.log"
WHITELIST="$ROOT_DIR/config/whitelist.conf"
BLACKLIST="$ROOT_DIR/config/blacklist.conf"
SEC_LOG="$ROOT_DIR/logs_output/security_events.log"

mkdir -p "$ROOT_DIR/logs_output"
[ ! -f "$BLACKLIST" ] && touch "$BLACKLIST"

USAGE="Uso: ./firewall.sh [FLAG] [ARGOMENTI]
  -s, --scan          Scansiona log per IP non in whitelist
  -n, --night         Trova accessi notturni (codice 400)
  -b, --ban   [IP]    Aggiunge manualmente un IP alla blacklist
  -c, --check-ban     Controlla se IP bannati hanno tentato l'accesso
  -r, --report        Genera report completo delle minacce"


case "$1" in

    # ------------------------------------------------------------------
    # SCAN: IP non presenti in whitelist
    # ------------------------------------------------------------------
    -s|--scan)
        echo "[*] Scansione dispositivi non autorizzati..."
        awk -F "|" '
            NR==FNR { whitelist[$1]=1; next }
            {
                gsub(/ /, "", $3)
                if (!($3 in whitelist))
                    print "ALERT: IP non autorizzato -> " $3 " | Data: " $1 " " $2 " | PID: " $5
            }
        ' "$WHITELIST" "$LOG_FILE" > "$SEC_LOG"
        echo "Scansione completata: $(wc -l < "$SEC_LOG") eventi sospetti."
        echo "Dettagli in: $SEC_LOG"
        ;;

    # ------------------------------------------------------------------
    # NIGHT: Accessi con codice 400 (notturni / non autorizzati)
    # ------------------------------------------------------------------
    -n|--night)
        echo "[*] Ricerca accessi notturni (codice 400)..."
        OUT="$ROOT_DIR/logs_output/night_breaches.log"
        awk -F "|" '$4 == "400" { print "NIGHT BREACH -> IP: " $3 " | Data: " $1 " " $2 " | PID: " $5 }' \
            "$LOG_FILE" > "$OUT"
        echo "$(wc -l < "$OUT") violazioni notturne salvate in: $OUT"
        ;;

    # ------------------------------------------------------------------
    # BAN: Aggiunge IP alla blacklist
    # ------------------------------------------------------------------
    -b|--ban)
        IP_TO_BAN="$2"
        if [[ -z "$IP_TO_BAN" ]]; then
            echo "Errore: specificare un IP. Esempio: ./firewall.sh -b 192.168.1.50"
            exit 1
        fi
        if grep -q "^${IP_TO_BAN}$" "$BLACKLIST"; then
            echo "L'IP $IP_TO_BAN è già in blacklist."
        else
            echo "$IP_TO_BAN" >> "$BLACKLIST"
            echo "IP $IP_TO_BAN aggiunto alla blacklist ($BLACKLIST)."
        fi
        ;;

    # ------------------------------------------------------------------
    # CHECK-BAN: IP bannati che hanno tentato l'accesso
    # ------------------------------------------------------------------
    -c|--check-ban)
        if [ ! -s "$BLACKLIST" ]; then
            echo "Blacklist vuota. Nessun IP da controllare."
            exit 0
        fi
        echo "[*] Controllo accessi da IP bannati..."
        awk -F "|" '
            NR==FNR { blacklist[$1]=1; next }
            {
                gsub(/ /, "", $3)
                if ($3 in blacklist)
                    print "CRITICAL: Tentativo da IP BANNATO -> " $3 " | Data: " $1 " " $2 " | PID: " $5
            }
        ' "$BLACKLIST" "$LOG_FILE"
        ;;

    # ------------------------------------------------------------------
    # REPORT: Report completo
    # ------------------------------------------------------------------
    -r|--report)
        OUT_REPORT="$ROOT_DIR/logs_output/full_report.txt"
        {
            echo "=========================================="
            echo "   REPORT DI SICUREZZA - $(date '+%Y-%m-%d %H:%M:%S')"
            echo "=========================================="

            echo ""
            echo "--- TOP 5 IP CON ERRORI 400 (ACCESSI NOTTURNI) ---"
            awk -F "|" '$4 == "400" { gsub(/ /, "", $3); print $3 }' "$LOG_FILE" \
                | sort | uniq -c | sort -nr | head -5

            echo ""
            echo "--- TOP 5 IP SCONOSCIUTI (NON IN WHITELIST) ---"
            awk -F "|" 'NR==FNR { white[$1]=1; next } { gsub(/ /, "", $3) } !($3 in white) { print $3 }' \
                "$WHITELIST" "$LOG_FILE" \
                | sort | uniq -c | sort -nr | head -5

            echo ""
            echo "--- IP IN BLACKLIST CHE HANNO TENTATO L'ACCESSO ---"
            if [ -s "$BLACKLIST" ]; then
                awk -F "|" 'NR==FNR { bl[$1]=1; next } { gsub(/ /, "", $3) } $3 in bl { print $3 " | " $1 " " $2 }' \
                    "$BLACKLIST" "$LOG_FILE" | head -10
            else
                echo "(blacklist vuota)"
            fi
        } | tee "$OUT_REPORT"
        echo ""
        echo "Report salvato in: $OUT_REPORT"
        ;;

    *)
        echo "$USAGE"
        ;;
esac
