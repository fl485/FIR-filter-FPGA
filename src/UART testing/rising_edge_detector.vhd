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

entity rising_edge_detector is
    Port(   i_input : in STD_LOGIC;
            i_clk   : in STD_LOGIC;
            o_output : out STD_LOGIC);
end rising_edge_detector;

architecture rtl of rising_edge_detector is
    signal r_sync_1 : std_logic := '0';
    signal r_sync_2 : std_logic := '0';
begin


    process (i_clk)
    begin
        if rising_edge(i_clk) then
            r_sync_1 <= i_input;
            r_sync_2 <= r_sync_1;
        end if;
    end process;
    o_output <= r_sync_1 and not r_sync_2;

end rtl;
