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

int main(void) {
    streaming chan enteringChannel;
    chan exitingChannel;
    SpdifTransmitPortConfig(outputPort, clockblock, masterClockPort);
    par {
        clockGen();
        SpdifReceive(inputPort, enteringChannel, 1, clockblock);
        handleSamples(enteringChannel, exitingChannel);
        SpdifTransmit(outputPort, exitingChannel);
    }
    return 0;
}
