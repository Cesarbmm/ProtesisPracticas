/*
Code for the V2 Wemos D1 R32 that controls the 4 motors of the prosthesis.
It receives commands from Matlab via Serial.

# Changelog
* v1: 23 / 06 / 2021
* v2: 30 / 05 / 2023
* v2.5: 03 / 07 / 2023    -   Added bluetooth

@author: z_tjona

*/

#include <Arduino.h>
#include "definitions.h"
#include "communications.h"
#include <Motors.h>
#include "functions.h"

Motors motors(ENCODER_MAX_LIMS,
              ENCODER_MIN_LIMS,
              ENCODER_REV_LIMS,
              ENCODER_DIRECTIONS,
              MOTOR_DIRECTIONS); // object with the 4 motors

// // ///////////////////////////////////
// // ///////////////////////////////////
// // ///////////////////////////////////
// // ///////////////////////////////////
// // ///////////////////////////////////
void setup()
{
  Serial.begin(250000);
  while (!Serial)
    ;
  SerialBT.begin(device_name);
  while (!SerialBT)
    ;

  // ///////////////////////////////////
  // Initial connection
  // ///////////////////////////////////
  send_msg("\n" + device_name + ": uC inited", CommunicationType::BOTH);
  send_msg("Software version: " + version, CommunicationType::BOTH);
  send_msg("Send any message to start.", CommunicationType::BOTH);

  bool waitConnection = true;
  // loop until a message is received either serial or Bluetooth
  while (true)
  {
    if (millis() % PERIOD_PING == 0)
      send_msg(".", CommunicationType::BOTH, false);

    // checking serial
    if (Serial.available())
    {
      communicationType = CommunicationType::SERIAL_COM;

      String msg = Serial.readStringUntil('\n');
      send_msg("Serial mode selected.", CommunicationType::BOTH);
      send_msg("Turning off Bluetooth...", CommunicationType::BOTH);
      SerialBT.disconnect();
      delay(200); // pause needed to avoid crashing.
      SerialBT.end();

      break;
    }

    if (SerialBT.connected() && waitConnection)
    {
      // Says hello when new connection.
      waitConnection = false; // only once
      send_msg("\n" + device_name + ": uC inited", CommunicationType::BLUETOOTH_COM);
      send_msg("Bluetooth device connected.", CommunicationType::BOTH);
      send_msg("Send any message to start.", CommunicationType::BLUETOOTH_COM);
    }

    if (SerialBT.available())
    {
      communicationType = CommunicationType::BLUETOOTH_COM;

      String msg = SerialBT.readStringUntil('\n');
      send_msg("Bluetooth mode selected.", CommunicationType::BOTH);

      break;
    }
  }
  send_msg("Ready!");

  // ///////////////////////////////////
  // encoders
  motors.attachEncoders(ENCODER1_LEFT,
                        ENCODER1_RIGHT,
                        ENCODER2_LEFT,
                        ENCODER2_RIGHT,
                        ENCODER3_LEFT,
                        ENCODER3_RIGHT,
                        ENCODER4_LEFT,
                        ENCODER4_RIGHT);

  tiempo = millis();
}

// // ///////////////////////////////////
// // ///////////////////////////////////
// // ///////////////////////////////////
// // ///////////////////////////////////
// // ///////////////////////////////////
void loop()
{
  // ------------- Decoding msg
  String msg = read_msg();

  if (msg == "ACK")
  {
    send_msg("ACK ok!");
    return;
  }

  // ------------- Cases
  if (msg != "")
  {
    MsgReceiveType action_type;
    void *action_generic = decodeMsg(msg, &action_type);

    bool status;
    // deciding depending on msg action type
    switch (action_type)
    {
    case MsgReceiveType::CLOSE_HAND:

      send_msg("Closing hand", LogLevel::DEBUG);
      motors.move(CLOSE_SPEED[0], CLOSE_SPEED[1], CLOSE_SPEED[2], CLOSE_SPEED[3]);

      break;

    case MsgReceiveType::OPEN_HAND:

      send_msg("Opening hand", LogLevel::DEBUG);
      motors.move(-CLOSE_SPEED[0], -CLOSE_SPEED[1], -CLOSE_SPEED[2], -CLOSE_SPEED[3]);

      break;

    case MsgReceiveType::MOVE_MOT:
    {
      Action_by2 action = *(Action_by2 *)action_generic;
      motors.move(action.index, action.value);

      break;
    }
    case MsgReceiveType::GO_HOME:

      send_msg("Not defined yet");
      // motors.goHome();
      break;

    case MsgReceiveType::FIND_HOME:

      send_msg("Not defined yet");
      // motors.findHome();
      break;

    case MsgReceiveType::MOVE:
    {
      Action_by4 action = *(Action_by4 *)action_generic;
      motors.move(action.v1, action.v2, action.v3, action.v4);

      break;
    }

    case MsgReceiveType::STOP:
      motors.stop();
      break;

    case MsgReceiveType::STOP_ONE:
    {
      Action_by1 action = *(Action_by1 *)action_generic;
      motors.stop(action.value);
      break;
    }

    case MsgReceiveType::RESET:
      motors.reset();
      break;

    case MsgReceiveType::MOD_PERIOD:
    {
      Action_by1 action = *(Action_by1 *)action_generic;
      PERIOD = action.value;

      send_msg("Changing period [ms] to " + String(PERIOD));
      break;
    }

    case MsgReceiveType::MSG_ERROR:
      send_msg("Error: unkown msg");
      send_msg(msg);
      break;

    default:
      send_msg("Error: regex error");
      break;
    }
  }

  // ------------- Sending encoders position
  wait_listen_motors(PERIOD, &motors); // waits and handles motor interruptions
  send_msg(motors.get_positions());
}
