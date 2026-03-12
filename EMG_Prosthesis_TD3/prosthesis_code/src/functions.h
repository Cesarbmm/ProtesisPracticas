/*
Functions with combined functionality for the prosthesis.


Laboratorio de Inteligencia y Visión Artificial
ESCUELA POLITÉCNICA NACIONAL
Quito - Ecuador

autor: Jonathan Zea
jonathan.a.zea@ieee.org

"I find that I don't understand things unless I try to program them."
-Donald E. Knuth

11 / 12 / 2023
*/

#include <Arduino.h>
#include "definitions.h"
#include "communications.h"
#include <Motors.h>

/// \brief waits the remaining time from the given ammount since the last call.
// Last call remember from ``tiempo`` variable.
/// \note probably, not the best interface. Used this way to allow communications.
void wait_listen_motors(int32_t pauseMs, Motors *mot)
// /////////////////////////////////////
{
    do
    {
        // check motors stopping conditions on lims
        for (uint8_t i = 0; i < 4; i++)
        {
            if (mot->danger_zone[i] && mot->dirs[i] == Motors::Direction::FORWARDING)
            { // if in danger zone and going forward
                mot->danger_zone[i] = false;
                mot->stop(i + 1);
                send_msg("Stopping: " + String(i + 1) + " due to danger zone");
                continue;
            }

            if (mot->neg_zone[i] && mot->dirs[i] == Motors::Direction::BACKWARDING)
            { // if in negative zone and going backward
                mot->neg_zone[i] = false;
                mot->stop(i + 1);
                send_msg("Stopping: " + String(i + 1) + " due to negative zone");
                continue;
            }
        }

    } while (millis() - tiempo < pauseMs);
    tiempo = millis();
}
