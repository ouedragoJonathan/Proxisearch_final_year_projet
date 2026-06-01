#include <esp_wifi.h>
#include <vector>
#include <WiFi.h>

// ======== CONFIGURATION ========
const uint8_t sniffChannel = 8;
const unsigned long sniffDuration = 10000;

// Identifiant de l'esp 32
const String espID = "A";
 

struct PacketInfo {
  uint8_t mac[6];
  int rssi;
};

std::vector<PacketInfo> packetList;
bool sniffing = false;
unsigned long sniffStartTime = 0;

// Adresse MAC de mon téléphone (aléatoire pour ce réseau) juste pour tester
uint8_t targetMac[6] = {0xAA, 0x88, 0xAC, 0x42, 0xA2, 0xE3};


// -------------------------------------------------------
// DÉCLARATION des fonctions AVANT leur utilisation
// -------------------------------------------------------

void startSniffing();           // prototype
void stopSniffingAndShow();     // prototype

// -------------------------------------------------------
void snifferCallback(void* buf, wifi_promiscuous_pkt_type_t type) {
  wifi_promiscuous_pkt_t* pkt = (wifi_promiscuous_pkt_t*)buf;
  if (pkt->rx_ctrl.sig_len < 16) return;

  uint8_t* src = &pkt->payload[10];
  int rssi = pkt->rx_ctrl.rssi;

  // On ne garde que les trames de mon téléphone
  if (memcmp(src, targetMac, 6) != 0) return;


  if (packetList.size() < 100) {
    PacketInfo p;
    memcpy(p.mac, src, 6);
    p.rssi = rssi;
    packetList.push_back(p);
  }
}

// -------------------------------------------------------
void startSniffing() {
  WiFi.disconnect(true);
  delay(100);
  WiFi.mode(WIFI_STA);

  esp_wifi_set_promiscuous_rx_cb(snifferCallback);
  esp_wifi_set_promiscuous(true);
  esp_wifi_set_channel(sniffChannel, WIFI_SECOND_CHAN_NONE);

  packetList.clear();
  sniffing = true;
  sniffStartTime = millis();
  Serial.println("\n🔍 Sniffing démarré sur le canal " + String(sniffChannel));
}

// -------------------------------------------------------
void stopSniffingAndShow() {
  esp_wifi_set_promiscuous(false);
  sniffing = false;

  Serial.println("=== Paquets capturés (" + String(packetList.size()) + ") ===");
  for (size_t i = 0; i < packetList.size(); i++) {
    char macStr[18];
    snprintf(macStr, sizeof(macStr), "%02X:%02X:%02X:%02X:%02X:%02X",
             packetList[i].mac[0], packetList[i].mac[1], packetList[i].mac[2],
             packetList[i].mac[3], packetList[i].mac[4], packetList[i].mac[5]);
    Serial.printf("[%2d] MAC=%s  RSSI=%d dBm\n", i, macStr, packetList[i].rssi);
  }
  Serial.println("=====================================\n");

  packetList.clear();
  startSniffing();
}

// -------------------------------------------------------
void setup() {
  Serial.begin(115200);
  WiFi.mode(WIFI_OFF);
  delay(100);
  startSniffing();
}

// -------------------------------------------------------
void loop() {
  if (sniffing && millis() - sniffStartTime >= sniffDuration) {
    stopSniffingAndShow();
  }
}