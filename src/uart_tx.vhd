----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 20.09.2026 20:47:39
-- Design Name: 
-- Module Name: uart_tx - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity uart_tx is
    generic (
        g_clks_per_bit : integer := 868
    );
    port (
        i_clock : in    std_logic;
        i_reset : in    std_logic; -- synchronour, ctive high
        i_valid : in    std_logic;
        i_data  : in    std_logic_vector(7 downto 0);
        o_tx    : out   std_logic;    
        o_ready : out   std_logic
    );
end uart_tx;

architecture rtl of uart_tx is

    type t_tx_state is (s_tx_idle, s_tx_start, s_tx_data, s_tx_stop);
    
    signal r_state : t_tx_state := s_tx_idle;
    signal r_clk_count : integer range 0 to g_clks_per_bit - 1 := 0;
    signal r_bit_index : integer range 0 to 7 := 0;
    signal r_data   : std_logic_vector(7 downto 0):= (others => '0');
    signal r_tx     : std_logic := '1';

    signal w_bit_done  : std_logic := '1';

begin

    w_bit_done <= '1' when r_clk_count = g_clks_per_bit - 1 else '0';
    o_ready <= '1' when r_state = s_tx_idle else '0';
    o_tx <= r_tx;

    --fsm
    process (i_clock)
    begin
        if rising_edge(i_clock) then

            if i_reset = '1' then -- reset
                r_tx <= '1';
                r_state <= s_tx_idle;
                r_bit_index <= 0;
            else
                if w_bit_done = '1' or r_state = s_tx_idle then
                    r_clk_count <= 0;
                else
                    r_clk_count <= r_clk_count + 1;
                end if;

                case r_state is

                    when s_tx_idle =>
                        if i_valid = '1' then
                            r_data  <= i_data;
                            r_tx    <= '0';
                            r_state <= s_tx_start;
                        end if;

                    when s_tx_start =>
                        if w_bit_done = '1' then
                            r_tx        <= r_data(0);
                            r_data      <= '0' & r_data(7 downto 1);
                            r_bit_index <= 0;
                            r_state     <= s_tx_data;
                        end if;


                    when s_tx_data =>
                        if w_bit_done = '1' then
                            if r_bit_index = 7 then
                                r_tx <= '1';
                                r_state <= s_tx_stop;
                            else
                                r_tx <= r_data(0);
                                r_data <= '0' & r_data(7 downto 1);
                                r_bit_index <= r_bit_index + 1;
                            end if;
                        end if;

                    when s_tx_stop =>
                        if w_bit_done = '1' then
                            r_state <= s_tx_idle;
                        end if;

                    when others =>
                        r_state <= s_tx_idle;
                
                end case;
            end if;
        end if;
    end process;
end rtl;
