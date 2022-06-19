//Copyright (C)2014-2021 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: Template file for instantiation
//GOWIN Version: V1.9.7.05Beta
//Part Number: GW1N-LV1QN48C6/I5
//Device: GW1N-1
//Created Time: Sun Jun 19 17:49:36 2022

//Change the instance name and port connections to the signal names
//--------Copy here to design--------

    dual_bram your_instance_name(
        .dout(dout_o), //output [0:0] dout
        .clka(clka_i), //input clka
        .cea(cea_i), //input cea
        .reseta(reseta_i), //input reseta
        .clkb(clkb_i), //input clkb
        .ceb(ceb_i), //input ceb
        .resetb(resetb_i), //input resetb
        .oce(oce_i), //input oce
        .ada(ada_i), //input [14:0] ada
        .din(din_i), //input [0:0] din
        .adb(adb_i) //input [14:0] adb
    );

//--------Copy end-------------------
