library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_top is
end tb_top;

architecture sim of tb_top is

    constant c_clk_period   : time    := 10 ns;
    constant c_clks_per_bit : integer := 100;   -- must match C_BAUD_RATE in top
    constant c_bit_period   : time    := c_clk_period * c_clks_per_bit;
    constant c_rx_timeout   : time    := 20 * c_bit_period;  -- max wait for a start bit

    signal i_clock   : std_logic := '0';
    signal i_btnC    : std_logic := '1';
    signal sw        : std_logic_vector(15 downto 0) := (others => '0');
    signal i_uart_rx : std_logic := '1';
    signal o_uart_tx : std_logic;
    signal led       : std_logic_vector(15 downto 0);

    signal r_done    : boolean := false;

    -- send one 8N1 byte, LSB first
    procedure uart_send (
        signal   rx   : out std_logic;
        constant data : in  std_logic_vector(7 downto 0)
    ) is
    begin
        rx <= '0';
        wait for c_bit_period;
        for i in 0 to 7 loop
            rx <= data(i);
            wait for c_bit_period;
        end loop;
        rx <= '1';
        wait for c_bit_period;
    end procedure;

    -- receive one 8N1 byte, sampling mid-bit
    procedure uart_recv (
        signal   tx   : in  std_logic;
        variable data : out std_logic_vector(7 downto 0);
        variable ok   : out boolean
    ) is
    begin
        data := (others => 'X');
        ok   := false;
        wait until tx = '0' for c_rx_timeout;
        if tx /= '0' then
            return;
        end if;
        wait for c_bit_period / 2;          -- middle of start bit
        for i in 0 to 7 loop
            wait for c_bit_period;
            data(i) := tx;
        end loop;
        wait for c_bit_period;              -- middle of stop bit
        ok := (tx = '1');
    end procedure;

begin

    i_clock <= not i_clock after c_clk_period / 2 when not r_done else i_clock;

    dut : entity work.top
        port map (
            i_clock   => i_clock,
            i_btnC    => i_btnC,
            sw        => sw,
            i_uart_rx => i_uart_rx,
            o_uart_tx => o_uart_tx,
            led       => led
        );

    stim : process
        variable v_errors : integer := 0;
        variable v_hdr    : std_logic_vector(7 downto 0);
        variable v_val    : integer;
        variable v_first  : integer;

        procedure check (cond : boolean; msg : string) is
        begin
            if not cond then
                v_errors := v_errors + 1;
                report "FAIL: " & msg severity error;
            end if;
        end procedure;

        procedure do_reset is
        begin
            i_btnC <= '1';
            wait for 10 * c_clk_period;
            i_btnC <= '0';
            wait for 10 * c_clk_period;
        end procedure;

        -- send header + 14-bit sample as 3 bytes
        procedure send_sample (hdr : std_logic_vector(7 downto 0); sample : integer) is
            variable v_s : unsigned(13 downto 0);
        begin
            v_s := to_unsigned(sample, 14);
            uart_send(i_uart_rx, hdr);
            uart_send(i_uart_rx, '0' & std_logic_vector(v_s(13 downto 7)));
            uart_send(i_uart_rx, '0' & std_logic_vector(v_s(6 downto 0)));
        end procedure;

        -- receive 3-byte reply, decode to header + value
        procedure get_reply (
            variable hdr : out std_logic_vector(7 downto 0);
            variable val : out integer
        ) is
            variable b0, b1, b2 : std_logic_vector(7 downto 0);
            variable ok         : boolean;
        begin
            hdr := (others => 'X');
            val := -1;
            uart_recv(o_uart_tx, b0, ok);
            check(ok, "reply byte 0 missing or bad stop bit");
            uart_recv(o_uart_tx, b1, ok);
            check(ok, "reply byte 1 missing or bad stop bit");
            uart_recv(o_uart_tx, b2, ok);
            check(ok, "reply byte 2 missing or bad stop bit");
            check(b0(7) = '1', "reply header bit 7 should be 1");
            check(b1(7) = '0' and b2(7) = '0', "reply data bytes bit 7 should be 0");
            hdr := b0;
            val := to_integer(unsigned(b1(6 downto 0) & b2(6 downto 0)));
        end procedure;

        procedure transact (
            hdr    : std_logic_vector(7 downto 0);
            sample : integer;
            variable hdr_rx : out std_logic_vector(7 downto 0);
            variable val    : out integer
        ) is
        begin
            send_sample(hdr, sample);
            get_reply(hdr_rx, val);
        end procedure;

        type t_int_array is array (natural range <>) of integer;
        constant c_test_vals : t_int_array := (0, 1, 1234, 8191, 8192, 16383);

    begin
        wait for 20 * c_clk_period;
        do_reset;


        -- T1: bypass preset (sw = 3), output should equal input
        report "T1: bypass";
        sw(1 downto 0) <= "11";
        wait for 5 * c_clk_period;
        for i in c_test_vals'range loop
            transact(x"81", c_test_vals(i), v_hdr, v_val);
            check(v_val = c_test_vals(i),
                  "bypass: in=" & integer'image(c_test_vals(i)) &
                  " out=" & integer'image(v_val));
            check(v_hdr = x"81", "bypass: header not echoed");
        end loop;

        -- T2: header echo with a different index
        report "T2: header echo";
        transact(x"A5", 100, v_hdr, v_val);
        check(v_hdr = x"A5", "header A5 not echoed");

        -- T3: no stray bytes after a reply
        report "T3: line idle after reply";
        wait for 5 * 10 * c_bit_period;
        check(o_uart_tx = '1', "tx line not idle after reply");

        -- T4: resync, second header while waiting for MSB
        report "T4: header while waiting for MSB";
        do_reset;
        uart_send(i_uart_rx, x"81");
        send_sample(x"82", 1000);
        get_reply(v_hdr, v_val);
        check(v_hdr = x"82", "resync (MSB state): wrong header");
        check(v_val = 1000,  "resync (MSB state): wrong value");

        -- T5: resync, header while waiting for LSB
        report "T5: header while waiting for LSB";
        do_reset;
        uart_send(i_uart_rx, x"81");
        uart_send(i_uart_rx, x"10");            -- MSB of an abandoned packet
        send_sample(x"83", 647);
        get_reply(v_hdr, v_val);
        check(v_hdr = x"83", "resync (LSB state): wrong header");
        check(v_val = 647,   "resync (LSB state): wrong value");

        -- T6: smoothing preset step response (sw = 0) assumes the coefficients sum to 1.0, so DC gain is 1
        report "T6: step response, heavy smoothing";
        do_reset;
        sw(1 downto 0) <= "00";
        wait for 5 * c_clk_period;
        for i in 0 to 23 loop
            transact(x"81", 8000, v_hdr, v_val);
            if i = 0 then
                v_first := v_val;
            end if;
        end loop;
        check(v_first < 8000, "step: first output should be below final value");
        check(  abs(v_val - 8000) <= 4,
                "step: settled to " & integer'image(v_val) & ", expected ~8000");

        -- T7: reset mid-packet clears the FSM
        report "T7: reset mid-packet";
        sw(1 downto 0) <= "11";
        uart_send(i_uart_rx, x"81");
        uart_send(i_uart_rx, x"05");
        do_reset;
        send_sample(x"84", 321);
        get_reply(v_hdr, v_val);
        check(v_hdr = x"84" and v_val = 321, "reset mid-packet did not recover");

        if v_errors = 0 then
            report "ALL TESTS PASSED" severity note;
        else
            report integer'image(v_errors) & " CHECK(S) FAILED" severity error;
        end if;
        r_done <= true;
        wait;
    end process;

    -- watchdog in case the DUT hangs and never replies
    watchdog : process
    begin
        wait until r_done for 50 ms;
        assert r_done report "TIMEOUT: testbench did not finish" severity failure;
        wait;
    end process;

end sim;