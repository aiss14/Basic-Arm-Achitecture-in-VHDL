--------------------------------------------------------------------------------
--	Instruktionsadressregister-Modul fuer den HWPR-Prozessor
--------------------------------------------------------------------------------
--	Datum:		29.10.2013
--	Version:	0.1
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ArmTypes.INSTRUCTION_ID_WIDTH;
use work.ArmTypes.VCR_RESET;

entity ArmInstructionAddressRegister is
	port(
		IAR_CLK: in std_logic;
		IAR_RST: in std_logic;
		IAR_INC: in std_logic;
		IAR_LOAD: in std_logic;
		IAR_REVOKE: in std_logic;
		IAR_UPDATE_HB: in std_logic;
--------------------------------------------------------------------------------
--	INSTRUCTION_ID_WIDTH  ist ein globaler Konfigurationsparameter
--	zur Einstellung der Breite der Instruktions-IDs und damit der Tiefe
--	der verteilten Puffer. Eine Breite von 3 Bit genuegt fuer die 
--	fuenfstufige Pipeline definitiv.
--------------------------------------------------------------------------------
		IAR_HISTORY_ID: in std_logic_vector(INSTRUCTION_ID_WIDTH - 1 downto 0);
		IAR_ADDR_IN: in std_logic_vector(31 downto 2);
		IAR_ADDR_OUT: out std_logic_vector(31 downto 2);
		IAR_NEXT_ADDR_OUT: out std_logic_vector(31 downto 2)
	);
end entity ArmInstructionAddressRegister;

architecture behave of ArmInstructionAddressRegister is
	component ArmRamBuffer
		generic(
			ARB_ADDR_WIDTH: natural range 1 to 4 := 3;
			ARB_DATA_WIDTH: natural range 1 to 64 := 32
		);
		port(
			ARB_CLK: in std_logic;
			ARB_WRITE_EN: in std_logic;
			ARB_ADDR: in std_logic_vector(ARB_ADDR_WIDTH - 1 downto 0);
			ARB_DATA_IN: in std_logic_vector(ARB_DATA_WIDTH - 1 downto 0);          
			ARB_DATA_OUT: out std_logic_vector(ARB_DATA_WIDTH - 1 downto 0)
		);
	end component ArmRamBuffer;

	signal addr: std_logic_vector(31 downto 2) := (others => '0');
	signal incAddr: std_logic_vector(31 downto 2);
	signal nextAddr: std_logic_vector(31 downto 2);
	signal historyBufferOut: std_logic_vector(31 downto 2);
begin
	IAR_HISTORY_BUFFER: ArmRamBuffer 
		generic map(
			ARB_ADDR_WIDTH => INSTRUCTION_ID_WIDTH,
			ARB_DATA_WIDTH => 30
		)
		port map(
			ARB_CLK => IAR_CLK,
			ARB_WRITE_EN => IAR_UPDATE_HB,
			ARB_ADDR => IAR_HISTORY_ID,
			ARB_DATA_IN => addr,
			ARB_DATA_OUT => historyBufferOut
		);
	
	incAddr <= std_logic_vector(unsigned(addr) + 1); -- Calculate address + 1
	nextAddr <= IAR_ADDR_IN when IAR_LOAD = '1' -- Use the external address input
		else incAddr when IAR_INC = '1' -- Use the incremented address
		else addr; -- Don't change the address

	IAR_ADDR_OUT <= addr; -- Output the current addresss
	IAR_NEXT_ADDR_OUT <= historyBufferOut when IAR_REVOKE = '1' else incAddr; -- Output the next address
	
	process (IAR_CLK) begin
		if rising_edge(IAR_CLK) then
			if IAR_RST = '1' then
				addr <= (others => '0');
			else
				addr <= nextAddr;
			end if;
		end if;
	end process;
end architecture behave;
