#!/bin/bash

ROOT_DIR="/workspaces/codespaces-blank/progetto-Bottarelli-Di_Landro-Suardi/intranet_sim"
USERS_CSV="$ROOT_DIR/data/users.csv"
WHITELIST="$ROOT_DIR/config/whitelist.conf"


next_id() {
    # Legge tutti gli id numerici e restituisce il massimo + 1
    tail -n +2 "$USERS_CSV" | cut -d',' -f1 | sort -n | tail -1 | awk '{print $1+1}'
}


valid_password() {
    local pass="$1"
    local allowed='abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!?@#$%^()&*'
    # Deve essere esattamente 8 caratteri
    if [[ ${#pass} -ne 8 ]]; then
        return 1
    fi
    # Ogni carattere deve appartenere ai caratteri ammessi
    local i char
    for (( i=0; i<${#pass}; i++ )); do
        char="${pass:$i:1}"
        if [[ "$allowed" != *"$char"* ]]; then
            return 1
        fi
    done
    return 0
}


valid_ip() {
    local ip="$1"
    # Controlla il formato con regex
    if [[ ! "$ip" =~ ^192\.168\.([0-9]{1,3})\.([0-9]{1,3})$ ]]; then
        return 1
    fi
    local x="${BASH_REMATCH[1]}"
    local y="${BASH_REMATCH[2]}"
    # Controlla i range numerici
    if (( x < 0 || x > 255 || y < 1 || y > 254 )); then
        return 1
    fi
    # Controlla che non sia già usato nel CSV
    if tail -n +2 "$USERS_CSV" | cut -d',' -f6 | grep -qx "$ip"; then
        return 2  # codice 2 = IP duplicato
    fi
    return 0
}


# Login
clear

echo "========================================="
echo "             Area Riservata"
echo "========================================="
echo ""
read -rp "Inserire la mail: " INPUT_MAIL
read -rsp "Inserire la password: " INPUT_PASS
echo ""


# Cerca la riga corrispondente nel CSV
MATCH=$(tail -n +2 "$USERS_CSV" | awk -F',' -v mail="$INPUT_MAIL" -v pass="$INPUT_PASS" '$3 == mail && $4 == pass {print $0}')

if [[ -z "$MATCH" ]]; then
    echo ""
    echo "Utente o password errati."
    exit 1
fi

# Controlla che il livello sia 3
USER_LEVEL=$(echo "$MATCH" | cut -d',' -f5)

if [[ "$USER_LEVEL" != "3" ]]; then
    echo ""
    echo "Accesso negato."
    exit 1
fi

# Menù
while true; do
    clear
    echo "========================================="
    echo "                  Menù"
    echo "========================================="
    echo ""
    echo "  1. Aggiungere un utente"
    echo "  2. Eliminare un utente"
    echo "  3. Modificare il livello di un utente"
    echo "  4. Uscire"
    echo ""
    read -rp "Selezionare un'opzione [1-4]: " CHOICE

    case "$CHOICE" in

        1)
            # Aggiungi utente

            clear
            echo "========================================="
            echo "          Aggiunta Nuovo Utente"
            echo "========================================="
            echo ""
            read -rp "Inserire il nome: " NEW_FIRST
            read -rp "Inserire il cognome: " NEW_LAST
            read -rp "Inserire la mail: " NEW_MAIL

            while true; do
                read -rsp "Inserire la password (8 caratteri tra: a-z A-Z 0-9 !?@#\$%^()&*): " NEW_PASS
                echo ""
                if valid_password "$NEW_PASS"; then
                    break
                else
                    echo "Password non valida: deve essere esattamente 8 caratteri usando solo i caratteri ammessi."
                fi
            done

            while true; do
                read -rp "Inserire il livello (1, 2 o 3): " NEW_LEVEL
                if [[ "$NEW_LEVEL" == "1" || "$NEW_LEVEL" == "2" || "$NEW_LEVEL" == "3" ]]; then
                    break
                else
                    echo "Livello non valido. Inserire 1, 2 o 3."
                fi
            done

            while true; do
                read -rp "Inserire l'indirizzo IP (formato 192.168.X.Y): " NEW_IP
                valid_ip "$NEW_IP"
                IP_RESULT=$?
                if [[ $IP_RESULT -eq 0 ]]; then
                    break
                elif [[ $IP_RESULT -eq 2 ]]; then
                    echo "Indirizzo IP già in uso. Inserirne uno diverso."
                else
                    echo "Indirizzo IP non valido. Usare il formato 192.168.X.Y con 0<=X<=255 e 1<=Y<=254."
                fi
            done

            NEW_ID=$(next_id)
            NEW_NAME="$NEW_FIRST $NEW_LAST"

            # Aggiunge la nuova riga al CSV
            echo "$NEW_ID,$NEW_NAME,$NEW_MAIL,$NEW_PASS,$NEW_LEVEL,$NEW_IP" >> "$USERS_CSV"

            # Aggiorna whitelist: aggiunge l'IP se nella subnet 192.168.x.x
            if [[ "$NEW_IP" =~ ^192\.168\. ]]; then
                if ! grep -qx "$NEW_IP" "$WHITELIST"; then
                    echo "$NEW_IP" >> "$WHITELIST"
                    sort -t'.' -k3,3n -k4,4n "$WHITELIST" -o "$WHITELIST"
                fi
            fi

            echo ""
            echo "Utente '$NEW_NAME' aggiunto con successo (ID: $NEW_ID)."
            read -rp "Premere INVIO per tornare al menù."
            ;;

        2)
            # Elimina utente

            clear
            echo "========================================="
            echo "           Eliminazione Utente"
            echo "========================================="
            echo ""
            read -rp "Inserire il nome: " DEL_FIRST
            read -rp "Inserire il cognome: " DEL_LAST
            DEL_NAME="$DEL_FIRST $DEL_LAST"

            # Controlla l'esistenza dell'utente
            DEL_MATCH=$(tail -n +2 "$USERS_CSV" | awk -F',' -v name="$DEL_NAME" '$2 == name {print NR+1; exit}')

            if [[ -z "$DEL_MATCH" ]]; then
                echo ""
                echo "Nessun utente trovato con il nome '$DEL_NAME'."
                read -rp "Premere INVIO per tornare al menù."
                continue
            fi

            echo ""
            echo "Utente trovato: $(awk -F',' -v name="$DEL_NAME" '$2 == name' "$USERS_CSV")"
            echo ""
            read -rp "Confermare l'eliminazione di '$DEL_NAME'? [Y/n]: " CONFIRM

            if [[ "$CONFIRM" == "Y" ]]; then
                # Elimina la riga corrispondente
                # Recupera l'IP dell'utente prima di eliminarlo
                DEL_IP=$(awk -F',' -v name="$DEL_NAME" '$2 == name {print $6; exit}' "$USERS_CSV" | tr -d ' \r')
                TMP_FILE=$(mktemp)
                awk -F',' -v name="$DEL_NAME" 'BEGIN{deleted=0} ($2 == name && deleted == 0) {deleted=1; next} {print}' \
                    "$USERS_CSV" > "$TMP_FILE"
                mv "$TMP_FILE" "$USERS_CSV"
                echo ""

                # Aggiorna whitelist: rimuove l'IP se presente
                if [[ -n "$DEL_IP" ]] && grep -qx "$DEL_IP" "$WHITELIST"; then
                    grep -vx "$DEL_IP" "$WHITELIST" > "${WHITELIST}.tmp"
                    mv "${WHITELIST}.tmp" "$WHITELIST"
                fi
                echo "Utente '$DEL_NAME' eliminato con successo."
            else
                echo ""
                echo "Operazione annullata."
            fi

            read -rp "Premere INVIO per tornare al menù."
            ;;

        3)
            # Modifica livello

            clear
            echo "========================================="
            echo "         Modifica Livello Utente"
            echo "========================================="
            echo ""
            read -rp "Inserire il nome: " MOD_FIRST
            read -rp "Inserire il cognome: " MOD_LAST
            MOD_NAME="$MOD_FIRST $MOD_LAST"

            # Controlla l'esistenza dell'utente
            MOD_MATCH=$(tail -n +2 "$USERS_CSV" | awk -F',' -v name="$MOD_NAME" '$2 == name {print; exit}')

            if [[ -z "$MOD_MATCH" ]]; then
                echo ""
                echo "Nessun utente trovato con il nome '$MOD_NAME'."
                read -rp "Premere INVIO per tornare al menù."
                continue
            fi

            CURRENT_LEVEL=$(echo "$MOD_MATCH" | cut -d',' -f5)
            echo ""
            echo "Utente trovato: $MOD_MATCH"
            echo "Livello attuale: $CURRENT_LEVEL"
            echo ""

            while true; do
                read -rp "Inserire il nuovo livello (1, 2 o 3): " NEW_LVL
                if [[ "$NEW_LVL" == "1" || "$NEW_LVL" == "2" || "$NEW_LVL" == "3" ]]; then
                    break
                else
                    echo "Livello non valido. Inserire 1, 2 o 3."
                fi
            done

            TMP_FILE=$(mktemp)
            awk -F',' -v OFS=',' -v name="$MOD_NAME" -v lvl="$NEW_LVL" \
                'BEGIN{modified=0} ($2 == name && modified == 0) {$5=lvl; modified=1} {print}' \
                "$USERS_CSV" > "$TMP_FILE"
            mv "$TMP_FILE" "$USERS_CSV"

            echo ""
            echo "Livello di '$MOD_NAME' aggiornato da $CURRENT_LEVEL a $NEW_LVL."
            read -rp "Premere INVIO per tornare al menù."
            ;;

        4)
            # Esci

            clear
            exit 1
            ;;

        *)
            echo ""
            echo "Opzione non valida. Inserire un numero tra 1 e 4."
            read -rp "Premere INVIO per riprovare..."
            ;;
    esac
done
