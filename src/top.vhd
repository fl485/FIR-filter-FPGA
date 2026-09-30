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
        i_btnC          : in    std_logic; -- reset, active high
        sw              : in    std_logic_vector(15 downto 0);
        i_uart_rx       : in    std_logic;    
        o_uart_tx       : out   std_logic;
        led             : out   std_logic_vector(15 downto 0):= (others => '0')
    );
end top;

architecture rtl of top is

    type t_coeff_set   is array (0 to N-1) of signed(C_COEFF_WIDTH-1 downto 0);
    type t_preset_bank is array (0 to 3)   of t_coeff_set;

    constant c_presets : t_preset_bank := (
        0 => (...),  -- heavy smoothing
        1 => (...),  -- moderate
        2 => (...),  -- light
        3 => (...)   -- bypass
    );
    
    type t_state is (
        S_WAIT_HEADER,
        S_WAIT_MSB,
        S_WAIT_LSB,
        S_FIR_CALC,
        S_TX_START,
        S_TX_WAIT
    );

    signal r_state : t_state := S_WAIT_HEADER;


    type t_sample_array is array (0 to c_n_stages - 1) of signed(13 downto 0);
    signal r_samples       : t_sample_array := (others => (others => '0'));
    signal r_packet_index  : std_logic_vector(7 downto 0) := (others => '0');
    signal r_sample_msb    : std_logic_vector(6 downto 0) := (others => '0');
    signal r_result        : unsigned(13 downto 0) := (others => '0');
    signal r_out_byte      : std_logic_vector(7 downto 0) := (others => '0');
    signal w_out_send      : std_logic := '0';
    signal w_in_byte_valid : std_logic := '0';
    signal r_in_byte       : std_logic := (others => 0);
    variable C_BAUD_RATE   : integer   := 100;
begin

    r_active_coeffs <= c_presets(to_integer(unsigned(sw(1 downto 0))));

    tx : entity work.uart_tx 
        generic map (
        g_clks_per_bit => C_BAUD_RATE
        )
        port map (
            i_clock => i_clock,
            i_reset => i_btnC,
            i_valid => w_out_send,
            i_data  => r_out_byte,
            o_tx    => o_uart_tx,
            o_ready => w_tx_ready
        );

    rx : entity work.uart_rx
        generic map (
            g_clks_per_bit => C_BAUD_RATE
        )
        port map (
            i_clk         => i_clock,
            i_reset       => i_btnC,
            i_rx          => i_uart_rx,
            o_data        => r_in_byte, -- packets in form 1sssssss 0ppppppp 0ppppppp where 's' is index and 'p' is data
            o_rx_valid    => w_in_byte_valid,
            o_rx_ready    => w_rx_ready,
            o_frame_error => w_rx_error
        );

    process (i_clock)
        variable v_sum    : signed(c_acc_width - 1 downto 0);
        variable v_scaled : signed(c_acc_width - 1 downto 0);
    begin
        if rising_edge(i_clock) then
            if i_btnC = '1' then
                r_state        <= S_WAIT_HEADER;
                w_out_send     <= '0';
                r_out_byte     <= (others => '0');
                r_samples      <= (others => (others => '0'));
                r_result       <= (others => '0');
            else
                w_out_send <= '0';  
                
                case r_state is
                    when S_WAIT_HEADER =>
                        if w_in_byte_valid = '1' and r_in_byte(7) = '1' then
                            r_packet_index <= r_in_byte;
                            r_state <= S_WAIT_MSB;
                        end if;

                    when S_WAIT_MSB =>
                        if w_in_byte_valid = '1' then
                            if  r_in_byte(7) = '0' then
                                r_sample_msb <= r_in_byte(6 downto 0);
                                r_state <= S_WAIT_LSB;
                            else
                                r_packet_index <= r_in_byte;
                            end if;
                        end if;

                    when S_WAIT_LSB =>
                        if w_in_byte_valid = '1' then
                            if  r_in_byte(7) = '0' then
                                r_samples <= r_sample_msb & r_in_byte(6 downto 0);
                                
                                for i in 1 to (c_n_stages - 1) downto 1 loop
                                    r_samples(i) <= r_samples(i - 1);
                                end loop;
                                
                                r_state <= S_FIR_CALC;
                            else
                                r_packet_index <= r_in_byte;
                                r_state <= S_WAIT_MSB;
                            end if;
                        end if;

                    when S_FIR_CALC =>
                        v_sum := (others => '0');
                        
                        for i in 0 to (c_n_stages - 1) downto 1 loop
                            v_sum := v_sum + resize(r_samples(i) * r_active_coeffs(i), c_acc_width);
                        end loop;
                        
                        v_scaled := shift_right(v_sum, c_frac_bits);
                        
                        -- saturation logic
                        if v_scaled < 0 then
                            r_result <= (others => '0');
                        elsif v_scaled > 16383 then
                            r_result <= to_unsigned(16383, 14);
                        else
                            r_result <= unsigned(v_scaled(13 downto 0));
                        end if;
                        
                        r_state <= S_TX_START;

                    when S_TX_START =>
                        if w_tx_ready = '1' then
                            case r_tx_count is
                                when 0 =>
                                    r_out_byte <= r_packet_index;
                                when 1 =>
                                    r_out_byte <= '0' & r_result(13 downto 7);
                                when 2 =>
                                    r_out_byte <= '0' & r_result(6 downto 0);
                            end case;
                            
                            w_out_send <= '1';
                            r_state <= S_TX_WAIT;
                        end if;

                    when S_TX_WAIT =>
                    if w_tx_ready = '1' then
                        if r_tx_count = 2 then
                            r_tx_count <= 0;
                            r_state <= S_WAIT_HEADER;
                        else
                            r_tx_count <= r_tx_count + 1;
                            r_state <= S_TX_START;
                        end if;
                    end if;
                end case;
            end if;
        end if;
    end process;
end rtl;