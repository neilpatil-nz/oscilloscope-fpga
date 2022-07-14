--Copyright (C)2014-2022 Gowin Semiconductor Corporation.
--All rights reserved.
--File Title: Template file for instantiation
--GOWIN Version: V1.9.8.05
--Part Number: GW1N-LV1QN48C6/I5
--Device: GW1N-1
--Created Time: Fri Jul 08 20:22:02 2022

--Change the instance name and port connections to the signal names
----------Copy here to design--------

component dual_adc_bram
    port (
        dout: out std_logic_vector(6 downto 0);
        clka: in std_logic;
        cea: in std_logic;
        reseta: in std_logic;
        clkb: in std_logic;
        ceb: in std_logic;
        resetb: in std_logic;
        oce: in std_logic;
        ada: in std_logic_vector(7 downto 0);
        din: in std_logic_vector(6 downto 0);
        adb: in std_logic_vector(7 downto 0)
    );
end component;

your_instance_name: dual_adc_bram
    port map (
        dout => dout_o,
        clka => clka_i,
        cea => cea_i,
        reseta => reseta_i,
        clkb => clkb_i,
        ceb => ceb_i,
        resetb => resetb_i,
        oce => oce_i,
        ada => ada_i,
        din => din_i,
        adb => adb_i
    );

----------Copy end-------------------
