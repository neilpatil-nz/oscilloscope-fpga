--Copyright (C)2014-2021 Gowin Semiconductor Corporation.
--All rights reserved.
--File Title: IP file
--GOWIN Version: V1.9.7.05Beta
--Part Number: GW1N-LV1QN48C6/I5
--Device: GW1N-1
--Created Time: Sat Jun 18 13:48:23 2022

library IEEE;
use IEEE.std_logic_1164.all;

entity Gowin_OSC is
    port (
        oscout: out std_logic
    );
end Gowin_OSC;

architecture Behavioral of Gowin_OSC is

    --component declaration
    component OSCH
        generic (
            FREQ_DIV: in integer := 96
        );
        port (
            OSCOUT: out std_logic
        );
    end component;

begin
    osc_inst: OSCH
        generic map (
            FREQ_DIV => 10
        )
        port map (
            OSCOUT => oscout
        );

end Behavioral; --Gowin_OSC
