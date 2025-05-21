#!/bin/bash
# Dieses Skript mountet den entfernten Lieferavis-Ordner auf dem ASERVER
# Der Mountounkt ist bereits in der fstab angelegt.
# Es wird nach allen PDFs gesucht
# Falls ein PDF noch nicht in der Datei TrackingFile gelistet ist, wird sie in den lokalen Archivordner kopiert.
# Anschließend wird der Dateiname in die Tracking-Datei aufgenommen, damit sie nicht noch einmal überteragen wird.
#
#Vor Ausführung werden verschiedene Checks durchgeführt.
#touch "$TRACKING_FILE" muss vorher ausgeführt werden.

#For Debugging only:
#set -e
#set -x


# Konfiguration
SOURCE_PATH="/media/ASERVER/Lieferavis_DEL"  # Verzeichnis mit den entfernten Dateien
PAPERLESS_CONSUMPTION_DIR="/home/delphin/nextcloud/10_Ablagen/Archiv"  # Zielverzeichnis
PAPERLESS_CONSUMPTION_DIR_RECURSIVE="$PAPERLESS_CONSUMPTION_DIR/DELPHIN APOTHEKE"
#PAPERLESS_CONSUMPTION_DIR_RECURSIVE="$HOME/test"

TRACKING_FILE="/home/delphin/robots/lieferavis2archiv/processed_files_DEL.txt"  # Datei zur Verfolgung der verarbeiteten Dateien

echo "robot.lieferavis2archiv_del.sh"
echo "LESE LIEFERSCHEINE VON DELPHIN POTHEKE EIN."
echo "==========================================="


# Sicherstellen, dass die Tracking-Datei existiert
if [ ! -f "$TRACKING_FILE" ]; then
    echo "FEHLER: Tracking-Datei $TRACKING_FILE existiert nicht."
    exit 1
fi


# Sicherstellen, dass das Mount-Verzeichnis ASERVER existiert
if [ ! -d "$SOURCE_PATH" ]; then
    mkdir -p "$SOURCE_PATH"
fi


# Mounten
echo "Mounting $SOURCE_PATH"
#mount $SOURCE_PATH
#sudo mount -t cifs -o username=$USERNAME,password=$PASSWORD "$REMOTE_SHARE" "$MOUNT_POINT"

# Status des Quell-Verzeichnisses prüfen
if mount | grep -q "$SOURCE_PATH"; then
    echo "OK: ASERVER bereits auf $SOURCE_PATH gemountet"
else
    mount $SOURCE_PATH
    if mount | grep -q "$SOURCE_PATH"; then
	echo "OK: ASERVER erfolgreich auf $SOURCE_PATH gemountet."
    else
	echo "FEHLER: Mount von ASERVER auf $SOURCE_PATH fehlgeschlagen!"
        exit 1
    fi
fi

# Status des Ziel-Verzeichnisses prüfen
if mount | grep -q "$PAPERLESS_CONSUMPTION_DIR"; then
    echo "OK: Archivordner ist verbunden: PAPERLESS_CONSUMPTION_DIR"
else
    echo "FEHLER: Archivordner $PAPERLESS_CONSUMPTION_DIR ist nicht verbunden!"
    exit 1
fi

numExported=0
numDiscarded=0
numErrors=0

# Neue Dateien verarbeiten
for file in "$SOURCE_PATH"/*.pdf; do
    # Prüfen, ob es sich um eine reguläre Datei handelt
    if [ -f "$file" ]; then
        filename=$(basename "$file")

        # Prüfen, ob die Datei bereits verarbeitet wurde
        if ! grep -q "^$filename$" "$TRACKING_FILE"; then
            #echo "Verarbeite neue Datei: $file"

            # Datei in den Paperless-ngx-Konsumordner kopieren
            if cp "$file" "$PAPERLESS_CONSUMPTION_DIR_RECURSIVE/"; then
                #echo "cp $file $PAPERLESS_CONSUMPTION_DIR_RECURSIVE"
                #Nur für debugging
		echo "OK: Datei $file wurde erfolgreich nach $PAPERLESS_CONSUMPTION_DIR_RECURSIVE kopiert."
		#Erhöhe Counter der erfolgreichen Exporte um 1
		((numExported++))
                # Datei als verarbeitet markieren
                echo "$filename" >> "$TRACKING_FILE"
            else
		#Erhöhe Fehlercounter um 1
		((numErrors++))
                echo "WARNUNG: Fehler beim Kopieren der Datei $file."
            fi
        else
	    ((numDiscarded++))
            #echo "Überspringe bereits verarbeitete Datei: $file" #Das sollte in Produktion auskommentiert werden.
        fi
    fi
done

echo "OK: Delphin-Uebertragung von Lieferscheinen erfolgreich abgeschlossen."
echo "Anzahl kopierter Lieferscheine: $numExported."
echo "Anzahl uebersprungener Lieferscheine: $numDiscarded."
echo "Anzahl an FEHLERN: $numErrors."

umount $SOURCE_PATH

