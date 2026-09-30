library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_fifo is
end tb_fifo;                     -- no ports, the testbench is the whole world

architecture sim of tb_fifo is

    signal s_clk     : std_logic := '0';
    signal s_reset   : std_logic := '0';
    signal s_wr_en   : std_logic := '0';
    signal s_wr_data : std_logic_vector(7 downto 0) := (others => '0');
    signal s_full    : std_logic;
    signal s_rd_en   : std_logic := '0';
    signal s_rd_data : std_logic_vector(7 downto 0);
    signal s_empty   : std_logic;

begin

    s_clk <= not s_clk after 5 ns;   -- 100 MHz

    dut : entity work.fifo
        generic map (g_depth => 8, g_width => 8)
        port map (
            i_clock   => s_clk,
            i_reset   => s_reset,
            i_wr_en   => s_wr_en,
            i_wr_data => s_wr_data,
            o_full    => s_full,
            i_rd_en   => s_rd_en,
            o_rd_data => s_rd_data,
            o_empty   => s_empty
        );

    stim : process

        -- NEW SYNTAX: a procedure is a reusable chunk of stimulus,
        -- like a function you can call, and it can contain waits.

        procedure push (d : in std_logic_vector(7 downto 0)) is
        begin
            s_wr_data <= d;
            s_wr_en   <= '1';
            wait until rising_edge(s_clk);   -- fifo samples wr_en on this edge
            s_wr_en   <= '0';
        end procedure;

        -- show-ahead: check the data BEFORE pulsing rd_en
        procedure pop (expected : in std_logic_vector(7 downto 0)) is
        begin
            wait for 1 ns;
            assert s_rd_data = expected report "pop: wrong data" severity error;
            s_rd_en <= '1';
            wait until rising_edge(s_clk);
            s_rd_en <= '0';
        end procedure;

    begin
        -- 1. reset
        s_reset <= '1';
        wait until rising_edge(s_clk);
        wait until rising_edge(s_clk);
        s_reset <= '0';
        wait until rising_edge(s_clk);
        wait for 1 ns;
        assert s_empty = '1' report "1: not empty after reset" severity error;
        assert s_full  = '0' report "1: full after reset"      severity error;

        -- 2. push 3, check first byte is visible with no read, then pop 3
        push(x"A1"); push(x"B2"); push(x"C3");
        wait for 1 ns;
        assert s_empty = '0'   report "2: still empty after pushes" severity error;
        assert s_rd_data = x"A1" report "2: show-ahead data wrong"  severity error;
        pop(x"A1"); pop(x"B2"); pop(x"C3");
        wait for 1 ns;
        assert s_empty = '1' report "2: not empty after popping all" severity error;

        -- 3. overfill: push 9 into a depth-8 fifo, the 9th must be refused
        for i in 0 to 7 loop
            push(std_logic_vector(to_unsigned(16 + i, 8)));   -- x"10" to x"17"
        end loop;
        wait for 1 ns;
        assert s_full = '1' report "3: not full after 8 pushes" severity error;
        push(x"FF");                                          -- should be dropped
        for i in 0 to 7 loop
            pop(std_logic_vector(to_unsigned(16 + i, 8)));
        end loop;
        wait for 1 ns;
        assert s_empty = '1' report "3: 9th push was not refused" severity error;

        -- 4. wrap test: 20 one-at-a-time push/pops walks the pointers past 7
        for i in 0 to 19 loop
            push(std_logic_vector(to_unsigned(32 + i, 8)));
            pop(std_logic_vector(to_unsigned(32 + i, 8)));
        end loop;
        wait for 1 ns;
        assert s_empty = '1' report "4: not empty after wrap test" severity error;

        -- 5. read and write in the same clock with 3 stored
        push(x"A1"); push(x"B2"); push(x"C3");
        s_wr_data <= x"D4";
        s_wr_en   <= '1';
        s_rd_en   <= '1';                -- this read consumes A1
        wait until rising_edge(s_clk);
        s_wr_en   <= '0';
        s_rd_en   <= '0';
        pop(x"B2"); pop(x"C3"); pop(x"D4");   -- count stayed 3, so exactly 3 left
        wait for 1 ns;
        assert s_empty = '1' report "5: count wrong after simultaneous rd/wr" severity error;

        report "TESTBENCH FINISHED" severity note;
        wait;                             -- stop this process forever
    end process;

end sim;