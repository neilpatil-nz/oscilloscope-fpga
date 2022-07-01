--Copyright (C)2014-2022 Gowin Semiconductor Corporation.
--All rights reserved.
--File Title: Template file for instantiation
--GOWIN Version: V1.9.8.05
--Part Number: GW1N-LV1QN48C6/I5
--Device: GW1N-1
--Created Time: Fri Jul 01 15:50:37 2022

--Change the instance name and port connections to the signal names
----------Copy here to design--------

component clock_sel
    port (
        clkout: out std_logic;
        clksel: in std_logic_vector(3 downto 0);
        clk0: in std_logic;
        clk1: in std_logic;
        clk2: in std_logic;
        clk3: in std_logic
    );
end component;

your_instance_name: clock_sel
    port map (
        clkout => clkout_o,
        clksel => clksel_i,
        clk0 => clk0_i,
        clk1 => clk1_i,
        clk2 => clk2_i,
        clk3 => clk3_i
    );

----------Copy end-------------------
