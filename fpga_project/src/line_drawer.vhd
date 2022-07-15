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
signal time_x0 : unsigned(7 downto 0) := (others =>'0');
signal time_x1 : unsigned(7 downto 0) := (others =>'0');

signal voltage_y0 : unsigned(6 downto 0) := (others =>'0');
signal voltage_y1 : unsigned(6 downto 0) := (others =>'0');

signal addr_x_count : unsigned(7 downto 0) := (others => '0');
signal addr_x_value : unsigned(7 downto 0) := (others => '0');
signal addr_y_value : unsigned(6 downto 0) := (others =>'0');
signal addr_y_sub_value : unsigned(6 downto 0) := (others =>'0');
signal addr_y_add_value : unsigned(6 downto 0) := (others =>'0');
signal addr_y_value_mult : unsigned(14 downto 0) := (others =>'0');
signal addr_y_value_unsigned : unsigned(14 downto 0) := (others =>'0');

constant ADC_ADDRESS_DEPTH : unsigned(7 downto 0) := to_unsigned(200,addr_x_count'length)-1;

-- line draw controller state
type FSM_states_line_draw is (IDLE, LOAD_X0, LOAD_Y0, LOAD_X1, LOAD_Y1, DETERMINE_DIRECTION, DRAW_STRAIGHT, DRAW_DOWN, DRAW_UP, MULT_DATA_0, MULT_DATA_1, MULT_DATA_2, MULT_DATA_3, ADD_DATA, WRITE_DATA, SET_Y_END, INCREMENT_Y, DECREMENT_Y, FINISHED);
signal line_draw_state : FSM_states_line_draw := IDLE;
signal line_draw_state_next : FSM_states_line_draw := IDLE;

begin
    
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
--                    time_x0 <= to_unsigned(0,time_x0'length);
                    line_draw_state <= LOAD_Y0;  
                    adc_data_wren <= '1';
                when LOAD_Y0 =>
                    line_draw_state <= LOAD_X1;
                    voltage_y0 <= unsigned(adc_data_in);
--                    voltage_y0 <= to_unsigned(0,voltage_y0'length);
                when LOAD_X1 =>
                    adc_data_addr <= std_logic_vector(time_x0 + 1);
                    time_x1 <= time_x0 + 1;
--                    time_x1 <= to_unsigned(199,time_x0'length);
                    line_draw_state <= LOAD_Y1;
                    adc_data_wren <= '1';
                when LOAD_Y1 =>
                    voltage_y1 <= unsigned(adc_data_in);
--                    voltage_y1 <= to_unsigned(118,voltage_y1'length);
                    line_draw_state <= DETERMINE_DIRECTION;
                when DETERMINE_DIRECTION =>
                    addr_x_value <= time_x0;
                    addr_y_value <= voltage_y0;
                     if (voltage_y0 > voltage_y1) then -- greater y value = bottom of the display
                         line_draw_state_next <= DRAW_UP;
                     elsif (voltage_y0 < voltage_y1) then
                         line_draw_state_next <= DRAW_DOWN;
                     elsif (voltage_y0 = voltage_y1) then
                         line_draw_state_next <= DRAW_STRAIGHT;
                     end if;  
                         line_draw_state_next <= DRAW_STRAIGHT;
   
                    line_draw_state <= MULT_DATA_0;
                when MULT_DATA_0 =>
                    addr_y_value_unsigned <= "00000000" & addr_y_value;
                    line_draw_state <= MULT_DATA_1;
                when MULT_DATA_1 =>
                    addr_y_value_mult <= shift_left(addr_y_value_unsigned, 7); -- y_value * 200
                    line_draw_state <= MULT_DATA_2;
                when MULT_DATA_2 =>
                    addr_y_value_mult <= addr_y_value_mult + shift_left(addr_y_value_unsigned, 6);
                    line_draw_state <= MULT_DATA_3;
                when MULT_DATA_3 =>
                    addr_y_value_mult <= addr_y_value_mult + shift_left(addr_y_value_unsigned, 3);
                    line_draw_state <= ADD_DATA;
                when ADD_DATA =>
                    addr_y_value_mult <= addr_y_value_mult + addr_x_value;
                    line_draw_state <= WRITE_DATA;
                when WRITE_DATA => 
                    frame_bram_addr <= std_logic_vector(addr_y_value_mult);
                    frame_bram_wren <= '1';
                    frame_bram_out  <= '1';
                    line_draw_state <= line_draw_state_next;
                when DRAW_STRAIGHT =>
                    addr_x_value <= time_x1;
                    addr_y_value <= voltage_y1;
                    line_draw_state <= MULT_DATA_0;
                    line_draw_state_next <= FINISHED;
                when DRAW_DOWN =>
                    if (addr_y_value < voltage_y1) then
                        addr_x_value <= time_x1;
                        line_draw_state_next <= DRAW_DOWN;
                        line_draw_state <= INCREMENT_Y;
                            
addr_y_add_value <= addr_y_value + "0000001";
                    else
                        addr_x_value <= time_x1;
                        line_draw_state_next <= FINISHED;
                        line_draw_state <= SET_Y_END;
                    end if;
                when DRAW_UP => 
                    if (addr_y_value > voltage_y1) then
                        addr_x_value <= time_x1;
                        line_draw_state_next <= DRAW_UP;
                        line_draw_state <= DECREMENT_Y;
addr_y_sub_value <= addr_y_value + "1111111";
                    else
                        addr_x_value <= time_x1;
                        line_draw_state_next <= FINISHED;
                        line_draw_state <= SET_Y_END;
                    end if;
                when SET_Y_END =>
                    addr_y_value <= voltage_y1;
                    line_draw_state <= MULT_DATA_0;
                when INCREMENT_Y =>
                    addr_y_value <= addr_y_add_value;
                    line_draw_state <= MULT_DATA_0;
                when DECREMENT_Y =>
                    addr_y_value <= addr_y_sub_value;
                    line_draw_state <= MULT_DATA_0;
                when FINISHED =>
                    if (addr_x_count < ADC_ADDRESS_DEPTH-2) then
                        addr_x_count <= addr_x_count + 1;
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
