--------------------------------------------------------------------------------
--
--   FileName:         apb_i2c_interface.vhd
--   Dependencies:     none
--   Design Software:  
----
--   Version History
--   Version 1.0.0 05/02/2025 Andreas Falkenberg
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity apb_i2c_interface is
    generic (
        num_i2c   : integer := 32;
        input_clk : INTEGER := 50_000_000; --input clock speed from user logic in Hz
        bus_clk   : INTEGER := 400_000     --speed the i2c bus (scl) will run at in Hz
    );

    port (
        -- APB interface signals
        PCLK    : in  std_logic; -- APB clock
        PRESETn : in  std_logic; -- APB reset (active low)
        PSEL    : in  std_logic; -- APB select
        PENABLE : in  std_logic; -- APB enable
        PWRITE  : in  std_logic; -- APB write enable
        PADDR   : in  std_logic_vector(11 downto 0); -- APB address bus
        PWDATA  : in  std_logic_vector(31 downto 0); -- APB write data bus
        PSLVERR : out std_logic; -- set to true by default		
        PRDATA  : out std_logic_vector(31 downto 0); -- APB read data bus
        PREADY  : out std_logic; -- APB ready signal
		
        SDA     : inout std_logic_vector(num_i2c-1 downto 0);
        SCL     : inout std_logic_vector(num_i2c-1 downto 0)
    );
end entity apb_i2c_interface;

architecture Behavioral of apb_i2c_interface is

component i2c_master
generic (
    input_clk : INTEGER;
    bus_clk   : INTEGER 
    );
port (
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
    num_read  : IN     STD_LOGIC_VECTOR(7 downto 0); -- only 000 to 111 implemented though
    read_ready: OUT    STD_LOGIC;                    --shows that data_rd is valid during this time	
    ack_error : OUT    STD_LOGIC;                    --flag if improper acknowledge from slave

    sda_in    : IN     STD_LOGIC;                    --serial data output of i2c bus
    sda_out   : OUT    STD_LOGIC;                    --serial data output of i2c bus    
    scl_in    : IN     STD_LOGIC;
    scl_out   : OUT    STD_LOGIC                     --serial clock output of i2c bus
);                  
end component;

    signal ena      : STD_LOGIC_VECTOR(num_i2c-1 downto 0);  --latch in command

    type addrType is array (num_i2c-1 downto 0) of std_logic_vector(6 downto 0);
    signal addr     : addrType; --address of target slave

    signal rw       : STD_LOGIC_VECTOR(num_i2c-1 downto 0);  --'0' is write, '1' is read
    
	type arrayType is array (num_i2c-1 downto 0) of std_logic_vector(7 downto 0);
	signal data_wr    : arrayType; 
    signal data_rd_0  : arrayType; 
    signal data_rd_1  : arrayType; 
    signal data_rd_2  : arrayType; 
    signal data_rd_3  : arrayType; 
    signal data_rd_4  : arrayType; 
    signal data_rd_5  : arrayType; 
    signal data_rd_6  : arrayType; 
    signal data_rd_7  : arrayType; 

    signal reg_wr     : arrayType; 
    signal data_next  : STD_LOGIC_VECTOR(num_i2c-1 downto 0);       
    signal busy       : STD_LOGIC_VECTOR(num_i2c-1 downto 0);   --indicates transaction in progress
    signal ack_error  : STD_LOGIC_VECTOR(num_i2c-1 downto 0);   
    signal read_ready : STD_LOGIC_VECTOR(num_i2c-1 downto 0);   
    signal sda_in     : STD_LOGIC_VECTOR(num_i2c-1 downto 0); 
    signal sda_out    : STD_LOGIC_VECTOR(num_i2c-1 downto 0); 
    signal scl_in     : STD_LOGIC_VECTOR(num_i2c-1 downto 0); 
    signal scl_out    : STD_LOGIC_VECTOR(num_i2c-1 downto 0); 
    signal num_read   : arrayType;

begin

GEN_I2C: for i in 0 to num_i2c-1 generate

    i2c_component: i2c_master
    generic map (
        input_clk => input_clk,
        bus_clk   => bus_clk
    )
    port map (
		clk       => PCLK,
	    reset_n   => PRESETn,
	    ena       => ena(i),
	    addr      => addr(i),
	    rw        => rw(i),
        reg_wr    => reg_wr(i),
	    data_wr   => data_wr(i),
        data_next => data_next(i),
	    
        busy      => busy(i),
	    data_rd_0 => data_rd_0(i),
        data_rd_1 => data_rd_1(i),
        data_rd_2 => data_rd_2(i),
        data_rd_3 => data_rd_3(i),
        data_rd_4 => data_rd_4(i),
        data_rd_5 => data_rd_5(i),
        data_rd_6 => data_rd_6(i),
        data_rd_7 => data_rd_7(i),
        num_read  => num_read(i),

        read_ready => read_ready(i),
        ack_error  => ack_error(i),

        sda_in     => sda_in(i),
        sda_out   => sda_out(i),
        scl_in    => scl_in(i),
        scl_out   => scl_out(i)
        );
end generate GEN_I2C;


    process (PCLK, PRESETn)
    begin
        if PRESETn = '0' then
            ena         <= (others => '0');
            addr        <= (others => (others => '0'));
            rw          <= (others => '0');
            reg_wr      <= (others => (others => '0'));
            data_wr     <= (others => (others => '0'));	
	        num_read    <= (others => (others => '0'));

			PRDATA    <= (others => '0');
			PREADY    <= '0';               
			PSLVERR   <= '0';
			
        elsif rising_edge(PCLK) then
            PREADY <= '0'; -- Default ready signal

            if PSEL = '1' and PENABLE = '1' then
                if PWRITE = '1' then
                    -- Write operation
                    if PADDR = x"000" then
			            ena <= PWDATA(num_i2c-1 downto 0);
		            elsif PADDR = x"004" then
			            rw <= PWDATA(num_i2c-1 downto 0);
					elsif PADDR(6 downto 0) = "0001000" then
			            addr(to_integer(unsigned(PADDR(11 downto 7))))    <= PWDATA(6 downto 0);
                    elsif PADDR(6 downto 0) = "0001100" then
						reg_wr(to_integer(unsigned(PADDR(11 downto 7))))  <= PWDATA(7 downto 0);
                    elsif PADDR(6 downto 0) = "0010000" then
                        data_wr(to_integer(unsigned(PADDR(11 downto 7)))) <= PWDATA(7 downto 0);
                    elsif PADDR(6 downto 0) = "0010100" then
                        num_read(to_integer(unsigned(PADDR(11 downto 7)))) <= PWDATA(7 downto 0);              
					end if;
				else
					-- Read operation
					if PADDR = x"000" then
						PRDATA(num_i2c-1 downto 0) <= ena;
						PRDATA(31 downto num_i2c) <= (others => '0');
					elsif PADDR = x"004" then 
						PRDATA(num_i2c - 1 downto 0) <= rw;
						PRDATA(31 downto num_i2c) <= (others => '0');		
					elsif PADDR(6 downto 0) = "0001000" then 
						PRDATA(6 downto 0) <= addr(to_integer(unsigned(PADDR(11 downto 7))));
						PRDATA(31 downto 7) <= (others => '0');               
					elsif PADDR(6 downto 0) = "0001100" then 
						PRDATA(7 downto 0) <= reg_wr(to_integer(unsigned(PADDR(11 downto 7))));
						PRDATA(31 downto 8) <= (others => '0');
					elsif PADDR(6 downto 0) = "0010000" then 
						PRDATA(7 downto 0) <= data_wr(to_integer(unsigned(PADDR(11 downto 7))));
						PRDATA(31 downto 8) <= (others => '0');
					elsif PADDR(6 downto 0) = "0010100" then 
						PRDATA(7 downto 0) <= num_read(to_integer(unsigned(PADDR(11 downto 7))));
						PRDATA(31 downto 8) <= (others => '0');              
					
					elsif PADDR = x"018" then 
						PRDATA(num_i2c-1 downto 0) <= busy;
						PRDATA(31 downto num_i2c) <= (others => '0');
					elsif PADDR = x"01C" then 
						PRDATA(num_i2c-1 downto 0) <= data_next;		      
						PRDATA(31 downto num_i2c) <= (others => '0');
					elsif PADDR = x"020" then 
						PRDATA(num_i2c-1 downto 0) <= read_ready;
						PRDATA(31 downto num_i2c) <= (others => '0');
					elsif PADDR = x"024" then 
						PRDATA(num_i2c-1 downto 0) <= ack_error;
						PRDATA(31 downto num_i2c) <= (others => '0');
					
					elsif PADDR(6 downto 0) = "1000000" then 
						PRDATA(7 downto 0) <= data_rd_0(to_integer(unsigned(PADDR(11 downto 7))));
						PRDATA(31 downto 8) <= (others => '0');
					elsif PADDR(6 downto 0) = "1000100" then 
						PRDATA(7 downto 0) <= data_rd_1(to_integer(unsigned(PADDR(11 downto 7))));
						PRDATA(31 downto 8) <= (others => '0');
					elsif PADDR(6 downto 0) = "1001000" then 
						PRDATA(7 downto 0) <= data_rd_2(to_integer(unsigned(PADDR(11 downto 7))));
						PRDATA(31 downto 8) <= (others => '0');
					elsif PADDR(6 downto 0) = "1001100" then 
						PRDATA(7 downto 0) <= data_rd_3(to_integer(unsigned(PADDR(11 downto 7))));
						PRDATA(31 downto 8) <= (others => '0');
					elsif PADDR(6 downto 0) = "1010000" then 
						PRDATA(7 downto 0) <= data_rd_4(to_integer(unsigned(PADDR(11 downto 7))));
						PRDATA(31 downto 8) <= (others => '0');
					elsif PADDR(6 downto 0) = "1010100" then 
						PRDATA(7 downto 0) <= data_rd_5(to_integer(unsigned(PADDR(11 downto 7))));
						PRDATA(31 downto 8) <= (others => '0');
					elsif PADDR(6 downto 0) = "1011000" then 
						PRDATA(7 downto 0) <= data_rd_6(to_integer(unsigned(PADDR(11 downto 7))));
						PRDATA(31 downto 8) <= (others => '0');
					elsif PADDR(6 downto 0) = "1011100" then 
						PRDATA(7 downto 0) <= data_rd_7(to_integer(unsigned(PADDR(11 downto 7))));
						PRDATA(31 downto 8) <= (others => '0');                
					end if;	
				end if;
				PREADY <= '1'; -- Indicate ready
			end if;
		end if;
    end process;
	
	
    -- tristate solution 
GEN_OUTPUT: for i in 0 to num_i2c-1 generate

    SCL(i) <= '0' WHEN scl_out(i) = '0' ELSE 'Z';
    SDA(i) <= '0' WHEN sda_out(i) = '0' ELSE 'Z';
    scl_in(i) <= SCL(i);
    sda_in(i) <= SDA(i);

end generate GEN_OUTPUT;
	
end architecture Behavioral;
