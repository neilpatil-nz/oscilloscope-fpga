--Copyright (C)2014-2021 Gowin Semiconductor Corporation.
--All rights reserved.
--File Title: Template file for instantiation
--GOWIN Version: V1.9.7.05Beta
--Part Number: GW1N-LV1QN48C6/I5
--Device: GW1N-1
--Created Time: Sat Jun 18 13:46:11 2022

--Change the instance name and port connections to the signal names
----------Copy here to design--------

component Gowin_rPLL
    port (
        clkout: out std_logic;
        clkoutd: out std_logic;
        clkin: in std_logic
    );
end component;

your_instance_name: Gowin_rPLL
    port map (
        clkout => clkout_o,
        clkoutd => clkoutd_o,
        clkin => clkin_i
    );

----------Copy end-------------------
