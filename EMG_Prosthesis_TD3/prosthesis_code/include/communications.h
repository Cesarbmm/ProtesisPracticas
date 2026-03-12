#include <Arduino.h>
#ifndef COMMUNICATIONS_H
#define COMMUNICATIONS_H

#include <Regexp.h> // docs at:
// http://www.gammon.com.au/scripts/doc.php?lua=string.find

#include "BluetoothSerial.h"
BluetoothSerial SerialBT;

/// \brief enum with the types of communication
enum class CommunicationType
{
  SERIAL_COM,
  BLUETOOTH_COM,
  BOTH
} communicationType; // global com type

/// \brief Reads from selected interface (serial, bluetooth or both)
/// \return message, "" empty when no message is received
String read_msg(CommunicationType type = communicationType)
{
  switch (type)
  {
  case CommunicationType::SERIAL_COM:
  case CommunicationType::BOTH:
    if (Serial.available())
      return Serial.readStringUntil('\n');
    break;
  case CommunicationType::BLUETOOTH_COM:
    if (SerialBT.available())
      return SerialBT.readStringUntil('\n');
    break;
  default:
    break;
  }

  return "";
}

/// \brief log level struct
enum LogLevel
{
  DEBUG,
  INFO,
  WARN,
  ERROR
};

/// \brief Send the msg either Bluetooth, serial or both.
/// \param msg string to send
/// \param type type of communication
/// \param NL if true, adds a new line at the end
/// \param loglevel level of the message, compares it with the global variable LOG_LEVEL
void send_msg(String msg, CommunicationType type = communicationType, bool NL = true, LogLevel loglevel = LogLevel::INFO)
{
  if (loglevel == LogLevel::DEBUG)
    if (LOG_LEVEL != "DEBUG")
      return;

  switch (type)
  {
  case CommunicationType::SERIAL_COM:
    if (NL)
      Serial.println(msg);
    else
      Serial.print(msg);
    break;

  case CommunicationType::BLUETOOTH_COM:
    if (NL)
      SerialBT.println(msg);
    else
      SerialBT.print(msg);

    break;

  case CommunicationType::BOTH:
    if (NL)
    {
      Serial.println(msg);
      SerialBT.println(msg);
    }
    else
    {
      Serial.print(msg);
      SerialBT.print(msg);
    }
    break;

  default:
    break;
  }
}

/// \brief overload method to send in debug mode.
/// \param msg string to send
/// \param loglevel level of the message, compares it with the global variable LOG_LEVEL
void send_msg(String msg, LogLevel loglevel)
{
  send_msg(msg, communicationType, true, loglevel);
}

// / \brief given 4 PWMs returns a string
// / \param speeds array of 4 pwm speeds
// / \return string with the format: PWM1,PWM2,PWM3,PWM4
// String format_speeds(int16_t *speeds)
// {
//   return String(speeds[0]) + ", " +
//          String(speeds[1]) + ", " +
//          String(speeds[2]) + ", " +
//          String(speeds[3]);
// }

/// \brief enum with the types of messages possible to receive
enum MsgReceiveType
{
  TARGET_GO,  // move to a target position
  CLOSE_HAND, // close the hand at predefined speed with limits
  OPEN_HAND,  // open the hand at predefined speed with limits
  MOVE_MOT,   // moves only 1 motor
  GO_HOME,    // go to the lower tension point
  FIND_HOME,  // find the lower tension point
  MOVE,       // move a motor
  STOP,       // stop all the motors
  STOP_ONE,   // stop one motor
  MOD_PERIOD, // changes the period to send encoder data
  RESET,      // resets the encoders' values
  MSG_ERROR,  // unkown msg
  REGEX_ERROR // some error on regex
};

/* ###########################################
 * ###########  Action types  ################
 * ###########################################
 */

/// \brief Action requires 4 variables
struct Action_by4
{
  int16_t v1 = 0; // e.g. pwm velocity of motor 1
  int16_t v2 = 0; // e.g. pwm velocity of motor 2
  int16_t v3 = 0; // e.g. pwm velocity of motor 3
  int16_t v4 = 0; // e.g. pwm velocity of motor 4
};

/// \brief Action requires 2 variables
struct Action_by2
{
  int16_t index = 0; // e.g. select motor 1
  int16_t value = 0; // e.g. pwm velocity of motor 1
};

/// \brief Action only changes 1 variable
struct Action_by1
{
  uint8_t value = 0; // e.g. stop motor 1
};

/// \brief returns the corresponding value of the hexadecimal numbers
/// \param letter char from 0-9 and A-F, a-f
int8_t hex2dec(char letter)
{
  switch (letter)
  {
  case '0':
    return 0;
  case '1':
    return 1;
  case '2':
    return 2;
  case '3':
    return 3;
  case '4':
    return 4;
  case '5':
    return 5;
  case '6':
    return 6;
  case '7':
    return 7;
  case '8':
    return 8;
  case '9':
    return 9;
  case 'A':
  case 'a':
    return 10;
  case 'B':
  case 'b':
    return 11;
  case 'C':
  case 'c':
    return 12;
  case 'D':
  case 'd':
    return 13;
  case 'E':
  case 'e':
    return 14;
  case 'F':
  case 'f':
    return 15;
  default:
    return 0; // must be error
  }
}

/// \brief converts a hexadecimal number to decimal
/// \param number string of the number
int32_t hex2dec(String number)
{
  int32_t val = 0;

  for (int i = 0; i < number.length(); i++)
  {
    int32_t digit = hex2dec(number.charAt(i));
    val += digit * pow(16, number.length() - i - 1);
  }
  return val;
}

/// \brief decodes the speed of a motor
/// \param msg string of size 3, the letter motor and the speed in Hexa (e.g. aFF means motor 1 backward at 255, B04 means motor 2 forward at 4)
int16_t decodeSpeed(String msg)
{
  int direction = 1; // assumes forward, -1 is backwards
  if (isLowerCase(msg.charAt(0)))
    direction = -1;
  int16_t vel = hex2dec(msg.substring(1, msg.length()));
  return vel * direction;
}

/// \brief decodes the raw string message into the desired action
/// \param msg string with the message, assumes it is a line
/// \param action_type pointer to the type of action to be returned
/// \return A type of action struct with the decoded message. void * used to return generic type.
void *decodeMsg(const String msg, MsgReceiveType *action_type)
{
  // Converting to char array
  int str_len = msg.length() + 1;
  char char_array[str_len];
  msg.toCharArray(char_array, str_len);

  //**************** REGEX
  MatchState ms; //
  ms.Target(char_array);

  //**************** First match: Speeds
  // %x Upper or lower case hexadecimal digit
  char result = ms.Match("^([Aa]%x%x?)([Bb]%x%x?)([Cc]%x%x?)([Dd]%x%x?)$"); //

  if (result == REGEXP_MATCHED)
  {
    // --------------------- REGEx velocity in hex to int pwm
    *action_type = MsgReceiveType::MOVE;

    Action_by4 *action = new Action_by4();

    char buffer[10] = ""; // buffer to store the capture

    // direction adjustements
    action->v1 = decodeSpeed(ms.GetCapture(buffer, 0));
    action->v2 = decodeSpeed(ms.GetCapture(buffer, 1));
    action->v3 = decodeSpeed(ms.GetCapture(buffer, 2));
    action->v4 = decodeSpeed(ms.GetCapture(buffer, 3));

    return action;
  }
  else if (result != REGEXP_NOMATCH) // eror in regex
    return nullptr;

  //**************** next match: STOP
  result = ms.Match("S:");
  if (result == REGEXP_MATCHED)
  {
    *action_type = MsgReceiveType::STOP;
    return nullptr;
  }
  else if (result != REGEXP_NOMATCH) // eror in regex
    return nullptr;

  //**************** next match: STOP 1 motor
  result = ms.Match("S%d+:");
  if (result == REGEXP_MATCHED)
  {
    *action_type = MsgReceiveType::STOP_ONE;
    Action_by1 *action = new Action_by1();
    action->value = msg.substring(1, msg.length() - 1).toInt();
    return action;
  }
  else if (result != REGEXP_NOMATCH) // eror in regex
    return nullptr;

  //**************** next match: RESET
  result = ms.Match("R:");
  if (result == REGEXP_MATCHED)
  {
    *action_type = MsgReceiveType::RESET;
    return nullptr;
  }
  else if (result != REGEXP_NOMATCH) // eror in regex
    return nullptr;

  //**************** next match: GO_HOME
  result = ms.Match("H[DN]%d+:");
  if (result == REGEXP_MATCHED)
  {
    *action_type = MsgReceiveType::GO_HOME;
    // action.noMovSpeed = msg.substring(2, msg.length() - 1).toInt();

    // action.debug = msg.charAt(1) == 'D';
    return nullptr;
  }
  else if (result != REGEXP_NOMATCH) // eror in regex
    return nullptr;

  //**************** next match: FIND_HOME with debugging
  result = ms.Match("F[DN]%d+:");
  if (result == REGEXP_MATCHED)
  {
    *action_type = MsgReceiveType::FIND_HOME;
    // action.noMovSpeed = msg.substring(2, msg.length() - 1).toInt();

    // action.debug = msg.charAt(1) == 'D';

    return nullptr;
  }
  else if (result != REGEXP_NOMATCH) // eror in regex
    return nullptr;

  //**************** next match: Change period
  result = ms.Match("P%d+");
  if (result == REGEXP_MATCHED)
  {
    *action_type = MsgReceiveType::MOD_PERIOD;
    String v1 = msg.substring(ms.MatchStart + 1, ms.MatchStart + ms.MatchLength);
    Action_by1 *action = new Action_by1();

    action->value = v1.toInt();
    return action;
  }
  else if (result != REGEXP_NOMATCH) // eror in regex
    return nullptr;

  //**************** next match: Close hand
  result = ms.Match("C:");
  if (result == REGEXP_MATCHED)
  {
    *action_type = MsgReceiveType::CLOSE_HAND;
    return nullptr;
  }
  else if (result != REGEXP_NOMATCH) // eror in regex
    return nullptr;

  //**************** next match: Close hand
  result = ms.Match("O:");
  if (result == REGEXP_MATCHED)
  {
    *action_type = MsgReceiveType::OPEN_HAND;
    return nullptr;
  }
  else if (result != REGEXP_NOMATCH) // eror in regex
    return nullptr;

  //**************** next match: Move 1 motor
  result = ms.Match("^([AaBbCcDd])(%x%x?)$");
  if (result == REGEXP_MATCHED)
  {
    *action_type = MsgReceiveType::MOVE_MOT;

    Action_by2 *action = new Action_by2();

    char buffer[10] = ""; // buffer to store the capture

    char l = *ms.GetCapture(buffer, 0);
    switch (l)
    {
    case 'A':
    case 'a':
      action->index = 1;
      break;
    case 'B':
    case 'b':
      action->index = 2;
      break;
    case 'C':
    case 'c':
      action->index = 3;
      break;
    case 'D':
    case 'd':
      action->index = 4;
      break;
    default:
      break;
    }

    int direction = 1; // assumes forward, -1 is backwards
    if (isLowerCase(l))
      direction = -1;
    action->value = direction * hex2dec(ms.GetCapture(buffer, 1));

    return action;
  }
  else if (result != REGEXP_NOMATCH) // eror in regex
    return nullptr;

  //**************** next match: Target motor setpoint
  result = ms.Match("T%d+:%d+");
  if (result == REGEXP_MATCHED)
  {
    *action_type = MsgReceiveType::TARGET_GO;

    Action_by2 *action = new Action_by2();

    // action.index = msg.substring(ms.MatchStart + 1, ms.MatchStart + ms.MatchLength - 2).toInt();
    // action.value = msg.substring(ms.MatchStart + ms.MatchLength - 1, ms.MatchStart + ms.MatchLength).toInt();

    return action;
  }
  else if (result != REGEXP_NOMATCH) // eror in regex
    return nullptr;

  //**************** next match: DEFAULT
  // when error in trama
  *action_type = MsgReceiveType::MSG_ERROR;
  return nullptr;
}

#endif // COMMUNICATIONS_H