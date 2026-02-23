# Intranet Simulation

Simulazione di un server intranet aziendale con gestione utenti, log di accesso e strumenti di analisi e sicurezza. Il progetto genera un ambiente fittizio completo (utenti, log, whitelist) su cui esercitare tutti gli script di amministrazione e monitoring.

---

## Struttura del progetto

```
progetto-Bottarelli-Di_Landro-Suardi/
│
├── install_server.sh          # Setup iniziale della simulazione
├── create_users.py            # Generazione database utenti
├── create_accesslog.py        # Generazione log di accesso
│
├── manuale.sh                 # Manuale degli script
│
├── add_convert.sh             # Gestione utenti (aggiunta, eliminazione, modifica)
├── audit_trail.sh             # Audit trail modifiche al CSV utenti
├── backup.sh                  # Backup e ripristino di users.csv e whitelist.conf
├── bandwidth.sh               # Monitoraggio consumo di banda per livello utente
├── firewall.sh                # Analisi di sicurezza della rete
├── log.sh                     # Estrazione e filtraggio del log di accesso
├── log_rotation.sh            # Rotazione e archiviazione del log
├── outside_access.sh          # Rilevamento accessi da IP esterni
├── user_report.sh             # Report utenti per livello
│
└── intranet_sim/
    ├── data/
    │   ├── users.csv              # Database utenti
    │   ├── users_snapshot.csv     # Snapshot per audit_trail
    │   └── backups/               # Backup timestampati
    ├── config/
    │   ├── settings.conf          # Orari diurni (START_HOUR, END_HOUR)
    │   ├── whitelist.conf         # IP autorizzati
    │   └── blacklist.conf         # IP bannati
    └── logs/
        ├── access.log             # Log di accesso attivo
        ├── archive/               # Log archiviati da log_rotation
        └── logs_output/           # Output di tutti gli script
```

---

## Avvio

Aprire un'istanza di Codespace dal repository corrente e assicurarsi che la directory corrente sia: ```workspaces/progetto-Bottarelli-Di_Landro-Suardi```

```bash
chmod +x install_server.sh
./install_server.sh
```

`install_server.sh` è l'unico script da eseguire per inizializzare l'intera simulazione. Va lanciato prima di qualsiasi altro script. Al termine, il comando `manuale` sarà disponibile globalmente.

---

## Infrastruttura

### `install_server.sh`

Configura l'intera simulazione dall'inizio. Esegue in sequenza:

1. Crea la struttura delle cartelle in `intranet_sim/`
2. Installa le dipendenze Python necessarie (`numpy`)
3. Scrive `settings.conf` con gli orari diurni (`START_HOUR=6`, `END_HOUR=21`)
4. Lancia `create_users.py` per generare il database utenti
5. Lancia `create_accesslog.py` per generare il log di accesso
6. Costruisce `whitelist.conf` con gli IP appartenenti alla nostra subnet
7. Rende eseguibili tutti gli script e installa `manuale` in `/usr/local/bin/`

**Output a schermo:**
```
Building Simulated Server at .../intranet_sim...
Server Simulation Ready.
  data/users.csv        -> 101 righe
  logs/access.log       -> 780 righe
  config/whitelist.conf -> 96 IP
  [OK] Comando 'manuale' installato.
```

---

### `create_users.py`

Genera `intranet_sim/data/users.csv` con 100 utenti fittizi. Ogni utente ha un ID progressivo, nome e cognome casuali, indirizzo email derivato dal nome, password casuale di 8 caratteri, livello di accesso e indirizzo IP univoco nella subnet `192.168.x.x`.

I livelli sono distribuiti con pesi realistici: il 65% degli utenti è guest (1), il 30% power user (2), il 5% admin (3). L'8% circa degli utenti con ID più alto viene assegnato al livello 0 (disabled).

**Formato CSV:**
```
id,name_surname,mail,password,level,ip_address
1,Liam Smith,liam.smith@mail.com,aB3!xY7q,1,192.168.42.17
```

---

### `create_accesslog.py`

Genera `intranet_sim/logs/access.log` con accessi simulati nell'arco del 2025. Combina due tipi di voci:

- **Accessi normali** (`NUM_LOGS = 500`): distribuiti casualmente tra tutti gli utenti. Gli accessi diurni (tra `START_HOUR` e `END_HOUR`) ricevono codice `200`, quelli notturni codice `400`. Con probabilità `EXTERNAL_IP_PROB = 0.05` (5%) l'accesso proviene da un IP esterno alla subnet, per rendere significativi `outside_access.sh` e `firewall.sh`.
- **Burst di banda** (`NUM_BURST_USERS = 4` utenti, `BURST_ACCESSES = 70` accessi in un giorno): simula utenti che superano la soglia di banda giornaliera, rendendo significativo `bandwidth.sh`.

I parametri di simulazione sono raggruppati in cima al file e facilmente modificabili:

```python
NUM_LOGS         = 500    # accessi normali
EXTERNAL_IP_PROB = 0.05   # % accessi da IP esterni
NUM_BURST_USERS  = 4      # utenti con picco di banda
BURST_ACCESSES   = 70     # accessi burst per utente (min 60 per alert guest)
```

**Formato log:**
```
DATA|ORA|IP|CODICE_ERRORE|PID
2025-06-14|14:32:11|192.168.42.17|200|18432
2025-06-15|03:12:44|192.168.88.21|400|9871
```

---

## Manuale

### `manuale.sh`

Mostra la documentazione di ogni script direttamente dal terminale, in stile `man` di Linux. Installato da `install_server.sh` in `/usr/local/bin/manuale`, è richiamabile da qualsiasi directory.

```bash
manuale <script>
```

Il nome dello script può essere passato in qualsiasi forma: con o senza `./` e con o senza `.sh`.

```bash
manuale log
manuale log.sh
manuale ./log.sh
```

Senza argomenti (o con uno sconosciuto) mostra la lista di tutti gli script disponibili.

---

## Script

### `add_convert.sh`

Interfaccia interattiva per la gestione del file `users.csv`, accessibile solo agli utenti di livello 3 (admin). All'avvio richiede mail e password; se le credenziali sono valide e il livello è 3, mostra un menù con tre operazioni.

```bash
./add_convert.sh
```

**Operazioni disponibili:**

| Opzione | Descrizione |
|--------|-------------|
| 1 | Aggiunge un nuovo utente con validazione di password (8 caratteri, charset limitato) e IP (formato `192.168.X.Y`, non duplicato) |
| 2 | Elimina un utente cercandolo per nome e cognome, con richiesta di conferma |
| 3 | Modifica il livello di accesso (1, 2 o 3) di un utente esistente |

**Output:** messaggi a schermo di conferma o errore. Tutte le modifiche vengono scritte direttamente su `users.csv`.

---

### `audit_trail.sh`

Confronta lo stato attuale di `users.csv` con uno snapshot salvato in precedenza e registra ogni differenza nel file `logs_output/audit_trail.log`. Ad ogni esecuzione aggiorna lo snapshot.

```bash
./audit_trail.sh [OPZIONE]
```

| Opzione | Descrizione |
|--------|-------------|
| *(nessuna)* | Confronta il CSV con lo snapshot e registra le modifiche |
| `--init` | Crea lo snapshot iniziale senza registrare modifiche |
| `--show` | Stampa a schermo il contenuto di `audit_trail.log` |

**Output — `logs_output/audit_trail.log`:**
```
2025-06-14 10:22:01 | INIT | Snapshot iniziale creato.
2025-06-15 09:10:44 | AGGIUNTO | ID: 101 | Nome: John Doe | Mail: john.doe@mail.com | Level: 1 | IP: 192.168.5.3
2025-06-15 09:15:12 | MODIFICATO | ID: 3 | Nome: Liam Smith | level: 1 -> 2 |
2025-06-15 09:18:30 | RIMOSSO | ID: 7 | Nome: Emma Jones | Mail: emma.jones@mail.com | Level: 1 | IP: 192.168.12.9
```

---

### `backup.sh`

Crea backup timestampati di `users.csv` e `whitelist.conf` nella cartella `data/backups/`. Mantiene automaticamente solo gli ultimi 5 backup per file, eliminando i più vecchi.

```bash
./backup.sh [OPZIONE]
```

| Opzione | Descrizione |
|--------|-------------|
| *(nessuna)* | Esegue il backup di entrambi i file |
| `--list` | Mostra i backup disponibili con dimensione e timestamp |
| `--restore [FILE]` | Ripristina un backup specifico (percorso completo). Prima di sovrascrivere, salva automaticamente un backup di sicurezza del file corrente |

**Output — backup creati in `data/backups/`:**
```
users_20250614_102201.csv
whitelist_20250614_102201.conf
```

**Output a schermo con `--list`:**
```
=== Backup disponibili in .../data/backups ===

  UTENTI (users.csv):
    6.8K  .../backups/users_20250614_102201.csv

  WHITELIST (whitelist.conf):
    1.2K  .../backups/whitelist_20250614_102201.conf
```

---

### `bandwidth.sh`

Incrocia il log di accesso con `users.csv` per calcolare il consumo di banda giornaliero di ogni utente. Ogni accesso con codice `200` equivale a 512 KB. Se il consumo supera la soglia del livello, genera un alert e invia una email all'amministratore.

```bash
./bandwidth.sh [YYYY-MM-DD]
```

Senza argomenti analizza l'intero log. Con una data analizza solo quel giorno.

**Soglie giornaliere:**

| Livello | Soglia |
|---------|--------|
| Admin (3) | 200 MB |
| Power User (2) | 100 MB |
| Guest (1) | 30 MB |
| Disabled (0) | 0 MB — alert immediato per qualsiasi accesso |

**Output — `logs_output/bandwidth_report.txt`:**
```
--- 2025-06-14 ---
  [ALERT] 2025-06-14 | John Doe (guest) | IP: 192.168.42.17 | 35.00 MB / soglia 30 MB (70 accessi)
  [OK]    2025-06-14 | Emma Jones (power_user) | 1.00 MB / 100 MB
  [CRITICAL] 2025-06-14 | Mark Brown (disabled) | IP: 192.168.88.5 | Accessi: 3 (account disabilitato!)
```

---

### `firewall.sh`

Analizza il log di accesso alla ricerca di comportamenti sospetti. Gestisce anche la blacklist manuale degli IP.

```bash
./firewall.sh [FLAG]
```

| Flag | Descrizione |
|------|-------------|
| `-s`, `--scan` | Trova gli IP nel log non presenti in `whitelist.conf` |
| `-n`, `--night` | Trova tutti gli accessi con codice `400` (notturni) |
| `-b`, `--ban [IP]` | Aggiunge un IP a `blacklist.conf` |
| `-c`, `--check-ban` | Controlla se IP in blacklist hanno tentato accessi |
| `-r`, `--report` | Genera un report completo con top 5 IP per errori, IP sconosciuti e tentativi da IP bannati |

**Output — `logs_output/security_events.log` (con `-s`):**
```
ALERT: IP non autorizzato -> 104.21.33.12 | Data: 2025-06-14 03:12:44 | PID: 9871
```

**Output — `logs_output/full_report.txt` (con `-r`):**
```
--- TOP 5 IP CON ERRORI 400 ---
  3 accessi -> 192.168.88.21
  2 accessi -> 104.21.33.12
...
--- IP IN BLACKLIST CHE HANNO TENTATO L'ACCESSO ---
  192.168.1.99 | 2025-06-15 02:44:01
```

---

### `log.sh`

Estrae voci dal log di accesso in base a diversi criteri di filtraggio. I risultati vengono salvati in file separati in `logs_output/`.

```bash
./log.sh [FLAG] [ARGOMENTI]
```

| Flag | Argomenti | Descrizione |
|------|-----------|-------------|
| `-a`, `--all` | — | Tutti gli accessi notturni (codice `400`) |
| `-t`, `--tail` | — | Gli ultimi 10 accessi notturni |
| `-i`, `--ip` | `IP_ADDRESS` | Tutti gli accessi di un IP specifico |
| `-d`, `--date` | `YYYY-MM-DD` | Tutti gli accessi di una data specifica |
| `-ds`, `--dates` | `YYYY-MM-DD` `YYYY-MM-DD` | Tutti gli accessi in un intervallo di date |
| `-dt`, `--date-time` | `YYYY-MM-DD` `HH_START` `HH_END` | Accessi di una data in un intervallo orario |

**File di output generati in `logs_output/`:**

| Flag | File |
|------|------|
| `-a` | `log_night.log` |
| `-t` | `log_night_10.log` |
| `-i` | `log_ip_<IP>.log` |
| `-d` | `log_date_<YYYY-MM-DD>.log` |
| `-ds` | `log_date_range_<DATA1>_<DATA2>.log` |
| `-dt` | `log_date_hour_<DATA>_<HH>-<HH>.log` |

---

### `log_rotation.sh`

Archivia le righe del log più vecchie di 30 giorni rispetto alla data più recente presente nel log stesso (non la data di sistema, per compatibilità con log simulati nel passato).

```bash
./log_rotation.sh [OPZIONE]
```

| Opzione | Descrizione |
|--------|-------------|
| *(nessuna)* | Archivia le righe vecchie e aggiorna il log attivo |
| `--undo` | Ripristina l'ultimo archivio nel log attivo, riordinando cronologicamente, e rimuove l'archivio |

**Output a schermo:**
```
[*] Log Rotation (modalità simulata)
    Data più recente nel log : 2025-12-28
    Soglia archiviazione     : 2025-11-28

  Righe da archiviare  : 91
  Righe da mantenere   : 9

  Archivio creato : .../logs/archive/access_2025-01-01_to_2025-11-15.log
[OK] Rotazione completata.
     Per annullare: ./log_rotation.sh --undo
```

**File archiviati in `logs/archive/`:**
```
access_2025-01-01_to_2025-11-15.log
```

---

### `outside_access.sh`

Scansiona il log alla ricerca di accessi provenienti da IP non appartenenti alla subnet interna `192.168.0.0/16`. Qualsiasi altro indirizzo è considerato esterno e sospetto.

```bash
./outside_access.sh [YYYY-MM-DD]
```

Senza argomenti analizza l'intero log. Con una data analizza solo quel giorno.

**Output — `logs_output/outside_access.log`:**
```
==================================================
  REPORT ACCESSI FUORI SEDE
  Generato: 2025-06-15 10:44:02
  Subnet interna: 192.168.0.0/16
==================================================

  [ALERT] 2025-03-12 14:22:01 | IP esterno: 104.21.33.12 | Codice: 200 | PID: 44231
  [ALERT] 2025-06-14 03:12:44 | IP esterno: 8.8.4.4      | Codice: 400 | PID: 9871

--- TOP IP ESTERNI PIÙ FREQUENTI ---
  3 accessi -> IP: 104.21.33.12
  2 accessi -> IP: 8.8.4.4

==================================================
  Totale accessi esterni rilevati: 5
==================================================
```

---

### `user_report.sh`

Genera una panoramica completa di tutti gli utenti nel CSV, suddivisi per livello. Per ciascun utente mostra le statistiche di accesso dal log. In fondo segnala gli utenti sospetti con più errori che accessi riusciti.

```bash
./user_report.sh
```

Nessun argomento richiesto. Il report viene stampato a schermo e salvato in `logs_output/user_report.txt`.

**Output — `logs_output/user_report.txt`:**
```
==================================================
  REPORT UTENTI PER LIVELLO
  Generato: 2025-06-15 10:50:01
==================================================

--- RIEPILOGO ---
  Utenti totali   : 100
  Admin      (3)  : 5     (5%)
  Power User (2)  : 25    (25%)
  Guest      (1)  : 62    (62%)
  Disabled   (0)  : 8     (8%)

==================================================
  ADMIN (Level 3)
==================================================
  [ID   1] Liam Smith                | liam.smith@mail.com
           IP: 192.168.42.17         | Accessi OK: 3    | Errori: 0    | Ultimo: 2025-11-04

...

==================================================
  UTENTI SOSPETTI (errori 400 > accessi 200)
==================================================
  [WARN] Henry Rodriguez            | (guest)      | IP: 192.168.76.139     | 2 errori vs 0 OK
```
