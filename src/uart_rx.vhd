----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 24.09.2026 01:15:53
-- Design Name: 
-- Module Name: uart_rx - Behavioral
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

entity uart_rx is
    generic (
        g_clks_per_bit : integer := 868
    );
    Port ( 
        i_clock : in std_logic;
        i_reset : in std_logic;
        i_rx : in std_logic;
        o_data : out std_logic_vector(7 downto 0);
        o_rx_valid : out std_logic;
        o_rx_ready : out std_logic;
        o_frame_error : out std_logic
    );
end uart_rx;

architecture Behavioral of uart_rx is

    signal r_sync : std_logic;
    signal r_sync_rx : std_logic;

    signal r_rx_ready : std_logic :='1';
    signal r_rx_valid : std_logic :='0';
    signal r_output : std_logic_vector(7 downto 0) := (others => '0');
    signal r_frame_error : std_logic:='0';

    constant c_clks_per_half_bit : integer := g_clks_per_bit / 2;
    signal r_clk_count : integer range 0 to g_clks_per_bit:=0;
    signal r_half_clk_count : integer range 0 to c_clks_per_half_bit:=0;
    signal w_clk: std_logic;
    signal w_half_clk : std_logic;
    signal r_hclk_reset : std_logic :='0';

    type t_rx_state is (s_rx_idle, s_rx_detected, s_rx_data, s_rx_stop);
    signal r_state : t_rx_state := s_rx_idle;

--    signal r_sample : std_logic :='0';
    signal r_bit_index : integer range 0 to 7 :=0;
    signal r_data : std_logic_vector(7 downto 0);

begin

    w_clk <= '1' when r_clk_count = g_clks_per_bit - 1 else '0';
    w_half_clk <= '1' when r_half_clk_count = c_clks_per_half_bit - 1 else '0';

    o_rx_ready <= r_rx_ready;
    o_rx_valid <= r_rx_valid;
    o_data <= r_output;
    o_frame_error <= r_frame_error;

    process (i_clock)
    begin
        if rising_edge(i_clock) then
            -- sync the async input signal to protect for metastability
            r_sync <= i_rx;
            r_sync_rx <= r_sync;
            
            --clock
            if w_clk = '1' or r_state = s_rx_idle or r_state = s_rx_detected then
                r_clk_count <= 0;
            else
                r_clk_count <= r_clk_count + 1;
            end if;
            
            --half baud clock
            if w_half_clk = '1' or r_hclk_reset = '1' then
                r_half_clk_count <= 0;
                r_hclk_reset <= '0';
            else
                r_half_clk_count <= r_half_clk_count + 1;
            end if;
            
            if i_reset = '1' then
                r_state <= s_rx_idle;
                r_rx_valid <= '0';
                r_frame_error <= '0';
                r_rx_ready <= '1';
                r_hclk_reset <= '1';
            else
                r_rx_valid <= '0';
                r_frame_error <= '0';
                case r_state is
                    when s_rx_idle =>
                        if r_sync_rx = '0' then
                            r_state <= s_rx_detected;
                            r_hclk_reset <= '1';
                            r_rx_ready <= '0';
                        else
                            r_rx_ready <= '1';
                        end if;
                        
                    when s_rx_detected =>
                        if w_half_clk = '1' then
                            if r_sync_rx = '0' then -- confirm valid start bit
                                r_state <= s_rx_data;
                                r_bit_index <= 0;
                            else
                                r_state <= s_rx_idle;
                            end if;
                        end if;
                        
                    when s_rx_data =>
                        if w_clk = '1' then
                            r_data(r_bit_index) <= r_sync_rx;
                            if r_bit_index < 7 then
                                r_bit_index <= r_bit_index + 1;
                            else
                                r_state <= s_rx_stop; 
                            end if;
                        end if;
                        
                    when s_rx_stop =>
                        if w_clk = '1' then
                            if r_sync_rx = '1' then
                                r_output <= r_data;
                                r_rx_valid <= '1';
                            else
                                r_output <= (others => '0');
                                r_frame_error <= '1';
                            end if;
                            r_state <= s_rx_idle;
                        end if;
                    
                    when others =>
                        r_state <= s_rx_idle;
                
                end case;
            end if;
        end if;
    end process;
end Behavioral;
