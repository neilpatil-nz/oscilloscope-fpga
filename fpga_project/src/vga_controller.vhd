library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

entity vga_controller is
    port(
    clock           : in std_logic;
    pixel_clock     : in std_logic;

    lcd_enable      : out std_logic;
    lcd_hsync       : out std_logic;
    lcd_vsync       : out std_logic;

    lcd_b           : out std_logic_vector(4 downto 0);
    lcd_g           : out std_logic_vector(5 downto 0);
    lcd_r           : out std_logic_vector(4 downto 0)
);
end entity;

architecture rtl of vga_controller is
constant ADDRESS_WIDTH : integer := 15; --synthesis keep
constant DATA_WIDTH    : integer := 1; --synthesis keep

constant y_BackPorch : integer  := 0;
constant y_Pulse : integer      := 5;
constant y_Height : integer     := 480;
constant y_Height_Partial : integer     := 120;
constant y_FrontPorch : integer := 45;

constant x_BackPorch : integer  := 182;
constant x_Pulse : integer      := 1;
constant x_Width : integer     := 800;
constant x_Width_Partial : integer     := 200;
constant x_FrontPorch : integer := 210;

constant HS_Pixel : integer := x_Width + x_FrontPorch + x_BackPorch;
constant VS_Line  : integer := y_Height + y_FrontPorch + y_BackPorch;

signal x_Count : integer range 0 to HS_Pixel := 0;
signal y_Count : integer range 0 to VS_Line := 0;
signal sig_Count : integer range 0 to 200 := 10;
signal sig_H_count : integer range 0 to 200 := 0;
signal sig_Vsync : std_logic;
signal sig_Hsync : std_logic;
signal output_lcd : std_logic_vector(5 downto 0);
signal x_Pixel : unsigned(ADDRESS_WIDTH-1 downto 0) := (others =>'0');
signal y_Pixel :unsigned(ADDRESS_WIDTH-1 downto 0) := (others =>'0');

-- bram signals
signal ram_q   : std_logic_vector(0 downto 0) := "0";
signal ram_wr_clk_en : std_logic := '0';
signal ram_rd_clk_en : std_logic := '1';
signal ram_reset : std_logic := '0';
signal ram_wr_address : std_logic_vector(ADDRESS_WIDTH - 1 downto 0) :=  (others =>'0'); --synthesis keep
signal ram_rd_address : std_logic_vector(ADDRESS_WIDTH - 1 downto 0) := (others =>'0');--synthesis keep 

begin
    -- hsync and vysnc 
    process(pixel_clock)
    begin
        if (rising_edge(pixel_clock)) then
            if( x_Count = HS_Pixel) then
                x_Count <= 0;
                y_Count <= y_Count + 1;
            elsif( y_Count = VS_Line) then
                x_Count <= 0;
                y_Count <= 0;
            else 
                x_Count <= x_Count + 1;
            end if;
        end if;
    end process;
    
    -- active low 
    lcd_hsync <= sig_Hsync;
    sig_Hsync <= '0' when ((x_Count >= x_Pulse) and x_Count <= (HS_Pixel - x_FrontPorch)) else '1';
    lcd_vsync <= sig_Vsync;
    sig_Vsync <= '0' when ((y_Count >= y_Pulse) and y_Count <= (VS_Line - 0)) else '1';

    lcd_enable <= '1' when (x_Count >= x_BackPorch and
                  x_Count <= (HS_Pixel - x_FrontPorch) and
                  y_Count >= y_BackPorch and
                  y_Count <= (VS_Line - y_FrontPorch-1)) else '0';

    output_lcd <= "111111" when (ram_q(0) = '1') else "000000";

    lcd_b <= output_lcd(4 downto 0);
    lcd_r <= output_lcd(4 downto 0);
    lcd_g <= output_lcd;

    -- memory address
    x_Pixel <=  shift_right(to_unsigned(x_Count-x_BackPorch, x_Pixel'length), 2);
    y_Pixel <=  to_unsigned((to_integer(unsigned(shift_right(to_unsigned(y_Count, y_Pixel'length), 2))) * x_Width_Partial),  y_Pixel'length);
    
    ram_rd_address <= std_logic_vector(x_Pixel + y_Pixel) when lcd_enable ='1' else (others =>'0');
    ram_rd_clk_en <= '1' when lcd_enable ='1' else '0';
                                                            
    -- framebuffer for display
    dual_port_ram: entity work.dual_bram
    port map (
        dout => ram_q,
        clka => clock,
        cea => ram_wr_clk_en,
        reseta => ram_reset,
        clkb => pixel_clock,
        ceb => ram_rd_clk_en,
        resetb => ram_reset,
        ada => ram_wr_address,
        din => ram_q,
        adb => ram_rd_address,
        oce => '0'
    );
    
end architecture;
