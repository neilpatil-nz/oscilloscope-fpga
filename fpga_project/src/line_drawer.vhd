library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity line_drawer is
port(
    clock           : in std_logic;
    
    -- adc controller signals
    adc_data_in     : in std_logic_vector (6 downto 0);
    adc_data_addr   : out std_logic_vector (7 downto 0);
    adc_data_wren   : out std_logic;
    start_drawing   : in std_logic;
    finished_drawing : out std_logic;
        
    -- frame buffer signals
    frame_bram_out  : out std_logic;
    frame_bram_wren : out std_logic;
    frame_bram_addr : out std_logic_vector(14 downto 0)
);
end entity;
architecture rtl of line_drawer is
-- time and voltage x0,y0 and x1, y1 signals
signal time_x0 : unsigned(7 downto 0) := (others =>'0');
signal time_x1 : unsigned(7 downto 0) := (others =>'0');

signal voltage_y0 : unsigned(6 downto 0) := (others =>'0');
signal voltage_y1 : unsigned(6 downto 0) := (others =>'0');

signal addr_x_count : unsigned(7 downto 0) := (others => '0');
signal addr_x_value : unsigned(7 downto 0) := (others => '0');
signal addr_y_value : unsigned(6 downto 0) := (others =>'0');

-- pipeline arithmetic signals
signal addr_y_sub_value : unsigned(6 downto 0) := (others =>'0');
signal addr_y_add_value : unsigned(6 downto 0) := (others =>'0');
signal addr_y_value_unsigned : unsigned(14 downto 0) := (others =>'0');
signal addr_y_value_mult_sum : unsigned(14 downto 0) := (others =>'0');
signal addr_y_value_mult_0 : unsigned(14 downto 0) := (others =>'0');
signal addr_y_value_mult_1 : unsigned(14 downto 0) := (others =>'0');
signal addr_y_value_mult_2 : unsigned(14 downto 0) := (others =>'0');

-- maximum x axis value
constant ADC_ADDRESS_DEPTH : unsigned(7 downto 0) := to_unsigned(200,addr_x_count'length)-1;

-- line draw controller state
type FSM_states_line_draw is (IDLE, LOAD_X0, LOAD_Y0, LOAD_X1, LOAD_Y1, DETERMINE_DIRECTION, DRAW_STRAIGHT, DRAW_DOWN, DRAW_UP, UNSIGNED_DATA, MULT_DATA_0, MULT_DATA_1, MULT_DATA_2, ADD_DATA_0, ADD_DATA_1, ADD_DATA_2, ADD_DATA_3, WRITE_DATA, SET_Y_END, INCREMENT_Y, DECREMENT_Y, FINISHED);
signal line_draw_state : FSM_states_line_draw := IDLE;
signal line_draw_state_next : FSM_states_line_draw := IDLE;

begin
    -- arithmetic signals 
    addr_y_sub_value <= addr_y_value + "1111111";
    addr_y_add_value <= addr_y_value + "0000001";

    process(clock)
    begin
        if (rising_edge(clock)) then
            frame_bram_wren <= '0';
            frame_bram_out  <= '0';
            finished_drawing <= '0';
            adc_data_wren <= '0';
            case (line_draw_state) is
                when IDLE => 
                    if (start_drawing = '1') then
                        line_draw_state <= LOAD_X0;     
                    end if;
                when LOAD_X0 => -- requires 1 clock cycle to access ram contents
                    adc_data_addr <= std_logic_vector(addr_x_count);
                    time_x0 <= addr_x_count;
                    line_draw_state <= LOAD_Y0;  
                    adc_data_wren <= '1';
                when LOAD_Y0 =>
                    line_draw_state <= LOAD_X1;
                    voltage_y0 <= unsigned(adc_data_in);
                when LOAD_X1 =>
                    adc_data_addr <= std_logic_vector(time_x0 + 1);
                    time_x1 <= time_x0 + 1;
                    line_draw_state <= LOAD_Y1;
                    adc_data_wren <= '1';
                when LOAD_Y1 =>
                    voltage_y1 <= unsigned(adc_data_in);
                    line_draw_state <= DETERMINE_DIRECTION;
                when DETERMINE_DIRECTION =>
                    addr_x_value <= time_x0;
                    addr_y_value <= voltage_y0;
                     if (voltage_y0 > voltage_y1) then -- greater y0 value = bottom of the display
                         line_draw_state_next <= DRAW_UP;
                     elsif (voltage_y0 < voltage_y1) then -- smaller y0 value = top of the display
                         line_draw_state_next <= DRAW_DOWN;
                     else
                         line_draw_state_next <= DRAW_STRAIGHT;
                     end if;  
                    line_draw_state <= UNSIGNED_DATA;
                when UNSIGNED_DATA => 
                    addr_y_value_unsigned <= "00000000" & addr_y_value;
                    line_draw_state <= MULT_DATA_0;
                when MULT_DATA_0 => -- six stage pipeline process for y_value * 200
                    addr_y_value_mult_0 <= shift_left(addr_y_value_unsigned, 7); -- y_value * 128
                    line_draw_state <= MULT_DATA_1;
                when MULT_DATA_1 =>
                    addr_y_value_mult_1 <= shift_left(addr_y_value_unsigned, 6); -- y_value * 64
                    line_draw_state <= MULT_DATA_2;
                when MULT_DATA_2 =>
                    addr_y_value_mult_2 <= shift_left(addr_y_value_unsigned, 3); -- y_value * 8
                    line_draw_state <= ADD_DATA_0;
                when ADD_DATA_0 => 
                    -- = y_value * 128
                    addr_y_value_mult_sum <= addr_y_value_mult_0;
                    line_draw_state <= ADD_DATA_1;
                when ADD_DATA_1 =>
                    -- (y_value * 128) + y_value * 64
                    addr_y_value_mult_sum <= addr_y_value_mult_sum + addr_y_value_mult_1;
                    line_draw_state <= ADD_DATA_2;
                when ADD_DATA_2 =>
                    -- (y_value * 128 + y_value * 64) + y_value * 8 
                    addr_y_value_mult_sum <= addr_y_value_mult_sum + addr_y_value_mult_2;
                    line_draw_state <= ADD_DATA_3;
                when ADD_DATA_3 =>
                    -- (y_value * 128 + y_value * 64 + y_value * 8 ) + x_addr
                    addr_y_value_mult_sum <= addr_y_value_mult_sum + addr_x_value;
                    line_draw_state <= WRITE_DATA;
                when WRITE_DATA => 
                    frame_bram_addr <= std_logic_vector(addr_y_value_mult_sum);
                    frame_bram_wren <= '1';
                    frame_bram_out  <= '1';
                    line_draw_state <= line_draw_state_next;
                when DRAW_STRAIGHT =>
                    addr_x_value <= time_x1;
                    addr_y_value <= voltage_y1;
                    line_draw_state <= UNSIGNED_DATA;
                    line_draw_state_next <= FINISHED;
                when DRAW_DOWN =>
                    if (addr_y_value /= voltage_y1) then
                        addr_x_value <= time_x1;
                        line_draw_state_next <= DRAW_DOWN;
                        line_draw_state <= INCREMENT_Y;
                    else
                        addr_x_value <= time_x1;
                        line_draw_state_next <= FINISHED;
                        line_draw_state <= SET_Y_END;
                    end if;
                when DRAW_UP => 
                    if (addr_y_value /= voltage_y1) then
                        addr_x_value <= time_x1;
                        line_draw_state_next <= DRAW_UP;
                        line_draw_state <= DECREMENT_Y;

                    else
                        addr_x_value <= time_x1;
                        line_draw_state_next <= FINISHED;
                        line_draw_state <= SET_Y_END;
                    end if;
                when SET_Y_END =>
                    addr_y_value <= voltage_y1;
                    line_draw_state <= UNSIGNED_DATA;
                when INCREMENT_Y =>
                    addr_y_value <= addr_y_add_value;
                    line_draw_state <= UNSIGNED_DATA;
                when DECREMENT_Y =>
                    addr_y_value <= addr_y_sub_value;
                    line_draw_state <= UNSIGNED_DATA;
                when FINISHED =>
                    if (addr_x_count < ADC_ADDRESS_DEPTH-1) then
                        addr_x_count <= addr_x_count + 2; -- increments in two
                        line_draw_state <= LOAD_X0;
                    else 
                        addr_x_count <= (others => '0');
                        line_draw_state <= IDLE;
                        finished_drawing <= '1';
                    end if;
            end case;
        end if;
    end process;
end architecture;
