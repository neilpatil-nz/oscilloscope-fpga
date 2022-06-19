library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

entity top_level is 
    port(
    CLOCK_IN : in std_logic;
    LCD_CLOCK : out std_logic;
    LCD_HSYNC : out std_logic;
    LCD_VSYNC : out std_logic;
    LCD_DEN   : out std_logic;
    LCD_R     : out std_logic_vector(4 downto 0);
    LCD_G     : out std_logic_vector(5 downto 0);
    LCD_B     : out std_logic_vector(4 downto 0);
    
    -- flash adc signals
    ADC_DATA      : in std_logic_vector(7 downto 0);
    ADC_WR_RDY    : in std_logic;
    ADC_RD        : out std_logic;
    ADC_CS        : out std_logic;
    ADC_INT       : in std_logic
);
    
end entity;


architecture rtl of top_level is

signal disp_clock : std_logic := '0';
signal sys_clock : std_logic := '0';
signal adc_clock : std_logic := '0';

-- adc to frame buffer signals
signal frame_bram_din : std_logic := '0';
signal frame_bram_wren : std_logic := '0';
signal frame_bram_addr : std_logic_vector(14 downto 0) := (others =>'0');
signal frame_bram_rst : std_logic := '0';

begin
    pll_clock : entity work.Gowin_rPLL
    port map(
        clkout => sys_clock,
        clkoutd => disp_clock, --33.33mhz
        clkin => CLOCK_IN
    );   
    
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
   

    adc : entity work.adc_controller
    generic map(
        PIXELS_HEIGHT => 120,
        PIXELS_WIDTH => 200
    )
    port map(
        clock => sys_clock,

        adc_data_in => ADC_DATA,
        adc_wr_rdy => ADC_WR_RDY,
        adc_rd => ADC_RD,
        adc_cs => ADC_CS,
        adc_int => ADC_INT,

        adc_data_out => frame_bram_din,
        adc_data_wren => frame_bram_wren,
        adc_data_addr => frame_bram_addr,
        frame_bram_rst => frame_bram_rst
    );


    
    

end architecture;