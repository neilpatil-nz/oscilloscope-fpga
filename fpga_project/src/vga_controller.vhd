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
    lcd_r           : out std_logic_vector(4 downto 0);

    frame_bram_din   : in std_logic;
    frame_bram_wren  : in std_logic;
    frame_bram_addr  : in std_logic_vector(14 downto 0);
    frame_bram_rst   : in std_logic
);
end entity;

architecture rtl of vga_controller is
constant ADDRESS_WIDTH : integer := 15;
constant DATA_WIDTH    : integer := 1; 

-- y constants 
constant y_BackPorch        : integer   := 0;
constant y_Pulse            : integer   := 5;
constant y_Height           : integer   := 480;
constant y_Height_Buffer    : integer   := 120;
constant y_FrontPorch       : integer   := 45;

-- x constants 
constant x_BackPorch        : integer   := 182;
constant x_Pulse            : integer   := 1;
constant x_Width            : integer   := 800;
constant x_Width_Buffer     : integer   := 200;
constant x_FrontPorch       : integer   := 210;

-- hsync top value 
constant HS_Pixel : integer := x_Width + x_FrontPorch + x_BackPorch;

-- vsync top value 
constant VS_Line  : integer := y_Height + y_FrontPorch + y_BackPorch;

-- x and y pixel counters 
signal x_Count : integer range 0 to HS_Pixel := 0;
signal y_Count : integer range 0 to VS_Line := 0;

-- frame bram addressing signals
signal x_Pixel : unsigned(ADDRESS_WIDTH-1 downto 0) := (others =>'0');
signal y_Pixel :unsigned(ADDRESS_WIDTH-1 downto 0) := (others =>'0');

-- output interfacing signals
signal sig_vsync : std_logic := '0';
signal sig_hsync : std_logic := '0';
signal output_lcd : std_logic_vector(5 downto 0) := (others => '0');
signal sig_lcd_enable : std_logic := '0';

-- bram signals
signal bram_qout   : std_logic_vector(0 downto 0) := "0";
signal bram_din   : std_logic_vector(0 downto 0) := "0";
signal bram_wr_clk_en : std_logic := '0';
signal bram_rd_clk_en : std_logic := '1';
signal bram_rst : std_logic := '0';
signal bram_wr_addr : std_logic_vector(ADDRESS_WIDTH - 1 downto 0) :=  (others =>'0'); --synthesis keep
signal bram_rd_addr : std_logic_vector(ADDRESS_WIDTH - 1 downto 0) := (others =>'0');--synthesis keep 

begin
    -- hsync and vysnc gen
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
    
    -- hsync and vsync signals (active low) 
    sig_hsync <= '0' when ((x_Count >= x_Pulse) and x_Count <= (HS_Pixel - x_FrontPorch)) else '1';
    sig_vsync <= '0' when ((y_Count >= y_Pulse) and y_Count <= (VS_Line - 0)) else '1';
    
    -- lcd enable (active high)
    sig_lcd_enable <= '1' when (x_Count >= x_BackPorch and
                      x_Count <= (HS_Pixel - x_FrontPorch) and
                      y_Count >= y_BackPorch and
                      y_Count <= (VS_Line - y_FrontPorch-1)) else '0';

    -- memory addressing
    x_Pixel <=  shift_right(to_unsigned(x_Count-x_BackPorch, x_Pixel'length), 2);
    y_Pixel <=  to_unsigned((to_integer(unsigned(shift_right(to_unsigned(y_Count, y_Pixel'length), 2))) * x_Width_Buffer),  y_Pixel'length);
    
    -- bram signals (din)
    bram_din(0) <= frame_bram_din;
    bram_wr_addr <= frame_bram_addr;
    bram_wr_clk_en <= frame_bram_wren;

    -- bram signals (qout)
    bram_rd_addr <= std_logic_vector(x_Pixel + y_Pixel) when sig_lcd_enable ='1' else (others =>'0');
   
    -- prevent accessing same address
    bram_rd_clk_en <= '1' when (sig_lcd_enable ='1' and bram_wr_clk_en = '0') else '0';
    
    -- reset bram 
    bram_rst <= frame_bram_rst;

    -- framebuffer for display
    dual_port_ram: entity work.dual_bram
    port map (
        dout    => bram_qout,
        clka    => clock,
        cea     => bram_wr_clk_en,
        reseta  => bram_rst,
        clkb    => pixel_clock,
        ceb     => bram_rd_clk_en,
        resetb  => bram_rst,
        ada     => bram_wr_addr,
        din     => bram_din,
        adb     => bram_rd_addr,
        oce     => '0'
    );

    -- output signals
    lcd_hsync <= sig_hsync;
    lcd_vsync <= sig_vsync;

    -- lcd enable
    lcd_enable <= sig_lcd_enable;

    output_lcd <= "111111" when (bram_qout(0) = '1') else "000000";
    
    lcd_b <= output_lcd(4 downto 0);
    lcd_r <= output_lcd(4 downto 0);
    lcd_g <= output_lcd;
    
end architecture;
