#include <Arduino.h>

#ifndef DEFINITIONS_H
#define DEFINITIONS_H

String version = "2.6";
String const LOG_LEVEL = "INFO"; // DEBUG, INFO, WARN, ERROR
// String const LOG_LEVEL = "DEBUG"; // when debugging

String device_name = "Prosthesis_EPN_v2";

uint32_t PERIOD = 100;       // period to transmit data, in ms
uint32_t tiempo = 0;         // last ms count where encoder data was sent
uint32_t PERIOD_PING = 1000; // ms to send initial ping message
uint32_t PERIOD_FAST = 500;  // ms to send fast messages

// ------------ Motor considerations
int8_t const MOTOR_DIRECTIONS[] = {1, 1, 1, -1};   // motor 4 must run inverted
int8_t const ENCODER_DIRECTIONS[] = {1, 1, -1, 1}; // encoder 3 must be inverted

// Motor order: little, idx, thumb, mid. Always check the hardware!
int32_t const ENCODER_MIN_LIMS[] = {0, 0, 0, 0};                 // only applied when moved forward
int32_t const ENCODER_MAX_LIMS[] = {26500, 11500, 8500, 9000};    //
int32_t const ENCODER_REV_LIMS[] = {-1700, -1000, -1000, -1000}; // applied at reset until moved forward

int16_t const CLOSE_SPEED[] = {255, 160, 160, 160}; //  pwm speeds to close hand

// ------------ General purpose pins
// const int pin1 = 9;
// const int pin2 = 10;

int noMovSpeed = 50; // pwm to find low point, this speed must be low enough to not move the fingers but to relax the tendoms.
// const int maxEncoderDif = 250;   // acceptable encoder range to reach low point. Motors will stop when entering: lP +- maxEncoderDif.
// const int tensionEncoderDif = 5; // difference in encoder position when the motor is tense
// ??const int encoderPause = 100;    // ms to update reading // 100

// ----------------- Motor constants
// const float COMPENSATION_MOTOR = 0.8; // motor 3 has different properties, so it is compensated.

// const float INCREASING_FACTOR_mid = 1.5; // factor to increase the speed of the motor when stopped before reaching the low point

// const float INCREASING_FACTOR = 1.3; // factor to increase the speed of the motor when stopped before reaching the low point
// const float DECREASING_FACTOR = 0.9; // factor to decrease the speed of the motor when approaching the low point

// const uint16_t MIN_NUM_ITER = 3; // minimum number of iterations to reach low point

// const uint16_t NUM_RETRIES_INERTIA = 3; // number of increments to break inertia in moving top

// ////////////////////////////
// Encoders
// ////////////////////////////
// Right (aka A signal) is yellow. Left (B signal) is white
int const ENCODER1_LEFT = A0;
int const ENCODER1_RIGHT = A1;
int const ENCODER2_LEFT = A2; // affected by builtin led, must be desoldered
int const ENCODER2_RIGHT = A3;
int const ENCODER3_LEFT = A4;
int const ENCODER3_RIGHT = A5;
int const ENCODER4_LEFT = 18;  // in UNO:  13
int const ENCODER4_RIGHT = 26; // in UNO:  2
#endif                         // DEFINITIONS_H