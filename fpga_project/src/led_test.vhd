library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

entity test_led is
    port(
    clock           : in std_logic;
    pixel_clock     : in std_logic;

    lcd_enable      : out std_logic;
    lcd_hsync       : out std_logic;
    lcd_vsync       : out std_logic;

    lcd_b           : out std_logic;
    lcd_g           : out std_logic;
    lcd_r           : out std_logic;
);
end entity;

architecture rtl of test_led is
constant y_BackPorch : integer  := 0;
constant y_Pulse : integer      := 5;
constant y_Height : integer     := 480;
constant y_FrontPorch : integer := 45;

constant x_BackPorch : integer  := 182;
constant x_Pulse : integer      := 1;
constant x_Width : integer     := 800;
constant x_FrontPorch : integer := 210;

constant HS_Pixel : integer := x_Width + x_FrontPorch + x_BackPorch;
constant VS_Line  : integer := y_Height + y_FrontPorch + y_BackPorch;

begin

end architecture;
