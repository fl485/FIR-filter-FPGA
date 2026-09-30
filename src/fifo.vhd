----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 30.09.2026 03:19:27
-- Design Name: 
-- Module Name: fifo - Behavioral
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

entity fifo is
    generic (
        g_depth : integer := 8;
        g_width : integer := 8);
    port (
        i_clock   : in  std_logic;
        i_reset   : in  std_logic;
        i_wr_en   : in  std_logic;
        i_wr_data : in  std_logic_vector(g_width - 1 downto 0);
        o_full    : out std_logic;
        i_rd_en   : in  std_logic;
        o_rd_data : out std_logic_vector(g_width - 1 downto 0);
        o_empty   : out std_logic
    );
end fifo;

architecture rtl of fifo is

    type t_mem is array (0 to g_depth - 1) of std_logic_vector(g_width - 1 downto 0);
    signal r_mem : t_mem := (others => (others => '0'));    

    signal r_wr_ptr : integer range 0 to g_depth - 1 := 0;
    signal r_rd_ptr : integer range 0 to g_depth - 1 := 0;
    signal r_count : integer range 0 to g_depth := 0;
begin

    o_empty <= '1' when r_count = 0 else '0';
    o_full  <= '1' when r_count = g_depth else '0';
    o_rd_data <= r_mem(r_rd_ptr);

    process (i_clock)

    variable v_wr : boolean;
    variable v_rd : boolean;

    begin
        if rising_edge(i_clock) then
            v_wr := (i_wr_en = '1') and (r_count < g_depth);
            v_rd := (i_rd_en = '1') and (r_count > 0);
            if i_reset = '1' then
                r_wr_ptr <= 0;
                r_rd_ptr <= 0;
                r_count <= 0;
            else
                if v_wr then
                    r_mem(r_wr_ptr) <= i_wr_data;
                    r_wr_ptr <= (r_wr_ptr + 1) mod g_depth;
                end if;
                if v_rd then
                    r_rd_ptr <= (r_rd_ptr + 1) mod g_depth;
                end if;
                if v_wr and not v_rd then
                    r_count <= r_count + 1;
                elsif v_rd and not v_wr then 
                    r_count <= r_count - 1;
                end if;    
            end if;
        end if;
    end process;
end rtl;