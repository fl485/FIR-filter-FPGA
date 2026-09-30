----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2026 20:00:39
-- Design Name: 
-- Module Name: rising edge detector - Behavioral
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

entity top is
    port (
        i_clock         : in    std_logic;
        i_btnR          : in    std_logic; -- reset, active high
        -- i_btnL          : in    std_logic;
        -- sw              : in    std_logic_vector(7 downto 0);
        -- i_btnC          : in    std_logic;
        i_uart_rx       : in    std_logic;    
        o_uart_tx       : out   std_logic
        -- led             : out   std_logic_vector(7 downto 0):= (others => '1')
    );
end top;

architecture rtl of top is
    signal r_data : std_logic_vector(7 downto 0):= (others => '0');
    -- signal w_ready : std_logic :='0' ;

    -- signal r_tx_valid : std_logic :='0' ;
    signal w_tx_ready : std_logic :='0' ;
    signal r_rx_valid : std_logic :='0' ;
    signal w_rx_ready : std_logic :='0' ;
    signal r_rx_frame_error : std_logic :='0' ;

    signal r_pending : std_logic :='0' ;

    signal r_db_btnR : std_logic :='0';
    signal r_edge_db_btnR : std_logic :='0';
begin



    tx : entity work.uart_tx 
        generic map (
        g_clks_per_bit => 868
        )
        port map (
            i_clock => i_clock,
            i_reset => r_edge_db_btnR,
            i_valid => r_pending,
            i_data  => r_data,
            o_tx    => o_uart_tx,
            o_ready => w_tx_ready
        );

    rx : entity work.uart_rx
        generic map (
            g_clks_per_bit => 868
        )
        port map (
            i_clk         => i_clock,
            i_reset       => r_edge_db_btnR,
            i_rx          => i_uart_rx,
            o_data        => r_data,
            o_rx_valid    => r_rx_valid,
            o_rx_ready    => w_rx_ready,
            o_frame_error => r_rx_frame_error
        );

    -- L_button_debounce : entity work.debouncer 
    --     port map (
    --         i_clk       => i_clock,
    --         i_input     => i_btnL,
    --         o_output    => r_db_btnL
    --     );

    -- L_button_edge_detector : entity work.rising_edge_detector 
    --     port map (
    --         i_clk       => i_clock,
    --         i_input     => r_db_btnL,
    --         o_output    => r_edge_db_btnL
    --     );

    R_button_debounce : entity work.debouncer 
        port map (
            i_clk       => i_clock,
            i_input     => i_btnR,
            o_output    => r_db_btnR
        );

    R_button_edge_detector : entity work.rising_edge_detector 
        port map (
            i_clk       => i_clock,
            i_input     => r_db_btnR,
            o_output    => r_edge_db_btnR
        );

    process (i_clock)
    begin
        if rising_edge(i_clock) then
            if r_rx_valid = '1' then
                r_pending <= '1';
            elsif r_pending = '1' and w_tx_ready = '1' then
                r_pending <= '0';
            end if;
        end if;
    end process;
        
end rtl;