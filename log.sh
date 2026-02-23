#!/bin/bash

# Formato log: DATA|ORA|IP|CODICE_ERRORE|PID
#              $1   $2  $3  $4            $5

ROOT_DIR="/workspaces/progetto-Bottarelli-Di_Landro-Suardi/intranet_sim"
CONFIG="$ROOT_DIR/config/settings.conf"
LOG_FILE="$ROOT_DIR/logs/access.log"
OUT_FILE="$ROOT_DIR/logs_output"

# Carica START_HOUR e END_HOUR da settings.conf
if [ ! -f "$CONFIG" ]; then
    echo "ERRORE: configurazione non trovata in $CONFIG"
    echo "Esegui prima ./install_server.sh"
    exit 1
fi
source "$CONFIG"
NIGHT='{ hour = substr($2,1,2) + 0; if (hour < '$START_HOUR' || hour >= '$END_HOUR') print}'
USAGE='Uso: ./log.sh [FLAG] [ARGOMENTI]
Opzioni:
  -a, --all                                             Estrae tutti i log avvenuti in orario notturno.
  -t, --tail                                            Estrae gli ultimi 10 log avvenuti in orario notturno.
  -i, --ip [IP_ADDRESS]                                 Estrae i log di un indirizzo IP specifico.
  -d, --date [YYYY-MM-DD]                               Estrae i log di una data specifica.
  -ds, --dates [YYYY-MM-DD_START] [YYYY-MM-DD_END]      Estrae i log in un intervallo di date.
  -dt, --date-time [YYYY-MM-DD] [HH_START] [HH_END]     Estrae i log di una data specifica in un intervallo orario.'


# Controlla che il log esista
if [ ! -f "$LOG_FILE" ]; then
    echo "ERRORE: log non trovato in $LOG_FILE"
    echo "Esegui prima ./install_server.sh"
    exit 1
fi

mkdir -p "$OUT_FILE"

validate_date() {
    local input_date="$1"

    # 1. Controllo con espressione regolare per il formato YYYY-MM-DD
    if [[ ! "$input_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        return 1
    fi

    # 2. Controllo logico del calendario (compatibile cross-platform)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # Logica macOS/BSD
        date -j -f "%Y-%m-%d" "$input_date" >/dev/null 2>&1
    else
        # Logica Linux/GNU
        date -d "$input_date" >/dev/null 2>&1
    fi
}

validate_hour() {
    local hour="$1"

    # Controlla che sia composta da una o due cifre numeriche
    if [[ ! "$hour" =~ ^[0-9]{1,2}$ ]]; then
        return 1
    fi

    # Controlla che sia compresa tra 0 e 23
    # 10# evita che 08 o 09 vengano interpretati come numeri ottali non validi
    if (( 10#$hour < 0 || 10#$hour > 23 )); then
        return 1
    fi
}

case $# in

    0)
        echo "$USAGE"
        exit 1;;

    1)
        # Tutti i log notturni

        if [[ "$1" == "-a" || "$1" == "--all" ]]; then
            awk -F "|" "$NIGHT" "$LOG_FILE" > "$OUT_FILE/log_night.log"
            echo "File di log notturni creato in $OUT_FILE/log_night.log"
        
        elif [[ "$1" == "-t" || "$1" == "--tail" ]]; then           # Ultimi 10 log notturni
            awk -F "|" "$NIGHT" "$LOG_FILE" | tail -n 10 > "$OUT_FILE/log_night_10.log"
            echo "Ultime 10 voci di log notturno salvate in $OUT_FILE come log_night_10.log"
        else
            echo "$USAGE"
        fi;;

    2)
        # Log di una data specifica

        if [[ "$1" == "-d" || "$1" == "--date" ]]; then
            DATE="$2"
            if ! validate_date "$DATE"; then
                echo "Errore: '$DATE' non è una data valida o non rispetta il formato (YYYY-MM-DD)."
                exit 1
            fi

            if grep -q "^$DATE|" "$LOG_FILE"; then
                awk -F"|" -v date="$DATE" '$1 == date' "$LOG_FILE" > "$OUT_FILE/log_date_${DATE}.log"
                echo "Voci di log per la data $DATE salvate in $OUT_FILE come log_date_$DATE.log"
            else
                echo "Nessuna voce trovata per la data $DATE."
            fi
        elif
            [[ "$1" == "-i" || "$1" == "--ip" ]]; then
            IP="$2"
            if grep -q "|$IP|" "$LOG_FILE"; then
                awk -F"|" -v ip="$IP" '$3 == ip' "$LOG_FILE" > "$OUT_FILE/log_ip_${IP}.log"
                echo "Voci di log per l'IP $IP salvate in $OUT_FILE come log_ip_$IP.log"
            else
                echo "Nessuna voce trovata per l'IP $IP."
            fi
        else
            echo "$USAGE"
        fi;;

    3)
        # Log in un intervallo di date

        if [[ "$1" == "-ds" || "$1" == "--dates" ]]; then
            DATE1="$2"
            DATE2="$3"

            if ! validate_date "$DATE1"; then
                echo "Errore: '$DATE1' non è una data valida o non rispetta il formato (YYYY-MM-DD)."
                exit 1
            fi

            if ! validate_date "$DATE2"; then
                echo "Errore: '$DATE2' non è una data valida o non rispetta il formato (YYYY-MM-DD)."
                exit 1
            fi

            awk -F"|" -v date1="$DATE1" -v date2="$DATE2" '$1 >= date1 && $1 <= date2' "$LOG_FILE" > "$OUT_FILE/log_date_range_${DATE1}_${DATE2}.log"
            echo "Voci di log dal $DATE1 al $DATE2 salvate in $OUT_FILE come log_date_range_$DATE1_$DATE2.log"
        else
            echo "$USAGE"
        fi;;

    4)
        # Log di una data in un intervallo orario

        if [[ "$1" == "-dt" || "$1" == "--date-time" ]]; then
            DATE="$2"
            START_HR="$3"
            END_HR="$4"

            if ! validate_date "$DATE"; then
                echo "Errore: '$DATE' non è una data valida o non rispetta il formato (YYYY-MM-DD)."
                exit 1
            fi

            if ! validate_hour "$START_HR" || ! validate_hour "$END_HR"; then
                echo "Errore: intervallo orario non valido."
                exit 1
            fi

            if (( 10#$START_HR >= 10#$END_HR )); then
                echo "Errore: intervallo orario non valido."
                exit 1
            fi

            printf -v S_PAD "%02d" "$START_HR"
            printf -v E_PAD "%02d" "$END_HR"

            OUT="$OUT_FILE/log_date_hour_${DATE}_${S_PAD}-${E_PAD}.log"
            awk -F"|" -v d="$DATE" -v s="$S_PAD" -v e="$E_PAD" '{h = substr($2,1,2) + 0 } $1 == d && h >= s && h < e' "$LOG_FILE" > "$OUT"

            if [[ -s "$OUT" ]]; then
                echo "Voci di log per la data $DATE tra le $S_PAD:00 e le $(($E_PAD - 1)):59 salvate in $OUT_FILE come log_date_hour_${DATE}_${S_PAD}-${E_PAD}.log"
            else
                rm -f "$OUT"
                echo "Nessuna voce trovata per $DATE tra le $S_PAD:00 e le $(($E_PAD - 1)):59."
            fi

        else
            echo "$USAGE"
        fi;;

    *)
        # Uso non valido

        echo "$USAGE"
        exit 1;;

esac
