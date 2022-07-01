--Copyright (C)2014-2022 Gowin Semiconductor Corporation.
--All rights reserved.
--File Title: Template file for instantiation
--GOWIN Version: V1.9.8.05
--Part Number: GW1N-LV1QN48C6/I5
--Device: GW1N-1
--Created Time: Thu Jun 30 16:22:16 2022

--Change the instance name and port connections to the signal names
----------Copy here to design--------

component Gowin_OSC
    port (
        oscout: out std_logic
    );
end component;

your_instance_name: Gowin_OSC
    port map (
        oscout => oscout_o
    );

----------Copy end-------------------
