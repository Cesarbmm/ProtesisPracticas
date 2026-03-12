#include "Motors.h"

// ///////////////////////////////////
ESP32Encoder *Motors::getEncoder(uint8_t idxM)
{
    ESP32Encoder *m = nullptr;
    switch (idxM)
    {
    case 1:
        m = &encoder1;
        break;

    case 2:
        m = &encoder2;
        break;

    case 3:
        m = &encoder3;
        break;
    case 4:
        m = &encoder4;
        break;

        // default: // error!
        //     return;
    }
    return m;
}

MotorControl *Motors::getMotor(uint8_t idxMotor)
// ///////////////////////////////////
{
    MotorControl *m = nullptr;
    switch (idxMotor)
    {
    case 1:
        m = &motor1;
        break;

    case 2:
        m = &motor2;
        break;

    case 3:
        m = &motor3;
        break;
    case 4:
        m = &motor4;
        break;

        // default: // error!
        //     return;
    }
    return m;
}

void Motors::stop(uint8_t idxM)
// ///////////////////////////////////
{
    MotorControl *m = getMotor(idxM);
    if (m != nullptr)
    {
        m->setSpeed(0);
        m->brake();
        dirs[idxM - 1] = Direction::STOPPED;
    }
}

void Motors::stop()
// ///////////////////////////////////
{
    motor1.setSpeed(0);
    motor2.setSpeed(0);
    motor3.setSpeed(0);
    motor4.setSpeed(0);

    motor1.brake();
    motor2.brake();
    motor3.brake();
    motor4.brake();

    dirs[0] = Direction::STOPPED;
    dirs[1] = Direction::STOPPED;
    dirs[2] = Direction::STOPPED;
    dirs[3] = Direction::STOPPED;
}

void Motors::move(uint8_t motorNum, int16_t pwmSpeed)
// ///////////////////////////////////
{
    MotorControl *m = getMotor(motorNum);
    if (m == nullptr)
        return;
    pwmSpeed = _motorDirections[motorNum - 1] * pwmSpeed;

    if (pwmSpeed > 0)
    {
        m->setSpeed(pwmSpeed);
        m->forward();
        if (_motorDirections[motorNum - 1] == 1)
        {
            dirs[motorNum - 1] = Direction::FORWARDING;
            already_moved[motorNum - 1] = true;
        }
        else
            dirs[motorNum - 1] = Direction::BACKWARDING;
    }
    else if (pwmSpeed == 0)
    {
        m->setSpeed(pwmSpeed);
        m->brake();
        dirs[motorNum - 1] = Direction::STOPPED;
    }
    else
    {
        m->setSpeed(abs(pwmSpeed));
        m->backward();
        if (_motorDirections[motorNum - 1] == 1)
            dirs[motorNum - 1] = Direction::BACKWARDING;
        else
        {
            dirs[motorNum - 1] = Direction::FORWARDING;
            already_moved[motorNum - 1] = true;
        }
    }
}

String Motors::get_positions()
// ///////////////////////////////////
{
    // motor positions
    int32_t p1 = getEncoderPosition(1);
    int32_t p2 = getEncoderPosition(2);
    int32_t p3 = getEncoderPosition(3);
    int32_t p4 = getEncoderPosition(4);

    String msg = "x" + String(p1) + "y" + String(p2) + "z" + String(p3) + "w" + String(p4);

    return msg;
}

void Motors::move(int16_t pwm1, int16_t pwm2, int16_t pwm3, int16_t pwm4)
// ///////////////////////////////////
{
    move(1, pwm1);
    move(2, pwm2);
    move(3, pwm3);
    move(4, pwm4);
}

void Motors::reset()
// ///////////////////////////////////
{
    encoder1.setCount(0);
    encoder2.setCount(0);
    encoder3.setCount(0);
    encoder4.setCount(0);
}

// void Motors::onOffController(const int32_t p_i, const uint8_t idxM, int16_t *speed, const int32_t midP, bool *dir)
// // ///////////////////////////////////
// {
//     // if (abs(midP - p_i) < maxEncoderDif) // close enough
//     //     // break;
//     //     *speed *= DECREASING_FACTOR; //

//     if (midP >= p_i && !*dir)
//     { // is ahead, but is going backwards, then go forward
//         *speed *= DECREASING_FACTOR;
//         debug("f: s=" + String(*speed));
//         *dir = true;
//         move(idxM, *speed, *dir);
//     }

//     // else if(midP > p_i && *dir){
//     //     // is infront and going forward
//     //     debug("good is F");
//     // }
//     // else if (midP < p_i && !*dir)
//     // {
//     //     debug("good is B");
//     // }
//     else if (midP <= p_i && *dir)
//     { // it is behind but is going forward
//         *speed *= DECREASING_FACTOR;
//         debug("b: s=" + String(*speed));
//         *dir = false;
//         move(idxM, *speed, *dir);
//     }
//     // else
//     // debug("mid: " + String(midP) + " p_i: " + String(p_i));
// }

// void Motors::stoppingCriteria(const uint16_t it, const uint8_t motIdx, const int32_t p, const int32_t pOld, bool *continuar, bool *dir, int16_t *speed)
// // ///////////////////////////////////
// {
//     if (!*continuar)
//         return;

//     if ((it > MIN_NUM_ITER && abs(p - pOld) < tensionEncoderDif) || it > 15) // temp to stop motor
//     {                                                                        // not moving
//         if (abs(p) > maxEncoderDif)
//         { // too far away, increase speed
//             *speed *= INCREASING_FACTOR;
//             move(motIdx, *speed, *dir);
//         }
//         else
//         {
//             // stopping motor
//             stop(motIdx);

//             *continuar = false;
//         }
//     }
// }

// void Motors::goHome()
// // ///////////////////////////////////
// { // TODO
//     // corresponding ith motor is moving while move_ith is true.
//     bool move1 = true, move2 = true, move3 = true, move4 = true;

//     int16_t speed1 = noMovSpeed;
//     int16_t speed2 = speed1, speed3 = speed1, speed4 = speed1;

//     // motor 3 is different, so it requires a decrement
//     // speed3 *= COMPENSATION_MOTOR;
//     // speed2 *= INCREASING_FACTOR;
//     // speed4 *= INCREASING_FACTOR_mid;

//     // usually, motors are in the forward direction, so starts going backwards
//     bool dir1 = false, dir2 = false, dir3 = false, dir4 = false;
//     move(-speed1, -speed2, -speed3, -speed4);
//     int32_t p_iOld1, p_iOld2, p_iOld3, p_iOld4;

//     uint16_t it = 0;
//     while (move1 || move2 || move3 || move4)
//     {
//         // pause to update encoder
//         wait(encoderPause);

//         stoppingCriteria(it, 1, p1, p_iOld1, &move1, &dir1, &speed1);
//         stoppingCriteria(it, 2, p2, p_iOld2, &move2, &dir2, &speed2);
//         stoppingCriteria(it, 3, p3, p_iOld3, &move3, &dir3, &speed3);
//         stoppingCriteria(it, 4, p4, p_iOld4, &move4, &dir4, &speed4);

//         p_iOld1 = p1, p_iOld2 = p2, p_iOld3 = p3, p_iOld4 = p4;
//         debug(String(p1) + " 1s:" + String(speed1));
//         debug(String(p2) + " 2s:" + String(speed2));
//         debug(String(p3) + " 3s:" + String(speed3));
//         debug(String(p4) + " 4s:" + String(speed4));
//         onOffController(p1, 1, &speed1, 0, &dir1);
//         onOffController(p2, 2, &speed2, 0, &dir2);
//         onOffController(p3, 3, &speed3, 0, &dir3);
//         onOffController(p4, 4, &speed4, 0, &dir4);
//         it++;
//     }

//     stop();

//     Serial.println("h:"); // finished msg
// }

// void Motors::findHome()
// // ///////////////////////////////////
// { // TODO
//     debug("Moving to home position");
//     for (uint8_t idxM = 1; idxM <= 4; idxM++)
//     { // motors move

//         int16_t speed = noMovSpeed;

//         // // motor 3 is different, so it requires a compensation
//         // if (idxM == 3)
//         //     speed *= COMPENSATION_MOTOR;
//         // else if (idxM == 2)
//         //     speed *= INCREASING_FACTOR;
//         // else if (idxM == 4)
//         //     speed *= INCREASING_FACTOR_mid;

//         transmit();

//         debug("Motor " + String(idxM));

//         int32_t p_iForward, p_iBackward;
//         for (uint8_t ij = 0; ij < NUM_RETRIES_INERTIA; ij++)
//         { // ------------ forward
//             debug("Speed " + String(speed));
//             debug("Forward");
//             // p_iForward = moveTop(idxM, speed);

//             // ------------- backwards
//             debug("Backward");
//             // p_iBackward = moveTop(idxM, -speed);

//             if (abs(p_iBackward - p_iForward) > maxEncoderDif)
//                 break;

//             // to break inertia
//             speed *= INCREASING_FACTOR;
//         }

//         // --------- mid point
//         int32_t midP = (p_iForward + p_iBackward) / 2; // target point
//         debug("Mid point: " + String(midP));

//         uint16_t it = 0;

//         move(idxM, speed);
//         int32_t p_i, p_iOld;
//         bool dir = true; // forward
//         while (true)
//         {
//             // pause to update encoder
//             wait(encoderPause);

//             // reading new encoder position
//             p_i = getEncoderPosition(idxM);
//             debug(String(p_i));
//             // debug("S:" + String(speed) + "D:" + String(dir) + "p:" + String(p_i));

//             if (it > 2 && abs(p_iOld - p_i) < tensionEncoderDif) // not moving
//                 break;
//             p_iOld = p_i;

//             onOffController(p_i, idxM, &speed, midP, &dir);
//             it++;

//             // only tries to stop if it has run for some time and
//             // the encoders are not changing much
//         }
//         stop();
//     }
//     if (debugMatlab)
//         transmit();

//     Serial.println("h:"); // finished msg
// }

int32_t Motors::getEncoderPosition(int idxM)
// ///////////////////////////////////
{
    ESP32Encoder *m = getEncoder(idxM);
    return _encoderDirections[idxM - 1] * m->getCount();
}

// NOTE: very inneficient, but it works
static IRAM_ATTR void enc_cb(Motors *mot, uint8_t idxM)
// /////////////////////////////////////////////////
{
    if (mot == nullptr)
    {
        Serial.println("[ERROR]|ISR| Enc.");
        return;
    }

    mot->danger_zone[idxM] = mot->getEncoderPosition(idxM + 1) >= mot->UPPER_LIMS[idxM];

    if (mot->already_moved[idxM])
        mot->neg_zone[idxM] = mot->getEncoderPosition(idxM + 1) <= mot->LOWER_LIMS[idxM];
    else
        mot->neg_zone[idxM] = mot->getEncoderPosition(idxM + 1) <= mot->REV_LIMS[idxM];
}

static IRAM_ATTR void enc_cb1(void *arg)
// /////////////////////////////////////////////////
{
    enc_cb((Motors *)arg, 0);
}
static IRAM_ATTR void enc_cb2(void *arg)
// /////////////////////////////////////////////////
{
    enc_cb((Motors *)arg, 1);
}
static IRAM_ATTR void enc_cb3(void *arg)
// /////////////////////////////////////////////////
{
    enc_cb((Motors *)arg, 2);
}
static IRAM_ATTR void enc_cb4(void *arg)
// /////////////////////////////////////////////////
{
    enc_cb((Motors *)arg, 3);
}

// must be defined after the callbacks
Motors::Motors(
    // /////////////////////////////////////////////////
    // /////////////////////////////////////////////////
    const int32_t *up_lim_t,
    const int32_t *low_lim_t,
    const int32_t *rev_lim_t,
    const int8_t *encoderDirections,
    const int8_t *motorDirections) : encoder1(true, enc_cb1, this),
                                     encoder2(true, enc_cb2, this),
                                     encoder3(true, enc_cb3, this),
                                     encoder4(true, enc_cb4, this),
                                     motor1(MotorControl(1)),
                                     motor2(MotorControl(2)),
                                     motor3(MotorControl(3)),
                                     motor4(MotorControl(4)),
                                     UPPER_LIMS{
                                         up_lim_t[0], up_lim_t[1],
                                         up_lim_t[2], up_lim_t[3]},
                                     LOWER_LIMS{
                                         low_lim_t[0], low_lim_t[1],
                                         low_lim_t[2], low_lim_t[3]},
                                     REV_LIMS{
                                         rev_lim_t[0], rev_lim_t[1],
                                         rev_lim_t[2], rev_lim_t[3]},
                                     _encoderDirections(encoderDirections),
                                     _motorDirections(motorDirections)
{
    MotorControl::init();
}

void Motors::attachEncoders(int e1_l, int e1_r, int e2_l, int e2_r,
                            int e3_l, int e3_r, int e4_l, int e4_r)
{
    // encoders
    encoder1.attachFullQuad(e1_l, e1_r);
    encoder2.attachFullQuad(e2_l, e2_r);
    encoder3.attachFullQuad(e3_l, e3_r);
    encoder4.attachFullQuad(e4_l, e4_r);
}
