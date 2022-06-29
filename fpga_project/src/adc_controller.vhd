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
    ledg            : out std_logic;
    adc_data_in     : in std_logic_vector(7 downto 0);
    adc_wr_rdy      : in std_logic;
    adc_rd          : out std_logic;
    adc_int         : in std_logic;
    
    adc_data_out    : out std_logic;
    adc_data_wren   : out std_logic;
    adc_data_addr   : out std_logic_vector(14 downto 0);
    frame_bram_rst : out std_logic
);
end entity;

architecture rtl of adc_controller is
constant t_new_conv : integer := 74; -- 1/(200MHz/110) = 550ns delay, min = 500ns
type FSM_states is (START_CONV, POLLING_CONV, FINISHED_CONV, WAITING);
signal adc_state : FSM_states := START_CONV;
signal adc_mem_addr_count : unsigned(14 downto 0) := (others => '0');
signal waiting_state_count : integer := 0;
signal adc_data_latch : std_logic_vector(7 downto 0):= (others =>'0');
signal adc_interrupt : std_logic := '0';
begin
    -- latch the interrupt
    process(adc_int)
    begin
        if(adc_int = '0') then
            adc_interrupt <= '1';
        else
            adc_interrupt <= '0';
        end if;
    end process;

    process(clock)
    variable adc_conversion_temp : unsigned (6 downto 0) := (others =>'0');
    begin
        if(rising_edge(clock)) then
            adc_rd <= '1'; -- active low
            adc_data_out <= '0';
            adc_data_wren <= '0';
            frame_bram_rst <= '0';
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
                        adc_data_wren <= '1';
                        adc_conversion_temp := resize(shift_right((unsigned(adc_data_in) * to_unsigned(PIXELS_HEIGHT, 7)), 8), 7);
--                        adc_data_addr  <= "0000000" & adc_data_latch;
                        adc_data_addr <= std_logic_vector(adc_mem_addr_count + (adc_conversion_temp * to_unsigned(PIXELS_WIDTH, 8))) ; -- divide by 256, 2^8 
                        adc_data_out  <= '1'; -- 1  -- convert adc_value into 
                        adc_mem_addr_count <= adc_mem_addr_count + 1;
                    else
                        adc_mem_addr_count <= (others =>'0'); -- reset counter 
                        frame_bram_rst <= '1'; -- reset frame buffer 
                    end if;
                    ADC_state <= WAITING;
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
end architecture;
