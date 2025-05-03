library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity apb_testbench is

end apb_testbench;


architecture tb_arch of apb_testbench is
    -- Clock and Reset signals
    signal PCLK     : std_logic := '0';
    signal PRESETn  : std_logic := '0';

    -- APB signals
    signal PSEL     : std_logic := '0';
    signal PENABLE  : std_logic := '0';
    signal PWRITE   : std_logic := '0';
    signal PADDR    : std_logic_vector(11 downto 0) := (others => '0');
    signal PWDATA   : std_logic_vector(31 downto 0) := (others => '0');
    signal PRDATA   : std_logic_vector(31 downto 0);
    signal PREADY   : std_logic;
    signal PSLVERR  : std_logic;

	CONSTANT num_i2c : integer := 32;
    signal SDA      : std_logic_vector(num_i2c-1 downto 0);
    signal SCL      : std_logic_vector(num_i2c-1 downto 0);

    -- Clock generation
    constant CLK_PERIOD : time := 10 ns;


component apb_i2c_interface
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
		
        SDA     : inout std_logic_vector(num_i2c downto 0);
        SCL     : inout std_logic_vector(num_i2c downto 0)
    );
end component;



begin

    uut: apb_i2c_interface
       generic map (
	        num_i2c => num_i2c,
            input_clk => 50_000_000,
            bus_clk   => 400_000			
	   )
	   
	   port map ( 
          PCLK => PCLK,
          PRESETn => PRESETn,
          PSEL    => PSEL,
          PENABLE => PENABLE,
          PWRITE  => PWRITE,
          PADDR   => PADDR,
          PWDATA  => PWDATA,
          PSLVERR => PSLVERR,
	  PRDATA  => PRDATA,
          PREADY  => PREADY,

          SDA     => SDA,
          SCL     => SCL
    );

    -- Clock process
    clk_process: process
    begin
        while true loop
            PCLK <= not PCLK;
            wait for CLK_PERIOD / 2;
        end loop;
    end process;

    -- Test stimulus
    stimulus_process: process
    begin
        -- Reset the system
        PRESETn <= '0';
        wait for 20 ns;
        PRESETn <= '1';
        wait for 20 ns;


        -- APB write number of elements we only support 0 and 1 here
        -- If 0 then we only write the slaveaddr and regaddr

		-- SET ENA = 0
        PSEL    <= '1';
        PWRITE  <= '1';
        PADDR   <= x"000";       -- ENA address
        PWDATA  <= x"00000000";  -- ENA DATA
        PENABLE <= '0';
        wait for 10 ns;
        PENABLE <= '1';
        wait for 10 ns;
        PSEL    <= '0';
        PENABLE <= '0';
        
		 -- APB set RW to write i.e. all 0 
        PSEL    <= '1';
        PWRITE  <= '1';
        PADDR   <= x"004";        -- 
        PWDATA  <= x"00000000";   -- 
        PENABLE <= '0';
        wait for 10 ns;
        PENABLE <= '1';
        wait for 10 ns;
        PSEL    <= '0';
        PENABLE <= '0';
		
		for i in 0 to 10 loop 
		
        -- APB write slave address		
        PSEL    <= '1';
        PWRITE  <= '1';
        PADDR   <= std_logic_vector(to_unsigned(8 + i*128, 12));         -- Register to set slave address
        PWDATA  <= x"000000AD";   -- i2c slave address
        PENABLE <= '0';
        wait for 10 ns;
        PENABLE <= '1';
        wait for 10 ns;
        PSEL    <= '0';
        PENABLE <= '0';
        wait for 10 ns;
		
		
        
        -- APB write register number
        PSEL    <= '1';
        PWRITE  <= '1';
        PADDR   <= std_logic_vector(to_unsigned(12 + i*128, 12));        -- Register to set register
        PWDATA  <= x"00000099";   -- Register number
        PENABLE <= '0';
        wait for 10 ns;
        PENABLE <= '1';
        wait for 10 ns;
        PSEL    <= '0';
        PENABLE <= '0';

        -- APB write data
        PSEL    <= '1';
        PWRITE  <= '1';
        PADDR   <= std_logic_vector(to_unsigned(16 + i*128, 12));        -- Register to set data
        PWDATA  <= x"00000023";   -- Data
        PENABLE <= '0';
        wait for 10 ns;
        PENABLE <= '1';
        wait for 10 ns;
        PSEL    <= '0';
        PENABLE <= '0';

		-- Number of Values to write 
		-- only 0 and 1 supported right now
        -- 0 means only slave, reg is sent
		-- 1 means slave, reg and data is sent
		
        PSEL    <= '1';
        PWRITE  <= '1';
        PADDR   <= std_logic_vector(to_unsigned(20 + i*128, 12));        -- number items to write
        PWDATA  <= x"00000001";  -- 
        PENABLE <= '0';
        wait for 10 ns;
        PENABLE <= '1';
        wait for 10 ns;
        PSEL    <= '0';
        PENABLE <= '0';

        end loop; 
		

        -- APB ENABLE ENA ONLY ONE I2C lower 8
        PSEL    <= '1';
        PWRITE  <= '1';
        PADDR   <= x"000";        -- Example address
        PWDATA  <= x"000000FF";  -- i2c slave address
        PENABLE <= '0';
        wait for 10 ns;
        PENABLE <= '1';
        wait for 10 ns;
        PSEL    <= '0';
        PENABLE <= '0';

        -- APB write ena 0
        PSEL    <= '1';
        PWRITE  <= '1';
        PADDR   <= x"000";        -- Example address
        PWDATA  <= x"00000000";  -- i2c slave address
        PENABLE <= '0';
        wait for 10 ns;
        PENABLE <= '1';
        wait for 10 ns;
        PSEL    <= '0';
        PENABLE <= '0';



	wait for 100000 ns;

        -- now we read data from the I2C 
	
        PSEL    <= '1';
        PWRITE  <= '1';
        PADDR   <= x"014";       -- number items to read
        PWDATA  <= x"00000001";  -- i2c slave address
        PENABLE <= '0';
        wait for 10 ns;
        PENABLE <= '1';
        wait for 10 ns;
        PSEL    <= '0';
        PENABLE <= '0';

        -- set RW to 1

        PSEL    <= '1';
        PWRITE  <= '1';
        PADDR   <= x"084";       -- Example address
        PWDATA  <= x"00000099";  -- i2c slave address
        PENABLE <= '0';
        wait for 10 ns;
        PENABLE <= '1';
        wait for 10 ns;
        PSEL    <= '0';
        PENABLE <= '0';


        -- APB write ena 1 -- we leave everything else as is
        PSEL    <= '1';
        PWRITE  <= '1';
        PADDR   <= x"000";        -- Example address
        PWDATA  <= x"00000002";  -- i2c slave address
        PENABLE <= '0';
        wait for 10 ns;
        PENABLE <= '1';
        wait for 10 ns;
        PSEL    <= '0';
        PENABLE <= '0';


       -- APB write ena 0
        PSEL    <= '1';
        PWRITE  <= '1';
        PADDR   <= x"000";        -- Example address
        PWDATA  <= x"00000000";  -- i2c slave address
        PENABLE <= '0';
        wait for 10 ns;
        PENABLE <= '1';
        wait for 10 ns;
        PSEL    <= '0';
        PENABLE <= '0';


        wait;
    end process;
end tb_arch;
