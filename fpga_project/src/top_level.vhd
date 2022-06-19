library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

entity top_level is 
    port(
    CLOCK_IN : in std_logic;
    LED_R     : out std_logic;
    LCD_CLOCK : out std_logic;
    LCD_HSYNC : out std_logic;
    LCD_VSYNC : out std_logic;
    LCD_DEN   : out std_logic;
    LCD_R     : out std_logic_vector(4 downto 0);
    LCD_G     : out std_logic_vector(5 downto 0);
    LCD_B     : out std_logic_vector(4 downto 0)
  
);
    
end entity;


architecture rtl of top_level is

signal disp_clock : std_logic := '0';
signal sys_clock : std_logic := '0';
signal adc_clock : std_logic := '0';


begin
    pll_clock : entity work.Gowin_rPLL
    port map(
        clkout => sys_clock,
        clkoutd => disp_clock, --33.33mhz
        clkin => CLOCK_IN
    );   
    
    LED_R <= disp_clock;
    LCD_CLOCK <= disp_clock;

    display : entity work.vga_controller
    port map(
        pixel_clock => disp_clock,
        clock       => sys_clock,
        lcd_enable  => LCD_DEN,
        lcd_hsync   => LCD_HSYNC,
        lcd_vsync   => LCD_VSYNC,
        lcd_b       => LCD_B,
        lcd_g       => LCD_G,
        lcd_r       => LCD_R
    );

    
    

end architecture;