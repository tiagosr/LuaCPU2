#include "Vcpu_tb.h"
#include <verilated.h>
#include <verilated_vcd_c.h>

int main(int argc, char** argv, char** env) {
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);
    Vcpu_tb* tb = new Vcpu_tb;

    VerilatedVcdC* tfp = new VerilatedVcdC;
    tb->trace(tfp, 99);
    tfp->open("trace.vcd");

    while (!Verilated::gotFinish()) {
        tb->eval();
        if (tfp) tfp->dump(Verilated::time());
        Verilated::timeInc(5);
    }

    tfp->close();
    delete tb;
    delete tfp;
    return 0;
}
