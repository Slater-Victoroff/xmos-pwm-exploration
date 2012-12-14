#include <xs1.h>
#include <stdio.h>
#include "SpdifReceive.h"
#include "SpdifTransmit.h"

#define LOCAL_CLOCK_INCREMENT 166667

buffered in port:4 inputPort = XS1_PORT_1C;
in port masterClockPort = XS1_PORT_1D;
buffered out port:32 outputPort = XS1_PORT_1L;
out port p_pll_clk = XS1_PORT_4E;
out port p_aud_cfg = XS1_PORT_4A;

clock clockblock = XS1_CLKBLK_1;

//This function checks the 4 LSBs to see if they are equal to 5, if they are it 
//removes the 4 MSBs and then writes the remaining useful 24 bits to either the
//right or the left. In theory it then also writes to the exiting channel.
void handleSamples(streaming chanend enteringChannel, chanend exitingChannel) {
    int v, left, right;
    while(1) {
        enteringChannel :> v;
        if((v & 0xF) == FRAME_Y) {
            right = (v & ~0xf) << 4;
            exitingChannel <: right;
        } else {
            left = (v & ~0xf) << 4;
            exitingChannel <: left;
        }
    }
}

//This makes a master clock.
void clockGen() {
   unsigned pinVal = 0;
   timer t;
   unsigned time;
   t :> time;
   p_aud_cfg <: 0;
   p_pll_clk <: pinVal;

   while(1) {
      t when timerafter(time) :> void;
      pinVal = !pinVal;
      p_pll_clk <: pinVal;
      time += LOCAL_CLOCK_INCREMENT;
   }
}

//This function is currently an attempt to take the mandatory clock we have for
//the spdif receive function and write it to a channel so that we may then
//use the same clock for the transmit spdif without breaking the whole
//synchronicity thing.
void receiveSpdif(streaming chanend enteringChannel, clock clockblock, chanend clockchannel){
	SpdifReceive(inputPort, enteringChannel, 1, clockblock);
	clockblock <: clockchannel;
}
	
//This function is used to configure the output port and then to 
//actually output the provided channel on the output port.
void transmitSpdif(chanend exitingChannel, chanend clockchannel) {
    SpdifTransmitPortConfig(outputPort, clockchannel, masterClockPort);
    SpdifTransmit(outputPort, exitingChannel);
}

//Doesn't currently work now. The issue being that we are trying to get some kind
//of clock between the receiving and transmitting to ensure that both the transmit
//and receive functions for spdif well... work.
int main(void) {
    streaming chan enteringChannel;
    chan exitingChannel;
    chan clockchannel;
    clockGen();
    par {
        receiveSpdif(enteringChannel, clockblock, clockchannel);
        handleSamples(enteringChannel, exitingChannel);
        transmitSpdif(exitingChannel, clockchannel);
    }
    return 0;
}
