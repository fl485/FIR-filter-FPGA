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

entity debouncer is
    generic (
        DEBOUNCE_LIMIT : integer :=2000000
    );
    Port ( i_input  : in STD_LOGIC;
           i_clk    : in STD_LOGIC;
           o_output : out STD_LOGIC);
end debouncer;

architecture rtl of debouncer is
    signal r_counter           : integer range 0 to DEBOUNCE_LIMIT := 0;
    signal r_debounced         : std_logic :='0';

    signal r_sync_1            : std_logic := '0';
    signal r_sync_2            : std_logic := '0';

begin

    o_output <= r_debounced;

    process (i_clk)
    begin
        if rising_edge(i_clk) then
            
            -- double flop to sync
            r_sync_1 <= i_input;
            r_sync_2 <= r_sync_1;
            
            --debouncer
            if r_sync_2 /= r_debounced then
                if r_counter < DEBOUNCE_LIMIT then
                    r_counter <= r_counter + 1;
                else
                    r_debounced <= r_sync_2;
                    r_counter <= 0;
                end if;
            else
                r_counter <= 0;
            end if;

        end if;
    end process;
    
end rtl;
