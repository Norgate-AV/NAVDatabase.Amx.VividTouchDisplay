MODULE_NAME='mVividTouchDisplay'    (
                                        dev vdvObject,
                                        dev dvPort
                                    )

(***********************************************************)
#include 'NAVFoundation.ModuleBase.axi'
#include 'NAVFoundation.Math.axi'
/*
 _   _                       _          ___     __
| \ | | ___  _ __ __ _  __ _| |_ ___   / \ \   / /
|  \| |/ _ \| '__/ _` |/ _` | __/ _ \ / _ \ \ / /
| |\  | (_) | | | (_| | (_| | ||  __// ___ \ V /
|_| \_|\___/|_|  \__, |\__,_|\__\___/_/   \_\_/
                 |___/

MIT License

Copyright (c) 2023 Norgate AV Services Limited

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

(***********************************************************)
(*          DEVICE NUMBER DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_DEVICE

(***********************************************************)
(*               CONSTANT DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_CONSTANT

constant long TL_DRIVE    = 1


constant integer STX    = $07
constant integer ETX    = $08
constant integer IDT    = $01
constant integer READ    = $01
constant integer WRITE    = $02
constant integer RESPONSE    = $00

constant integer REQUIRED_POWER_ON    = 1
constant integer REQUIRED_POWER_OFF    = 2

constant integer ACTUAL_POWER_ON    = 1
constant integer ACTUAL_POWER_OFF    = 2

constant integer REQUIRED_INPUT_VGA_1    = 1
constant integer REQUIRED_INPUT_HDMI_1    = 2
constant integer REQUIRED_INPUT_HDMI_2    = 3
constant integer REQUIRED_INPUT_HDMI_3    = 4
constant integer REQUIRED_INPUT_HDMI_4    = 5
constant integer REQUIRED_INPUT_DISPLAYPORT_1    = 6
constant integer REQUIRED_INPUT_IPC_OPS_1    = 7
constant integer REQUIRED_INPUT_HDMI_5    = 8
constant integer REQUIRED_INPUT_MEDIA_PLAYER_1    = 9

constant integer ACTUAL_INPUT_VGA_1    = 1
constant integer ACTUAL_INPUT_HDMI_1    = 2
constant integer ACTUAL_INPUT_HDMI_2    = 3
constant integer ACTUAL_INPUT_HDMI_3    = 4
constant integer ACTUAL_INPUT_HDMI_4    = 5
constant integer ACTUAL_INPUT_DISPLAYPORT_1    = 6
constant integer ACTUAL_INPUT_IPC_OPS_1    = 7
constant integer ACTUAL_INPUT_HDMI_5    = 8
constant integer ACTUAL_INPUT_MEDIA_PLAYER_1    = 9

constant char INPUT_COMMANDS[][NAV_MAX_CHARS]    = { "$00",
                            "$09",
                            "$0A",
                            "$0B",
                            "$0C",
                            "$0D",
                            "$14",
                            "$17",
                            "$18" }

constant integer GET_POWER    = 1
constant integer GET_INPUT    = 2
constant integer GET_MUTE    = 3
constant integer GET_VOLUME    = 4

constant integer REQUIRED_MUTE_ON    = 1
constant integer REQUIRED_MUTE_OFF    = 2

constant integer ACTUAL_MUTE_ON    = 1
constant integer ACTUAL_MUTE_OFF    = 2

constant integer MAX_VOLUME = 100
constant integer MIN_VOLUME = 0

(***********************************************************)
(*              DATA TYPE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_TYPE

(***********************************************************)
(*               VARIABLE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_VARIABLE
volatile _NAVDisplay uDisplay

volatile integer iLoop
volatile integer iPollSequence = GET_POWER

volatile integer iRequiredPower
volatile integer iRequiredInput
volatile integer iRequiredMute
volatile sinteger siRequiredVolume = -1

volatile long ltDrive[] = { 200 }

volatile long ltFeedback[] = { 200 }

volatile integer iSemaphore
volatile char cRxBuffer[NAV_MAX_BUFFER]

volatile integer iModuleEnabled

volatile integer iPowerBusy

volatile integer iCommandBusy
volatile integer iCommandLockOut

volatile integer iID = 1

volatile integer iRebuildReady = false

volatile integer iInputInitialized = false
volatile integer iVolumeInitialized = false

(***********************************************************)
(*               LATCHING DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_LATCHING

(***********************************************************)
(*       MUTUALLY EXCLUSIVE DEFINITIONS GO BELOW           *)
(***********************************************************)
DEFINE_MUTUALLY_EXCLUSIVE

(***********************************************************)
(*        SUBROUTINE/FUNCTION DEFINITIONS GO BELOW         *)
(***********************************************************)
(* EXAMPLE: DEFINE_FUNCTION <RETURN_TYPE> <NAME> (<PARAMETERS>) *)
(* EXAMPLE: DEFINE_CALL '<NAME>' (<PARAMETERS>) *)
define_function SendStringRaw(char cParam[]) {
     NAVErrorLog(NAV_LOG_LEVEL_DEBUG, NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_STRING_TO, dvPort, cParam))
    send_string dvPort,"cParam"
}

define_function SendString(char cParam[]) {
    SendStringRaw("cParam,NAV_CR")
}

define_function Build(integer iType, char cCmd[], char cVal[]) {
    SendString("STX,IDT,iType,cCmd,cVal,ETX")
}

define_function SendQuery(integer iParam) {
    switch (iParam) {
    case GET_POWER: Build(READ, 'POW', '')
    case GET_INPUT: Build(READ, 'MIN', '')
    //case GET_MUTE: SendString("'QAM'")
    case GET_VOLUME: Build(READ, 'VOL', '')
    }
}

define_function TimeOut() {
    cancel_wait 'CommsTimeOut'
    wait 300 'CommsTimeOut' { [vdvObject,DEVICE_COMMUNICATING] = false }
}

define_function SetPower(integer iParam) {
    switch (iParam) {
    case REQUIRED_POWER_ON: { Build(WRITE, 'POW', "$01") }
    case REQUIRED_POWER_OFF: { Build(WRITE, 'POW', "$00") }
    }
}

define_function SetInput(integer iParam) {
    switch (iParam) {
    case REQUIRED_INPUT_VGA_1: { Build(WRITE, 'MIN', "$00") }
    case REQUIRED_INPUT_HDMI_1: { Build(WRITE, 'MIN', "$09") }
    case REQUIRED_INPUT_HDMI_2: { Build(WRITE, 'MIN', "$0A") }
    case REQUIRED_INPUT_HDMI_3: { Build(WRITE, 'MIN', "$0B") }
    case REQUIRED_INPUT_HDMI_4: { Build(WRITE, 'MIN', "$0C") }
    case REQUIRED_INPUT_DISPLAYPORT_1: { Build(WRITE, 'MIN', "$0D") }
    }
}

define_function SetVolume(sinteger siParam) { Build(WRITE, 'VOL', "siParam") }

/*
define_function RampVolume(integer iParam) {
    switch (iParam) {
    case VOL_UP: {
        if (uDisplay.Volume.Level.Actual < MAX_VOLUME) {
        SendString("'AUU'")
        }
    }
    case VOL_DN: {
        if (uDisplay.Volume.Level.Actual > MIN_VOLUME) {
        SendString("'AUD'")
        }
    }
    }
}

define_function SetMute(integer iParam) {
    switch (iParam) {
    case REQUIRED_MUTE_ON: { SendString("'AMT:1'") }
    case REQUIRED_MUTE_OFF: { SendString("'AMT:0'") }
    }
}
*/

define_function Process() {
    stack_var char cTemp[NAV_MAX_BUFFER]
    iSemaphore = true
    while (length_array(cRxBuffer) && NAVContains(cRxBuffer,"ETX")) {
    cTemp = remove_string(cRxBuffer,"ETX",1)
    if (length_array(cTemp)) {
        cTemp = NAVStripCharsFromRight(cTemp, 1)    //Remove ETX
        cTemp = NAVStripCharsFromLeft(cTemp, 2)    //Remove STX, IDT
         NAVErrorLog(NAV_LOG_LEVEL_DEBUG, NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_PARSING_STRING_FROM, dvPort, cTemp))
        switch (get_buffer_char(cTemp)) {
        case RESPONSE: {    //Responses from Screen
            stack_var char cCmd[NAV_MAX_CHARS]
            cCmd = NAVRemoveStringByLength(cTemp, 3)
            switch (cCmd) {
            case 'POW': {
                switch (cTemp[1]) {
                case $00: uDisplay.PowerState.Actual = ACTUAL_POWER_OFF
                case $01: {
                    uDisplay.PowerState.Actual = ACTUAL_POWER_ON
                    select {
                    active (!iVolumeInitialized): {
                        iPollSequence = GET_VOLUME
                    }
                    }
                }
                }

                iPollSequence = GET_INPUT
            }
            case 'MIN': {
                switch (cTemp[1]) {
                case $00: uDisplay.Input.Actual = ACTUAL_INPUT_VGA_1
                case $09: uDisplay.Input.Actual = ACTUAL_INPUT_HDMI_1
                case $0A: uDisplay.Input.Actual = ACTUAL_INPUT_HDMI_2
                case $0B: uDisplay.Input.Actual = ACTUAL_INPUT_HDMI_3
                case $0C: uDisplay.Input.Actual = ACTUAL_INPUT_HDMI_4
                case $0D: uDisplay.Input.Actual = ACTUAL_INPUT_DISPLAYPORT_1
                }

                iInputInitialized = true
                iPollSequence = GET_POWER
            }
            case 'VOL': {
                uDisplay.Volume.Level.Actual = cTemp[1]
                UpdateVolume(uDisplay.Volume.Level.Actual)
                iVolumeInitialized = true
                iPollSequence = GET_POWER
            }
            }
        }
        }
    }
    }

    iSemaphore = false
}

define_function UpdateVolume(sinteger siParam) {
    send_level vdvObject,VOL_LVL,NAVScaleValue(siParam,(MAX_VOLUME - MIN_VOLUME),255,0)
}

define_function Drive() {
    iLoop++
    switch (iLoop) {
    case 1:
    case 6:
    case 11:
    case 16: { SendQuery(iPollSequence); return }
    case 21: { iLoop = 1; return }
    default: {
        if (iCommandLockOut) { return }
        if (iRequiredPower && (iRequiredPower == uDisplay.PowerState.Actual)) { iRequiredPower = 0; return }
        if (iRequiredInput && (iRequiredInput == uDisplay.Input.Actual)) { iRequiredInput = 0; return }
        //if (iRequiredMute && (iRequiredMute == uDisplay.Volume.Mute.Actual)) { iRequiredMute = 0; return }

        if (iRequiredPower && (iRequiredPower != uDisplay.PowerState.Actual) && [vdvObject,DEVICE_COMMUNICATING]) {
        iCommandBusy = true
        SetPower(iRequiredPower)
        iCommandLockOut = true
        wait 80 iCommandLockOut = false
        iPollSequence = GET_POWER
        return
        }

        if (iRequiredInput && (uDisplay.PowerState.Actual == ACTUAL_POWER_ON) && (iRequiredInput != uDisplay.Input.Actual) && [vdvObject,DEVICE_COMMUNICATING]) {
        iCommandBusy = true
        SetInput(iRequiredInput)
        //uDisplay.Input.Actual = iRequiredInput
        iCommandLockOut = true
        wait 30 iCommandLockOut = false
        iPollSequence = GET_INPUT
        return
        }

        /*
        if (iRequiredMute && (uDisplay.PowerState.Actual == ACTUAL_POWER_ON) && (iRequiredMute != uDisplay.Volume.Mute.Actual) && [vdvObject,DEVICE_COMMUNICATING]) {
        iCommandBusy = true
        SetMute(iRequiredMute);
        iCommandLockOut = true
        wait 10 iCommandLockOut = false
        iPollSequence = GET_MUTE;
        return
        }
        */

        if (siRequiredVolume >= 0 && (uDisplay.PowerState.Actual == ACTUAL_POWER_ON) && [vdvObject,DEVICE_COMMUNICATING]) {
        iCommandBusy = true
        SetVolume(siRequiredVolume);
        siRequiredVolume = -1
        //iPollSequence = GET_VOLUME;
        return
        }

        /*
        if ([vdvObject,VOL_UP]) { RampVolume(VOL_UP) }
        if ([vdvObject,VOL_DN]) { RampVolume(VOL_DN) }
        */
    }
    }
}

(***********************************************************)
(*                STARTUP CODE GOES BELOW                  *)
(***********************************************************)
DEFINE_START
create_buffer dvPort,cRxBuffer

iModuleEnabled = true

// Update event tables
rebuild_event()

(***********************************************************)
(*                THE EVENTS GO BELOW                      *)
(***********************************************************)
DEFINE_EVENT
data_event[dvPort] {
    online: {
    if (iModuleEnabled) {
        send_command data.device,"'SET BAUD 115200,N,8,1 485 DISABLE'"
        send_command data.device,"'B9MOFF'"
        send_command data.device,"'CHARD-0'"
        send_command data.device,"'CHARDM-0'"
        send_command data.device,"'HSOFF'"
        NAVTimelineStart(TL_DRIVE,ltDrive,timeline_absolute,timeline_repeat)
    }

    [vdvObject,DEVICE_COMMUNICATING] = true
    [vdvObject,DATA_INITIALIZED] = true
    }
    string: {
    if (iModuleEnabled) {
        [vdvObject,DEVICE_COMMUNICATING] = true
        [vdvObject,DATA_INITIALIZED] = true
        TimeOut()
        // NAVErrorLog(NAV_LOG_LEVEL_DEBUG, NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_STRING_FROM, dvPort, data.text))
        if (!iSemaphore) { Process() }
    }
    }
}

data_event[vdvObject] {
    command: {
    stack_var char cCmdHeader[NAV_MAX_CHARS]
    stack_var char cCmdParam[3][NAV_MAX_CHARS]
    if (iModuleEnabled) {
        NAVErrorLog(NAV_LOG_LEVEL_DEBUG, NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_COMMAND_FROM, data.device, data.text))
        cCmdHeader = DuetParseCmdHeader(data.text)
        cCmdParam[1] = DuetParseCmdParam(data.text)
        cCmdParam[2] = DuetParseCmdParam(data.text)
        cCmdParam[3] = DuetParseCmdParam(data.text)
        switch (cCmdHeader) {
        case 'PROPERTY': {
            switch (cCmdParam[1]) {
            case 'IP_ADDRESS': {
                //cIPAddress = cCmdParam[2]
                //NAVTimelineStart(TL_IP_CHECK,ltIPCheck,timeline_absolute,timeline_repeat)
            }
            case 'ID': {
                //iID = atoi(cCmdParam[2])
            }
            }
        }
        case 'REBUILD': { iRebuildReady = true }
        case 'PASSTHRU': { SendString(cCmdParam[1]) }

        case 'POWER': {
            switch (cCmdParam[1]) {
            case 'ON': { iRequiredPower = REQUIRED_POWER_ON; Drive() }
            case 'OFF': { iRequiredPower = REQUIRED_POWER_OFF; iRequiredInput = 0; Drive() }
            }
        }
        case 'VOLUME': {
            switch (cCmdParam[1]) {
            case 'ABS': {
                siRequiredVolume = atoi(cCmdParam[2]); Drive();
            }
            default: {
                siRequiredVolume = NAVScaleValue(atoi(cCmdParam[1]),255,(MAX_VOLUME - MIN_VOLUME),0); Drive();
            }
            }
        }
        case 'INPUT': {
            switch (cCmdParam[1]) {
            case 'VGA': {
                switch (cCmdParam[2]) {
                case '1': { iRequiredPower = REQUIRED_POWER_ON; iRequiredInput = REQUIRED_INPUT_VGA_1; Drive() }
                }
            }
            case 'HDMI': {
                switch (cCmdParam[2]) {
                case '1': { iRequiredPower = REQUIRED_POWER_ON; iRequiredInput = REQUIRED_INPUT_HDMI_1; Drive() }
                case '2': { iRequiredPower = REQUIRED_POWER_ON; iRequiredInput = REQUIRED_INPUT_HDMI_2; Drive() }
                case '3': { iRequiredPower = REQUIRED_POWER_ON; iRequiredInput = REQUIRED_INPUT_HDMI_3; Drive() }
                case '4': { iRequiredPower = REQUIRED_POWER_ON; iRequiredInput = REQUIRED_INPUT_HDMI_4; Drive() }
                case '5': { iRequiredPower = REQUIRED_POWER_ON; iRequiredInput = REQUIRED_INPUT_HDMI_5; Drive() }
                }
            }
            case 'DISPLAYPORT': {
                switch (cCmdParam[2]) {
                case '1': { iRequiredPower = REQUIRED_POWER_ON; iRequiredInput = REQUIRED_INPUT_DISPLAYPORT_1; Drive() }
                }
            }
            case 'IPC_OPS': {
                switch (cCmdParam[2]) {
                case '1': { iRequiredPower = REQUIRED_POWER_ON; iRequiredInput = REQUIRED_INPUT_IPC_OPS_1; Drive() }
                }
            }
            case 'MEDIA_PLAYER': {
                switch (cCmdParam[2]) {
                case '1': { iRequiredPower = REQUIRED_POWER_ON; iRequiredInput = REQUIRED_INPUT_MEDIA_PLAYER_1; Drive() }
                }
            }
            }
        }
        }
    }
    }
}

channel_event[vdvObject,0] {
    on: {
    if (iModuleEnabled) {
        switch (channel.channel) {
        case POWER: {
            if (iRequiredPower) {
            switch (iRequiredPower) {
                case REQUIRED_POWER_ON: { iRequiredPower = REQUIRED_POWER_OFF; iRequiredInput = 0; Drive() }
                case REQUIRED_POWER_OFF: { iRequiredPower = REQUIRED_POWER_ON; Drive() }
            }
            }else {
            switch (uDisplay.PowerState.Actual) {
                case ACTUAL_POWER_ON: { iRequiredPower = REQUIRED_POWER_OFF; iRequiredInput = 0; Drive() }
                case ACTUAL_POWER_OFF: { iRequiredPower = REQUIRED_POWER_ON; Drive() }
            }
            }
        }
        case PWR_ON: { iRequiredPower = REQUIRED_POWER_ON; Drive() }
        case PWR_OFF: { iRequiredPower = REQUIRED_POWER_OFF; iRequiredInput = 0; Drive() }
        //case PIC_MUTE: { SetShutter(![vdvObject,PIC_MUTE_FB]) }
        /*
        case VOL_MUTE: {
            if (uDisplay.PowerState.Actual == ACTUAL_POWER_ON) {
            if (iRequiredMute) {
                switch (iRequiredMute) {
                case REQUIRED_MUTE_ON: { iRequiredMute = REQUIRED_MUTE_OFF; Drive() }
                case REQUIRED_MUTE_OFF: { iRequiredMute = REQUIRED_MUTE_ON; Drive() }
                }
            }else {
                switch (uDisplay.Volume.Mute.Actual) {
                case ACTUAL_MUTE_ON: { iRequiredMute = REQUIRED_MUTE_OFF; Drive() }
                case ACTUAL_MUTE_OFF: { iRequiredMute = REQUIRED_MUTE_ON; Drive() }
                }
            }
            }
        }
        */
        }
    }
    }
}

timeline_event[TL_DRIVE] { Drive() }

timeline_event[TL_NAV_FEEDBACK] {
    if (iModuleEnabled) {
    //[vdvObject,VOL_MUTE_FB] = (uDisplay.Volume.Mute.Actual == ACTUAL_MUTE_ON)
    [vdvObject,POWER_FB] = (uDisplay.PowerState.Actual == ACTUAL_POWER_ON)
    }
}

(***********************************************************)
(*                     END OF PROGRAM                      *)
(*        DO NOT PUT ANY CODE BELOW THIS COMMENT           *)
(***********************************************************)

