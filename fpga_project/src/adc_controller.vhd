library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity adc_controller is
generic (
    PIXELS_HEIGHT : integer;
    PIXELS_WIDTH : integer
);
port(
    clock           : in std_logic;
    adc_data_in     : in std_logic_vector(7 downto 0);
    adc_rd          : out std_logic;
    adc_int         : in std_logic;
    
    adc_data_out    : out std_logic_vector(6 downto 0);
    adc_data_rden   : in std_logic;
    adc_data_addr   : in std_logic_vector(7 downto 0);
    frame_bram_rst  : out std_logic;

    start_drawing   : out std_logic;
    finished_drawing: in std_logic;
    rst_bram_start  : out std_logic;
    rst_bram_complete: in std_logic
);
end entity;

architecture rtl of adc_controller is
constant ADDRESS_WIDTH : integer := 8;
constant DATA_WIDTH    : integer := 7;

-- waiting state counter
signal waiting_state_count : unsigned(16 downto 0) := (others =>'0');
constant t_new_conv : unsigned(16 downto 0)  := to_unsigned(40000, waiting_state_count'length); -- 1/(200MHz/110) = 550ns delay, min = 500ns

signal refresh_state_count : unsigned(31 downto 0) := (others =>'0');
constant t_top_count : unsigned(31 downto 0)  := to_unsigned(10000000, refresh_state_count'length); -- 1/(200MHz/110) = 550ns delay, min = 500ns

type FSM_states is (START_CONV, POLL_CONV, FINISHED_CONV, RESET_DISP, WAITING);
signal adc_state : FSM_states := START_CONV;

type DISP_states is (IDLE, RESET, DRAW, FINISHED);
signal disp_state : DISP_states := IDLE;

signal start_disp_draw : std_logic := '0';
signal finished_disp_draw : std_logic := '0';

-- addr counter 
signal adc_mem_addr_count : unsigned(7 downto 0) := (others => '0');

-- adc data signals
signal adc_data_latch : std_logic_vector(7 downto 0):= (others =>'0');
signal adc_data_unsigned : unsigned(15 downto 0):= (others =>'0');
signal adc_data_mult: unsigned(15 downto 0):= (others =>'0');
signal adc_data_processed : unsigned(6 downto 0):= (others =>'0');

constant sig_pixel_height : unsigned(7 downto 0) := to_unsigned(PIXELS_HEIGHT, 8);
constant sig_pixel_width : unsigned(7 downto 0) := to_unsigned(200, 8);

-- bram dout signals
signal adc_bram_qout    : std_logic_vector(6 downto 0) := (others =>'0'); 
signal adc_bram_rd_clk_en : std_logic := '0';
signal adc_bram_rd_addr : std_logic_vector(ADDRESS_WIDTH - 1 downto 0) := (others =>'0');

-- bram din signals
signal adc_bram_din     : std_logic_vector(6 downto 0) := (others =>'0'); 
signal adc_bram_wr_clk_en : std_logic := '0';
signal adc_bram_wr_addr : std_logic_vector(ADDRESS_WIDTH - 1 downto 0) :=  (others =>'0'); 

signal adc_bram_rst : std_logic := '0';

-- adc interrupt
signal adc_interrupt : std_logic := '0';
begin
    adc_data_out <= adc_bram_qout;
    adc_bram_rd_clk_en <= adc_data_rden;
    adc_bram_rd_addr <= adc_data_addr;

    -- latch the interrupt
    process(adc_int)
    begin
        if(adc_int = '0') then
            adc_interrupt <= '1';
        else
            adc_interrupt <= '0';
        end if;
    end process;

    -- adc controller
    process(clock)
    variable adc_conversion_temp : unsigned (6 downto 0) := (others =>'0');
    begin
        if(rising_edge(clock)) then
            adc_rd <= '1'; -- active low
            adc_bram_din <=  (others =>'0');
            adc_bram_wr_clk_en <= '0';
            frame_bram_rst <= '0';
            start_disp_draw <= '0';

            case(adc_state) is 
                when START_CONV =>
                    adc_rd <= '0';
                    adc_state <= POLL_CONV;
                when POLL_CONV =>
                    if (adc_interrupt = '1')then
                        ADC_state <= FINISHED_CONV;
                    else
                        adc_rd <= '0';
                    end if;
                when FINISHED_CONV =>
                    if (adc_mem_addr_count < sig_pixel_width-1) then
                        adc_conversion_temp := resize(shift_right((unsigned(not adc_data_in) * to_unsigned(PIXELS_HEIGHT, 7)), 8), 7); -- (adc value * total height)/divide by 2^8
                        adc_bram_din <= std_logic_vector(adc_conversion_temp) ; -- divide by 256, 2^8 
                        adc_bram_wr_addr <= std_logic_vector(adc_mem_addr_count);
                       -- write a white pixel
                        adc_bram_wr_clk_en  <= '1'; -- 1 indicates ` white
                        adc_mem_addr_count <= adc_mem_addr_count + 1;
                        ADC_state <= WAITING;
                    else
                        ADC_state <= RESET_DISP; -- reset frame buffer 
                    end if;
                when RESET_DISP => 
                    if (finished_disp_draw = '0') then
                        start_disp_draw <= '1';
                    else
                        adc_state <= START_CONV;
                        adc_mem_addr_count <= (others =>'0'); -- reset counter 
                    end if;
                when WAITING =>
                    if (waiting_state_count < t_new_conv) then
                        waiting_state_count <= waiting_state_count + 1;
                    else
                        waiting_state_count <= (others => '0');
                        ADC_state <= START_CONV;
                    end if;
            end case;
        end if;
    end process;

    -- disp controller
    process(clock)
    begin
        if(rising_edge(clock)) then
            rst_bram_start <= '0';
            start_drawing <= '0'; 
            finished_disp_draw <= '0';
            case (disp_state) is 
                when IDLE =>
                    if (start_disp_draw = '1') then
                        disp_state <= RESET;
                    end if;
                when RESET =>
                    if (rst_bram_complete = '0') then
                        rst_bram_start <= '1';
                    else
                        disp_state <= DRAW;
                    end if;
                when DRAW =>
                    if (finished_drawing = '0') then
                        start_drawing <= '1';
                    else
                        disp_state <= FINISHED;
                    end if;
                when FINISHED =>
                     if (refresh_state_count < t_top_count) then
                        refresh_state_count <= refresh_state_count + 1;
                    else
                        refresh_state_count <= (others => '0');
                        disp_state <= IDLE;
                        finished_disp_draw <= '1';
                    end if;
            end case;
        end if;
    end process;

    -- adc data buffer 
    adc_data_buffer: entity work.dual_adc_bram
    port map (
        -- data in signals
        din     => adc_bram_din,
        clka    => clock,
        cea     => adc_bram_wr_clk_en,
        ada     => adc_bram_wr_addr,
        
        -- data out signasl
        clkb    => clock,
        ceb     => adc_bram_rd_clk_en,
        dout    => adc_bram_qout,
        adb     => adc_bram_rd_addr,
        
        -- unneeded signals
        oce     => '0',
        resetb  => adc_bram_rst,
        reseta  => adc_bram_rst
        );
end architecture;