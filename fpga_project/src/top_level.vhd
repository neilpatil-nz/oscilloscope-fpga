-- Oscilloscope FPGA Project
-- Name: Neil Patil
-- Date: 2022
library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

entity top_level is 
    port(
    CLOCK_IN : in std_logic;
    
    -- lcd signals
    LCD_CLOCK : out std_logic;
    LCD_HSYNC : out std_logic;
    LCD_VSYNC : out std_logic;
    LCD_DEN   : out std_logic;
    LCD_R     : out std_logic_vector(4 downto 0);
    LCD_G     : out std_logic_vector(5 downto 0);
    LCD_B     : out std_logic_vector(4 downto 0);
    
    -- flash adc signals
    ADC_DATA      : in std_logic_vector(7 downto 0);
    ADC_RD        : out std_logic;
    ADC_INT       : in std_logic
);
end entity;

architecture rtl of top_level is
-- clock signals
signal disp_clock : std_logic := '0';
signal sys_clock : std_logic := '0';
signal main_clock : std_logic := '0';

-- adc to line draw signals
signal adc_data_out : std_logic_vector(6 downto 0) := (others =>'0');
signal adc_data_wren: std_logic := '0';
signal adc_data_addr : std_logic_vector(7 downto 0) := (others =>'0');
signal start_drawing   : std_logic := '0';
signal finished_drawing  : std_logic := '0';

-- line draw to frame buffer signals
signal frame_bram_din : std_logic := '0';
signal frame_bram_wren : std_logic := '0';
signal frame_bram_addr : std_logic_vector(14 downto 0) := (others =>'0');
signal frame_bram_rst : std_logic := '0';

-- frame buffer reset handshaking signals
signal rst_bram_start : std_logic := '0';
signal rst_bram_complete  : std_logic := '0';
begin
    pll_clock : entity work.Gowin_rPLL
    port map(
        clkout => main_clock, --400mhz
        clkoutd => disp_clock, --33.33mhz
        clkoutd3 => sys_clock, --133.3mhz
        clkin => CLOCK_IN
    );   
    
    LCD_CLOCK <= disp_clock;
    
    -- display component 
    display : entity work.vga_controller
    port map(
        main_clock => main_clock,
        pixel_clock => disp_clock,
        clock       => sys_clock,
        lcd_enable  => LCD_DEN,
        lcd_hsync   => LCD_HSYNC,
        lcd_vsync   => LCD_VSYNC,
        lcd_b       => LCD_B,
        lcd_g       => LCD_G,
        lcd_r       => LCD_R,
        frame_bram_din => frame_bram_din,
        frame_bram_wren => frame_bram_wren, 
        frame_bram_addr => frame_bram_addr,
        frame_bram_rst => frame_bram_rst,

        rst_bram_start => rst_bram_start, 
        rst_bram_complete => rst_bram_complete
    );

    -- adc component 
    adc : entity work.adc_controller
    generic map(
        PIXELS_HEIGHT => 120,
        PIXELS_WIDTH => 200
    )
    port map(
        clock => sys_clock,

        -- flash to adc controller signals
        adc_data_in => ADC_DATA,
        adc_rd => ADC_RD,
        adc_int => ADC_INT,

        -- adc controller to line draw
        adc_data_out => adc_data_out,
        adc_data_rden => adc_data_wren,
        adc_data_addr => adc_data_addr,
        start_drawing  => start_drawing,
        finished_drawing => finished_drawing,

        -- bram reset controller
        rst_bram_start => rst_bram_start, 
        rst_bram_complete => rst_bram_complete
    );

    -- line draw controller component 
    line_draw : entity work.line_drawer
    port map(
        clock => sys_clock,

        -- adc to line draw
        adc_data_in => adc_data_out,
        adc_data_wren => adc_data_wren,
        adc_data_addr => adc_data_addr,
        start_drawing  => start_drawing,
        finished_drawing => finished_drawing,

        -- line draw to bram
        frame_bram_out  => frame_bram_din,
        frame_bram_wren  => frame_bram_wren,
        frame_bram_addr  => frame_bram_addr
    );
end architecture;