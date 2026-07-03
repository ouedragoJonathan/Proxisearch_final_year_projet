#include <WiFi.h>
#include <esp_wifi.h>
#include <PubSubClient.h>
#include <map>
#include <vector>
#include <algorithm>

// ======== CONFIGURATION ========
const String espID = "A"; // À changer en "B" ou "C" sur chaque carte

const char* apSsid     = "ESP32-A";
const char* apPassword = "";

const char* staSsid     = "InViis-4G";
const char* staPassword = "InviisLabnet@2015#";

const char* mqttServer = "192.168.100.127";
const int   mqttPort   = 1883;

const int SAMPLE_COUNT = 35;
// ===============================

WiFiClient   wifiClient;
PubSubClient mqttClient(wifiClient);

bool readyToMeasure = false;
bool announcedReady = false;

std::map<String, std::vector<int8_t>> samplesByPhone;

String macToString(const uint8_t* mac) {
  char buf[18];
  snprintf(buf, sizeof(buf), "%02X:%02X:%02X:%02X:%02X:%02X",
           mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
  return String(buf);
}

int8_t computeMode(const std::vector<int8_t>& values) {
  if (values.empty()) return 0;
  int bestCount = 0;
  int8_t bestValue = values.back();

  for (size_t i = 0; i < values.size(); i++) {
    int count = 0;
    for (size_t j = 0; j < values.size(); j++) {
      if (values[j] == values[i]) count++;
    }
    if (count > bestCount) {
      bestCount = count;
      bestValue = values[i];
    }
  }
  if (bestCount <= 1) {
    return values.back();
  }
  return bestValue;
}

// BUG CORRIGÉ : remplace ARDUINO_EVENT_WIFI_AP_PROBEREQRECVED par le mode
// promiscuous. L'ancien event ne capte que les probe requests — trames émises
// par un téléphone qui CHERCHE des réseaux. Dès qu'il est connecté (même à
// l'AP de cet ESP32), il arrête d'en émettre → samplesByPhone reste vide →
// aucun RSSI n'est jamais publié → le serveur ne calcule jamais de position.
// Le mode promiscuous capte TOUTES les trames 802.11 dans l'air, y compris
// les Data frames du téléphone connecté à l'AP.
void IRAM_ATTR promiscuousCallback(void* buf, wifi_promiscuous_pkt_type_t type) {
  if (!readyToMeasure) return;
  if (type != WIFI_PKT_MGMT && type != WIFI_PKT_DATA) return;

  const wifi_promiscuous_pkt_t* pkt = (wifi_promiscuous_pkt_t*)buf;
  if (pkt->rx_ctrl.sig_len < 16) return;

  int8_t rssi = (int8_t)pkt->rx_ctrl.rssi;
  const uint8_t* frame = pkt->payload;

  // Filtre broadcast/multicast
  if (frame[10] & 0x01) return;

  // Filtre notre propre MAC d'AP
  uint8_t apMac[6];
  esp_wifi_get_mac(WIFI_IF_AP, apMac);
  bool isSelf = true;
  for (int i = 0; i < 6; i++) {
    if (frame[10 + i] != apMac[i]) { isSelf = false; break; }
  }
  if (isSelf) return;

  String phoneMac = macToString(frame + 10);
  samplesByPhone[phoneMac].push_back(rssi);
}

void mqttCallback(char* topic, byte* payload, unsigned int length) {
  String topicStr = String(topic);
  String msg;
  for (unsigned int i = 0; i < length; i++) msg += (char)payload[i];

  if (topicStr == "esp32/clock") {
    Serial.println("\n🚦 [" + espID + "] Signal GO reçu — démarrage de la boucle.");
    samplesByPhone.clear();
    readyToMeasure = true;
    // readyToMeasure reste true pour toujours : l'ESP tourne en boucle
    // infinie mesure → publie → mesure → publie sans jamais s'arrêter.
  }
}

void announceReady() {
  String topic = "esp32/" + espID + "/pret";
  mqttClient.publish(topic.c_str(), "1");
  Serial.println("✅ [" + espID + "] Annoncé prêt sur " + topic);
  announcedReady = true;
}

void connectMqtt() {
  mqttClient.setServer(mqttServer, mqttPort);
  mqttClient.setCallback(mqttCallback);

  while (!mqttClient.connected()) {
    Serial.print("📶 [" + espID + "] Connexion à Mosquitto...");
    String clientId = "esp32-" + espID;
    if (mqttClient.connect(clientId.c_str())) {
      Serial.println(" connecté.");
      mqttClient.subscribe("esp32/clock");
      announceReady();
    } else {
      Serial.println(" échec, nouvelle tentative dans 2s.");
      delay(2000);
    }
  }
}

void publishReadySamples() {
  for (auto it = samplesByPhone.begin(); it != samplesByPhone.end(); ) {
    const String& phoneMac = it->first;
    std::vector<int8_t>& samples = it->second;

    if ((int)samples.size() >= SAMPLE_COUNT) {
      int8_t rssiToSend = computeMode(samples);
      String topic = phoneMac + "/" + espID + "/rssi";
      String payloadStr = String(rssiToSend);
      mqttClient.publish(topic.c_str(), payloadStr.c_str());

      Serial.println("📡 [" + espID + "] " + topic + " = " + payloadStr
                     + " (mode sur " + String(samples.size()) + " mesures)");

      it = samplesByPhone.erase(it);
      // readyToMeasure reste true → repart immédiatement en collecte
    } else {
      ++it;
    }
  }
}

void setup() {
  Serial.begin(115200);
  Serial.println("\n=== ESP32 " + espID + " ===");

  WiFi.mode(WIFI_AP_STA);
  WiFi.softAP(apSsid, apPassword);
  Serial.println("📡 [" + espID + "] AP démarré : " + String(apSsid));

  WiFi.begin(staSsid, staPassword);
  unsigned long t0 = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - t0 < 15000) {
    delay(500);
    Serial.print(".");
  }
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n✅ [" + espID + "] STA connecté à " + String(staSsid));
  } else {
    Serial.println("\n⚠️ [" + espID + "] Connexion STA échouée.");
  }

  esp_wifi_set_promiscuous(true);
  esp_wifi_set_promiscuous_rx_cb(&promiscuousCallback);
  Serial.println("🔍 [" + espID + "] Mode promiscuous activé.");

  connectMqtt();
}

void loop() {
  if (!mqttClient.connected()) {
    connectMqtt();
  }
  mqttClient.loop();

  // Ré-annonce "prêt" toutes les 5s tant que le GO n'est pas reçu
  static unsigned long lastAnnounce = 0;
  if (!readyToMeasure && millis() - lastAnnounce > 5000) {
    announceReady();
    lastAnnounce = millis();
  }


  if (readyToMeasure) {
    publishReadySamples();
  }
}