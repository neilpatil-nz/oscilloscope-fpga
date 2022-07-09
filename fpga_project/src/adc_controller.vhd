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
    adc_data_wren   : in std_logic;
    adc_data_addr   : in std_logic_vector(7 downto 0);
    frame_bram_rst  : out std_logic;

    start_drawing   : out std_logic
    -- rst_bram_start  : out std_logic;
    -- rst_bram_complete: in std_logic
);
end entity;

architecture rtl of adc_controller is
constant ADDRESS_WIDTH : integer := 8;
constant DATA_WIDTH    : integer := 7;

-- waiting state counter (controls sampling rate/f)
constant t_new_conv : integer := 200000; -- 1/(200MHz/110) = 550ns delay, min = 500ns
signal waiting_state_count : integer := 0;

type FSM_states is (START_CONV, POLLING_CONV, FINISHED_CONV, UPDATE_DISPLAY, WAITING);
signal adc_state : FSM_states := START_CONV;

signal adc_mem_addr_count : unsigned(7 downto 0) := (others => '0');
signal adc_data_unsigned : unsigned(7 downto 0):= (others =>'0');
signal adc_data_temp : unsigned(6 downto 0):= (others =>'0');
signal adc_interrupt : std_logic := '0';

-- bram signals
signal adc_bram_qout    : std_logic_vector(6 downto 0) := (others =>'0'); 
signal adc_bram_din     : std_logic_vector(6 downto 0) := (others =>'0'); 

signal adc_bram_wr_clk_en : std_logic := '0';
signal adc_bram_rd_clk_en : std_logic := '1';
signal adc_bram_rst : std_logic := '0';
signal adc_bram_wr_addr : std_logic_vector(ADDRESS_WIDTH - 1 downto 0) :=  (others =>'0'); 
signal adc_bram_rd_addr : std_logic_vector(ADDRESS_WIDTH - 1 downto 0) := (others =>'0');
signal adc_bram_wr_clk : std_logic := '0';

begin
    -- adc data buffer signals
    adc_data_out <= adc_bram_qout;
    adc_bram_rd_clk_en <= adc_data_wren;
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
    
    -- process adc data
    adc_data_unsigned <= unsigned(not adc_data_in);
    adc_data_temp <= resize(shift_right((adc_data_unsigned * to_unsigned(PIXELS_HEIGHT, 7)), 8), 7);

    -- adc controller
    process(clock)  
    variable adc_conversion_temp : unsigned (6 downto 0) := (others =>'0');
    begin
        if(rising_edge(clock)) then
            adc_rd <= '1'; -- active low
            adc_bram_din <= (others =>'0');
            adc_bram_wr_clk_en <= '0';
            frame_bram_rst <= '0';
            -- control signals with reset in vga
            -- rst_bram_start <= '0';
            start_drawing <= '1';    
            case(adc_state) is 
                when START_CONV =>
                    adc_rd <= '0';
                    adc_state <= POLLING_CONV;
                when POLLING_CONV =>
                    if (adc_interrupt = '1')then
                        ADC_state <= FINISHED_CONV;
                    else
                        adc_rd <= '0';
                    end if;
                when FINISHED_CONV =>
                    if (adc_mem_addr_count < to_unsigned(200,adc_mem_addr_count'length)) then
                        adc_bram_wr_clk_en <= '1';
                        adc_bram_wr_addr <= std_logic_vector(adc_mem_addr_count);
                        adc_bram_din <= std_logic_vector(adc_data_temp);
                       -- write a white pixel
                        adc_mem_addr_count <= adc_mem_addr_count + 1;
                        ADC_state <= WAITING;
                    else
                        adc_mem_addr_count <= (others =>'0'); -- reset counter 
                        ADC_state <= UPDATE_DISPLAY; -- reset frame buffer 
                    end if;
                when UPDATE_DISPLAY => 
                    start_drawing <= '1';    
                    adc_state <= START_CONV;
                    -- if (rst_bram_complete = '0') then
                    --     rst_bram_start <= '1';
                    -- else
                    --     adc_state <= START_CONV;
                    -- end if;
                when WAITING =>
                    if (waiting_state_count < t_new_conv) then
                        waiting_state_count <= waiting_state_count + 1;
                    else
                        waiting_state_count <= 0;
                        ADC_state <= START_CONV;
                    end if;
            end case;
        end if;
    end process;

    
    -- adc data buffer 
    adc_data_buffer: entity work.dual_adc_bram
    port map (
        dout    => adc_bram_qout,
        clka    => adc_bram_wr_clk,
        cea     => adc_bram_wr_clk_en,
        reseta  => adc_bram_rst,
        clkb    => clock,
        ceb     => adc_bram_rd_clk_en,
        resetb  => adc_bram_rst,
        ada     => adc_bram_wr_addr,
        din     => adc_bram_din,
        adb     => adc_bram_rd_addr,
        oce     => '0'
    );
end architecture;
