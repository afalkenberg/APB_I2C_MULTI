--------------------------------------------------------------------------------
--
--   FileName:         i2c_master.vhd
--
--
--   Version History
--   This code originate from Scott Larsen. 
--   Nevertheles there were many features and changes added 
--   by Andreas Falkenberg 05/02/2025
--------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_unsigned.all;
USE ieee.NUMERIC_STD.all;

ENTITY i2c_master IS
  GENERIC(
    input_clk : INTEGER := 50_000_000; --input clock speed from user logic in Hz
    bus_clk   : INTEGER := 400_000);   --speed the i2c bus (scl) will run at in Hz
  PORT(
    clk       : IN     STD_LOGIC;                    --system clock
    reset_n   : IN     STD_LOGIC;                    --active low reset
    ena       : IN     STD_LOGIC;                    --latch in command
    addr      : IN     STD_LOGIC_VECTOR(6 DOWNTO 0); --address of target slave
    rw        : IN     STD_LOGIC;                    --'0' is write, '1' is read
    reg_wr    : IN     STD_LOGIC_VECTOR(7 DOWNTO 0);
    data_wr   : IN     STD_LOGIC_VECTOR(7 DOWNTO 0); --data to write to slave
    data_next : OUT    STD_LOGIC;                    --write the next input 

    busy      : OUT    STD_LOGIC;                    --indicates transaction in progress

    data_rd_0 : OUT    STD_LOGIC_VECTOR(7 DOWNTO 0); --data read from slave
    data_rd_1 : OUT    STD_LOGIC_VECTOR(7 DOWNTO 0); --data read from slave
    data_rd_2 : OUT    STD_LOGIC_VECTOR(7 DOWNTO 0); --data read from slave
    data_rd_3 : OUT    STD_LOGIC_VECTOR(7 DOWNTO 0); --data read from slave
    data_rd_4 : OUT    STD_LOGIC_VECTOR(7 DOWNTO 0); --data read from slave
    data_rd_5 : OUT    STD_LOGIC_VECTOR(7 DOWNTO 0); --data read from slave
    data_rd_6 : OUT    STD_LOGIC_VECTOR(7 DOWNTO 0); --data read from slave
    data_rd_7 : OUT    STD_LOGIC_VECTOR(7 DOWNTO 0); --data read from slave
    num_read  : IN     STD_LOGIC_VECTOR(7 downto 0); -- only 1 to 8 valid
    read_ready: OUT    STD_LOGIC;                    --shows that data_rd is valid during this time	
    
    ack_error : OUT    STD_LOGIC;                    --flag if improper acknowledge from slave

    sda_in    : IN     STD_LOGIC;                    --serial data output of i2c bus
    sda_out   : OUT    STD_LOGIC;                    --serial data output of i2c bus    
    
    scl_in    : IN     STD_LOGIC;
    scl_out   : OUT    STD_LOGIC                     --serial clock output of i2c bus
);                  

END i2c_master;

ARCHITECTURE logic OF i2c_master IS
  CONSTANT divider  :  INTEGER := (input_clk/bus_clk)/4; --number of clocks in 1/4 cycle of scl
  TYPE machine IS(ready, start, command, slv_ack1, wr1, wr2, rd, slv_ack2, mstr_ack, stop); --needed states
  SIGNAL state         : machine;                        --state machine
  SIGNAL data_clk      : STD_LOGIC;                      --data clock for sda
  SIGNAL data_clk_prev : STD_LOGIC;                      --data clock during previous system clock
  SIGNAL scl_clk       : STD_LOGIC;                      --constantly running internal scl
  SIGNAL scl_ena       : STD_LOGIC := '0';               --enables internal scl to output
  SIGNAL sda_intern    : STD_LOGIC := '1';               --internal sda
  SIGNAL sda_ena_n     : STD_LOGIC;                      --enables internal sda to output
  SIGNAL addr_rw       : STD_LOGIC_VECTOR(7 DOWNTO 0);   --latched in address and read/write
  SIGNAL data_tx       : STD_LOGIC_VECTOR(7 DOWNTO 0);   --latched in data to write to slave
  SIGNAL data_rx       : STD_LOGIC_VECTOR(7 DOWNTO 0);   --data received from slave
  SIGNAL bit_cnt       : INTEGER RANGE 0 TO 7 := 7;      --tracks bit number in transaction
  SIGNAL stretch       : STD_LOGIC := '0';               --identifies if slave is stretching scl
  SIGNAL ena_int       : STD_LOGIC := '0';               --internal ena signal
  SIGNAL ack_error_intern : STD_LOGIC := '0';               --internal ena signal
  SIGNAL read_counter  : STD_LOGIC_VECTOR(7 downto 0);

  type memType is array (7 downto 0) of std_logic_vector(7 downto 0);

  SIGNAL data_read_array : memType;	
	 
BEGIN

  --generate the timing for the bus clock (scl_clk) and the data clock (data_clk)
  PROCESS(clk, reset_n)
    VARIABLE count  :  INTEGER RANGE 0 TO divider*4;  --timing for clock generation
  BEGIN
    IF(reset_n = '0') THEN                --reset asserted
      stretch <= '0';
      count := 0;
    ELSIF(clk'EVENT AND clk = '1') THEN
      data_clk_prev <= data_clk;          --store previous value of data clock
      IF(count = divider*4-1) THEN        --end of timing cycle
        count := 0;                       --reset timer
      ELSIF(stretch = '0') THEN           --clock stretching from slave not detected
        count := count + 1;               --continue clock generation timing
      END IF;
      CASE count IS
        WHEN 0 TO divider-1 =>            --first 1/4 cycle of clocking
          scl_clk  <= '0';
          data_clk <= '0';
        WHEN divider TO divider*2-1 =>    --second 1/4 cycle of clocking
          scl_clk  <= '0';
          data_clk <= '1';
        WHEN divider*2 TO divider*3-1 =>  --third 1/4 cycle of clocking
          scl_clk <= '1';                 --release scl
          IF(scl_in = '0') THEN              --detect if slave is stretching clock
            stretch <= '1';
          ELSE
            stretch <= '0';
          END IF;
          data_clk <= '1';
        WHEN OTHERS =>                    --last 1/4 cycle of clocking
          scl_clk <= '1';
          data_clk <= '0';
      END CASE;
    END IF;
  END PROCESS;

  -- take care of ena signal --	

  -- ena_int <= ena;

  PROCESS(clk, reset_n)
  BEGIN
    IF(reset_n = '0') THEN 
       ena_int <= '0';
    ELSIF(clk'EVENT AND clk = '1') THEN
       IF(ena = '1') THEN
          ena_int <= '1';
       ELSIF(ena = '0' AND (state = wr2)) THEN
          ena_int <= '0';
       ELSIF(ena = '0' AND (state = wr1) AND (num_read = "00000000")) THEN 
          ena_int <= '0';       
       ELSIF(ena = '0' AND (state = mstr_ack) AND (read_counter = num_read)) THEN
          ena_int <= '0';
       END IF;
    END IF;
  END PROCESS; 

  -- create control signals --

  PROCESS(clk, reset_n)
  BEGIN	
     IF(clk'EVENT AND clk = '1') THEN
        IF(state = mstr_ack) THEN 
           read_ready <= '1';
        ELSE
	   read_ready <= '0';
        END IF;

	IF(state = command) THEN 
           data_next <= '1';
        ELSE 
           data_next <= '0';
        END IF; 		

     END IF;
  END PROCESS;
 


  --state machine and writing to sda during scl low (data_clk rising edge)
  PROCESS(clk, reset_n)
  BEGIN
    IF(reset_n = '0') THEN                 --reset asserted
      state <= ready;                      --return to initial state
      busy <= '1';                         --indicate not available
      scl_ena    <= '0';                   --sets scl high impedance
      sda_intern <= '1';                   --sets sda high impedance
      ack_error_intern <= '0';             --clear acknowledge error flag
      bit_cnt <= 7;                        --restarts data bit counter
     

    ELSIF(clk'EVENT AND clk = '1') THEN
      IF(data_clk = '1' AND data_clk_prev = '0') THEN  --data clock rising edge
        CASE state IS
          WHEN ready =>                      --idle state
            IF(ena_int = '1') THEN           --transaction requested
              busy <= '1';                   --flag busy
              addr_rw <= addr & rw;          --collect requested slave address and command
              data_tx <= reg_wr;             --collect requested data to write
              state <= start;                --go to start bit

              read_counter <= (others => '0');

            ELSE                             --remain idle
              busy  <= '0';                  --unflag busy
              state <= ready;                --remain idle
            END IF;
          WHEN start =>                      --start bit of transaction
            busy <= '1';                     --resume busy if continuous mode
            sda_intern <= addr_rw(bit_cnt);  --set first address bit to bus
            state      <= command;                --go to command
          WHEN command =>                    --address and command byte of transaction
            IF(bit_cnt = 0) THEN             --command transmit finished
              sda_intern <= '1';             --release sda for slave acknowledge
              bit_cnt <= 7;                  --reset bit counter for "byte" states
              state <= slv_ack1;             --go to slave acknowledge (command)
            ELSE                             --next clock cycle of command state
              bit_cnt <= bit_cnt - 1;        --keep track of transaction bits
              sda_intern <= addr_rw(bit_cnt-1); --write address/command bit to bus
              state <= command;              --continue with command
            END IF;
          WHEN slv_ack1 =>                   --slave acknowledge bit (command)
            IF(addr_rw(0) = '0') THEN        --write command
              sda_intern <= data_tx(bit_cnt);   --write first bit of data
              state <= wr1;                   --go to write byte
            ELSE                             --read command
              sda_intern <= '1';             --release sda from incoming data
              state <= rd;                   --go to read byte
            END IF;
          WHEN wr1 =>                         --write byte of transaction
            busy <= '1';                     --resume busy if continuous mode
            IF(bit_cnt = 0) THEN             --write byte transmit finished
              sda_intern <= '1';                --release sda for slave acknowledge
              bit_cnt <= 7;                  --reset bit counter for "byte" states
              state <= slv_ack2;             --go to slave acknowledge (write)
            ELSE                             --next clock cycle of write state
              bit_cnt <= bit_cnt - 1;        --keep track of transaction bits
              sda_intern <= data_tx(bit_cnt-1); --write next bit to bus
              state <= wr1;                  --continue writing
            END IF;
         WHEN wr2 =>                         --write byte of transaction
            busy <= '1';                     --resume busy if continuous mode
            IF(bit_cnt = 0) THEN             --write byte transmit finished
              sda_intern <= '1';                --release sda for slave acknowledge
              bit_cnt <= 7;                  --reset bit counter for "byte" states
              state <= slv_ack2;             --go to slave acknowledge (write)
            ELSE                             --next clock cycle of write state
              bit_cnt <= bit_cnt - 1;        --keep track of transaction bits
              sda_intern <= data_tx(bit_cnt-1); --write next bit to bus
              state <= wr2;                  --continue writing
            END IF;
          WHEN rd =>                         --read byte of transaction
            busy <= '1';                     --resume busy if continuous mode
            IF(bit_cnt = 0) THEN             --read byte receive finished
              IF(ena_int = '1' AND addr_rw = addr & rw) THEN  --continuing with another read at same address
                sda_intern <= '0';              --acknowledge the byte has been received
              ELSE                           --stopping or continuing with a write
                sda_intern <= '1';           --send a no-acknowledge (before stop or repeated start)
              END IF;
              bit_cnt <= 7;                  --reset bit counter for "byte" states
              
              
              data_read_array(to_integer(unsigned(read_counter))) <= data_rx;            --output received data
	      read_counter <= read_counter + 1;	

              
	      state <= mstr_ack;             --go to master acknowledge
            ELSE                             --next clock cycle of read state
              bit_cnt <= bit_cnt - 1;        --keep track of transaction bits
              state <= rd;                   --continue reading
            END IF;
          WHEN slv_ack2 =>                   --slave acknowledge bit (write)
            IF(ena_int = '1') THEN           --continue transaction
              busy <= '0';                   --continue is accepted
              addr_rw <= addr & rw;          --collect requested slave address and command
              data_tx <= data_wr;            --collect requested data to write
              IF(addr_rw = addr & rw) THEN   --continue transaction with another write
                sda_intern <= data_wr(bit_cnt); --write first bit of data
                state <= wr2;                 --go to write byte
              ELSE                           --continue transaction with a read or new slave
                state <= start;              --go to repeated start
              END IF;
            ELSE                             --complete transaction
              state <= stop;                 --go to stop bit
            END IF;
          WHEN mstr_ack =>                   --master acknowledge bit after a read
	    IF(ena_int = '1') THEN           --continue transaction
              busy <= '0';                   --continue is accepted and data received is available on bus
              addr_rw <= addr & rw;          --collect requested slave address and command
              data_tx <= data_wr;            --collect requested data to write (not needed ?)
              IF(addr_rw = addr & rw) THEN   --continue transaction with another read
                sda_intern <= '1';              --release sda from incoming data
                state <= rd;                 --go to read byte
              ELSE                           --continue transaction with a write or new slave
                state <= start;              --repeated start
              END IF;    
            ELSE                             --complete transaction
              state <= stop;                 --go to stop bit
            END IF;
          WHEN stop =>                       --stop bit of transaction
            busy <= '0';                     --unflag busy
            state <= ready;                  --go to idle state
        END CASE;    
      ELSIF(data_clk = '0' AND data_clk_prev = '1') THEN  --data clock falling edge
        CASE state IS
          WHEN start =>                  
            IF(scl_ena = '0') THEN                  --starting new transaction
              scl_ena <= '1';                       --enable scl output
              ack_error_intern <= '0';              --reset acknowledge error output
            END IF;
          WHEN slv_ack1 =>                          --receiving slave acknowledge (command)
            IF(sda_in /= '0' OR ack_error_intern = '1') THEN  --no-acknowledge or previous no-acknowledge
              ack_error_intern <= '1';                     --set error output if no-acknowledge
            END IF;
          WHEN rd =>                                --receiving slave data
            data_rx(bit_cnt) <= sda_in;             --receive current slave data bit
          WHEN slv_ack2 =>                          --receiving slave acknowledge (write)
            IF(sda_in /= '0' OR ack_error_intern = '1') THEN  --no-acknowledge or previous no-acknowledge
              ack_error_intern <= '1';                     --set error output if no-acknowledge
            END IF;
          WHEN stop =>
            scl_ena <= '0';                         --disable scl
          WHEN OTHERS =>
            NULL;
        END CASE;
      END IF;
    END IF;
  END PROCESS;  

  --set sda output
  WITH state SELECT
    sda_ena_n <= data_clk_prev WHEN start,     --generate start condition
                 NOT data_clk_prev WHEN stop,  --generate stop condition
                 sda_intern WHEN OTHERS;          --set to internal sda signal    

  ack_error <= ack_error_intern;      
  --set scl and sda outputs

  scl_out <= '0' WHEN (scl_ena = '1' AND scl_clk = '0') ELSE '1';
  sda_out <= '0' WHEN sda_ena_n = '0' ELSE '1';
  

  -- tristate solution 
  -- scl <= '0' WHEN (scl_ena = '1' AND scl_clk = '0') ELSE 'Z';
  -- sda <= '0' WHEN sda_ena_n = '0' ELSE 'Z';

  data_rd_0 <= data_read_array(0);
  data_rd_1 <= data_read_array(1);
  data_rd_2 <= data_read_array(2);
  data_rd_3 <= data_read_array(3);
  data_rd_4 <= data_read_array(4);
  data_rd_5 <= data_read_array(5);
  data_rd_6 <= data_read_array(6);
  data_rd_7 <= data_read_array(7);

END logic;
