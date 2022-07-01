--Copyright (C)2014-2022 Gowin Semiconductor Corporation.
--All rights reserved.
--File Title: IP file
--GOWIN Version: V1.9.8.05
--Part Number: GW1N-LV1QN48C6/I5
--Device: GW1N-1
--Created Time: Fri Jul 01 15:50:37 2022

library IEEE;
use IEEE.std_logic_1164.all;

entity clock_sel is
    port (
        clkout: out std_logic;
        clksel: in std_logic_vector(3 downto 0);
        clk0: in std_logic;
        clk1: in std_logic;
        clk2: in std_logic;
        clk3: in std_logic
    );
end clock_sel;

architecture Behavioral of clock_sel is

    signal gw_gnd: std_logic;

    --component declaration
    component DCS
        generic (
            DCS_MODE : STRING := "RISING"
        );
        port (
            CLKOUT: out std_logic;
            CLKSEL: in std_logic_vector(3 downto 0);
            CLK0: in std_logic;
            CLK1: in std_logic;
            CLK2: in std_logic;
            CLK3: in std_logic;
            SELFORCE: in std_logic
        );
    end component;

begin
    gw_gnd <= '0';

    dcs_inst: DCS
        generic map (
            DCS_MODE => "RISING"
        )
        port map (
            CLKOUT => clkout,
            CLKSEL => clksel,
            CLK0 => clk0,
            CLK1 => clk1,
            CLK2 => clk2,
            CLK3 => clk3,
            SELFORCE => gw_gnd
        );

end Behavioral; --clock_sel
