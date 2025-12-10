#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <WiFiManager.h>
#include <DHT.h>
#include "time.h"

// -------------- CONFIGURA AQUI --------------
const char* FIREBASE_HOST = "db-iot-c500c-default-rtdb.firebaseio.com"; // sin https ni slash final
const char* FIREBASE_SECRET = "C2OA81XWmiRO22u2iNerI9xgI4O4guhlQ18b8dsA"; // legacy token (prototipo)
// deviceId lo manejamos como String (mutable y concat-friendly)
String deviceId = "espD0EF763382FC";

// Pines y ajustes
#define DHTPIN 4
#define DHTTYPE DHT11
#define PIR_PIN 15
#define BUZZER_PIN 16

#define READ_CONFIG_INTERVAL 5000        // ms
#define DHT_READ_INTERVAL 5000           // ms
#define TEMP_HYSTERESIS 0.3              // °C

// -------------- LCD I2C ----------------
#define LCD_ADDRESS 0x27   // dirección más común, si tu módulo es 0x3F cámbialo
LiquidCrystal_I2C lcd(LCD_ADDRESS, 16, 2);

// -------------- Globals ----------------
DHT dht(DHTPIN, DHTTYPE);
WiFiManager wifiManager;

String pairingCode = "";
uint32_t pairingCodeNum = 0;    // versión numérica no-negativa
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
  // Reservar para reducir realocaciones
  String url;
  url.reserve(150);
  url += "https://";
  url += FIREBASE_HOST;
  url += pathNoDot;
  url += ".json?auth=";
  url += FIREBASE_SECRET;
  return url;
}

// GET simple: devuelve body o empty string
String restGet(const String &pathNoDot) {
  if (!WiFi.isConnected()) return "";
  WiFiClientSecure client = restClient();
  HTTPClient https;
  String url = fbUrl(pathNoDot);
  if (!https.begin(client, url)) {
    https.end();
    return "";
  }
  int httpCode = https.GET();
  String payload = "";
  if (httpCode == HTTP_CODE_OK) {
    payload = https.getString();
  }
  https.end();
  return payload;
}

// PATCH (actualiza parcialmente, no reemplaza todo el nodo)
bool restPatchJSON(const String &pathNoDot, const String &jsonPayload) {
  if (!WiFi.isConnected()) return false;
  WiFiClientSecure client = restClient();
  HTTPClient https;
  String url = fbUrl(pathNoDot);
  if (!https.begin(client, url)) {
    https.end();
    return false;
  }
  https.addHeader("Content-Type", "application/json");
  int code = https.sendRequest("PATCH", (uint8_t*)jsonPayload.c_str(), jsonPayload.length());
  bool ok = (code == HTTP_CODE_OK);
  https.end();
  return ok;
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
  return stripQuotes(t);
}

// ---------- LCD helpers ----------
void lcdShowTop(const char* txt) {
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print(txt);
}

void lcdShowPairing(const String &code, bool claimed) {
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Vincular:");
  lcd.setCursor(0, 1);
  if (code.length() == 0) {
    lcd.print("generando...");
  } else {
    // mostrar código en formato 6 dígitos
    lcd.print(code);
    if (claimed) {
      lcd.print(" OK");
    }
  }
}

// ---------- Pairing ----------
uint32_t genPairingCodeNum() {
  // numero entre 100000 y 999999 (6 dígitos), no-negativo garantizado
  uint32_t r = (uint32_t)(esp_random() & 0xFFFFFFFF);
  r = (r % 900000U) + 100000U;
  return r;
}

String format6(uint32_t n) {
  char buf[8];
  sprintf(buf, "%06u", n);
  return String(buf);
}

void publishPairingCodeIfNeeded() {
  String codePath = String("/pairing/") + deviceId + "/code";
  String resp = restGet(codePath);
  if (resp.length() > 0 && resp != "null") {
    pairingCode = parseStringFromResp(resp);
    // intentar parse numérico (seguro que es dígitos)
    pairingCodeNum = (uint32_t) pairingCode.toInt();
    Serial.print("Pairing code existing: ");
    Serial.println(pairingCode);
    String claimedResp = restGet(String("/pairing/") + deviceId + "/claimed");
    if (claimedResp.length() > 0 && claimedResp != "null") {
      bool cl = false;
      if (parseBoolFromResp(claimedResp, cl)) {
        deviceClaimed = cl;
        Serial.print("claimed = "); Serial.println(deviceClaimed ? "true" : "false");
      }
    }
    // Mostrar en LCD
    lcdShowPairing(pairingCode, deviceClaimed);
    return;
  }

  pairingCodeNum = genPairingCodeNum();
  pairingCode = format6(pairingCodeNum);
  pairingCreatedAt = millis();

  // construir JSON de forma compacta
  String json;
  json.reserve(120);
  json  = "{\"code\":\"";
  json += pairingCode;
  json += "\",\"createdAt\":\"";
  json += getISOTime();
  json += "\",\"claimed\":false}";

  bool ok = restPutJSON(String("/pairing/") + deviceId, json);
  if (ok) {
    Serial.print("Pairing creado: ");
    Serial.println(pairingCode);
  } else {
    Serial.println("Error creando pairing (REST).");
  }
  Serial.print("PAIRING CODE (serial): ");
  Serial.println(pairingCode);

  // Mostrar en LCD
  lcdShowPairing(pairingCode, false);
}

// ---------- Check claim ----------
void checkIfClaimed() {
  String resp = restGet(String("/devices/") + deviceId + "/ownerUid");
  String uid = parseStringFromResp(resp);
  if (uid.length() > 0) {
    deviceOwnerUid = uid;
    deviceClaimed = true;
    Serial.print("Device claimed by uid: ");
    Serial.println(deviceOwnerUid);
    // actualizar LCD para indicar claim
    lcdShowPairing(pairingCode, true);
  } else {
    deviceClaimed = false;
  }
}

// ---------- Config read (ahora lee /devices y /config por compatibilidad) ----------
void readRemoteConfig() {
  if (!WiFi.isConnected()) return;

  String baseDev = String("/devices/") + deviceId;
  // pirEnabled
  String pirResp = restGet(baseDev + "/pirEnabled");
  bool tmpB;
  if (parseBoolFromResp(pirResp, tmpB)) {
    Serial.print("devices.pirEnabled = "); Serial.println(tmpB ? "true" : "false");
  }

  // alarm
  String alarmResp = restGet(baseDev + "/alarm");
  bool alarmVal;
  if (parseBoolFromResp(alarmResp, alarmVal)) {
    Serial.print("devices.alarm = "); Serial.println(alarmVal ? "true" : "false");
    if (alarmVal) {
      if (buzzerEnabled) {
        for (int i=0;i<3;i++){ beepBuzzer(200); delay(120); }
      }
      // ACK: resetear alarm a false
      restPatchJSON(baseDev + "/alarm", "false");
    }
  }

  // tempThreshold: primero /devices, luego /config
  float valF;
  String tmpDevResp = restGet(baseDev + "/tempThreshold");
  if (parseFloatFromResp(tmpDevResp, valF)) {
    tempThreshold = valF;
    Serial.print("devices.tempThreshold = "); Serial.println(tempThreshold);
  } else {
    String tmpCfgResp = restGet(String("/config/") + deviceId + "/tempThreshold");
    if (parseFloatFromResp(tmpCfgResp, valF)) {
      tempThreshold = valF;
      Serial.print("config.tempThreshold = "); Serial.println(tempThreshold);
    }
  }

  // buzzerEnabled: check devices then config
  String bzDev = restGet(baseDev + "/buzzerEnabled");
  bool bz;
  if (parseBoolFromResp(bzDev, bz)) {
    buzzerEnabled = bz;
    Serial.print("devices.buzzerEnabled = "); Serial.println(buzzerEnabled ? "true" : "false");
  } else {
    String bzCfg = restGet(String("/config/") + deviceId + "/buzzerEnabled");
    if (parseBoolFromResp(bzCfg, bz)) {
      buzzerEnabled = bz;
      Serial.print("config.buzzerEnabled = "); Serial.println(buzzerEnabled ? "true" : "false");
    }
  }
}

// ---------- Events write ----------
unsigned long nowMs() {
  time_t s = time(nullptr);
  if (s > 1000) { // NTP ok
    unsigned long ms = (unsigned long)s * 1000UL + (millis() % 1000);
    return ms;
  } else {
    return millis();
  }
}

void writeEventToFirebaseRest(const String &type, const String &startTime, const String &endTime, unsigned long duration_s, float tempValue = NAN, bool buzzerUsed = false) {
  String j;
  j.reserve(200);
  j  = "{";
  j += "\"type\":\""; j += type; j += "\"";
  j += ",\"startTime\":\""; j += startTime; j += "\"";
  j += ",\"endTime\":\""; j += endTime; j += "\"";
  j += ",\"duration_s\":" + String((int)duration_s);
  j += ",\"buzzerUsed\":" + String(buzzerUsed ? "true" : "false");
  if (!isnan(tempValue)) j += ",\"temp_c\":" + String(tempValue);
  j += ",\"timestamp\":" + String(nowMs());
  j += "}";
  bool ok = restPostJSON(String("/events/") + deviceId, j);
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

  randomSeed((unsigned long)esp_random());

  // Inicializar I2C y LCD
  Wire.begin(); // SDA=21, SCL=22 por defecto en la mayoría de ESP32
  lcd.init();
  lcd.backlight();
  lcdShowTop("Iniciando...");

  WiFi.mode(WIFI_STA);
  wifiManager.setTimeout(180);
  Serial.println("Conectando a WiFi...");
  if (!wifiManager.autoConnect("ESP32-AP")) {
    Serial.println("Portal timeout -> reboot");
    delay(1000);
    ESP.restart();
  }

  delay(200);
  Serial.print("*wm:STA IP Address: ");
  Serial.println(WiFi.localIP());

  // Generar deviceId usando MAC (coincide con app si usas mismo formato)
  deviceId = String("esp") + WiFi.macAddress();
  deviceId.replace(":", "");
  Serial.print("deviceId: "); Serial.println(deviceId);

  // Mostrar deviceId (acortado) en la LCD para depuración rápida
  String shortId = deviceId;
  if (shortId.length() > 16) shortId = shortId.substring(0, 16);
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("ID:");
  lcd.setCursor(4, 0);
  lcd.print(shortId);
  lcd.setCursor(0, 1);
  lcd.print("IP:");
  lcd.setCursor(3, 1);
  lcd.print(WiFi.localIP().toString());

  configTime(0, 0, "pool.ntp.org", "time.nist.gov");
  struct tm timeinfo;
  if (getLocalTime(&timeinfo, 5000)) {
    Serial.println("NTP ok");
  } else {
    Serial.println("NTP fallo (seguir de todas formas)");
  }

  delay(200);

  if (WiFi.isConnected()) {
    publishPairingCodeIfNeeded();
    readRemoteConfig(); // leer valores iniciales
    checkIfClaimed();
  } else {
    Serial.println("No hay WiFi después de conectar: no intento REST");
    lcdShowTop("Sin WiFi");
  }
}

void loop() {
  static unsigned long lastCheckClaim = 0;
  if (millis() - lastCheckClaim > 7000) {
    lastCheckClaim = millis();
    if (WiFi.isConnected()) checkIfClaimed();
  }

  if (millis() - lastConfigRead > READ_CONFIG_INTERVAL) {
    lastConfigRead = millis();
    if (WiFi.isConnected()) readRemoteConfig();
  }

  // DHT lectura: publicamos siempre telemetría y además temp_high si aplica
  if (millis() - lastDHTRead > DHT_READ_INTERVAL) {
    lastDHTRead = millis();
    float t = dht.readTemperature();
    float h = dht.readHumidity();
    if (isnan(t)) {
      Serial.println("Error leyendo DHT11");
    } else {
      Serial.print("Temp: "); Serial.print(t); Serial.print(" °C  Hum: "); Serial.println(h);

      // Publicar telemetría siempre
      String j;
      j.reserve(200);
      j  = "{";
      j += "\"type\":\"temperature\"";
      j += ",\"temp_c\":" + String(t);
      j += ",\"hum\":" + String(h);
      j += ",\"startTime\":\"" + getISOTime() + "\"";
      j += ",\"timestamp\":" + String(nowMs());
      j += "}";
      bool ok = restPostJSON(String("/events/") + deviceId, j);
      if (ok) Serial.println("Telemetry temp enviada");
      else Serial.println("Error enviar telemetry");

      // Actualizar nodo devices/<deviceId>/temperature para UI instantánea (PATCH para no borrar ownerUid)
      String devJson = "{\"temperature\":" + String(t) + "}";
      restPatchJSON(String("/devices/") + deviceId, devJson);

      // Si alta temperatura -> evento extra y marca lastTempHigh
      if (t > tempThreshold + TEMP_HYSTERESIS) {
        Serial.println("Temperatura alta detectada!");
        if (buzzerEnabled) beepBuzzer(500);

        String j2;
        j2.reserve(160);
        j2  = "{";
        j2 += "\"type\":\"temp_high\"";
        j2 += ",\"temp_c\":" + String(t);
        j2 += ",\"startTime\":\"" + getISOTime() + "\"";
        j2 += ",\"timestamp\":" + String(nowMs());
        j2 += "}";
        restPostJSON(String("/events/") + deviceId, j2);

        // actualizar lastTempHigh en devices (PATCH)
        String put = "{\"lastTempHigh\":\"" + getISOTime() + "\"}";
        restPatchJSON(String("/devices/") + deviceId, put);
      }
    }
  }

  // PIR polling: detectar inicio y fin con tiempos precisos
  int pirVal = digitalRead(PIR_PIN);
  if (pirVal == HIGH && !motionOngoing) {
    motionOngoing = true;
    pirStartMillis = millis();
    pirStartISO = getISOTime();
    Serial.println("Movimiento INICIADO");
    if (buzzerEnabled) digitalWrite(BUZZER_PIN, HIGH);
  } else if (pirVal == LOW && motionOngoing) {
    motionOngoing = false;
    unsigned long pirEndMillis = millis();
    unsigned long dur_s = (pirEndMillis - pirStartMillis) / 1000;
    String pirEndISO = getISOTime();
    Serial.printf("Movimiento FINALIZADO, duracion: %lus\n", dur_s);
    if (buzzerEnabled) digitalWrite(BUZZER_PIN, LOW);
    writeEventToFirebaseRest("motion", pirStartISO, pirEndISO, dur_s, NAN, buzzerEnabled);

    // también actualizar lastMotion en devices para UI instantánea (PATCH)
    String put = "{\"lastMotion\":\"" + getISOTime() + "\"}";
    restPatchJSON(String("/devices/") + deviceId, put);
  }

  delay(40);
}
