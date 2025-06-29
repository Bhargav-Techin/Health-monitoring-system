#include <Wire.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <Adafruit_MLX90614.h>
#include "MAX30105.h"
#include "spo2_algorithm.h"  // SparkFun SpO2 processing

// ============ WiFi & ThingSpeak ============
const char* ssid = "Bh******H";
const char* password = "12******90";
const String apiKey = "EZM**********5Q5";
const String server = "http://api.thingspeak.com/update";

// ============ Sensor & Buzzer Setup ============
Adafruit_MLX90614 mlx = Adafruit_MLX90614();
MAX30105 particleSensor;

#define BUZZER_PIN 18
unsigned long lastSendTime = 0;
unsigned long interval = 5000; // 5 seconds

// Buffers for SpO2 calculation
uint32_t irBuffer[100];   // Infrared LED sensor data
uint32_t redBuffer[100];  // Red LED sensor data

void setup() {
  Serial.begin(115200);
  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, LOW);

  Wire.begin(21, 22);  // SDA, SCL pins for ESP32

  // Connect to WiFi
  WiFi.begin(ssid, password);
  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi connected!");
  Serial.print("IP Address: ");
  Serial.println(WiFi.localIP());

  // MLX90614 setup
  if (!mlx.begin()) {
    Serial.println("MLX90614 not detected. Check wiring.");
    while (1);
  } else {
    Serial.println("MLX90614 connected.");
  }

  // MAX30102 setup
  if (!particleSensor.begin(Wire, I2C_SPEED_STANDARD)) {
    Serial.println("MAX30102 not detected. Check wiring.");
    while (1);
  } else {
    Serial.println("MAX30102 connected.");
    particleSensor.setup();  // Default settings
    particleSensor.setPulseAmplitudeRed(0x3F);  // Higher brightness
    particleSensor.setPulseAmplitudeIR(0x3F);
  }
}

void loop() {
  if (millis() - lastSendTime >= interval) {
    // ============ Read temperature ============
    float temp = mlx.readObjectTempC();
    Serial.print("Body Temp (°C): ");
    Serial.println(temp);

    // ============ Read HR and SpO2 ============
    int32_t spo2;
    int8_t validSPO2;
    int32_t heartRate;
    int8_t validHeartRate;

    for (int i = 0; i < 100; i++) {
      while (particleSensor.available() == false) particleSensor.check();
      redBuffer[i] = particleSensor.getRed();
      irBuffer[i] = particleSensor.getIR();
      particleSensor.nextSample();
    }

    // Corrected function call
    maxim_heart_rate_and_oxygen_saturation(
      irBuffer,
      100,
      redBuffer,
      &spo2,
      &validSPO2,
      &heartRate,
      &validHeartRate
    );

    Serial.print("Heart Rate (BPM): ");
    Serial.println(validHeartRate ? heartRate : 0);

    Serial.print("SpO2 (%): ");
    Serial.println(validSPO2 ? spo2 : 0);

    // ============ Buzzer Logic ============
    if (temp > 42.0 || (validHeartRate && heartRate > 200)) {
      digitalWrite(BUZZER_PIN, HIGH);
      Serial.println("⚠️ Warning: Abnormal values detected! Buzzer ON.");
    } else {
      digitalWrite(BUZZER_PIN, LOW);
    }

    // ============ Send to ThingSpeak ============
    if (WiFi.status() == WL_CONNECTED) {
      HTTPClient http;
      String url = server + "?api_key=" + apiKey +
                   "&field1=" + String(temp) +
                   "&field2=" + String(validHeartRate ? heartRate : 0) +
                   "&field3=" + String(validSPO2 ? spo2 : 0);

      http.begin(url);
      int httpCode = http.GET();
      if (httpCode > 0) {
        Serial.println("✅ Data sent to ThingSpeak.");
      } else {
        Serial.print("❌ HTTP Error: ");
        Serial.println(httpCode);
      }
      http.end();
    } else {
      Serial.println("❌ WiFi not connected.");
    }

    Serial.println("-------------------------------");
    lastSendTime = millis();
  }
}
