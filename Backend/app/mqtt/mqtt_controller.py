import paho.mqtt.client as mqtt
import time
import asyncio
from app.services.trilateration import multilateration_position
from app.core.state import process_position

MQTT_BROKER = "192.168.100.127"
MQTT_PORT = 1883

# BUG CORRIGÉ : MAX_AGE passe de 3s à 10s.
# Les 3 ESP publient leurs RSSI dans une fenêtre qui peut aller jusqu'à ~5-6s
# selon l'activité réseau du téléphone en mode promiscuous. Avec 3s, la mesure
# du premier ESP expirait avant que le troisième publie → les 3 RSSI n'étaient
# jamais présents simultanément → aucune position ne pouvait être calculée.
MAX_AGE = 10.0

mqtt_client = mqtt.Client(client_id="proxisearch-server")
phone_data = {}
ready_esps = set()
go_sent = False
_missing_a_logged: set[str] = set()

# Téléphones vendeurs verrouillés : position figée, plus de trilatération live
locked_phones: dict[str, tuple[float, float]] = {}


def lock_phone_position(mac: str, position: tuple[float, float]) -> None:
    mac = mac.strip().upper()
    locked_phones[mac] = position
    if mac in phone_data:
        phone_data[mac]["position"] = position
        phone_data[mac]["locked"] = True


def unlock_phone_position(mac: str) -> None:
    mac = mac.strip().upper()
    locked_phones.pop(mac, None)
    if mac in phone_data:
        phone_data[mac]["locked"] = False


def on_connect(client, userdata, flags, rc):
    global go_sent, ready_esps
    if rc == 0:
        print("✅ Serveur connecté à Mosquitto avec succès.")
        client.subscribe("esp32/+/pret", qos=0)
        client.subscribe("+/+/rssi", qos=0)
        # B/C ont souvent déjà reçu le GO avant le démarrage du serveur ; A reste
        # bloqué sans mesure. On renvoie GO à chaque connexion pour resynchroniser.
        ready_esps.clear()
        go_sent = False
        client.publish("esp32/clock", "GO")
        go_sent = True
        print("🚦 Signal GO envoyé (démarrage / reconnexion serveur).")
    else:
        print(f"❌ Échec de la connexion MQTT, code : {rc}")


def on_message(client, userdata, msg):
    global phone_data, go_sent

    topic = msg.topic
    try:
        payload = msg.payload.decode()
    except UnicodeDecodeError:
        print(f"⚠️ Payload illisible sur {topic}")
        return

    # --- Annonce "prêt" d'un ESP32 ---
    if topic.startswith("esp32/") and topic.endswith("/pret"):
        esp_id = topic.split("/")[1]
        if esp_id not in ("A", "B", "C"):
            return
        ready_esps.add(esp_id)
        print(f"📍 ESP32 {esp_id} prêt ({len(ready_esps)}/3)")
        if len(ready_esps) == 3 and not go_sent:
            mqtt_client.publish("esp32/clock", "GO")
            go_sent = True
            print("🚦 Tous les ESP32 prêts — signal GO envoyé (une seule fois).")
        return

    # --- Mesure RSSI → {mac_tel}/{id_esp}/rssi ---
    parts = topic.split("/")
    if len(parts) != 3 or parts[2] != "rssi":
        return

    phone_mac = parts[0].strip().upper()
    esp_id    = parts[1]

    try:
        rssi = float(payload)
    except ValueError:
        print(f"⚠️ RSSI invalide de {esp_id} : {payload}")
        return

    if phone_mac not in phone_data:
        phone_data[phone_mac] = {"rssi": {}, "timestamps": {}, "position": None, "locked": False}

    data = phone_data[phone_mac]

    # Vendeur verrouillé : on ignore les nouvelles mesures RSSI
    if phone_mac in locked_phones:
        data["position"] = locked_phones[phone_mac]
        data["locked"] = True
        return
    data["rssi"][esp_id]       = rssi
    data["timestamps"][esp_id] = time.time()
    print(f"📡 [{phone_mac}] RSSI {esp_id} = {rssi} dBm")

    now = time.time()

    # Nettoyage des mesures périmées (MAX_AGE corrigé à 10s)
    for k in list(data["timestamps"].keys()):
        if now - data["timestamps"][k] > MAX_AGE:
            print(f"⏳ [{phone_mac}] Mesure {k} trop vieille (>{MAX_AGE}s) — ignorée.")
            del data["timestamps"][k]

    if "A" in data["timestamps"] and "B" in data["timestamps"] and "C" in data["timestamps"]:
        rssi_a = data["rssi"]["A"]
        rssi_b = data["rssi"]["B"]
        rssi_c = data["rssi"]["C"]
        raw_x, raw_y = multilateration_position(rssi_a, rssi_b, rssi_c)
        smooth_x, smooth_y = process_position(
            phone_mac,
            (raw_x, raw_y),
            rssi_a,
            rssi_b,
            rssi_c,
            tau=1.5,
        )
        data["position"] = (round(smooth_x, 2), round(smooth_y, 2))
        print(
            f"📍 [{phone_mac}] Position : x={smooth_x:.2f}, y={smooth_y:.2f} "
            f"(RSSI A={rssi_a:.0f} B={rssi_b:.0f} C={rssi_c:.0f})"
        )
        data["timestamps"].clear()
        _missing_a_logged.discard(phone_mac)
    elif (
        "B" in data["timestamps"]
        and "C" in data["timestamps"]
        and "A" not in data["timestamps"]
        and phone_mac not in _missing_a_logged
    ):
        print(
            f"⚠️ [{phone_mac}] RSSI A manquant — trilatération impossible "
            f"(B={data['rssi'].get('B')}, C={data['rssi'].get('C')}). "
            f"Vérifiez que l'ESP32 A a bien reçu le signal GO."
        )
        _missing_a_logged.add(phone_mac)


async def start_mqtt():
    mqtt_client.on_connect = on_connect
    mqtt_client.on_message = on_message
    try:
        mqtt_client.connect(MQTT_BROKER, MQTT_PORT, 60)
        mqtt_client.loop_start()
        print("🔌 Client MQTT démarré (en attente des 3 ESP32 pour le GO)")
    except Exception as e:
        print(f"❌ Impossible de se connecter au broker MQTT : {e}")
        return False
    return True


if __name__ == "__main__":
    if asyncio.run(start_mqtt()):
        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            print("\n🛑 Arrêt manuel.")
        finally:
            mqtt_client.loop_stop()
            mqtt_client.disconnect()
            print("💤 Serveur MQTT arrêté.")