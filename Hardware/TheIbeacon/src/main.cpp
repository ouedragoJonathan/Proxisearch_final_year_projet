#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <BLEBeacon.h>

// put function declarations here:
#define DEVICE_NAME "MON_IBEACON"
#define SERVICE_UUID "2cba8be0-8bd8-4dc7-936a-84bafd7c5f72"
#define BEACON_UUID "7c09ada1-4db9-48b5-b520-107dfffe9b10"
#define BEACON_UUID_REV "0bfcdcdd-08b7-4759-ba88-4d44b5a5bdf6"
#define CHARACTERISTIC_UUID "71da6a95-5734-4d28-a372-d583f31ac6f7"


BLEServer *pServer;
BLECharacteristic *pCharacteristic;
bool deviceConnected=false;
uint8_t value = 0;
void init_service();
void init_beacon();


class MyServerCallbacks:public BLEServerCallbacks{
  void onConnect(BLEServer* pServer){
    deviceConnected=true;
    Serial.println("deviceConnected = true");
  };

  void onDisconnect(BLEServer* pServer){
    deviceConnected=true;
    Serial.println("deviceConnected = false");

    // Restart advertising to be visible and connectable again
      BLEAdvertising* pAdvertising;
      pAdvertising = pServer->getAdvertising();
      pAdvertising->start();
      Serial.println("iBeacon advertising restarted");

  }

};

class MyCallbacks: public BLECharacteristicCallbacks {

    void onWrite(BLECharacteristic *pCharacteristic) {

      std::string rxValue = pCharacteristic->getValue();

      if (rxValue.length() > 0) {

        Serial.println("*********");

        Serial.print("Received Value: ");

        for (int i = 0; i < rxValue.length(); i++) {

          Serial.print(rxValue[i]);
        }
        Serial.println();

        Serial.println("*********");
      }
    }
};



void setup() {
  // put your setup code here, to run once:
  Serial.begin(115200);
  Serial.println();
  Serial.println("Initializing...");
  Serial.flush();
  BLEDevice::init(DEVICE_NAME);
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());
  init_service();
  init_beacon();
 
}

void loop() {
  // put your main code here, to run repeatedly:
    if (deviceConnected) {
    Serial.printf("*** NOTIFY: %d ***n", value);
    pCharacteristic->setValue(&value, 1);
    pCharacteristic->notify();
    value++;
  };
  delay(2000);

}

// put function definitions here:
void init_service() {
  BLEAdvertising* pAdvertising;
  pAdvertising = pServer->getAdvertising();
  pAdvertising->stop();
  // Create the BLE Service
  BLEService *pService = pServer->createService(BLEUUID(SERVICE_UUID));
  // Create a BLE Characteristic
  pCharacteristic = pService->createCharacteristic(
                      CHARACTERISTIC_UUID,
                      BLECharacteristic::PROPERTY_READ   |
                      BLECharacteristic::PROPERTY_WRITE  |
                      BLECharacteristic::PROPERTY_NOTIFY
                    );
  pCharacteristic->setCallbacks(new MyCallbacks());
  pCharacteristic->addDescriptor(new BLE2902());
  pAdvertising->addServiceUUID(BLEUUID(SERVICE_UUID));
  // Start the service
  pService->start();
  pAdvertising->start();
};



void init_beacon() {
  BLEAdvertising* pAdvertising;
  pAdvertising = pServer->getAdvertising();
  pAdvertising->stop();
  // iBeacon
  BLEBeacon myBeacon;
  myBeacon.setManufacturerId(0x4c00);
  myBeacon.setMajor(5);
  myBeacon.setMinor(88);
  myBeacon.setSignalPower(0xc5);
  myBeacon.setProximityUUID(BLEUUID(BEACON_UUID_REV));
  BLEAdvertisementData advertisementData;
  advertisementData.setFlags(0x1A);
  advertisementData.setManufacturerData(myBeacon.getData());
  pAdvertising->setAdvertisementData(advertisementData);
  pAdvertising->start();
}
