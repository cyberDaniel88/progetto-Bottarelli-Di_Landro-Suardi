#!/bin/bash

# =============================================================================
# user_report.sh  –  Report Utenti per Livello
# Genera una panoramica completa degli utenti nel CSV suddivisi per livello:
#   Level 3 = admin
#   Level 2 = power_user
#   Level 1 = guest
#   Level 0 = disabled
# Mostra statistiche, liste dettagliate, attività nel log e utenti sospetti.
# Formato CSV: id,name_surname,mail,password,level,ip_address
# Formato log: DATA|ORA|IP|CODICE_ERRORE|PID
# =============================================================================

ROOT_DIR="/workspaces/progetto-Bottarelli-Di_Landro-Suardi/intranet_sim"
USERS_CSV="$ROOT_DIR/data/users.csv"
LOG_FILE="$ROOT_DIR/logs/access.log"
OUT_DIR="$ROOT_DIR/logs_output"
REPORT="$OUT_DIR/user_report.txt"

mkdir -p "$OUT_DIR"

if [ ! -f "$USERS_CSV" ]; then
    echo "ERRORE: $USERS_CSV non trovato. Esegui prima ./install_server.sh"
    exit 1
fi

echo "[*] Generazione report utenti per livello..."

{
    echo "=================================================="
    echo "  REPORT UTENTI PER LIVELLO"
    echo "  Generato: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "  Sorgente: $USERS_CSV"
    echo "=================================================="
    echo ""

    # ── STATISTICHE GENERALI ─────────────────────────────────────────────────
    TOTALE=$(tail -n +2 "$USERS_CSV" | wc -l)
    N3=$(awk -F',' '$5=="3"' "$USERS_CSV" | wc -l)
    N2=$(awk -F',' '$5=="2"' "$USERS_CSV" | wc -l)
    N1=$(awk -F',' '$5=="1"' "$USERS_CSV" | wc -l)
    N0=$(awk -F',' '$5=="0"' "$USERS_CSV" | wc -l)

    echo "--- RIEPILOGO ---"
    echo "  Utenti totali   : $TOTALE"
    printf "  Admin      (3)  : %-4s  (%s%%)\n" "$N3" "$(( N3 * 100 / TOTALE ))"
    printf "  Power User (2)  : %-4s  (%s%%)\n" "$N2" "$(( N2 * 100 / TOTALE ))"
    printf "  Guest      (1)  : %-4s  (%s%%)\n" "$N1" "$(( N1 * 100 / TOTALE ))"
    printf "  Disabled   (0)  : %-4s  (%s%%)\n" "$N0" "$(( N0 * 100 / TOTALE ))"
    echo ""

    # ── DETTAGLIO PER LIVELLO ────────────────────────────────────────────────
    for LEVEL in 3 2 1 0; do
        case "$LEVEL" in
            3) LABEL="ADMIN (Level 3)"      ;;
            2) LABEL="POWER USER (Level 2)" ;;
            1) LABEL="GUEST (Level 1)"      ;;
            0) LABEL="DISABLED (Level 0)"   ;;
        esac

        echo "=================================================="
        echo "  $LABEL"
        echo "=================================================="

        HAS_USERS=0
        while IFS=',' read -r id nome mail pass level ip; do
            [ "$level" != "$LEVEL" ] && continue
            HAS_USERS=1
            ip=$(echo "$ip" | tr -d ' \r')

            if [ -f "$LOG_FILE" ]; then
                ACC_200=$(awk -F"|" -v uip="$ip" '$3==uip && $4=="200"' "$LOG_FILE" | wc -l)
                ACC_400=$(awk -F"|" -v uip="$ip" '$3==uip && $4=="400"' "$LOG_FILE" | wc -l)
                ULTIMO=$(awk -F"|" -v uip="$ip" '$3==uip {print $1}' "$LOG_FILE" | sort | tail -1)
                [ -z "$ULTIMO" ] && ULTIMO="mai"
            else
                ACC_200="-"; ACC_400="-"; ULTIMO="N/D"
            fi

            printf "  [ID %3s] %-25s | %s\n" "$id" "$nome" "$mail"
            printf "           IP: %-18s | Accessi OK: %-4s | Errori: %-4s | Ultimo: %s\n" \
                "$ip" "$ACC_200" "$ACC_400" "$ULTIMO"
            echo ""
        done < <(tail -n +2 "$USERS_CSV")

        [ "$HAS_USERS" -eq 0 ] && echo "  Nessun utente in questo livello."
        echo ""
    done

    # ── UTENTI SOSPETTI: più 400 che 200 ────────────────────────────────────
    echo "=================================================="
    echo "  UTENTI SOSPETTI (errori 400 > accessi 200)"
    echo "=================================================="
    echo ""

    if [ ! -f "$LOG_FILE" ]; then
        echo "  Log non disponibile."
    else
        SOSPETTI=0
        while IFS=',' read -r id nome mail pass level ip; do
            ip=$(echo "$ip" | tr -d ' \r')

            ACC_200=$(awk -F"|" -v uip="$ip" '$3==uip && $4=="200"' "$LOG_FILE" | wc -l)
            ACC_400=$(awk -F"|" -v uip="$ip" '$3==uip && $4=="400"' "$LOG_FILE" | wc -l)

            if (( ACC_400 > 0 && ACC_400 > ACC_200 )); then
                case "$level" in
                    3) LEVEL_LABEL="admin"      ;;
                    2) LEVEL_LABEL="power_user" ;;
                    1) LEVEL_LABEL="guest"      ;;
                    0) LEVEL_LABEL="disabled"   ;;
                    *) LEVEL_LABEL="unknown"    ;;
                esac

                printf "  [WARN] %-25s | %-11s | IP: %-18s | %s errori vs %s OK\n" \
                    "$nome" "($LEVEL_LABEL)" "$ip" "$ACC_400" "$ACC_200"
                (( SOSPETTI++ ))
            fi
        done < <(tail -n +2 "$USERS_CSV")

        if [ "$SOSPETTI" -eq 0 ]; then
            echo "  Nessun utente sospetto rilevato."
        else
            echo ""
            echo "  Totale utenti sospetti: $SOSPETTI"
        fi
    fi
    echo ""

    echo "=================================================="
    echo "  Fine report."
    echo "=================================================="

} | tee "$REPORT"

echo ""
echo "[OK] Report salvato in: $REPORT"