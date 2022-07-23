library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity line_draw_controller is
port(
    clock           : in std_logic;
    
    -- adc controller signals
    adc_data_in     : in std_logic_vector (6 downto 0);
    adc_data_addr   : out std_logic_vector (7 downto 0);
    adc_data_wren   : out std_logic;
    frame_bram_rst  : out std_logic;
    start_drawing   : in std_logic;
    finished_drawing : out std_logic;
        
    -- frame buffer signals
    frame_bram_out  : out std_logic;
    frame_bram_wren : out std_logic;
    frame_bram_addr : out std_logic_vector(14 downto 0)
);
end entity;
architecture rtl of line_draw_controller is
signal time_x0 : unsigned(7 downto 0) := (others =>'0');
signal time_x1 : unsigned(7 downto 0) := (others =>'0');
signal time_xa :  unsigned(7 downto 0) := (others =>'0');
signal time_xb :  unsigned(7 downto 0) := (others =>'0');
signal time_x_end :  unsigned(7 downto 0) := (others =>'0');

signal voltage_y0 : unsigned(6 downto 0) := (others =>'0');
signal voltage_y1 : unsigned(6 downto 0) := (others =>'0');
signal voltage_ya : unsigned(6 downto 0) := (others =>'0');
signal voltage_yb : unsigned(6 downto 0) := (others =>'0');
signal voltage_y_end : unsigned(6 downto 0) := (others =>'0');

-- extra bit for signed
signal time_dx    : signed(7 downto 0) := (others => '0');
signal voltage_dy : signed(6  downto 0) := (others => '0');


-- drawing direction
signal draw_right : std_logic := '0';
signal draw_down : std_logic := '0';
signal voltage_y0_greater_y1 : std_logic := '0';

signal draw_x : std_logic := '0';
signal draw_y  : std_logic := '0';

-- error signals (determine direction)
signal curr_error : signed(7 downto 0) := (others => '0');
signal d_error : signed(7 downto 0) := (others =>'0');

signal addr_x_count : unsigned(7 downto 0) := (others => '0');
signal addr_x_value : unsigned(7 downto 0) := (others => '0');
signal addr_y_value : unsigned(6 downto 0) := (others =>'0');

constant ADC_ADDRESS_DEPTH : unsigned(7 downto 0) := to_unsigned(200,addr_x_count'length) - 1;

-- line draw controller state
type FSM_states_line_draw is (IDLE, LOAD_X0, LOAD_Y0, LOAD_X1, LOAD_Y1, DETERMINE_DIRECTION, INIT_0, INIT_1, INIT_2, DRAWING);
signal line_draw_state : FSM_states_line_draw := IDLE;
begin
    time_xa <= time_x1 when voltage_y0_greater_y1 ='1' else time_x0;
    time_xb <= time_x0 when voltage_y0_greater_y1 ='1' else time_x1;
    voltage_ya <= voltage_y1 when voltage_y0_greater_y1 ='1' else voltage_y0;
    voltage_yb <= voltage_y0 when voltage_y0_greater_y1 ='1' else voltage_y1;
    adc_data_wren <= '1';
    draw_x <= '1' when (2*curr_error >= voltage_dy) else '0';
    draw_y <= '1' when (2*curr_error >= time_dx) else '0';

    process(clock)
    begin
    if (rising_edge(clock)) then
        finished_drawing <= '0';
        frame_bram_wren <= '0';
        frame_bram_out <= '0';
        case(line_draw_state) is
            when IDLE =>
                if (start_drawing = '1') then
                    line_draw_state <= LOAD_X0;
                end if;
            when LOAD_X0 => -- requires 2 clock cycles to access ram contents
                adc_data_addr <= std_logic_vector(addr_x_count);
                time_x0 <= addr_x_count;
                line_draw_state <= LOAD_Y0;
            when LOAD_Y0 =>
                voltage_y0 <= unsigned(adc_data_in);
                line_draw_state <= LOAD_X1;
            when LOAD_X1 =>
                adc_data_addr <= std_logic_vector(addr_x_count + 1);
                time_x1 <= addr_x_count + 1;
                line_draw_state <= LOAD_Y1;
            when LOAD_Y1 =>
                voltage_y1 <= unsigned(adc_data_in);
                line_draw_state <= DETERMINE_DIRECTION;
            when DETERMINE_DIRECTION =>
                if (voltage_y0 > voltage_y1) then
                    voltage_y0_greater_y1 <= '1';
                else 
                    voltage_y0_greater_y1 <= '0';
                end if;
                line_draw_state <= INIT_0;
            when INIT_0 =>
                if (time_xa < time_xb) then 
                    draw_right <= '1';
                else 
                    draw_right <= '0';
                end if;
                line_draw_state <= INIT_1;
            when INIT_1 =>
                if (draw_right = '1') then
                    time_dx <= signed(time_xb - time_xa);
                else
                    time_dx <= signed(time_xa - time_xb);
                end if;
                voltage_dy <= signed(voltage_ya - voltage_yb);
                line_draw_state <= INIT_2;
            when INIT_2 =>
                curr_error <= time_dx + voltage_dy;
                addr_x_value <= time_xa;
                addr_y_value <= voltage_ya;
                time_x_end <= time_xb;
                voltage_y_end <= voltage_yb;
                line_draw_state <= DRAWING;
            when DRAWING =>
                frame_bram_wren <= '1';
                frame_bram_out <= '1';
                if (addr_x_value = time_x_end and addr_y_value = voltage_y_end) then
                    if (addr_x_count = ADC_ADDRESS_DEPTH) then
                        addr_x_count <= (others => '0'); -- reset counter 
                        line_draw_state <= IDLE;
                        finished_drawing <= '1';
                    else
                        addr_x_count <= addr_x_count + 1; -- else continue through buffer
                        line_draw_state <= LOAD_X0;
                    end if;
                else
                    if (draw_x = '1') then
                        if (draw_right = '1' )then
                            addr_x_value <= (addr_x_value + 1);
                        else
                            addr_x_value <= (addr_x_value - 1);
                        end if;
                        curr_error <= curr_error + voltage_dy;
                    end if;
                    if (draw_y = '1') then
                        if (draw_down = '1' )then
                            addr_y_value <= addr_y_value + 1;
                        else
                            addr_y_value <= addr_y_value - 1;
                        end if;
                        curr_error <= curr_error + time_dx;
                    end if;

                    if (draw_y = '1' and draw_x = '1') then
                        if (draw_right = '1' )then
                            addr_x_value <= (addr_x_value + 1);
                        else
                            addr_x_value <= (addr_x_value - 1);
                        end if;                        
                        if (draw_down = '1' )then
                            addr_y_value <= addr_y_value + 1;
                        else
                            addr_y_value <= addr_y_value - 1;
                        end if;
                        curr_error <= curr_error + time_dx + voltage_dy;
                    end if;
                end if;
        end case;
    end if;
    end process;
    -- frame_bram_addr <= std_logic_vector(to_unsigned(120, 15)) ; -- divide by 256, 2^8 
    -- frame_bram_out <= '1';

    frame_bram_addr <= std_logic_vector(addr_x_value + (addr_y_value * to_unsigned(200, 8))) ; -- divide by 256, 2^8 


end architecture;
