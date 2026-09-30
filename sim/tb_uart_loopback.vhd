----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2026 19:11:21
-- Design Name: 
-- Module Name: debouncer - Behavioral
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

use std.env.all;

entity tb_uart_loopback is
end tb_uart_loopback;

architecture Behavioral of tb_uart_loopback is

    constant c_clks_per_bit : integer := 8;   

    signal r_clk    : std_logic := '0';
    signal r_reset  : std_logic := '0';

    -- TX side
    signal r_tx_valid : std_logic := '0';
    signal r_tx_data  : std_logic_vector(7 downto 0) := (others => '0');
    signal r_tx_line  : std_logic;               
    signal r_tx_ready : std_logic;

    -- RX side
    signal r_rx_data        : std_logic_vector(7 downto 0);
    signal r_rx_valid       : std_logic;
    signal r_rx_ready       : std_logic;
    signal r_rx_frame_error : std_logic;

    type t_bytes is array (natural range <>) of std_logic_vector(7 downto 0);
    constant c_test_bytes : t_bytes(0 to 4) := (x"00", x"FF", x"55", x"AA", x"41");

begin

    uart_tx_inst : entity work.uart_tx
        generic map (
            g_clks_per_bit => c_clks_per_bit
        )
        port map (
            i_clock => r_clk,
            i_reset => r_reset,
            i_valid => r_tx_valid,
            i_data  => r_tx_data,
            o_tx    => r_tx_line,
            o_ready => r_tx_ready
        );

    uart_rx_inst : entity work.uart_rx
        generic map (
            g_clks_per_bit => c_clks_per_bit
        )
        port map (
            i_clk         => r_clk,
            i_reset       => r_reset,
            i_rx          => r_tx_line,
            o_data        => r_rx_data,
            o_rx_valid    => r_rx_valid,
            o_rx_ready    => r_rx_ready,
            o_frame_error => r_rx_frame_error
        );

    clock : process
    begin
        r_clk <= not r_clk;
        wait for 5 ns;
    end process;

    checker : process
        variable v_errors : integer := 0;
    begin
        for i in c_test_bytes'range loop
            wait until rising_edge(r_clk) and (r_rx_valid = '1' or r_rx_frame_error = '1');

            if r_rx_frame_error = '1' then
                v_errors := v_errors + 1;
                report "byte " & integer'image(i) & ": unexpected frame error" severity warning;
            elsif r_rx_data /= c_test_bytes(i) then
                v_errors := v_errors + 1;
                report "byte " & integer'image(i) & ": got " & to_hstring(r_rx_data) & ", expected " & to_hstring(c_test_bytes(i)) severity warning;
            end if;
        end loop;

        if v_errors = 0 then
            report "RESULT: PASS, all " & integer'image(c_test_bytes'length) & " bytes looped back correctly";
        else
            report "RESULT: FAIL, " & integer'image(v_errors) & " error(s)";
        end if;

        wait;   
    end process;

    stimulus : process

        procedure send_byte(b : std_logic_vector(7 downto 0)) is
        begin
            wait until rising_edge(r_clk) and r_tx_ready = '1';
            r_tx_data  <= b;
            r_tx_valid <= '1';
            wait until rising_edge(r_clk);
            r_tx_valid <= '0';
        end procedure;

    begin
        r_reset <= '1';
        wait for 25 ns;
        r_reset <= '0';
        wait until rising_edge(r_clk);

        for i in c_test_bytes'range loop
            send_byte(c_test_bytes(i));
        end loop;

        wait until rising_edge(r_clk) and r_tx_ready = '1';
        wait for 50 ns;
        std.env.finish;
    end process;
end Behavioral;
