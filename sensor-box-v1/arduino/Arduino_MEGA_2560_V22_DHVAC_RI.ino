#include <dht11.h>


/**
 * BLE on Arduino with sensors
 * code for Arduino MEGA 2560
 * created on: 2014/7/4
 * 
 * Copyright 2014 T2T Inc. 
 *
 * 
 * 
 **/
// 2014 Dec. 
// Ready for remote control via BBB+Cloud. 

// 2014 Sep. Added: 
// Sensor ID HEAD
//@"EC",                      // index ID: E
//@"TDS",                     // index ID: D
//@"SAL",                     // index ID: S
//@"SG",                      // index ID: G
//@"ph",                      // index ID: P
//@"CO2",                     // index ID: C
//@"Humidity",                // index ID: H
//@"Temperature",             // index ID: T
//@"Water Temperature",       // index ID: W
//@"High Water Level",        // index ID: X
//@"Low Water Level",         // index ID: Y

// 2015 Jan. Added:  
//@"VOC sensor",              // index ID: V
//@"Air Pressure sensor",     // index ID: R
//@"Sound Volume",            // index ID: Z
//@"Photoresistor value",     // index ID: B
//@"PM2.5",                   // index ID: M

// Control ID HEAD
//@"Fan",                     // index ID: F 
//@"LED Dimming",             // index ID: L 
//@"PUMP",                    // index ID: U
//@"LED Array",               // index ID: A
//@"Sensor Switch"            // index ID: N
//@"Power OnOff"              // index ID: O
//@"Sensor Data Interval"     // inded ID: I
 
#include <Arduino.h>
#include <Wire.h>
#include <Servo.h>   
#include <dht11.h>     // Thermometer and Humidity Sensor
#include <OneWire.h>   // Water-proof-thermometer 
#include <LedControl.h>
#include <SFE_BMP180.h>


#define SOFTUART 1
//#define ENABLE_PH_SENSOR 1
//#define ENABLE_EC_SENSOR 1  // ENABLE_PM_2_POINT_5_SENSOR_S3 and ENABLE_EC_SENSOR are both connected to Serial3. 
//#define ENABLE_CO2METERS_CO2_SENSOR  1  // ENABLE_CO2METERS_CO2_SENSOR and the other CO2 sensors are connected to Serial1. 
//#define ENABLE_GE_CO2_SENSOR   1
#define ENABLE_LED_DIMMING_I2C 1
#define ENABLE_VOC_SENSOR_I2C  1
#define ENABLE_AIR_PRESSURE_SENSOR_I2C  1
#define ENABLE_PM_2_POINT_5_SENSOR_S3   1  // ENABLE_PM_2_POINT_5_SENSOR_S3 and ENABLE_EC_SENSOR are both connected to Serial3. 


// For unit test
//#define DUMMY_TEST_CONTROL 1
//#define DUMMY_TEST_SENSOR  1

#define DEFAULT_RATE 9600
#define MIN_SENSOR_UPDATE_INTERVAL  1000
#define MAX_SENSOR_UPDATE_INTERVAL  10000


// For  Meter's CO2 Sensor
#if defined ENABLE_CO2METERS_CO2_SENSOR
#define CO2_COMMAND_LENGTH 7
#define CO2_COMMAND_LENGTH_MID_BYTE 3
// The command to read data from CO2 Sensor
uint8_t co2_cmd_read_co2_data[7] = {0xFE, 0X44, 0X00, 0X08, 0X02, 0X9F, 0X25};
unsigned long co2_resp_read_co2_value;
#endif  // ENABLE_CO2METERS_CO2_SENSOR

// For GE's CO2 Sensor
#if defined ENABLE_GE_CO2_SENSOR
#define CO2_COMMAND_LENGTH 5
#define CO2_COMMAND_LENGTH_MID_BYTE 3
uint8_t co2_cmd_read_co2_data[5] = {0xFF, 0xFE, 0x02, 0x02, 0x03};
unsigned long co2_resp_read_co2_value;
#endif  //ENABLE_GE_CO2_SENSOR

// to seperate 4 different attribute: EC,TDS,SAL,SG
#define EC_INDEX_EC    0
#define EC_INDEX_TDS   1
#define EC_INDEX_SAL   2
#define EC_INDEX_SG    3

//For Photoresistor
#define PHOTORESISTOR_ANALOG_PIN   2   // Analog Pin only
int photoresistorValue = 0;            // Photoresistor value. 

// For LED Array
LedControl lc=LedControl(51,52,53,1);  // Pin number for Arduino Mega 2560
unsigned int led_array_icon_id = 0xFF ; // 0xFF means off

#if defined ENABLE_LED_DIMMING_I2C
// LED Dimming with I2C
#define LED_DIMMING_OFF_VALUE 128
byte LED_DIMMING_SLAVE_ADDRESS = 0X2E; // 0x5C for 256-bit
byte i2c_error;
//byte LED_DIMMING_SLAVE_ADDRESS = 0x5C; 
byte led_dimming_value = 0;
byte led_dimming_ack = 0;
#endif


#if defined ENABLE_VOC_SENSOR_I2C
// VOC 
#define VOC_COMMAND_LENGTH 7
#define VOC_COMMAND_LENGTH_VOC_BYTE 4
byte VOC_SENSOR_SLAVE_ADDRESS = 0x5A; // 0x5A for 256-bit, 0x2B for 128 bit
byte voc_read_bytes[VOC_COMMAND_LENGTH];
unsigned long voc_co2_prediction = 0; 
unsigned long voc_resistance_value = 0;
#endif


#if defined ENABLE_AIR_PRESSURE_SENSOR_I2C
// Airpressure 
byte AIR_PRESSURE_SENSOR_SLAVE_ADDRESS = 0x77; // 0x77 for 256-bit, 0x3B for 128 bit
//byte i2c_error;
SFE_BMP180 pressure;
#define ALTITUDE 1655.0 // Altitude of Taipei City in Boulder, CO. in meters
byte air_pressure_value = 0;
byte air_pressure_ack = 0;
#endif

// Microphone (sensor)
#define MICROPHONE_DIGITAL_PIN  3
#define MICROPHONE_ANALOG_PIN   0 // analog IO A0
int mic_nVolume;
int mic_bSound;


// PM2.5 Sensor
#if defined ENABLE_PM_2_POINT_5_SENSOR_S3
#define PM25_READ_BYTE_BEGIN    0
#define PM25_READ_BYTE_VOUT_H   1
#define PM25_READ_BYTE_VOUT_L   2
#define PM25_READ_BYTE_VREF_H   3
#define PM25_READ_BYTE_VREF_L   4
#define PM25_READ_BYTE_CHKSUM   5
#define PM25_READ_BYTE_END      6
#define PM25_COMMAND_LENGTH     7
int  pm25_read_byte_state = 0;
boolean pm25_input_readcomplete = false;
//byte pm25_read_bytes[PM25_COMMAND_LENGTH];
byte pm25_current_read_byte;
float pm25_Vo;
#endif

Servo servos[6];
uint8_t myservoPin[6]={3,5,6,9,10,11};

// The variables for PWM control
#define FAN_SPEED_PWM_PIN 11  // PWM pin 11 output for fan speed control  
#define FAN_ON_OFF_PIN    10   
int fan_on_off = 0;
int fan_pwm = 0;

// The variables for ON.OFF control. 
#define LED_BRIGHTNESS_PWM_PIN 7  // PWM pin 7 output for LED brightness control 
#define LED_ON_OFF_PIN 8
int led_on_off = 0;
int led_pwm = 0;

// The variables for ON.OFF control. 
#define PUMP_ON_OFF_PIN   9
int pump_on_off = 0;

// The variables for water level sensors. 
#define LOW_WATER_LEVEL_PIN   4
#define HIGH_WATER_LEVEL_PIN  5

// The variables for Thermo and Humidity Sensor
#define DHT11_PIN 6  // DHT11 = RHT03 pin 6(Digital/PWM)
//#define DHT11_PIN 2  // DHT11 connects to A2. 

dht11 DHT11;

//The variables for Water-proof-thermometer 
#define DS18S20_PIN 2  // DS18S20 pin 2
OneWire ds(DS18S20_PIN);  // Temperature chip i/o

String parameter[10];
int arg[10];
volatile uint8_t state=0;
volatile int paraIndex=-1;

uint8_t readData[20];
uint8_t readIndex=0;

unsigned long time;
unsigned long sensorTime;
unsigned long unitTestSensorTime; 


#if defined DUMMY_TEST_SENSOR
int dummy_sensor_data_change_switch = 0;
#endif

// Power on off
int powerOnOff = 0;

// Sensor 
int sensorSwitch = 1;

// Sensor interval
int sensorInterval = MIN_SENSOR_UPDATE_INTERVAL;

/********** LED array related **************************************/
// LED pattern
// 9 icons of 8x8
unsigned char icon_lib[9][8] = {0x00,0x24,0x66,0x24,0x00,0x81,0x66,0x3C,
0x00,0x42,0x24,0x42,0x00,0x3C,0x66,0x81,0xC3,0xE7,0x66,0x3C,0x3C,0x66,0xE7,
0xC3,0x3C,0x7E,0xE7,0xC3,0xC3,0xE7,0x7E,0x3C,0x49,0x92,0x92,0xDB,0x49,0x00,
0xC3,0x7E,0xEA,0x2A,0xEE,0x82,0xE2,0x00,0x00,0x00,0x81,0x42,0x66,0x42,0x99,
0x24,0x24,0x3C,0x10,0x14,0x58,0x38,0x58,0x14,0x18,0x10,0xC,0x18,0x18,0x7E,
0x18,0x18,0x18,0x18};

void draw_icon_invert(unsigned char *icon){
  unsigned char mask[]={1, 2, 4, 8, 16, 32, 64, 128};
  lc.clearDisplay(0);
  for(int r=0; r<8; r++){
    for(int c=0; c<8; c++){
      if(icon[7-r] & mask[c])    //draw invert vertically due to yasai installation
        lc.setLed(0,r,c,true);  //draw to the LED array
    } 
  }
}

/********** LED array numbers drawing **************************************/
unsigned char num_lib[11][8] = {0x07,0x05,0x05,0x05,0x07,0x00,0x00,0x00,0x06,
  0x02,0x02,0x02,0x07,0x00,0x00,0x00,0x07,0x01,0x07,0x04,0x07,0x00,0x00,0x00,
  0x07,0x01,0x07,0x01,0x07,0x00,0x00,0x00,0x05,0x05,0x07,0x01,0x01,0x00,0x00,
  0x00,0x07,0x04,0x07,0x01,0x07,0x00,0x00,0x00,0x04,0x04,0x07,0x05,0x07,0x00,
  0x00,0x00,0x07,0x01,0x01,0x01,0x01,0x00,0x00,0x00,0x07,0x05,0x07,0x05,0x07,
  0x00,0x00,0x00,0x07,0x05,0x07,0x01,0x01,0x00,0x00,0x00,0x00,0x00,0x66,0x99,
  0x99,0x66,0x00,0x00};

void draw_num(int value){
  int ceiling_space = 1;  //space from top
  if((value > 99) || (value < 0))
    draw_icon_invert(num_lib[10]);
  else{
    unsigned char frame[8] = {0,0,0,0,0,0,0,0};
    char x = value/10; char y = value%10;
    for(int i = 0; i<5; i++){
      frame[i+ceiling_space] = num_lib[x][i]<<4 | num_lib[y][i];
      //frame[i+ceiling_space] = num_lib[y][i];
    }
    draw_icon_invert(frame);
  }
}


// boot animation related
unsigned char logo_lib[4][8] = {0x62,0x92,0x84,0x80,0x80,0x80,0x90,0x60,0xE6,0x89,0x88,0xE4,0x82,0x81,0x89,0xE6,0x77,0x24,0x24,0x27,0x24,0x24,0x24,0x27,0x30,0x48,0x40,0x40,0x40,0x40,0x48,0x30};

unsigned int logo_anim_ctr=0;
#define logo_anim_vlines 8*4

char logo_anim_toggle = 1;

unsigned char icon_btn_flip[5] = {0,0,0,0,0};
/********** LED array related **************************************/

/************************************************
    Variables for EC Sensor
/************************************************/
#if defined ENABLE_EC_SENSOR
String ec_inputstring = "";                                                       //a string to hold incoming data from the PC
String ec_sensorstring = "";                                                      //a string to hold the data from the Atlas Scientific product
String ec_sensorstring_ec = "";
String ec_sensorstring_tds = "";
String ec_sensorstring_sal = "";
String ec_sensorstring_sg = "";
boolean ec_input_stringcomplete = false;                                          //have we received all the data from the PC
boolean ec_sensor_stringcomplete = false;                                         //have we received all the data from the Atlas Scientific product
#endif //ENABLE_EC_SENSOR

/************************************************
    Variables for ph Sensor
/************************************************/
#if defined ENABLE_PH_SENSOR
String ph_inputstring = "";                                                       //a string to hold incoming data from the PC
String ph_sensorstring = "";                                                      //a string to hold the data from the Atlas Scientific product
boolean ph_input_stringcomplete = false;                                          //have we received all the data from the PC
boolean ph_sensor_stringcomplete = false;                                         //have we received all the data from the Atlas Scientific product
#endif //ENABLE_PH_SENSOR

/************************************************
    Variables for co2 Sensor
/************************************************/
#if defined ENABLE_CO2METERS_CO2_SENSOR
boolean co2_input_stringcomplete = false;
boolean co2_sensor_stringcomplete = false;
#endif // ENABLE_CO2METERS_CO2_SENSOR

#if defined ENABLE_GE_CO2_SENSOR
boolean co2_input_stringcomplete = false;
boolean co2_sensor_stringcomplete = false;
#endif // ENABLE_GE_CO2_SENSOR

/************************************************
    Clear the serial receive data
/************************************************/
void clearbuff() {
	int i;
	for(i=0;i<8;i++){
		parameter[i] ="";
		arg[i]=0;
	}
	paraIndex=-1;
	state=0;
        //Serial.println("clearbuff");

        // clear data buffer to sensor
#if defined ENABLE_PH_SENSOR
        ph_inputstring = ""; 
        ph_sensorstring = "";
        ph_input_stringcomplete = false;
        ph_sensor_stringcomplete = false;
#endif // ENABLE_PH_SENSOR

        // clear data buffer from sensor
#if defined ENABLE_EC_SENSOR
        ec_inputstring = "";
        ec_sensorstring = "";
        ec_sensorstring_ec = "";
        ec_sensorstring_tds = "";
        ec_sensorstring_sal = "";
        ec_sensorstring_sg = "";
        ec_input_stringcomplete = false;  
        ec_sensor_stringcomplete = false;
#endif // ENABLE_EC_SENSOR
 
#if defined ENABLE_CO2METERS_CO2_SENSOR
        co2_input_stringcomplete = false;  
        co2_sensor_stringcomplete = false;
#endif

}


/************************************************
	ASCII characters into int
/************************************************/
void convert(){
	int i;
	for(i=1;i<=paraIndex;i++){
		char temp_char[parameter[i].length() + 1];
		parameter[i].toCharArray(temp_char, sizeof(temp_char));
		arg[i-1] = (uint8_t)(atoi(temp_char));
	}
}


/************************************************
      Servo  Control
/***********************************************/
void servoCtrl(uint8_t channer, uint8_t value){
	if(channer>6) return;
	uint8_t pin=channer+1;
#if defined SOFTUART
	Serial.print("ServoControl:");
	Serial.print(",");
	Serial.print(pin);
	Serial.print(",");
	Serial.println(value);
#endif
	if(!servos[channer-1].attached())
		servos[channer-1].attach(pin);
	servos[channer-1].write(value);
	delay(10);
}

/************************************************
      Sensor  and Control subroutine 
/***********************************************/
// get sensor data from all sensors
// Sensor ID HEAD
//@"EC",                      // index ID: E
//@"TDS",                     // index ID: D
//@"SAL",                     // index ID: S
//@"SG",                      // index ID: G
//@"ph",                      // index ID: P
//@"CO2",                     // index ID: C
//@"Humidity",                // index ID: H
//@"Temperature",             // index ID: T
//@"Water Temperature",       // index ID: W
//@"High Water Level",        // index ID: X
//@"Low Water Level",         // index ID: Y

// TODO
/*
void powerOff()
{    
  //  FAN Off
  pinMode(FAN_ON_OFF_PIN, OUTPUT);   
  digitalWrite(FAN_ON_OFF_PIN, LOW);
               
  //  FAN PWM 0
  pinMode(FAN_SPEED_PWM_PIN, OUTPUT); 
  analogWrite(FAN_SPEED_PWM_PIN, 0);
              
  // PUMP Off
  pinMode(PUMP_ON_OFF_PIN, OUTPUT);   
  digitalWrite(PUMP_ON_OFF_PIN, LOW);
  
  pinMode(LED_ON_OFF_PIN, OUTPUT);   
  digitalWrite(LED_ON_OFF_PIN, LOW);
  Wire.beginTransmission(LED_DIMMING_SLAVE_ADDRESS);
  //Wire.write(byte(0x00));           // sends instruction byte
  Wire.write(LED_DIMMING_OFF_VALUE);
  Wire.endTransmission();
  
  sensorSwitch = 0;
  Serial.println("Powered Off!");
}
*/

/*
void powerOn()
{
               
  //  FAN Off
  pinMode(FAN_ON_OFF_PIN, OUTPUT);   
  digitalWrite(FAN_ON_OFF_PIN, HIGH);
               
  //  FAN PWM 0
  pinMode(FAN_SPEED_PWM_PIN, OUTPUT); 
  analogWrite(FAN_SPEED_PWM_PIN, fan_pwn);
              
  // PUMP Off
  pinMode(PUMP_ON_OFF_PIN, OUTPUT);   
  digitalWrite(PUMP_ON_OFF_PIN, HIGH);
  
  pinMode(LED_ON_OFF_PIN, OUTPUT);   
  digitalWrite(LED_ON_OFF_PIN, HIGH);
  Wire.beginTransmission(LED_DIMMING_SLAVE_ADDRESS);
  //Wire.write(byte(0x00));           // sends instruction byte
  Wire.write(64);
  Wire.endTransmission();
  
  sensorSwitch = 1;
  Serial.println("Powered On!");
}
*/

void getSensorData(){ 
#if defined ENABLE_EC_SENSOR
            if (ec_sensor_stringcomplete){                                                  //if a string from the Atlas Scientific product has been received in its entierty 
                if(sensorSwitch>0)
                {
                   Serial.print("E" + ec_sensorstring_ec);                                 //send that string to to the PC's serial monitor
                   Serial.print("\t\r\n");
                   delay(100);
                   
                   Serial.print("D" + ec_sensorstring_tds);                                 //send that string to to the PC's serial monitor
                   Serial.print("\t\r\n");
                   delay(100);
                   
                   Serial.print("S" + ec_sensorstring_sal);                                 //send that string to to the PC's serial monitor
                   Serial.print("\t\r\n");
                   delay(100);
                   
                   Serial.print("G" + ec_sensorstring_sg);                                 //send that string to to the PC's serial monitor
                   Serial.print("\t\r\n");
                   delay(100);
                }
                ec_sensorstring = "";                                                       //clear the string:
                ec_sensor_stringcomplete = false;                                           //reset the flag used to tell if we have received a completed string from the Atlas Scientific product
            }
#endif

#if defined ENABLE_PH_SENSOR
            if (ph_sensor_stringcomplete){                                                  //if a string from the Atlas Scientific product has been received in its entierty 
                if(sensorSwitch>0)
                {
                    Serial.print("P" + ph_sensorstring);                                //send that string to to the PC's serial monitor
                    Serial.print("\t\r\n");
                    delay(100);
                }
                ph_sensorstring = "";                                                       //clear the string:
                ph_sensor_stringcomplete = false;                                           //reset the flag used to tell if we have received a completed string from the Atlas Scientific product
            }
#endif

#if defined ENABLE_CO2METERS_CO2_SENSOR
            if (co2_sensor_stringcomplete){
                if(sensorSwitch>0)
                {
                  if(5000 > co2_resp_read_co2_value) // Filter out unreasonable data/noise 
                  { 
                    char message[20];
                    sprintf(message,"C%lu\t", co2_resp_read_co2_value);
                    Serial.print(message);
                    Serial.print("\t\r\n");
                  }
                }
                co2_sensor_stringcomplete = false;
            }
#endif //ENABLE_CO2METERS_CO2_SENSOR

#if defined ENABLE_GE_CO2_SENSOR
            if (co2_sensor_stringcomplete){
                if(sensorSwitch>0)
                {
                  if(2000 > co2_resp_read_co2_value) // Filter out unreasonable data/noise 
                  { 
                    //char message[20];
                    Serial.print("C");
                    Serial.print(co2_resp_read_co2_value);
                    Serial.print("\t\r\n");
                  }
                }
                co2_sensor_stringcomplete = false;                                           //reset the flag used to tell if we have received a completed string from the Atlas Scientific product
            }
#endif //ENABLE_GE_CO2_SENSOR


           // Read the temperature and humidity. 
           if(sensorSwitch>0) {
           int chk = DHT11.read(DHT11_PIN);
           switch (chk)
           {
              case 0: //DHTLIB_OK:  
		Serial.print("H"); 
		break;
              case -1: //DHTLIB_ERROR_CHECKSUM: 
		Serial.println("H Checksum error,\t"); 
		break;
              case -2: //DHTLIB_ERROR_TIMEOUT: 
		Serial.println("H Time out error,\t"); 
		break;
              default: 
		Serial.println("H Unknown error,\t"); 
		break;
           }

     // DISPLAY DATA
          if (100 > DHT11.humidity)   // filter out unreasonable data/noise
          {
            Serial.print(DHT11.humidity, 1);
            Serial.print("\t\r\n");
            //delay(100);
          }
          
          if (50 > DHT11.temperature)  // filter out unreasonable data/noise
          {
            Serial.print("T");
            Serial.print(DHT11.temperature, 1);
            Serial.print("\t\r\n");
            //delay(100);
          }
         }
         
         // Read the temperature from the water proof thermometer DS18S20
         // Comment it out because it's not in use. 
         /*
         if(sensorSwitch>0) {
            float temperature = getTemp();
            if (50 > temperature )   // filter out unreasonable data/noise
            {
              Serial.print("W");
              Serial.print(temperature,1);
              Serial.print("\t\r\n");
              delay(100);
            }
         }
         */
         
         // Read the water high level status 
         /*
         if(sensorSwitch>0) {
           int n=analogRead(HIGH_WATER_LEVEL_PIN); // High water level. If n>=20, the sensor is above a specified water level.
            if (n>=20) {
              Serial.print("X0"); // water level under high-water-mark
              Serial.print("\t\r\n");
            }
            else {
              Serial.print("X1"); // water level above high-water-mark
              Serial.print("\t\r\n");
            }
            //delay(100);
         
         }
         
         // Read the water low level status 
         if(sensorSwitch>0) {
           int n=analogRead(LOW_WATER_LEVEL_PIN); // Low water level. If n>=20, the sensor is under a specifiedwater. 
            if (n>=20) {
              Serial.print("Y1"); // water level under low-water-mark
             Serial.print("\t\r\n"); 
            }
            else {
              Serial.print("Y0"); // water level above low-water-mark
              Serial.print("\t\r\n");
            }
           //delay(100);
         }
         */
         
         
         // Read the VOC value
#if defined ENABLE_VOC_SENSOR_I2C
         if(sensorSwitch>0) {
            Wire.beginTransmission(VOC_SENSOR_SLAVE_ADDRESS);
            Wire.requestFrom(VOC_SENSOR_SLAVE_ADDRESS, VOC_COMMAND_LENGTH);    // request 7 bytes from slave device VOC_SENSOR_SLAVE_ADDRESS
   
            if(Wire.available())    // slave may send less than requested
            { 
              for(int i=0; i< VOC_COMMAND_LENGTH; i++)
              {
	           voc_read_bytes[i] = Wire.read();      //get the byte we just received
                   //Serial.println(voc_read_bytes[i]);         // print the byte value
              }
              voc_co2_prediction = voc_read_bytes[0]*256 + voc_read_bytes[0];
              voc_resistance_value = voc_read_bytes[4]*65536 + voc_read_bytes[5]*256 + voc_read_bytes[6];
              
              Serial.print("C");
              Serial.print(voc_co2_prediction);
              Serial.print("\t\r\n");
              
              Serial.print("V");
              Serial.print(voc_resistance_value);
              Serial.print("\t\r\n");
            }
           
            Wire.endTransmission();
         }
#endif

#if defined ENABLE_AIR_PRESSURE_SENSOR_I2C
         if(sensorSwitch>0) 
         {
             char status;
             double T,P,p0,a;

  // Loop here getting pressure readings every 10 seconds.

  // If you want sea-level-compensated pressure, as used in weather reports,
  // you will need to know the altitude at which your measurements are taken.
  // We're using a constant called ALTITUDE in this sketch:
            /*
            Serial.println();
            Serial.print("provided altitude: ");
            Serial.print(ALTITUDE,0);
            Serial.print(" meters, ");
            Serial.print(ALTITUDE*3.28084,0);
            Serial.println(" feet");
            */
  
  // If you want to measure altitude, and not pressure, you will instead need
  // to provide a known baseline pressure. This is shown at the end of the sketch.

  // You must first get a temperature measurement to perform a pressure reading.
  
  // Start a temperature measurement:
  // If request is successful, the number of ms to wait is returned.
  // If request is unsuccessful, 0 is returned.

            status = pressure.startTemperature();
            if (status != 0)
            {
    // Wait for the measurement to complete:
              delay(status);

    // Retrieve the completed temperature measurement:
    // Note that the measurement is stored in the variable T.
    // Function returns 1 if successful, 0 if failure.

              status = pressure.getTemperature(T);
              if (status != 0)
              {
      // Print out the measurement:
                //Serial.print("temperature: ");
                //Serial.print(T,2);
                //Serial.print(" deg C, ");
                //Serial.print((9.0/5.0)*T+32.0,2);
                //Serial.println(" deg F");
      
      // Start a pressure measurement:
      // The parameter is the oversampling setting, from 0 to 3 (highest res, longest wait).
      // If request is successful, the number of ms to wait is returned.
      // If request is unsuccessful, 0 is returned.

                status = pressure.startPressure(3);
                if (status != 0)
                {
        // Wait for the measurement to complete:
                  delay(status);

        // Retrieve the completed pressure measurement:
        // Note that the measurement is stored in the variable P.
        // Note also that the function requires the previous temperature measurement (T).
        // (If temperature is stable, you can do one temperature measurement for a number of pressure measurements.)
        // Function returns 1 if successful, 0 if failure.

                  status = pressure.getPressure(P,T);
                  if (status != 0)
                  {
                  // Print out the measurement:
                    Serial.print("R");  // output format for current RI
                    //Serial.print("absolute pressure: ");
                    Serial.print(P,2);
                    Serial.print("\t\r\n");
                    //Serial.print(" mb, ");
                    //Serial.print(P*0.0295333727,2);
                    //Serial.println(" inHg");

          // The pressure sensor returns abolute pressure, which varies with altitude.
          // To remove the effects of altitude, use the sealevel function and your current altitude.
          // This number is commonly used in weather reports.
          // Parameters: P = absolute pressure in mb, ALTITUDE = current altitude in m.
          // Result: p0 = sea-level compensated pressure in mb

                    p0 = pressure.sealevel(P,ALTITUDE); // we're at 1655 meters (Boulder, CO)
                   //Serial.print("relative (sea-level) pressure: ");
                   //Serial.print(p0,2);
                   //Serial.print(" mb, ");
                   //Serial.print(p0*0.0295333727,2);
                   //Serial.println(" inHg");

          // On the other hand, if you want to determine your altitude from the pressure reading,
          // use the altitude function along with a baseline pressure (sea-level or other).
          // Parameters: P = absolute pressure in mb, p0 = baseline pressure in mb.
          // Result: a = altitude in m.
                   a = pressure.altitude(P,p0);
                   //Serial.print("computed altitude: ");
                   //Serial.print(a,0);
                   //Serial.print(" meters, ");
                   //Serial.print(a*3.28084,0);
                   //Serial.println(" feet");
                 }
                 else Serial.println("error retrieving pressure measurement\n");
               }
               else Serial.println("error starting pressure measurement\n");
             }
             else Serial.println("error retrieving temperature measurement\n");
           }
           else Serial.println("error starting temperature measurement\n");
           //delay(100);  // Pause for 0.1 seconds.
         }
#endif

// Microphone sensor
         if(sensorSwitch>0) {
           mic_nVolume = analogRead(MICROPHONE_ANALOG_PIN);
           mic_bSound = digitalRead(MICROPHONE_DIGITAL_PIN);           
           Serial.print("Z");
           Serial.print(mic_nVolume);
           Serial.print("\t\r\n");
         }
         
// PM 2.5 sensor
#if defined ENABLE_PM_2_POINT_5_SENSOR_S3
       if (pm25_input_readcomplete) {
         if(sensorSwitch>0) {
           // K = V / (0.1 mg/m^3) = 0.35 from http://pan.baidu.com/s/1i33juUL
           float pm_25 = (pm25_Vo/1024*5)*0.35 ;
           
           // Another equation: V*0.17-0.1 from http://www.howmuchsnow.com/arduino/airquality/ 
           //float pm_25 = (pm25_Vo/1024*5)*0.17-0.1 ;
           
           Serial.print("M");
           Serial.print(pm_25,2);
           Serial.print("\t\r\n");
           pm25_input_readcomplete = false;
         }
       }
#endif

         // Read the value of photoresistor
         photoresistorValue = analogRead(PHOTORESISTOR_ANALOG_PIN);
         Serial.print("B");
         Serial.print(photoresistorValue, DEC);
         Serial.print("\t\r\n");
         delay(100);


}


// DS18S20xx
float getTemp(){
  //returns the temperature from one DS18S20 in DEG Celsius
  byte data[12];
  byte addr[8];

  if ( !ds.search(addr)) {
      //no more sensors on chain, reset search
      ds.reset_search();
      return -1000;
  }

  if ( OneWire::crc8( addr, 7) != addr[7]) {
      Serial.println("CRC is not valid!");
      return -1000;
  }

  if ( addr[0] != 0x10 && addr[0] != 0x28) {
      Serial.print("Device is not recognized");
      return -1000;
  }

  ds.reset();
  ds.select(addr);
  ds.write(0x44,1); // start conversion, with parasite power on at the end

  byte present = ds.reset();
  ds.select(addr);    
  ds.write(0xBE); // Read Scratchpad

  
  for (int i = 0; i < 9; i++) { // we need 9 bytes
    data[i] = ds.read();
  }
  
  ds.reset_search();
  
  byte MSB = data[1];
  byte LSB = data[0];

  float tempRead = ((MSB << 8) | LSB); //using two's compliment
  float TemperatureSum = tempRead / 16;
  
  return TemperatureSum;
  
}

#if defined DUMMY_TEST_CONTROL
void dummyTestControlDevice(){
                unitTestSensorTime = millis();
               
                // Test FAN On/Off
                pinMode(FAN_ON_OFF_PIN, OUTPUT);   
                if ( 0 < fan_on_off)
                {
	          digitalWrite(FAN_ON_OFF_PIN, HIGH);
                  fan_on_off = 0;
                }
                else
                {
                  digitalWrite(FAN_ON_OFF_PIN, LOW);
                  fan_on_off =1;
                }
               
               // Test FAN PWM
               pinMode(FAN_SPEED_PWM_PIN, OUTPUT); 
	       analogWrite(FAN_SPEED_PWM_PIN, 63+fan_pwm);
               if (0==fan_pwm)
                 fan_pwm = LED_DIMMING_OFF_VALUE;
               else
                 fan_pwm = 0;                 

                // Test PUMP On/Off
                pinMode(PUMP_ON_OFF_PIN, OUTPUT);   
                if ( 0 < pump_on_off)
                {
	          digitalWrite(PUMP_ON_OFF_PIN, HIGH);
                  pump_on_off = 0;
                }
                else
                {
                  digitalWrite(PUMP_ON_OFF_PIN, LOW);
                  pump_on_off =1;
                }
                
                // I2C Integration 
#if defined ENABLE_LED_DIMMING_I2C
               {  
                  led_dimming_value = led_dimming_value + 4;        // increment value
                  if(led_dimming_value > LED_DIMMING_OFF_VALUE) // if reached 64th position (max)
                  {
                    led_dimming_value = 0;    // start over from the on witg max. value
                  }
                  Wire.beginTransmission(LED_DIMMING_SLAVE_ADDRESS);
                  //Wire.write(byte(0x00));           // sends instruction byte
                  Wire.write(led_dimming_value);
                  i2c_error = Wire.endTransmission();
                  Serial.print("i2c_error ");
                  Serial.println(i2c_error);
                  Serial.print("led_dimming_value ");
                  Serial.println(led_dimming_value);
               }
           
#endif
}
#endif

#if defined DUMMY_TEST_SENSOR
void dummyTestSensorData(){
  // dummy sensor data
  float ph, ec, tds, sal, sg, h, t, uwt;
  int co2, hwl=1, lwl=1;
  if (dummy_sensor_data_change_switch == 0 )
  {
     ph = 3.49;
     ec = 1.0;
     tds = 1.0;
     sal = 1.0; 
     sg = 1.0; 
     h = 50.0;
     t = 25.0;
     uwt = 24.0;
     co2 = 500; 
     hwl = 1; 
     lwl = 1;
  }
  else
  {
     ph = 4.49;
     ec = 1.1;
     tds = 1.1;
     sal = 1.1; 
     sg = 1.1; 
     h = 60.0;
     t = 28.0;
     uwt = 27.0;
     co2 = 600; 
     hwl = 0; 
     lwl = 0;
  }
  
  if (sensorSwitch>0)
  {
#if defined ENABLE_PH_SENSOR
  Serial.print("P");
  Serial.print(ph);
  Serial.print("\t\r\n");
  delay(100);
#endif

#if defined ENABLE_EC_SENSOR
  Serial.print("E");
  Serial.print(ec);
  Serial.print("\t\r\n");
  delay(100);

  Serial.print("D");
  Serial.print(tds);
  Serial.print("\t\r\n");
  delay(100);
  
  Serial.print("S");
  Serial.print(sal);
  Serial.print("\t\r\n");
  delay(100);
  
  Serial.print("G");
  Serial.print(sg);
  Serial.print("\t\r\n");
  delay(100);
#endif

#if defined ENABLE_CO2METERS_CO2_SENSOR
  Serial.print("C");
  Serial.print(co2);
  Serial.print("\t\r\n");
  delay(100);
#endif

  Serial.print("H");
  Serial.print(h);
  Serial.print("\t\r\n");
  delay(100);

  Serial.print("T");
  Serial.print(t);
  Serial.print("\t\r\n");
  delay(100);
  
  Serial.print("W");
  Serial.print(uwt);
  Serial.print("\t\r\n");  
  delay(100);
  
  
  Serial.print("X");
  Serial.print(hwl);
  Serial.print("\t\r\n");  
  delay(100);
  
  Serial.print("Y");
  Serial.print(lwl);
  Serial.print("\t\r\n");  
  delay(100);
  }  
}
#endif


void getControlDevState()
{
//@"Fan",                     // index ID: F 
//@"LED Dimming",             // index ID: L 
//@"PUMP",                    // index ID: U
//@"LED Array",               // index ID: A
//@"Sensor Switch OnOff"      // index ID: N
//@"Power OnOff"              // index ID: O
//@"Sensor Data Interval"     // inded ID: I
  
  // Fan 0~100
  Serial.print("F");
  Serial.print(fan_pwm);
  Serial.print("\t\r\n");  
  //delay(100);
  
  // LED 0~128
  //led_dimming_value = LED_DIMMING_OFF_VALUE;
  Serial.print("L");
  Serial.print(led_dimming_value);
  Serial.print("\t\r\n");
  //delay(100);
  
  // PUMP, 0, 1 so far 
  Serial.print("U");
  Serial.print(pump_on_off);
  Serial.print("\t\r\n");
  //delay(100);
                          
  // LED Array 0,1,2,3,4
  Serial.print("A");
  Serial.print(led_array_icon_id);
  Serial.print("\t\r\n");
  //delay(100);
  
  // Sensor Switch OnOff
  Serial.print("N");
  Serial.print(sensorSwitch);
  Serial.print("\t\r\n");  
  //delay(100);
  
  // Power OnOff
  //Serial.print("O");
  //Serial.print(powerOnOff);
  //Serial.print("\t\r\n");  
  //delay(100);
  
  // Sensor Data Interval
  //Serial.print("I");
  //Serial.print(sensorInterval);
  //Serial.print("\t\r\n"); 
  //delay(100);
  
}

/************************************************
      Arduino  setup
/***********************************************/
void setup()  
{
   // Initialization on LED Control
   lc.shutdown(0,false);
   lc.setIntensity(0,8);
   lc.clearDisplay(0);
   
   Wire.begin(); // I2C and SPI master 
   Serial.begin(DEFAULT_RATE);                                             //set baud rate for the hardware serial port_0 to DEFAULT_RATE
#if defined ENABLE_EC_SENSOR
  Serial3.begin(38400);                                                   //set baud rate for software serial port_3 to 38400 (EC Sensor)
 // For EC Sensor
  ec_inputstring.reserve(5);                                               //set aside some bytes for receiving data from the PC or mobile phone
  ec_sensorstring.reserve(30);                                             //set aside some bytes for receiving data from EC Sensor 
#endif

#if defined ENABLE_PH_SENSOR
  Serial2.begin(38400);                                                   //set baud rate for software serial port_2 to 38400 (ph Sensor)
  // For ph Sensor
  ph_inputstring.reserve(5);                                               //set aside some bytes for receiving data from the PC or mobile phone
  ph_sensorstring.reserve(30);                                             //set aside some bytes for receiving data from ph Sensor
#endif

#if defined ENABLE_CO2METERS_CO2_SENSOR
  // For CO2 Meter's CO2 sensor
  Serial1.begin(9600);                                                    //set baud rate for software serial port_1 to 9600 (CO2 Meter's CO2 Sensor)
#endif

#if defined ENABLE_GE_CO2_SENSOR
  // For CO2 Meter's CO2 sensor
  Serial1.begin(19200);                                                    //set baud rate for software serial port_1 to 192000 (GE's CO2 Sensor)
#endif

  // Test
  led_on_off = 1;
  LED_DIMMING_SLAVE_ADDRESS = 0x2E;
  led_dimming_value = 128;    // start as dimming-off
  pinMode(LED_ON_OFF_PIN, OUTPUT);  
  digitalWrite(LED_ON_OFF_PIN, HIGH);
  
#if defined SOFTUART
  Serial.println("BLE Shield v22.1");
#endif

  if (pressure.begin())
    Serial.println("BMP180 init success");
  else
  {
    // Oops, something went wrong, this is usually a connection problem,
    // see the comments at the top of this sketch for the proper connections.

    Serial.println("BMP180 init fail\n\n");
    while(1); // Pause forever.
  }
  
  // Microphone(sensor)
  pinMode(MICROPHONE_DIGITAL_PIN, INPUT); 
  
// PM 2.5 Sensor
#if defined ENABLE_PM_2_POINT_5_SENSOR_S3
  Serial3.begin(2400);                                                   //set baud rate for software serial port_3 to 2400 (EC Sensor)
#endif

  //getControlDevState();
    
}



/************************************************
      Arduino loop
/***********************************************/
void loop() {
  
  //animation logic ////////////////////////////////////////////////
  if (logo_anim_toggle == 1){
    int v_scan = logo_anim_ctr % (logo_anim_vlines);
    
    // calculate the scroll frame
    int scan_align = v_scan % 8;
    int i=v_scan/8; int j;
    if(i==3) j=0; else j=i+1;

    unsigned char frame [8] = {0,0,0,0,0,0,0,0};
    memset(frame, 0, 8);
    for(int k=0; k<8; k++){
      if(scan_align==0){
        frame[k] = logo_lib[i][k];
      }
      else
        frame[k] = logo_lib[i][k]<<scan_align | (logo_lib[j][k]>>(7 - scan_align) & 255>>(7-scan_align));
    }
    draw_icon_invert(frame);
    logo_anim_ctr++;
  }
  //animation logic ENDS //////////////////////////////////////////

  
  // TODO Power On Off
  /*
   if (powerOnOff > 0)
     powerOn();
   else
   {
     //powerOff();
     return;
   }
   */
     
  // EC Sensor's data check
#if defined ENABLE_EC_SENSOR
   if (ec_input_stringcomplete){                                                  //if a string from the PC has been received in its entirety 
      Serial3.print(ec_inputstring);                                              //send that string to the Atlas Scientific product
      ec_inputstring = "";                                                        //clear the string:
      ec_input_stringcomplete = false;                                            //reset the flag used to tell if we have received a completed string from the PC
     }
#endif

#if defined ENABLE_PH_SENSOR
    if (ph_input_stringcomplete){                                                 //if a string from the PC has been received in its entirety 
      Serial2.print(ph_inputstring);                                              //send that string to the Atlas Scientific product
      ph_inputstring = "";                                                        //clear the string:
      ph_input_stringcomplete = false;                                            //reset the flag used to tell if we have received a completed string from the PC
     }
#endif
    
    // Updates of controlled dev
    if(millis()-sensorTime>sensorInterval)
    {
#if defined  DUMMY_TEST_CONTROL
      dummyTestControlDevice();
#else
      getControlDevState();
#endif
    }
  
    // Updates of sensors
    if(millis()-sensorTime > sensorInterval)
    {
      sensorTime = millis();

// Firing CO2 read data command in this time-tigger. 
#if defined ENABLE_CO2METERS_CO2_SENSOR
      Serial1.write(co2_cmd_read_co2_data, CO2_COMMAND_LENGTH);
      delay(100);
#endif

#if defined ENABLE_GE_CO2_SENSOR
      Serial1.write(co2_cmd_read_co2_data, CO2_COMMAND_LENGTH);
      delay(100); // 
#endif
      
#if defined DUMMY_TEST_SENSOR
        if ( dummy_sensor_data_change_switch != 0 )
          dummy_sensor_data_change_switch = 0;
        else
          dummy_sensor_data_change_switch = 1;
        dummyTestSensorData();
#else
        getSensorData(); 
#endif
    }

  // BLE Shield data diepatching or receiving.   
	if(state==1){  
		convert();
		if (parameter[0]==""){
			clearbuff();
                        return;
		} 
#if defined SOFTUART
                Serial.print("state:");
		Serial.print(parameter[0]);
		Serial.print(",");
		Serial.print(parameter[1]);
		Serial.print(",");
		Serial.println(parameter[2]);
#endif
                if (parameter[0]=="SN"){	// Start/Stop sending sensor data
                   if (arg[0] == 1)
                     sensorSwitch = 1;
                   else if (arg[0] == 0)
                     sensorSwitch = 0;
                   else
                   {
                     // TODO\: Error handling
                   }
                   Serial.print("N");
                   Serial.print(sensorSwitch);
                   Serial.print("\t\r\n");  
                   delay(100);
                   /*
                   if (sensorInterval >= MIN_SENSOR_UPDATE_INTERVAL )
                   {
                     if (sensorInterval > MAX_SENSOR_UPDATE_INTERVAL )
                        sensorInterval = MAX_SENSOR_UPDATE_INTERVAL;  
                     Serial.print("I");
                     Serial.print(sensorInterval);
                     Serial.print("\t\r\n");  
                     delay(100);
                   }
                   else
                     sensorInterval = MIN_SENSOR_UPDATE_INTERVAL; 
                   */
		}
                
                /*
                if (parameter[0]=="PO"){	// Power on \Off
                   if (arg[0] == 1)
                   {
                     powerOnOff = 1;
                     powerOn();
                   }
                   else if (arg[0] == 0)
                   {
                     powerOnOff = 0;
                     powerOff();
                   }
		}
                */

                // I2C Control
                if (parameter[0]=="IC"){	// I2C. The first application is LED dimming. 
                  if (arg[0] == 1 )         // ID unumber 1 associated to LED_DIMMING_SLAVE_ADDRESS
                  {
                    if (arg[1] < LED_DIMMING_OFF_VALUE)
                    {
                      // force LED on.
                      pinMode(LED_ON_OFF_PIN, OUTPUT);   
                      digitalWrite(LED_ON_OFF_PIN, HIGH);
                      Wire.beginTransmission(LED_DIMMING_SLAVE_ADDRESS);
                      led_dimming_value = arg[1];
                      Wire.write(led_dimming_value);
                      Wire.endTransmission();
                      // output sensor state

                    }
                    else // LED Off
                    {
                      // force LED off.
                      pinMode(LED_ON_OFF_PIN, OUTPUT);   
                      digitalWrite(LED_ON_OFF_PIN, LOW);
                      Wire.beginTransmission(LED_DIMMING_SLAVE_ADDRESS);
                      Wire.write(LED_DIMMING_OFF_VALUE);
                      Wire.endTransmission();
                      led_dimming_value = LED_DIMMING_OFF_VALUE;
                    }
                    Serial.print("L");
                    Serial.print(led_dimming_value);
                    Serial.print("\t\r\n");
                    //delay(100);
                  }
                }
                else // The other ID
                {
                  // TODO: The other device
                }
                
                // SPI Control
                if (parameter[0]=="SPI"){	// SPI. The first application is LED Array displaying icons.
                   if (arg[0] == 1)             // ID unumber 1 associated to LedControl lc=LedControl(51,52,53,1);
                   {
                     led_array_icon_id = arg[1];
                     logo_anim_toggle = 0;      // Toggle animation stop by any input LED array character. 
                     
                     if (led_array_icon_id < 100)    // draw 0~99
                       draw_num(led_array_icon_id);
                     else
                     {
                       switch(led_array_icon_id) // Using switch-case here instead of draw_icon_invert(icon_lib[arg[1]-100]); in case of some exception case. 
                       { 
                         case 100:  // Smile face
                           draw_icon_invert(icon_lib[0]);
                           break;
                          
                         case 101:  // Sad face
                           draw_icon_invert(icon_lib[1]);
                           break;
                        
                         case 102:  // 'X'
                           draw_icon_invert(icon_lib[2]);
                           break;
                        
                         case 103:  // 'O'
                           draw_icon_invert(icon_lib[3]);
                           break;
                        
                         case 104:  // Uen-Sen, hot spring
                           draw_icon_invert(icon_lib[4]);
                           break;
                           
                         case 105:  // "24"
                           draw_icon_invert(icon_lib[5]);
                           break;
                          
                         case 106:  // >o< 
                           draw_icon_invert(icon_lib[6]);
                           break;
                        
                         case 107:  // Bluetooth icon
                           draw_icon_invert(icon_lib[7]);
                           break;
                        
                         case 108:  // 'f'
                           draw_icon_invert(icon_lib[8]);
                           break;
                         
                         case 0xFF:  // LED Array Off
                           draw_icon_invert(icon_lib[8]);
                           lc.shutdown(0,false);
                           lc.setIntensity(0,8);
                           lc.clearDisplay(0);
                           break;
                        
                         default:
                           led_array_icon_id = 0;
                           lc.shutdown(0,false);
                           lc.setIntensity(0,8);
                           lc.clearDisplay(0);
                           lc.setLed(0,2,2,true);
                           lc.setLed(0,4,4,true);
                           lc.setLed(0,6,6,true);
                           break;
                       } // End of Switch
                     } // End of if (led_array_icon_id < 100)
                     Serial.print("A");
                     Serial.print(led_array_icon_id);
                     Serial.print("\t\r\n");
                     //delay(100);
                   } // End of if()
                   else
                   {
                     // For the other SPI devices
                   }
                 } // The end of "parameter[0]=="SPI""
       

		if (parameter[0]=="OFF"){	// Leave ctro
			for(readIndex=0;readIndex<20;readIndex++)
				readData[readIndex]=0;
		} 
		
		if (parameter[0]=="PW"){	// PWM
                          if(servos[arg[0]-2].attached())  
                            servos[arg[0]-2].detach();
                          // transfer % to 0~255 levels.
                          //float pwm_value;
                          //pwm_value = arg[1]*2.55;
                          //Serial.print(pwm_value);
                          // Set the switch/slide status variable. 
                          if (FAN_SPEED_PWM_PIN == arg[0])
                          {
                             // If Fan's PWM set to 0 or the other error, force it to be turned off. 
                             if(0 >= arg[1])
                             {
                               fan_pwm = 0;
                               //FAN Off
                               pinMode(arg[0], OUTPUT); 
			       analogWrite(arg[0], fan_pwm);
                               pinMode(FAN_ON_OFF_PIN, OUTPUT);   
                               digitalWrite(FAN_ON_OFF_PIN, LOW);
                             }
                             else
                             {
                                //FAN On
                               pinMode(FAN_ON_OFF_PIN, OUTPUT);   
                               digitalWrite(FAN_ON_OFF_PIN, HIGH);
                               fan_pwm = arg[1];
                               pinMode(arg[0], OUTPUT); 
			       analogWrite(arg[0], fan_pwm);
                             } 
                             Serial.print("F");
                             Serial.print(fan_pwm);
                             Serial.print("\t\r\n");
                             //delay(100);
                          } 
                          else // For the rest devices. 
                          {
                            pinMode(arg[0], OUTPUT); 
			    digitalWrite(arg[0], arg[1]);
                          }
		}
		
		if (parameter[0]=="SE"){	// Servo
                        //sensorSwitch = 1;
			servoCtrl(arg[0], arg[1]);
		}
		
		if (parameter[0]=="DL"){	// Dimmer
			
		}
		
		if (parameter[0]=="AD"){	// ADC 
                        //sensorSwitch = 1;
			float tmp =analogRead(arg[0])*0.0048;
			Serial1.print("@AD,");
			Serial1.print(arg[0]);
			Serial1.print(",");
			Serial1.print(tmp);
			Serial1.print("\r\n");
			readData[arg[0]+14]=arg[1];
		}
		
		if (parameter[0]=="OP"){	// OUTPUT
			if(servos[arg[0]-2].attached())  servos[arg[0]-2].detach();
			pinMode(arg[0], OUTPUT); 
			digitalWrite(arg[0], arg[1]);
                        if(PUMP_ON_OFF_PIN == arg[0])
                        {
                          pump_on_off = arg[1];
                          Serial.print("U");
                          Serial.print(pump_on_off);
                          Serial.print("\t\r\n");
                          //delay(100);
                        }
                        // LED Dimming lite edition
                        else if (LED_ON_OFF_PIN == arg[0])
                        {
                          if (arg[1] > 0)
                          {
                           // force LED on.
                           pinMode(LED_ON_OFF_PIN, OUTPUT);   
                           digitalWrite(LED_ON_OFF_PIN, HIGH);
                           Wire.beginTransmission(LED_DIMMING_SLAVE_ADDRESS);
                           led_dimming_value = arg[1];
                           Wire.write(led_dimming_value);
                           Wire.endTransmission();
                           }
                           else
                           {
                           // force LED off.
                            pinMode(LED_ON_OFF_PIN, OUTPUT);   
                            digitalWrite(LED_ON_OFF_PIN, LOW);
                            Wire.beginTransmission(LED_DIMMING_SLAVE_ADDRESS);
                            Wire.write(LED_DIMMING_OFF_VALUE);
                            Wire.endTransmission();
                            led_dimming_value = LED_DIMMING_OFF_VALUE;
                           }
                           // output sensor state
                           Serial.print("L");
                           Serial.print(led_dimming_value);
                           Serial.print("\t\r\n");
                           //delay(100);
                        }
                        else if (FAN_ON_OFF_PIN == arg[0])
                        {
                          if (arg[1] > 0)
                          {
                            // Fan On
                             pinMode(FAN_ON_OFF_PIN, OUTPUT);
                             digitalWrite(FAN_ON_OFF_PIN, HIGH);
                             // Set FAN PWM
                             fan_pwm = 50;
                             pinMode(FAN_SPEED_PWM_PIN, OUTPUT); 
	                     analogWrite(FAN_SPEED_PWM_PIN, fan_pwm);
                          }
                          else
                          {
                            //Fan Off
                             pinMode(FAN_ON_OFF_PIN, OUTPUT);
                             digitalWrite(FAN_ON_OFF_PIN, LOW);
                             // Set FAN PWM
                             fan_pwm = 0;
                             pinMode(FAN_SPEED_PWM_PIN, OUTPUT); 
	                     analogWrite(FAN_SPEED_PWM_PIN, fan_pwm);
                          }
                          Serial.print("F");
                          Serial.print(fan_pwm);
                          Serial.print("\t\r\n");
                          //delay(100);
                        }
                        else
                        {
                          // TODO
                        }
			readData[arg[0]]=0;
		}
		
		if (parameter[0]=="IP"){	// INPUT
			if(servos[arg[0]-2].attached())  servos[arg[0]-2].detach();
			if(arg[1]==1){
				pinMode(arg[0], INPUT); 				
			}else{
				pinMode(arg[0], OUTPUT); 				
			}
			readData[arg[0]]=arg[1];
		}

		
        clearbuff();
        // ouput data
	}else if(millis()-time>50){  
	
		time = millis();
		
		int tmp;
		float adVar;
		
		while(readData[readIndex]!=1){
			readIndex++;
			if(readIndex>19){
				readIndex=0;
				break;
			}
		}
#if defined SOFTUART
//		Serial.print("readData:");
//		Serial.println(readIndex);
#endif
		if(readData[readIndex]==1){
                        //sensorSwitch = 1;
			if(readIndex<14){	//PIN INPUT 
				pinMode(readIndex, INPUT); 
				tmp =digitalRead(readIndex);
				Serial1.print("@IP,");
				Serial1.print(readIndex);
				Serial1.print(",");
				Serial1.print(tmp);
				Serial1.print("\r\n");
				
#if defined SOFTUART
				Serial.print("@IP,");
				Serial.print(readIndex);
				Serial.print(",");				
				Serial.println(tmp);
				Serial.print("\r\n");
#endif
			}else{	// ADC
				tmp =readIndex-14;
				adVar =analogRead(tmp)*0.0049;
				Serial1.print("@AD,");
				Serial1.print(tmp);
				Serial1.print(",");
				Serial1.print(adVar);
				Serial1.print("\r\n");
#if defined SOFTUART
				Serial.print("@AD,");
				Serial.print(tmp);
				Serial.print(",");
				Serial.print(adVar);
				Serial.print("\r\n");
#endif
			}
			readIndex++;
			if(readIndex>19) readIndex=0;
		}
	}	
}


// All output sensor data and control command input to the arduino board
void serialEvent() {  //if the hardware serial port_0 receives a char
	while (Serial.available()) {
		char inChar = (char)Serial.read(); 
                if(state==1) return;
		switch(inChar){
			case'@':
				clearbuff();
				paraIndex=0;
			break;
			case',':
				paraIndex++;
			break;
			case '\n':	//0x0A
				state=1;
				return;
			break;
			case '\r':	//0x0D
				state=1;
				return;
			break;
			default: 
				if(paraIndex>=0&&state==0) parameter[paraIndex] +=inChar;
			break;
		}
	     }            
      }


// CO2 Sensors are connected to Serial 1. 
#if defined ENABLE_CO2METERS_CO2_SENSOR
void serialEvent1(){
               if (co2_sensor_stringcomplete)
               {
                 co2_sensor_stringcomplete = false;
               }
               if (Serial1.available()) 
               {
                 //char co2_inchar = (char);
                 uint8_t co2_resp_read_co2_buffer[CO2_COMMAND_LENGTH];
                 for(int i=0; i< CO2_COMMAND_LENGTH; i++)
                 {
	           co2_resp_read_co2_buffer[i] = Serial1.read();     //get the byte we just received
                 }
                 int high = co2_resp_read_co2_buffer[CO2_COMMAND_LENGTH_MID_BYTE];         //high byte for value is 4th byte in packet in the packet
                 int low = co2_resp_read_co2_buffer[CO2_COMMAND_LENGTH_MID_BYTE+1];        //low byte for value is 5th byte in the packet
                 co2_resp_read_co2_value = high*256 + low;                //combine high byte and low byte
                 co2_sensor_stringcomplete = true;
                 return;
               }
}
#endif  //ENABLE_CO2METERS_CO2_SENSOR

#if defined ENABLE_GE_CO2_SENSOR
void serialEvent1(){
               if (co2_sensor_stringcomplete)
               {
                 co2_sensor_stringcomplete = false;
               }
               if (Serial1.available()) 
               {
                 //char co2_inchar = (char);
                 uint8_t co2_resp_read_co2_buffer[CO2_COMMAND_LENGTH];
                 for(int i=0; i< CO2_COMMAND_LENGTH; i++)
                 {
	           co2_resp_read_co2_buffer[i] = Serial1.read();     //get the byte we just received
                   Serial.print("GE CO2 read Byte:  ");
                   Serial.println(co2_resp_read_co2_buffer[i],HEX);
                 }
                 int high = co2_resp_read_co2_buffer[CO2_COMMAND_LENGTH_MID_BYTE];         //high byte for value is 4th byte in packet in the packet
                 int low = co2_resp_read_co2_buffer[CO2_COMMAND_LENGTH_MID_BYTE+1];        //low byte for value is 5th byte in the packet
                 co2_resp_read_co2_value = high*256 + low;                //combine high byte and low byte
                 co2_sensor_stringcomplete = true;
                 return;
               }
}
#endif  //ENABLE_GE_CO2_SENSOR

// pH sensors are connected to Serial 2
#if defined ENABLE_PH_SENSOR
void serialEvent2(){                                                         //if the hardware serial port_2 receives a char
               if (ph_sensor_stringcomplete)
               {
                 ph_sensorstring = ""; 
                 ph_sensor_stringcomplete = false;
               }
               while (Serial2.available()) {
                 char ph_inchar = (char)Serial2.read();                       //get the char we just received
                 
                 if(ph_inchar == '\r') {                                      //if the incoming character is a <CR>, set the flag and return
                   ph_sensor_stringcomplete = true;
                   return;
                 }
                 ph_sensorstring += ph_inchar;                                 //add it to the inputString
               }
}
#endif //ENABLE_PH_SENSOR

// EC Sensors are connected to Serial 3
#if defined ENABLE_EC_SENSOR
void serialEvent3(){  //if the hardware serial port_3 receives a char 
                int ec_index = EC_INDEX_EC;                                  // to seperate 4 different attribute: EC,TDS,SAL,SG
                if (ec_sensor_stringcomplete)
                {
                  ec_sensorstring = "";
                  ec_sensorstring_ec = "";
                  ec_sensorstring_tds = "";
                  ec_sensorstring_sal = "";
                  ec_sensorstring_sg = "";
                  ec_sensor_stringcomplete = false;
                }
                while (Serial3.available()) {
                  char ec_inchar = (char)Serial3.read();                     //get the char we just received
                  if(ec_inchar == '\r') {                                    //if the incoming character is a <CR>, set the flag and return
                    ec_sensor_stringcomplete = true;
                    return;
                  }
                  //ec_sensorstring += ec_inchar;                              //add it to the inputString
                  
                  // to seperate 4 different attribute: EC,TDS,SAL,SG
                  if ( ec_index == EC_INDEX_EC )
                  {
                    if(ec_inchar == ',') 
                    {
                      ec_index = ec_index+1;
                      continue;
                    } 
                    else
                    {
                      ec_sensorstring_ec += ec_inchar;
                    }
                  }
                  else if ( ec_index == EC_INDEX_TDS )
                  {
                    if(ec_inchar == ',') 
                    {
                      ec_index = ec_index+1;
                      continue;
                    } 
                    else
                    {
                      ec_sensorstring_tds += ec_inchar;
                    }
                  }
                  else if ( ec_index == EC_INDEX_SAL )
                  {
                    if(ec_inchar == ',') 
                    {
                      ec_index = ec_index+1;
                      continue;
                    } 
                    else
                    {
                      ec_sensorstring_sal += ec_inchar;
                    }
                  }
                  else if ( ec_index == EC_INDEX_SG )
                  {
                    if(ec_inchar == ',') 
                    {
                      // Error happens. !! 
                      // TODO: Error handling
                      //ec_index = ec_index+1;
                      continue;
                    } 
                    else
                    {
                      ec_sensorstring_sg += ec_inchar;
                    }
                  }
                  else
                   // Do nothing but jump to next e. 
                    continue;
                 
                }
             }
#endif //ENABLE_EC_SENSOR


// PM2.5 Sensor's serial events: serialEvent and serialEvent3
#if defined ENABLE_PM_2_POINT_5_SENSOR_S3
void serialEvent3(){  //if the hardware serial port_3 receives a char 
               if (pm25_input_readcomplete)
               {
                 pm25_input_readcomplete = false;
               }
               if (Serial3.available()) {
                 
                 uint8_t pm25_read_bytes[PM25_COMMAND_LENGTH];
                 for(int i=0; i< PM25_COMMAND_LENGTH; i++)
                 {
	           pm25_read_bytes[i] = Serial3.read();     //get the byte we just received
                 }
                 unsigned int high = pm25_read_bytes[PM25_READ_BYTE_VOUT_H];       //high byte for value is 2nd byte in packet in the packet
                 unsigned int low = pm25_read_bytes[PM25_READ_BYTE_VOUT_L];        //low byte for value is 3rd byte in the packet
                 pm25_Vo = (high*256 + low);                //combine high byte and low byte
                 pm25_input_readcomplete = true;
                 return;
               }
}
#endif //ENABLE_PM_2_POINT_5_SENSOR_S3

