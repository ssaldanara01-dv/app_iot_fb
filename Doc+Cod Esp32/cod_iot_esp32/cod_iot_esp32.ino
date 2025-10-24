
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <WiFiManager.h>
#include <DHT.h>
#include "time.h"

// -------------- CONFIGURA AQUI --------------
const char* FIREBASE_HOST = "db-iot-c500c-default-rtdb.firebaseio.com"; // sin https:// ni slash final
const char* FIREBASE_SECRET = "C2OA81XWmiRO22u2iNerI9xgI4O4guhlQ18b8dsA"; // legacy token (prototipo)

#define DHTPIN 4
#define DHTTYPE DHT11
#define PIR_PIN 15
#define BUZZER_PIN 16

#define READ_CONFIG_INTERVAL 5000        // ms
#define DHT_READ_INTERVAL 5000           // ms
#define TEMP_HYSTERESIS 0.3              // °C

// -------------- Globals ----------------
DHT dht(DHTPIN, DHTTYPE);
WiFiManager wifiManager;

String deviceId;
String pairingCode = "";
bool deviceClaimed = false;
String deviceOwnerUid = "";
unsigned long pairingCreatedAt = 0;

bool buzzerEnabled = true;
float tempThreshold = 28.0;

unsigned long lastConfigRead = 0;
unsigned long lastDHTRead = 0;

bool motionOngoing = false;
unsigned long pirStartMillis = 0;
String pirStartISO = "";


// ---------- Helpers REST ----------
WiFiClientSecure restClient() {
  WiFiClientSecure client;
  client.setInsecure(); // Para prototipo — en producción valida CA
  return client;
}

// Construye URL base: https://HOST + path + .json?auth=SECRET
String fbUrl(const String &pathNoDot) {
  // pathNoDot ejemplo: "/config/esp01/buzzerEnabled"
  String url = String("https://") + FIREBASE_HOST + pathNoDot + ".json?auth=" + FIREBASE_SECRET;
  return url;
}

// GET simple: devuelve body o empty string
String restGet(const String &pathNoDot) {
  if (!WiFi.isConnected()) return "";
  WiFiClientSecure client = restClient();
  HTTPClient https;
  String url = fbUrl(pathNoDot);
  if (!https.begin(client, url)) {
    // begin falló
    https.end();
    return "";
  }
  int httpCode = https.GET();
  String payload = "";
  if (httpCode == HTTP_CODE_OK) {
    payload = https.getString();
  } else {
    // no ok -> payload vacío
    //Serial.printf("GET %s -> %d\n", url.c_str(), httpCode);
  }
  https.end();
  return payload;
}

// PUT (set) JSON en path (reemplaza)
bool restPutJSON(const String &pathNoDot, const String &jsonPayload) {
  if (!WiFi.isConnected()) return false;
  WiFiClientSecure client = restClient();
  HTTPClient https;
  String url = fbUrl(pathNoDot);
  if (!https.begin(client, url)) {
    https.end();
    return false;
  }
  https.addHeader("Content-Type", "application/json");
  int code = https.PUT(jsonPayload);
  bool ok = (code == HTTP_CODE_OK);
  https.end();
  return ok;
}

// POST (push) JSON a path (genera new key)
bool restPostJSON(const String &pathNoDot, const String &jsonPayload) {
  if (!WiFi.isConnected()) return false;
  WiFiClientSecure client = restClient();
  HTTPClient https;
  String url = fbUrl(pathNoDot);
  if (!https.begin(client, url)) {
    https.end();
    return false;
  }
  https.addHeader("Content-Type", "application/json");
  int code = https.POST(jsonPayload);
  bool ok = (code == HTTP_CODE_OK || code == HTTP_CODE_CREATED);
  https.end();
  return ok;
}

// Helpers para parseo básico (sin ArduinoJson)
String stripQuotes(const String &s) {
  if (s.length() >= 2 && s[0] == '\"' && s[s.length()-1] == '\"') return s.substring(1, s.length()-1);
  return s;
}

bool parseBoolFromResp(const String &resp, bool &out) {
  String t = resp;
  t.trim();
  if (t == "true" || t == "\"true\"") { out = true; return true; }
  if (t == "false" || t == "\"false\"") { out = false; return true; }
  // si viene objeto {"buzzerEnabled":true} etc. buscar "true"/"false"
  if (t.indexOf("true") >= 0) { out = true; return true; }
  if (t.indexOf("false") >= 0) { out = false; return true; }
  return false;
}

bool parseFloatFromResp(const String &resp, float &out) {
  String t = resp;
  t.trim();
  t.replace("\"", "");
  if (t.length() == 0 || t == "null") return false;
  out = t.toFloat();
  return true;
}

String parseStringFromResp(const String &resp) {
  String t = resp;
  t.trim();
  if (t == "null" || t.length() == 0) return "";
  // resp puede venir con comillas -> strip
  return stripQuotes(t);
}

// ---------- Pairing ----------
String genPairingCode() {
  long r = (long)esp_random() % 900000 + 100000; // 6 dígitos
  char buf[8];
  sprintf(buf, "%06ld", r);
  return String(buf);
}

void publishPairingCodeIfNeeded() {
  String codePath = "/pairing/" + deviceId + "/code";
  String resp = restGet(codePath);
  if (resp.length() > 0 && resp != "null") {
    pairingCode = parseStringFromResp(resp);
    Serial.print("Pairing code existing: ");
    Serial.println(pairingCode);
    // check claimed
    String claimedResp = restGet("/pairing/" + deviceId + "/claimed");
    if (claimedResp.length() > 0 && claimedResp != "null") {
      bool cl = false;
      if (parseBoolFromResp(claimedResp, cl)) {
        deviceClaimed = cl;
        Serial.print("claimed = "); Serial.println(deviceClaimed ? "true" : "false");
      }
    }
    return;
  }

  // No existe -> crear bajo /pairing/<deviceId>
  pairingCode = genPairingCode();
  pairingCreatedAt = millis();
  String json = "{";
  json += "\"code\":\"" + pairingCode + "\"";
  json += ",\"createdAt\":\"" + String(getISOTime()) + "\"";
  json += ",\"claimed\":false";
  json += "}";
  bool ok = restPutJSON("/pairing/" + deviceId, json);
  if (ok) {
    Serial.print("Pairing creado: ");
    Serial.println(pairingCode);
  } else {
    Serial.println("Error creando pairing (REST).");
  }
  Serial.print("PAIRING CODE (serial): ");
  Serial.println(pairingCode);
}

// ---------- Check claim ----------
void checkIfClaimed() {
  String resp = restGet("/devices/" + deviceId + "/ownerUid");
  String uid = parseStringFromResp(resp);
  if (uid.length() > 0) {
    deviceOwnerUid = uid;
    deviceClaimed = true;
    Serial.print("Device claimed by uid: ");
    Serial.println(deviceOwnerUid);
  } else {
    deviceClaimed = false;
  }
}

// ---------- Config read ----------
void readRemoteConfig() {
  if (!WiFi.isConnected()) return;

  // buzzerEnabled
  String buzResp = restGet("/config/" + deviceId + "/buzzerEnabled");
  bool valBool;
  if (parseBoolFromResp(buzResp, valBool)) {
    // read lastUpdatedBy
    String lastBy = parseStringFromResp(restGet("/config/" + deviceId + "/lastUpdatedBy"));
    if (!deviceClaimed || lastBy.length() == 0 || lastBy == deviceOwnerUid) {
      buzzerEnabled = valBool;
      Serial.print("config.buzzerEnabled = "); Serial.println(buzzerEnabled ? "true" : "false");
    } else {
      Serial.println("Cambio buzzer ignorado: no hecho por owner.");
    }
  }

  // tempThreshold
  String tmpResp = restGet("/config/" + deviceId + "/tempThreshold");
  float valF;
  if (parseFloatFromResp(tmpResp, valF)) {
    String lastBy = parseStringFromResp(restGet("/config/" + deviceId + "/lastUpdatedBy"));
    if (!deviceClaimed || lastBy.length() == 0 || lastBy == deviceOwnerUid) {
      tempThreshold = valF;
      Serial.print("config.tempThreshold = "); Serial.println(tempThreshold);
    } else {
      Serial.println("Cambio tempThreshold ignorado: no hecho por owner.");
    }
  }
}

// ---------- Events write ----------
void writeEventToFirebaseRest(const String &type, const String &startTime, const String &endTime, unsigned long duration_s, float tempValue = NAN, bool buzzerUsed = false) {
  // Build JSON manually
  String j = "{";
  j += "\"type\":\"" + type + "\"";
  j += ",\"startTime\":\"" + startTime + "\"";
  j += ",\"endTime\":\"" + endTime + "\"";
  j += ",\"duration_s\":" + String((int)duration_s);
  j += ",\"buzzerUsed\":" + String(buzzerUsed ? "true" : "false");
  if (!isnan(tempValue)) j += ",\"temp_c\":" + String(tempValue);
  j += "}";

  bool ok = restPostJSON("/events/" + deviceId, j);
  if (ok) Serial.println("Evento enviado (REST).");
  else Serial.println("Fallo enviar evento (REST).");
}


// ---------- Time helper ----------
String getISOTime() {
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) {
    char buf[64];
    sprintf(buf, "uptime_ms_%lu", millis());
    return String(buf);
  }
  char buf[64];
  strftime(buf, sizeof(buf), "%Y-%m-%dT%H:%M:%S", &timeinfo);
  return String(buf);
}

// ---------- buzzer ----------
void beepBuzzer(unsigned long ms) {
  digitalWrite(BUZZER_PIN, HIGH);
  delay(ms);
  digitalWrite(BUZZER_PIN, LOW);
}

// ---------- setup / loop ----------
void setup() {
  Serial.begin(115200);
  delay(100);

  pinMode(PIR_PIN, INPUT);
  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, LOW);

  dht.begin();

  // seed random (seguro)
  randomSeed((unsigned long)esp_random());

  // WiFi config portal
  WiFi.mode(WIFI_STA);
  wifiManager.setTimeout(180);
  Serial.println("Conectando a WiFi...");
  if (!wifiManager.autoConnect("ESP32-AP")) {
    Serial.println("Portal timeout -> reboot");
    delay(1000);
    ESP.restart();
  }

  // Pequeña espera para estabilizar estado
  delay(200);
  Serial.print("*wm:STA IP Address: ");
  Serial.println(WiFi.localIP());
  Serial.print("IP: "); Serial.println(WiFi.localIP());

  // Ahora que WiFi está listo, crea deviceId usando MAC (más seguro aquí)
  deviceId = "esp" + WiFi.macAddress();
  deviceId.replace(":", "");
  Serial.print("deviceId: "); Serial.println(deviceId);

  // Inicializar NTP con espera y usando struct tm válido (no pasar nullptr)
  configTime(0, 0, "pool.ntp.org", "time.nist.gov");
  struct tm timeinfo;
  if (getLocalTime(&timeinfo, 5000)) {
    Serial.println("NTP ok");
  } else {
    Serial.println("NTP fallo (seguir de todas formas)");
  }

  // Espera ligera para evitar llamar HTTPS/TLS inmediatamente
  delay(200);

  // Publicar pairing si hace falta (solo si hay WiFi)
  if (WiFi.isConnected()) {
    publishPairingCodeIfNeeded();
    // Leer config inicial
    readRemoteConfig();
  } else {
    Serial.println("No hay WiFi después de conectar: no intento REST");
  }
}

void loop() {
  // check claim cada 7s aprox
  static unsigned long lastCheckClaim = 0;
  if (millis() - lastCheckClaim > 7000) {
    lastCheckClaim = millis();
    if (WiFi.isConnected()) checkIfClaimed();
  }

  // refresh config
  if (millis() - lastConfigRead > READ_CONFIG_INTERVAL) {
    lastConfigRead = millis();
    if (WiFi.isConnected()) readRemoteConfig();
  }

  // DHT lectura
  if (millis() - lastDHTRead > DHT_READ_INTERVAL) {
    lastDHTRead = millis();
    float t = dht.readTemperature();
    float h = dht.readHumidity();
    if (isnan(t)) {
      Serial.println("Error leyendo DHT11");
    } else {
      Serial.print("Temp: "); Serial.print(t); Serial.print(" °C  Hum: "); Serial.println(h);
      if (t > tempThreshold + TEMP_HYSTERESIS) {
        Serial.println("Temperatura alta detectada!");
        String ts = getISOTime();
        bool bz = false;
        if (buzzerEnabled) {
          bz = true;
          beepBuzzer(500);
        }
        writeEventToFirebaseRest("temperature", ts, ts, 0, t, bz);
      }
    }
  }

  // PIR polling: detectar inicio y fin con tiempos precisos
  int pirVal = digitalRead(PIR_PIN);
  if (pirVal == HIGH && !motionOngoing) {
    // inicio
    motionOngoing = true;
    pirStartMillis = millis();
    pirStartISO = getISOTime();
    Serial.println("Movimiento INICIADO");
    if (buzzerEnabled) digitalWrite(BUZZER_PIN, HIGH);
  } else if (pirVal == LOW && motionOngoing) {
    // fin
    motionOngoing = false;
    unsigned long pirEndMillis = millis();
    unsigned long dur_s = (pirEndMillis - pirStartMillis) / 1000;
    String pirEndISO = getISOTime();
    Serial.printf("Movimiento FINALIZADO, duracion: %lus\n", dur_s);
    if (buzzerEnabled) digitalWrite(BUZZER_PIN, LOW);
    writeEventToFirebaseRest("motion", pirStartISO, pirEndISO, dur_s, NAN, buzzerEnabled);
  }

  delay(40);
}
