library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

entity vga_controller is
    port(
    main_clock      : in std_logic; -- 400mhz
    clock           : in std_logic;
    pixel_clock     : in std_logic;

    -- LCD display driver signals
    lcd_enable      : out std_logic;
    lcd_hsync       : out std_logic;
    lcd_vsync       : out std_logic;
    lcd_b           : out std_logic_vector(4 downto 0);
    lcd_g           : out std_logic_vector(5 downto 0);
    lcd_r           : out std_logic_vector(4 downto 0);
    
    -- writing to frame buffer signals
    frame_bram_din   : in std_logic;
    frame_bram_wren  : in std_logic;
    frame_bram_addr  : in std_logic_vector(14 downto 0);
    frame_bram_rst   : in std_logic;

    -- reset frame buffer signals
    rst_bram_start  : in std_logic;
    rst_bram_complete: out std_logic
);
end entity;

architecture rtl of vga_controller is
-- frame buffer constants 
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

-- colour signals
constant COLOUR_NUM_WIDTH : integer := 2;
constant COLOUR_DATA_WIDTH : integer := 6;

-- signal and grid colour control signals
constant signal_lcd : std_logic_vector(COLOUR_NUM_WIDTH - 1 downto 0) := "01";
constant grid_lcd : std_logic_vector(COLOUR_NUM_WIDTH - 1 downto 0) := "10";

-- grid line enable signals 
signal grid_line_y_en : std_logic := '0';
signal grid_line_x_en : std_logic := '0';

-- x and y pixel counters 
signal x_Count : integer range 0 to HS_Pixel := 0;
signal y_Count : integer range 0 to VS_Line := 0;

-- frame bram addressing signals
signal x_Pixel : unsigned(ADDRESS_WIDTH-1 downto 0) := (others =>'0');
signal y_Pixel :unsigned(ADDRESS_WIDTH-1 downto 0) := (others =>'0');

-- output interfacing signals
signal sig_vsync : std_logic := '0';
signal sig_hsync : std_logic := '0';
signal output_lcd : std_logic_vector(COLOUR_NUM_WIDTH-1 downto 0) := (others => '0');
signal sig_lcd_enable : std_logic := '0';

-- frame buffer bram signals (write)
signal bram_wr_addr : std_logic_vector(ADDRESS_WIDTH - 1 downto 0) :=  (others =>'0'); 
signal bram_wr_clk_en : std_logic := '0';
signal bram_din   : std_logic_vector(0 downto 0) := "0";
signal bram_wr_clk : std_logic := '0';

-- frame buffer bram signals (read)
signal bram_rd_clk_en : std_logic := '1';
signal bram_rd_addr : std_logic_vector(ADDRESS_WIDTH - 1 downto 0) := (others =>'0');
signal bram_qout   : std_logic_vector(0 downto 0) := "0";

-- reset bram signal (set low permanently)
signal bram_rst : std_logic := '0';

-- used for clock select (UNUSED)
-- signal bram_wr_clk_sel : std_logic_vector(3 downto 0) := (others =>'0');

-- frame bram reset signals
signal rst_frame_buffer_count : unsigned(14 downto 0) := (others => '0');
signal rst_data_addr          : std_logic_vector(14 downto 0) := (others => '0');
constant rst_frame_buffer_top : unsigned(14 downto 0) := to_unsigned(24000,rst_frame_buffer_count'length) - 1;
signal rst_data_wren          : std_logic := '0';
signal rst_data_out           : std_logic := '0';

-- reset controller states 
type RST_states is (IDLE, RESETTING, INCREMENT_ADD, FINISHED);
signal rst_state : RST_states := IDLE;

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
        
    grid_line_y_en <= '1' when y_Count >= 60 and y_Count < 62 else -- 5V
                    '1' when y_Count >= 120 and y_Count < 122 else -- 4.375V
                    '1' when y_Count >= 180 and y_Count < 182 else -- 3.75V
                    '1' when y_Count >= 240 and y_Count < 242 else -- 3.125V
                    '1' when y_Count >= 300 and y_Count < 302 else -- 2.5V
                    '1' when y_Count >= 360 and y_Count < 362 else -- 1.875V 
                    '1' when y_Count >= 420 and y_Count < 422 else -- 1.25V
                    '1' when y_Count >= 480 and y_Count < 482 else -- 0.625V
                    '0';                                           -- 0V

    grid_line_x_en <= '1' when (x_Count >= x_BackPorch and x_Count >= 200+x_BackPorch and x_Count < 202+x_BackPorch) else 
                      '1' when (x_Count >= x_BackPorch and x_Count >= 400+x_BackPorch and x_Count < 402+x_BackPorch) else 
                      '1' when (x_Count >= x_BackPorch and x_Count >= 600+x_BackPorch and x_Count < 602+x_BackPorch) else 
                      '1' when (x_Count >= x_BackPorch and x_Count >= 800+x_BackPorch and x_Count < 802+x_BackPorch) else 
                      '0';

    -- bram signals (din)
    bram_din(0) <= rst_data_out when rst_data_wren = '1' else frame_bram_din;
    bram_wr_addr <= rst_data_addr when rst_data_wren = '1' else frame_bram_addr;
    bram_wr_clk_en <= frame_bram_wren or rst_data_wren;
    bram_wr_clk_sel <= "0010" when rst_data_wren = '1' else "0001";

    -- bram signals (qout)
    bram_rd_addr <= std_logic_vector(x_Pixel + y_Pixel) when sig_lcd_enable ='1' else (others =>'0');
   
    -- prevent accessing same address
    bram_rd_clk_en <= '1' when (sig_lcd_enable ='1' AND rst_data_wren = '0') else '0';
    
    -- reset bram 
    bram_rst <= '0';
    
    -- framebuffer for display
    dual_port_ram: entity work.dual_bram
    port map (
        dout    => bram_qout,
        clka    => bram_wr_clk,
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

--    multiplexing between clocks(unused)
--    clock_sel: entity work.clock_sel
--    port map (
--        clkout => bram_wr_clk,
--        clksel => bram_wr_clk_sel,
--        clk0 => clock,     
--        clk1 => main_clock,
--        clk2 => '0',
--        clk3 => '0'
--    );

    -- frame buffer reset controller
    process(clock)
    begin
        if(rising_edge(clock)) then
            case (rst_state) is 
                when IDLE =>
                    if (rst_bram_start = '1') then
                        rst_state <= RESETTING; 
                    else
                        rst_frame_buffer_count <= (others =>'0');
                        rst_data_wren <= '0';
                        rst_bram_complete <= '0';
                    end if;
                when RESETTING =>
                    if (rst_frame_buffer_count < rst_frame_buffer_top) then
                        rst_data_addr <= std_logic_vector(rst_frame_buffer_count);  
                        rst_data_out  <= '0'; -- clear: 0 indicates black
                        rst_data_wren <= '1';
                        rst_bram_complete <= '0';
                        rst_state <= INCREMENT_ADD;
                    else 
                        rst_state <= FINISHED;
                    end if;
                when INCREMENT_ADD =>
                    rst_frame_buffer_count <= rst_frame_buffer_count + 1;
                    rst_state <= RESETTING; 
                when FINISHED =>
                    rst_bram_complete <= '1';
                    rst_data_wren <= '0';
                    rst_state <= IDLE;
            end case;
        end if;
    end process;


    -- output signals
    lcd_hsync <= sig_hsync;
    lcd_vsync <= sig_vsync;

    -- lcd enable
    lcd_enable <= sig_lcd_enable;

    output_lcd <= signal_lcd when (bram_qout(0) = '1') else 
                  grid_lcd when grid_line_y_en = '1' or grid_line_x_en = '1' else "00";

    lcd_r <= "00011" when output_lcd = grid_lcd else "00000";
    lcd_g <= "100000" when output_lcd = signal_lcd else -- green colour signal
             "000011" when output_lcd = grid_lcd else "000000"; -- grey colour grid line
    lcd_b <= "00011" when output_lcd = grid_lcd else "00000";
    
end architecture;
