library ieee;
use ieee.std_logic_1164.all;
use ieee.math_real.ceil;
use ieee.math_real.log2;


entity ArmRAMB_4kx8 is
	generic (WIDTH : positive := 8;
			 SIZE  : positive := 4096);	
	port (RAM_CLK : in std_logic;
		ADDRA : in  std_logic_vector(integer(ceil(log2(real(SIZE))))-1 downto 0);
		DOA   : out std_logic_vector(WIDTH-1 downto 0);
		ENA	  : in  std_logic;
		ADDRB : in  std_logic_vector(integer(ceil(log2(real(SIZE))))-1 downto 0);
		DIB   : in  std_logic_vector(WIDTH-1 downto 0);
		DOB   : out std_logic_vector(WIDTH-1 downto 0);
		ENB	  : in  std_logic;
		WEB   : in  std_logic);
end entity ArmRAMB_4kx8;


architecture behavioral of ArmRAMB_4kx8 is
 signal ram : ram_type;
    type ram_type is array (SIZE - 1 downto 0) of std_logic_vector (WIDTH - 1 downto 0);
begin
  process (RAM_CLK) 
    begin
        -- Reading from PortA
        if RAM_CLK'event and RAM_CLK ='1' then
            if ENA = '1' then
                DOA <= ram(to_integer(unsigned(ADDRA)));
            end if;
        end if;
    end process;

    process (RAM_CLK) 
    begin
     -- Reading and Writing in/from PortB
        if RAM_CLK'event and RAM_CLK ='1' then
            -- Read from PortB
            if ENB = '1' then           
             DOB <= ram(to_integer(unsigned(ADDRB)));
            -- Write in PortB
                if WEB = '1' then
                    ram(to_integer(unsigned(ADDRB))) <= DIB;
                end if;
            end if;
        end if;
    end process;
end architecture behavioral;
		
-- Help from the Source:
-- https://www.xilinx.com/support/documentation/sw_manuals/xilinx2017_3/ug901-vivado-synthesis.pdf
-- Filename: ram_tdp_rf_rf.vhd (page 118-119)


		





