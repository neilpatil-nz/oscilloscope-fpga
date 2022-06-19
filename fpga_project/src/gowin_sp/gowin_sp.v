//Copyright (C)2014-2021 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: IP file
//GOWIN Version: V1.9.7.05Beta
//Part Number: GW1N-LV1QN48C6/I5
//Device: GW1N-1
//Created Time: Sun Jun 19 13:32:37 2022

module Gowin_SP (dout, clk, oce, ce, reset, wre, ad, din);

output [119:0] dout;
input clk;
input oce;
input ce;
input reset;
input wre;
input [7:0] ad;
input [119:0] din;

wire [7:0] sp_inst_3_dout_w;
wire gw_vcc;
wire gw_gnd;

assign gw_vcc = 1'b1;
assign gw_gnd = 1'b0;

SP sp_inst_0 (
    .DO(dout[31:0]),
    .CLK(clk),
    .OCE(oce),
    .CE(ce),
    .RESET(reset),
    .WRE(wre),
    .BLKSEL({gw_gnd,gw_gnd,gw_gnd}),
    .AD({gw_gnd,ad[7:0],gw_gnd,gw_vcc,gw_vcc,gw_vcc,gw_vcc}),
    .DI(din[31:0])
);

defparam sp_inst_0.READ_MODE = 1'b0;
defparam sp_inst_0.WRITE_MODE = 2'b00;
defparam sp_inst_0.BIT_WIDTH = 32;
defparam sp_inst_0.BLK_SEL = 3'b000;
defparam sp_inst_0.RESET_MODE = "SYNC";

SP sp_inst_1 (
    .DO(dout[63:32]),
    .CLK(clk),
    .OCE(oce),
    .CE(ce),
    .RESET(reset),
    .WRE(wre),
    .BLKSEL({gw_gnd,gw_gnd,gw_gnd}),
    .AD({gw_gnd,ad[7:0],gw_gnd,gw_vcc,gw_vcc,gw_vcc,gw_vcc}),
    .DI(din[63:32])
);

defparam sp_inst_1.READ_MODE = 1'b0;
defparam sp_inst_1.WRITE_MODE = 2'b00;
defparam sp_inst_1.BIT_WIDTH = 32;
defparam sp_inst_1.BLK_SEL = 3'b000;
defparam sp_inst_1.RESET_MODE = "SYNC";

SP sp_inst_2 (
    .DO(dout[95:64]),
    .CLK(clk),
    .OCE(oce),
    .CE(ce),
    .RESET(reset),
    .WRE(wre),
    .BLKSEL({gw_gnd,gw_gnd,gw_gnd}),
    .AD({gw_gnd,ad[7:0],gw_gnd,gw_vcc,gw_vcc,gw_vcc,gw_vcc}),
    .DI(din[95:64])
);

defparam sp_inst_2.READ_MODE = 1'b0;
defparam sp_inst_2.WRITE_MODE = 2'b00;
defparam sp_inst_2.BIT_WIDTH = 32;
defparam sp_inst_2.BLK_SEL = 3'b000;
defparam sp_inst_2.RESET_MODE = "SYNC";

SP sp_inst_3 (
    .DO({sp_inst_3_dout_w[7:0],dout[119:96]}),
    .CLK(clk),
    .OCE(oce),
    .CE(ce),
    .RESET(reset),
    .WRE(wre),
    .BLKSEL({gw_gnd,gw_gnd,gw_gnd}),
    .AD({gw_gnd,ad[7:0],gw_gnd,gw_vcc,gw_vcc,gw_vcc,gw_vcc}),
    .DI({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,din[119:96]})
);

defparam sp_inst_3.READ_MODE = 1'b0;
defparam sp_inst_3.WRITE_MODE = 2'b00;
defparam sp_inst_3.BIT_WIDTH = 32;
defparam sp_inst_3.BLK_SEL = 3'b000;
defparam sp_inst_3.RESET_MODE = "SYNC";

endmodule //Gowin_SP
