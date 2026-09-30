----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 22.09.2026 15:49:48
-- Design Name: 
-- Module Name: tb_uart_tx - Behavioral
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
use std.env.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity tb_uart_tx is
end tb_uart_tx;

architecture Behavioral of tb_uart_tx is
    signal tb_clock  : std_logic:='0';
    signal tb_reset  : std_logic:='0';
    signal tb_valid  : std_logic:='0';
    signal tb_data   : std_logic_vector(7 downto 0):= (others => '0');
    signal tb_tx     : std_logic:='0';
    signal tb_ready  : std_logic:='0';
begin

    uart_tx : entity work.uart_tx
    generic map (
        g_clks_per_bit => 4
    )
    port map (
        i_clock => tb_clock,
        i_reset => tb_reset,
        i_valid => tb_valid,
        i_data  => tb_data,
        o_tx    => tb_tx,
        o_ready => tb_ready
    );


    clock : process
    begin
        tb_clock <= not tb_clock;
        wait for 5 ns;
    end process;

    stimulus : process

        procedure send_byte(b : std_logic_vector(7 downto 0)) is 
        begin
            wait until rising_edge(tb_clock) and tb_ready = '1';

            tb_data <= b;
            tb_valid <= '1';

            wait until rising_edge(tb_clock);

            tb_valid <= '0';
        end procedure;

        procedure send_byte_reset(b : std_logic_vector(7 downto 0)) is 
        begin
            wait until rising_edge(tb_clock) and tb_ready = '1';

            tb_data <= b;
            tb_valid <= '1';
            wait until rising_edge(tb_clock);
            tb_valid <= '0';

            wait until rising_edge(tb_clock);
            wait until rising_edge(tb_clock);
            wait until rising_edge(tb_clock);
            wait until rising_edge(tb_clock);

            tb_reset <= '1';
            wait until rising_edge(tb_clock);
            tb_reset <= '0';
        end procedure;

    begin
        
        wait until tb_ready = '1';

        send_byte("11110000");
        send_byte_reset("10101010");

        wait until rising_edge(tb_clock) and tb_ready = '1';
        report "RESULT: all bytes sent";
        wait;
        
    end process;


end Behavioral;
