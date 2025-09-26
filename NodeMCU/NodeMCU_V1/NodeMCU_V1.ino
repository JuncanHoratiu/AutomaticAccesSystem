#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>
#include <SPI.h>
#include <MFRC522.h>

const char* ssid = "ABC12";
const char* password = "5932bfe8";

ESP8266WebServer server(80);

// ----- Releu, LED, Buton -----
const int ledPin = D1;
const int ledOnboardPin = D4;
bool ledState = HIGH;

// ----- RFID -----
#define SS_PIN D4
#define RST_PIN D3
MFRC522 rfid(SS_PIN, RST_PIN);
byte authorizedUIDs[][4] = {
  {0x5D, 0x7A, 0x1C, 0x2F},
  {0x83, 0x51, 0xBA, 0xD9}
};
const int authorizedCount = sizeof(authorizedUIDs) / sizeof(authorizedUIDs[0]);

// ----- MAX9814 -----
const int soundSensorPin = A0;
const int soundThreshold = 600;
bool alertSoundDetected = false;
unsigned long lastSoundTime = 0;
const unsigned long alertDuration = 5000;
unsigned long lastSoundCheck = 0;
const unsigned long soundCheckInterval = 2000;

// ----- Cerere acces buton -----
const int buttonPin = D2;
bool accessButtonPressed = false;
unsigned long lastAccessButtonTime = 0;
const unsigned long accessRequestDuration = 10000;

// ----- Funcții -----
void updateLedStatus() {
  digitalWrite(ledPin, ledState);
  digitalWrite(ledOnboardPin, (ledState == LOW) ? LOW : HIGH);
}

void unlockDoor() {
  Serial.println("Acces permis. Ușa se deschide...");
  digitalWrite(ledPin, LOW);
  digitalWrite(ledOnboardPin, LOW);
  delay(3000);
  digitalWrite(ledPin, HIGH);
  digitalWrite(ledOnboardPin, HIGH);
  ledState = HIGH;
}

bool isAuthorized(byte *uid) {
  for (int i = 0; i < authorizedCount; i++) {
    bool match = true;
    for (int j = 0; j < 4; j++) {
      if (uid[j] != authorizedUIDs[i][j]) {
        match = false;
        break;
      }
    }
    if (match) return true;
  }
  return false;
}

void detectSound() {
  if (millis() - lastSoundCheck >= soundCheckInterval) {
    lastSoundCheck = millis();
    int soundLevel = analogRead(soundSensorPin);
    if (soundLevel > soundThreshold) {
      Serial.println("Sunet detectat - ALERTĂ!");
      alertSoundDetected = true;
      lastSoundTime = millis();
    }
  }
}

// ----- Web -----
void handleRoot() {
  server.send(200, "text/plain", "ESP8266 activ");
}
void handleLedOn() {
  ledState = HIGH;
  updateLedStatus();
  server.send(200, "text/plain", "Usa inchisa");
}
void handleLedOff() {
  ledState = LOW;
  updateLedStatus();
  server.send(200, "text/plain", "Usa deschisa");
}
void handleStatus() {
  server.send(200, "text/plain", String(ledState));
}
void handleUnlock() {
  Serial.println("Cerere de deblocare primită.");
  unlockDoor();
  server.send(200, "text/plain", "Ușa a fost deblocată.");
}
void handleAlert() {
  if (alertSoundDetected && (millis() - lastSoundTime <= alertDuration)) {
    server.send(200, "text/plain", "1");
  } else {
    alertSoundDetected = false;
    server.send(200, "text/plain", "0");
  }
}
void handleAccessRequest() {
  if (accessButtonPressed && (millis() - lastAccessButtonTime <= accessRequestDuration)) {
    server.send(200, "text/plain", "1");
  } else {
    accessButtonPressed = false;
    server.send(200, "text/plain", "0");
  }
}

void setup() {
  pinMode(ledPin, OUTPUT);
  pinMode(ledOnboardPin, OUTPUT);
  pinMode(buttonPin, INPUT_PULLUP);
  updateLedStatus();

  Serial.begin(115200);
  delay(1000);

  WiFi.begin(ssid, password);
  Serial.print("Conectare WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nConectat la rețea: " + WiFi.localIP().toString());

  SPI.begin();
  rfid.PCD_Init();
  Serial.println("Modul RFID inițializat.");

  // ✅ Configurare rute HTTP
  server.on("/", handleRoot);
  server.on("/on", handleLedOn);
  server.on("/off", handleLedOff);
  server.on("/status", handleStatus);
  server.on("/unlock", handleUnlock);
  server.on("/alert", handleAlert);
  server.on("/access-request", handleAccessRequest);

  server.begin();
  Serial.println("Server HTTP pornit.");
}

void loop() {
  server.handleClient();

  if (digitalRead(buttonPin) == LOW) {
    delay(50);
    while (digitalRead(buttonPin) == LOW) delay(10);
    Serial.println("Buton acces apăsat!");
    accessButtonPressed = true;
    lastAccessButtonTime = millis();
  }

  if (rfid.PICC_IsNewCardPresent() && rfid.PICC_ReadCardSerial()) {
    Serial.print("Card detectat. UID: ");
    for (byte i = 0; i < rfid.uid.size; i++) {
      Serial.print(rfid.uid.uidByte[i] < 0x10 ? "0" : "");
      Serial.print(rfid.uid.uidByte[i], HEX);
      Serial.print(" ");
    }
    Serial.println();
    if (isAuthorized(rfid.uid.uidByte)) {
      unlockDoor();
    } else {
      Serial.println("Acces respins. Card necunoscut.");
    }
    rfid.PICC_HaltA();
  }

  detectSound();
}
