/*

# Changelog
* v1: 23 / 06 / 2021
* v2: 30 / 05 / 2023

@author: z_tjona
*/
#pragma once // el pragma once funcionó... :o!
#include <Arduino.h>

// ///////////////////////////////////
#ifdef ESP32

#include <ESP32Encoder.h>
#include <MotorControl.h>

// /////////////////////////////////////////////////

/// @brief Callback of the encoder interrupt
/// @param arg pointer to the encoder object
/// @return void
static IRAM_ATTR void enc_cb1(void *arg);
static IRAM_ATTR void enc_cb2(void *arg); //
static IRAM_ATTR void enc_cb3(void *arg); //
static IRAM_ATTR void enc_cb4(void *arg); //

// class that handles the motors
class Motors
// ///////////////////////////////////
{
private:
    // ///////////////////////////////////

    /// \brief returns the motor pointer for the given index
    MotorControl *getMotor(uint8_t idxMotor);

    /// \brief returns the motor encoder pointer for the given index
    ESP32Encoder *getEncoder(uint8_t idxM);

    // is a vector of 1 or -1 that reverts the counter direction
    const int8_t *_encoderDirections;

    // is a vector of 1 or -1 that reverts the motor direction
    const int8_t *_motorDirections;

    // ///////////////////////////////////
public:
    enum class Direction //
    {
        FORWARDING,
        STOPPED,
        BACKWARDING
    };

    // Intended direction of the motors. It already consider the inversions.
    Direction dirs[4] = {Direction::STOPPED, Direction::STOPPED,
                         Direction::STOPPED, Direction::STOPPED};

    // if the motor is in the danger zone
    bool danger_zone[4] = {false, false, false, false};

    // if the motor is in the negative zone
    bool neg_zone[4] = {false, false, false, false};

    // flag to know if the motors have already moved forward
    // when true, the motors will be stopped when reaching the limits
    // when false, the motor will not be stopped when reaching the limits
    bool already_moved[4] = {false, false, false, false};

    int32_t const UPPER_LIMS[4]; // upper encoder limits of the motors
    int32_t const LOWER_LIMS[4]; // lower encoder limits of the motors
    int32_t const REV_LIMS[4];   // reverse encoder limits of the motors

    size_t const MOTOR_COUNT = 4;

    /// \brief returns the position of a requested encoder considering the direction
    /// \param idxM index of the motor
    int32_t getEncoderPosition(int idxM);

    MotorControl motor1;
    MotorControl motor2;
    MotorControl motor3;
    MotorControl motor4;

    ESP32Encoder encoder1;
    ESP32Encoder encoder2;
    ESP32Encoder encoder3;
    ESP32Encoder encoder4;

    /// \brief constructor that attaches motor limits, encoder directions
    /// \param up_lim_t upper limits of the motors, must be pointer not int32_t up_lim_t[], also, check the const
    /// \param low_limt_t lower limits of the motors
    /// \param rev_limt_t reverse limits of the motors
    /// \param encoderDirections directions of the encoders
    /// \param motorDirections directions of the motors
    Motors(const int32_t *up_lim_t, const int32_t *low_limt_t,
           const int32_t *rev_limt_t,
           const int8_t *encoderDirections, const int8_t *motorDirections);

    /// \brief brakes given motor idx, first reduces speed
    void stop(uint8_t idxM);

    /// \brief brakes all the motors, first reduces speed
    void stop();

    /// \brief moves a given motor with a given speed
    /// \param motorNum is the index of the motor 1-4
    /// \param pwmSpeed is the speed of the motor 0-255
    void move(uint8_t motorNum, int16_t pwmSpeed);

    /// \brief moves all the motors
    void move(int16_t pwm1, int16_t pwm2, int16_t pwm3, int16_t pwm4);

    /// \brief gets encoder positions in a string that will be transmitted.
    /// \return string with the format: ENC1,ENC2,ENC3,ENC4
    String get_positions();

    /// \brief resets the encoders' counters
    void reset();

    /// \brief attach encoder pins to the motors
    /// \param e1_l left pin of encoder 1
    /// \param e1_r right pin of encoder 1
    /// \param e2_l left pin of encoder 2, etc...
    /// \param e2_r -
    /// \param e3_l -
    /// \param e3_r -
    /// \param e4_l -
    /// \param e4_r -
    void attachEncoders(int e1_l, int e1_r, int e2_l, int e2_r, int e3_l, int e3_r, int e4_l, int e4_r);
};

/// @brief Generic callback of the encoder interrupt
/// @param idx index of the motor
/// @return void
static IRAM_ATTR void enc_cb(Motors *mot, uint8_t idxM);

#endif
