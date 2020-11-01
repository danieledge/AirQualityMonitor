#include <FlashAsEEPROM_SAMD.h>
#include <FlashAsEEPROM_SAMD_Impl.h>
#include <FlashStorage_SAMD51.h>

#include <bsec.h>
#include <AtWiFi.h>
#include"TFT_eSPI.h"
#include <PubSubClient.h>
#include "Free_Fonts.h"
#include "bsec_serialized_configurations_iaq.h"

#define BME_SCK 13
#define BME_MISO 12
#define BME_MOSI 11
#define BME_CS 10
#define IIC_ADDR  uint8_t(0x76)

#define STATE_SAVE_PERIOD  UINT32_C(360 * 60 * 1000) // 360 minutes - 4 times a day

// Update these with values suitable for your network.
const char* ssid = "Downstairs Wifi"; // WiFi Name
const char* password = "MYPASS";  // WiFi Password
const char* mqtt_server = "homeassistant.local";  // MQTT Broker URL
const char* mqtt_user = "Daniel"; // MQTT User
const char* mqtt_pass = "MQTTPASS"; //MQTT Password
String clientId = "RoomSensor1";

const char* topic1 = "HAStateStream50/roomsensor1/room_sensor1_rawTemperature/state";
const char* topic1_unit = "HAStateStream50/roomsensor1/room_sensor1_rawTemperature/unit_of_measurement";
const char* topic1_unit_value = "\u00b0C";
const char* topic1_title = "Raw Temperature";


const char* topic2 =  "HAStateStream50/roomsensor1/room_sensor1_pressure/state";
const char* topic2_unit = "HAStateStream50/roomsensor1/room_sensor1_pressure/unit_of_measurement";
const char* topic2_title = "Pressure";
const char* topic2_unit_value = "hPA";

const char* topic3 = "HAStateStream50/roomsensor1/room_sensor1_rawRelativeHumidity/state";
const char* topic3_unit = "HAStateStream50/roomsensor1/room_sensor1_rawRelativeHumidity/unit_of_measurement";
const char* topic3_title = "Raw Relative Humidity";
const char* topic3_unit_value = "%";

const char* topic4 = "HAStateStream50/roomsensor1/room_sensor1_gasResistance/state";
const char* topic4_unit = "HAStateStream50/roomsensor1/room_sensor1_gasResistance/unit_of_measurement";
const char* topic4_title = "Gas Resistance";
const char* topic4_unit_value = "Ohm";

const char* topic5 = "HAStateStream50/roomsensor1/room_sensor1_IAQ/state";
const char* topic5_unit = "HAStateStream50/roomsensor1/room_sensor1_IAQ/unit_of_measurement";
const char* topic5_title = "IAQ";
const char* topic5_unit_value = "IAQ";

const char* topic6 = "HAStateStream50/roomsensor1/room_sensor1_IAQ_ACCURACY/state";
const char* topic6_unit = "HAStateStream50/roomsensor1/room_sensor1_IAQ_ACCURACY/unit_of_measurement";
const char* topic6_title = "IAQ Accuracy";
const char* topic6_unit_value = "IAQ ACC";

const char* topic7 = "HAStateStream50/roomsensor1/room_sensor1_temperature/state";
const char* topic7_unit = "HAStateStream50/roomsensor1/room_sensor1_temperature/unit_of_measurement";
const char* topic7_title = "Temperature";
const char* topic7_unit_value = "\u00b0C";

const char* topic8 = "HAStateStream50/roomsensor1/room_sensor1_RelativeHumidity/state";
const char* topic8_unit = "HAStateStream50/roomsensor1/room_sensor1_RelativeHumidity/unit_of_measurement";
const char* topic8_title = "Relative Humidity";
const char* topic8_unit_value = "%";

const char* topic9 = "HAStateStream50/roomsensor1/room_sensor1_StaticIAQ/state";
const char* topic9_unit = "HAStateStream50/roomsensor1/room_sensor1_StaticIAQ/unit_of_measurement";
const char* topic9_title = "Static IAQ";
const char* topic9_unit_value = "IAQ";

const char* topic10 = "HAStateStream50/roomsensor1/room_sensor1_co2Equivalent/state";
const char* topic10_unit = "HAStateStream50/roomsensor1/room_sensor1_co2Equivalent/unit_of_measurement";
const char* topic10_title = "CO2";
const char* topic10_unit_value = "ppm";

const char* topic11 = "HAStateStream50/roomsensor1/room_sensor1_breathVOCequivalent/state";
const char* topic11_unit = "HAStateStream50/roomsensor1/room_sensor1_breathVOCequivalent/unit_of_measurement";
const char* topic11_title = "Breath VOC";
const char* topic11_unit_value = "ppm";

const char* screen_title = "Enviroment Sensor";


TFT_eSPI tft;
WiFiClient wioClient;
PubSubClient client(wioClient);

// Create an object of the class Bsec
Bsec iaqSensor;
String output;

uint8_t bsecState[BSEC_MAX_STATE_BLOB_SIZE] = {0};
uint16_t stateUpdateCounter = 0;
//#include "config/generic_33v_3s_4d/bsec_iaq.txt"
//const uint8_t bsec_config_iaq[] = {};


// Helper functions declarations
void checkIaqSensorStatus(void);
void errLeds(void);
void loadState(void);
void updateState(void);
/*
   Set up Wifi Connection

*/
void setup_wifi() {
  delay(10);
  tft.begin();
  tft.setRotation(3);
  tft.fillScreen(TFT_BLACK);
  tft.setFreeFont(FMB12);
  tft.setCursor((320 - tft.textWidth("Connecting to Wi-Fi..")) / 2, 120);
  tft.print("Connecting to Wi-Fi..");
  WiFi.begin(ssid, password); // Connecting WiFi

  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("WiFi connected");

  tft.fillScreen(TFT_BLACK);
  tft.setCursor((320 - tft.textWidth("Connected!")) / 2, 120);
  tft.print("Connected!");

  Serial.println("IP address: ");
  Serial.println(WiFi.localIP()); // Display Local IP Address

  // Set Up Screen and Display Title
  tft.fillScreen(TFT_BLACK);
  tft.setFreeFont(FF17);
  tft.setTextColor(tft.color565(224, 225, 232));
  tft.drawString(screen_title, 10, 10);



}

/*
   Connect to MQTT Server

*/
void reconnect() {
  client.setServer(mqtt_server, 1883); // Connect the MQTT Server
  // Loop until we're reconnected
  while (!client.connected()) {
    Serial.print("Attempting MQTT connection...");
    // Attempt to connect
    if (client.connect(clientId.c_str(), mqtt_user, mqtt_pass)) {
      Serial.println("connected");

      //Set Up Unit Of Measurements

      if (client.publish(topic1_unit, topic1_unit_value))
      {
        Serial.println("Publish message success: Topic 1 Unit Value");
      }
      else
      {
        Serial.println("Could not send message :Topic 1 Unit Value");
      }

      if (client.publish(topic2_unit, topic2_unit_value))
      {
        Serial.println("Publish message success: Topic 2 Unit Value");
      }
      else
      {
        Serial.println("Could not send message :Topic 2 Unit Value");
      }

      if (client.publish(topic3_unit, topic3_unit_value))
      {
        Serial.println("Publish message success: Topic 3 Unit Value");
      }
      else
      {
        Serial.println("Could not send message :Topic 3 Unit Value");
      }

      if (client.publish(topic4_unit, topic4_unit_value))
      {
        Serial.println("Publish message success: Topic 4 Unit Value");
      }
      else
      {
        Serial.println("Could not send message :Topic 4 Unit Value");
      }

      if (client.publish(topic5_unit, topic5_unit_value))
      {
        Serial.println("Publish message success: Topic 5 Unit Value");
      }
      else
      {
        Serial.println("Could not send message :Topic 5 Unit Value");
      }

      if (client.publish(topic6_unit, topic6_unit_value))
      {
        Serial.println("Publish message success: Topic 6 Unit Value");
      }
      else
      {
        Serial.println("Could not send message :Topic 6 Unit Value");
      }

      if (client.publish(topic7_unit, topic7_unit_value))
      {
        Serial.println("Publish message success: Topic 7 Unit Value");
      }
      else
      {
        Serial.println("Could not send message :Topic 7 Unit Value");
      }
      if (client.publish(topic8_unit, topic8_unit_value))
      {
        Serial.println("Publish message success: Topic 8 Unit Value");
      }
      else
      {
        Serial.println("Could not send message :Topic 8 Unit Value");
      }
      if (client.publish(topic9_unit, topic9_unit_value))
      {
        Serial.println("Publish message success: Topic 9 Unit Value");
      }
      else
      {
        Serial.println("Could not send message :Topic 9 Unit Value");
      }
      if (client.publish(topic10_unit, topic10_unit_value))
      {
        Serial.println("Publish message success: Topic 10 Unit Value");
      }
      else
      {
        Serial.println("Could not send message :Topic 10 Unit Value");
      }
      if (client.publish(topic11_unit, topic11_unit_value))
      {
        Serial.println("Publish message success: Topic 11 Unit Value");
      }
      else
      {
        Serial.println("Could not send message :Topic 11 Unit Value");
      }

    } else {
      Serial.print("failed, rc=");
      Serial.print(client.state());
      Serial.println(" try again in 5 seconds");
      // Wait 5 seconds before retrying
      delay(5000);
    }
  }
}

void setup_multisensor() {
  //EEPROM.begin(BSEC_MAX_STATE_BLOB_SIZE + 1); // 1st address for the length
  Serial.begin(9600);
  Wire.begin();

  iaqSensor.begin(BME680_I2C_ADDR_PRIMARY, Wire);
  output = "\nBSEC library version " + String(iaqSensor.version.major) + "." + String(iaqSensor.version.minor) + "." + String(iaqSensor.version.major_bugfix) + "." + String(iaqSensor.version.minor_bugfix);
  Serial.println(output);
  //iaqSensor.setConfig(bsec_config_iaq);
  //checkIaqSensorStatus();
   loadState();


  bsec_virtual_sensor_t sensorList[10] = {
    BSEC_OUTPUT_RAW_TEMPERATURE,
    BSEC_OUTPUT_RAW_PRESSURE,
    BSEC_OUTPUT_RAW_HUMIDITY,
    BSEC_OUTPUT_RAW_GAS,
    BSEC_OUTPUT_IAQ,
    BSEC_OUTPUT_STATIC_IAQ,
    BSEC_OUTPUT_CO2_EQUIVALENT,
    BSEC_OUTPUT_BREATH_VOC_EQUIVALENT,
    BSEC_OUTPUT_SENSOR_HEAT_COMPENSATED_TEMPERATURE,
    BSEC_OUTPUT_SENSOR_HEAT_COMPENSATED_HUMIDITY,
  };
  iaqSensor.updateSubscription(sensorList, 10, BSEC_SAMPLE_RATE_LP);
  checkIaqSensorStatus();
}

void setup() {

    
  tft.begin();
  tft.fillScreen(TFT_BLACK);
  tft.setRotation(3);
  Serial.println();

  setup_wifi();
  setup_multisensor() ;
  reconnect();

  // Set Up Units of Measurement
  if (client.publish(topic1_unit, topic1_unit_value))
  {
    Serial.println("Publish message success: Topic 1 Unit Value");
  }
  else
  {
    Serial.println("Could not send message :Topic 1 Unit Value");
  }

  if (client.publish(topic2_unit, topic2_unit_value))
  {
    Serial.println("Publish message success: Topic 2 Unit Value");
  }
  else
  {
    Serial.println("Could not send message :Topic 2 Unit Value");
  }

  if (client.publish(topic3_unit, topic3_unit_value))
  {
    Serial.println("Publish message success: Topic 3 Unit Value");
  }
  else
  {
    Serial.println("Could not send message :Topic 3 Unit Value");
  }

  if (client.publish(topic4_unit, topic4_unit_value))
  {
    Serial.println("Publish message success: Topic 4 Unit Value");
  }
  else
  {
    Serial.println("Could not send message :Topic 4 Unit Value");
  }

  if (client.publish(topic5_unit, topic5_unit_value))
  {
    Serial.println("Publish message success: Topic 5 Unit Value");
  }
  else
  {
    Serial.println("Could not send message :Topic 5 Unit Value");
  }

  if (client.publish(topic6_unit, topic6_unit_value))
  {
    Serial.println("Publish message success: Topic 6 Unit Value");
  }
  else
  {
    Serial.println("Could not send message :Topic 6 Unit Value");
  }

  if (client.publish(topic7_unit, topic7_unit_value))
  {
    Serial.println("Publish message success: Topic 7 Unit Value");
  }
  else
  {
    Serial.println("Could not send message :Topic 7 Unit Value");
  }
  if (client.publish(topic8_unit, topic8_unit_value))
  {
    Serial.println("Publish message success: Topic 8 Unit Value");
  }
  else
  {
    Serial.println("Could not send message :Topic 8 Unit Value");
  }
  if (client.publish(topic9_unit, topic9_unit_value))
  {
    Serial.println("Publish message success: Topic 9 Unit Value");
  }
  else
  {
    Serial.println("Could not send message :Topic 9 Unit Value");
  }
  if (client.publish(topic10_unit, topic10_unit_value))
  {
    Serial.println("Publish message success: Topic 10 Unit Value");
  }
  else
  {
    Serial.println("Could not send message :Topic 10 Unit Value");
  }
  if (client.publish(topic11_unit, topic11_unit_value))
  {
    Serial.println("Publish message success: Topic 11 Unit Value");
  }
  else
  {
    Serial.println("Could not send message :Topic 11 Unit Value");
  }

}

/*

   Main Loop - Loop Forever!

*/
void loop(void)
{

  if (!client.connected()) {
       Serial.println("I found I wasn't connected to mqtt so went in to mqtt reconnect");
    reconnect();
  }

if (WiFi.status() != WL_CONNECTED) {
     Serial.println("I found I wasn't connected so went in to wifi setup");
     setup_wifi();
  }
  
  unsigned long time_trigger = millis();
  if (iaqSensor.run()) { // If new data is available
    output = String(time_trigger);
    output += ", " + String(iaqSensor.rawTemperature);
    output += ", " + String(iaqSensor.pressure);
    output += ", " + String(iaqSensor.rawHumidity);
    output += ", " + String(iaqSensor.gasResistance);
    output += ", " + String(iaqSensor.iaq);
    output += ", " + String(iaqSensor.iaqAccuracy);
    output += ", " + String(iaqSensor.temperature);
    output += ", " + String(iaqSensor.humidity);
    output += ", " + String(iaqSensor.staticIaq);
    output += ", " + String(iaqSensor.co2Equivalent);
    output += ", " + String(iaqSensor.breathVocEquivalent);
    Serial.println(output);
    updateState();
    
    tft.fillRoundRect(10, 45, 300, 55, 5, tft.color565(40, 40, 86));
    tft.fillRoundRect(10, 105, 300, 55, 5, tft.color565(40, 40, 86));
    tft.fillRoundRect(10, 165, 300, 55, 5, tft.color565(40, 40, 86));

    tft.setFreeFont(FMB9); // Draw Titles
    tft.drawString(topic7_title, 10, 50); // Temperature
    tft.drawString(topic8_title, 10, 110); // Humidity

    tft.setTextColor(TFT_GREEN); // Draw Air Quality Index as Title In Green
    tft.drawString(("Air Quality:" + String(iaqSensor.staticIaq) + "(" + String(iaqSensor.iaqAccuracy) + ")" ), 10, 170); // IAQ

    tft.setTextColor(tft.color565(224, 225, 232)); // Reset Text Color
    tft.drawString(String(iaqSensor.rawTemperature) + "" + topic7_unit_value, 10, 75);  // Display Latest Temperature
    tft.drawString(String(iaqSensor.rawHumidity) + "" + topic8_unit_value, 10, 135);    // Display Latest Humidity

    tft.setFreeFont(FM9); // Display CO2 and Breath VOC
    tft.drawString(("CO2:" + String(iaqSensor.co2Equivalent) + "" + String(topic10_unit_value) + " bVoc:" + String(iaqSensor.breathVocEquivalent) + "" + String(topic11_unit_value)), 10, 195);

    //Publish Raw Temp
    if (client.publish(topic1, String(iaqSensor.rawTemperature).c_str()))
    {
      Serial.println("Publish Temp message success");
    }
    else
    {
      Serial.println("Could not send Temp message :(");
    }

    //Publish Raw Pressure
    if (client.publish(topic2, String(iaqSensor.pressure).c_str()))
    {
      Serial.println("Publish Pressure message success");
    }
    else
    {
      Serial.println("Could not send Pressure message :(");
    }


    //Publish Raw Relative Humidity
    if (client.publish(topic3, String(iaqSensor.rawHumidity).c_str()))
    {
      Serial.println("Publish Humidity message success");
    }
    else
    {
      Serial.println("Could not send Humidity message :(");
    }


    //Publish Raw gasResistance
    if (client.publish(topic4, String(iaqSensor.gasResistance).c_str()))
    {
      Serial.println("Publish Gas message success");
    }
    else
    {
      Serial.println("Could not send Gas message :(");
    }


    //Publish IAQ
    if (client.publish(topic5, String(iaqSensor.iaq).c_str()))
    {
      Serial.println("Publish IAQ message success");
    }
    else
    {
      Serial.println("Could not send IAQ message :(");
    }

    //Publish IAQ Accuracy
    if (client.publish(topic6, String(iaqSensor.iaqAccuracy).c_str()))
    {
      Serial.println("Publish IAQ Accuracy message success");
    }
    else
    {
      Serial.println("Could not send IAQ Accuracy  message :(");
    }

    //Publish temperature
    if (client.publish(topic7, String(iaqSensor.temperature).c_str()))
    {
      Serial.println("Publish temperature message success");
    }
    else
    {
      Serial.println("Could not send temperature message :(");
    }

    // Publish Humidity
    if (client.publish(topic8, String(iaqSensor.humidity).c_str()))
    {
      Serial.println("Publish Humidity message success");
    }
    else
    {
      Serial.println("Could not send Humidity message :(");
    }

    // Publish Static IAQ
    if (client.publish(topic9, String(iaqSensor.staticIaq).c_str()))
    {
      Serial.println("Publish Static IAQ message success");
    }
    else
    {
      Serial.println("Could not send Static IAQ message :(");
    }

    // Publish CO2 Equivalent IAQ
    if (client.publish(topic10, String(iaqSensor.co2Equivalent).c_str()))
    {
      Serial.println("Publish  Co2 Equiv message success");
    }
    else
    {
      Serial.println("Could not send Co2 message :(");
    }
    // Publish  Breath VOC
    if (client.publish(topic11, String(iaqSensor.breathVocEquivalent).c_str()))
    {
      Serial.println("Publish breathVocEquivalent message success");
    }
    else
    {
      Serial.println("Could not send breathVocEquivalent message :(");
    }

  } else {
    checkIaqSensorStatus();
  }

  // delay(5000);

  // client.loop();
}

void checkIaqSensorStatus(void)
{
  if (iaqSensor.status != BSEC_OK) {
    if (iaqSensor.status < BSEC_OK) {
      output = "BSEC error code : " + String(iaqSensor.status);
      Serial.println(output);
      //  for (;;)
      //  errLeds(); /* Halt in case of failure */
    } else {
      output = "BSEC warning code : " + String(iaqSensor.status);
      Serial.println(output);
    }
  }

  if (iaqSensor.bme680Status != BME680_OK) {
    if (iaqSensor.bme680Status < BME680_OK) {
      output = "BME680 error code : " + String(iaqSensor.bme680Status);
      Serial.println(output);
      //for (;;)
      // errLeds(); /* Halt in case of failure */
    } else {
      output = "BME680 warning code : " + String(iaqSensor.bme680Status);
      Serial.println(output);
    }
  }
}

void errLeds(void)
{
  pinMode(LED_BUILTIN, OUTPUT);
  digitalWrite(LED_BUILTIN, HIGH);
  delay(100);
  digitalWrite(LED_BUILTIN, LOW);
  delay(100);
}

void updateState(void)
{
  bool update = false;
  if (stateUpdateCounter == 0) {
    /* First state update when IAQ accuracy is >= 3 */
    if (iaqSensor.iaqAccuracy >= 3) {
      update = true;
      stateUpdateCounter++;
    }
  } else {
    /* Update every STATE_SAVE_PERIOD minutes */
    if ((stateUpdateCounter * STATE_SAVE_PERIOD) < millis()) {
      update = true;
      stateUpdateCounter++;
    }
  }

  if (update) {
    iaqSensor.getState(bsecState);
    checkIaqSensorStatus();

    Serial.println("Writing state to EEPROM");

    for (uint8_t i = 0; i < BSEC_MAX_STATE_BLOB_SIZE ; i++) {
      EEPROM.write(i + 1, bsecState[i]);
      Serial.println(bsecState[i], HEX);
    }

    EEPROM.write(0, BSEC_MAX_STATE_BLOB_SIZE);
    EEPROM.commit();
  }
}

void loadState(void)
{
  if (EEPROM.read(0) == BSEC_MAX_STATE_BLOB_SIZE) {
    // Existing state in EEPROM
    Serial.println("Reading state from EEPROM");

    for (uint8_t i = 0; i < BSEC_MAX_STATE_BLOB_SIZE; i++) {
      bsecState[i] = EEPROM.read(i + 1);
      Serial.println(bsecState[i], HEX);
    }
    iaqSensor.setState(bsecState);
    checkIaqSensorStatus();
  } else {
    // Erase the EEPROM with zeroes
    Serial.println("Erasing EEPROM");

    for (uint8_t i = 0; i < BSEC_MAX_STATE_BLOB_SIZE + 1; i++)
      EEPROM.write(i, 0);

    EEPROM.commit();
  }
}