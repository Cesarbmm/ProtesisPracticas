# Rreward function calculation
The reward function evaluates the performance of the agent's action by assigning ìt an scalar reward.

The reward is calculated using the ``motor data`` (i.e. prosthesis) and the ``glove data`` (i.e. hand of the user). 

## Homogenization
Homogenization is refered to the process of unifying the prosthesis and the flexion glove units.


``` mermaid
---
title: Homogenization between the prosthesis encoder motors and the sensors of the flexion glove
---

  stateDiagram
    direction LR
    classDef input : font-weight:bold, stroke-width:2px,stroke:yellow

    motor : prosthesis
    glove_data : flexion glove
    reward_calculation : reward function

    state motor{
        encoder: Encoders
        encoder2flex: encoder2flex
        encoder --> encoder2flex: m-by-4 at 10 Hz
        
    

        note left of encoder
            The prosthesis has 4 motors:
            # 1000:1 gear ratio
            1) little (little and ring finger)
            # 298:1 gear ratio
            2) index
            3) thumb
            4) middle

            The position of each motor is 
            captured with a magnetic,
            diferential & relative
            encoder.
        end note

        note left of encoder2flex
            Function that converts the motor data
            using 3 zones:
            gap - 
            lineal - 
            break - 
        end note
    }
    
    
    state glove_data{
        glove: flexion sensors
        reduceFlexDimension: reduceFlexDimension
        glove --> reduceFlexDimension: n-by-1 [struct] at 100 Hz

        note left of glove
            The flexion glove has 9 
            flexion sensors
            thumb: 1
            index: 2
            middle: 2
            ring: 2
            little: 2
        end note
       
        note left of reduceFlexDimension
            Function that converts the fileds of the glove
            by adding the values of the sensors of the same
            finger.
        end note
    }


        
        encoder2flex --> flexJoined_scale1 : m-by-4
        reduceFlexDimension --> flexJoined_scale2 : n-by-4

    

    state reward_calculation{
        reward_function : reward calculation
        flexJoined_scale1: flexJoined_scaler
        flexJoined_scale2: flexJoined_scaler
        
        
        flexJoined_scale1 --> reward_function
        flexJoined_scale2 --> reward_function
        
        note left of reward_function
            Currently, only uses the
            the most recent values
        end note
    }

    
    reward_function --> [*]

    class glove, encoder input


```
