--------------------------------------------------------------------------------
--	Schnittstelle zur Anbindung des RAM an die Busse des HWPR-Prozessors
--------------------------------------------------------------------------------
--	Datum:		??.??.2013
--	Version:	?.?
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

library work;
use work.ArmConfiguration.all;

entity ArmMemInterface is
	generic(
--------------------------------------------------------------------------------
--	Beide Generics sind fuer das HWPR nicht relevant und koennen von
--	Ihnen ignoriert werden.
--------------------------------------------------------------------------------
		SELECT_LINES				: natural range 0 to 2 := 1;
		EXTERNAL_ADDRESS_DECODING_INSTRUCTION : boolean := false);
	port (  RAM_CLK	:  in  std_logic;
		--	Instruction-Interface	
       		IDE		:  in std_logic;	
			IA		:  in std_logic_vector(31 downto 2);
			ID		: out std_logic_vector(31 downto 0);	
			IABORT	: out std_logic;
		--	Data-Interface
			DDE		:  in std_logic;
			DnRW	:  in std_logic;
			DMAS	:  in std_logic_vector(1 downto 0);
			DA 		:  in std_logic_vector(31 downto 0);
			DDIN	:  in std_logic_vector(31 downto 0);
			DDOUT	: out std_logic_vector(31 downto 0);
			DABORT	: out std_logic);
end entity ArmMemInterface;

architecture behave of ArmMemInterface is	
 signal a : std_logic;	--for the alignement
       signal web : std_logic_vector(3 downto 0);
       signal doa, dob : std_logic_vector(31 downto 0); -- in RAM
       signal position : std_logic_vector(1 downto 0); --for the position of the byte
    
begin	
    INTERFACE  : entity.work.ArmRAMB_4kx32
                port map(   RAM_CLK => RAM_CLK,
                            ENA   =>  IDE,
                            ADDRA => IA(13 down to 2),
                            WEB   => web,
                            ENB   => DDE,
                            ADDRB => DA(13 downto 2),
                            DIB   => DDIN,
                            DOA   => doa,
                            DOB   => dob,       
                             ); 
  process (DMAS, DA) begin
        case DMAS is
            when DMAS_BYTE => a <= '1'; 
            when DMAS_HWORD => a <= not DA(0); 
            when DMAS_WORD => a <= not DA(1) and not DA(0); 
            when others => a <= '0'; 
        end case;
    end process;
   process (DDE, DnRW,DMAS,DA,a) is
    begin
        if DDE = '1' and DnRW = '1' and aligned = '1' then
            position := DA(1 downto 0); -- Storing the last two bytes 
    
            -- Enabling different bytes in writing
            case DMAS is
                when DMAS_HWORD =>
                    case position is
                        when "00" => web <= "0011"; -- Write the lower half word
                        when "10" => web <= "1100"; -- Write the upper half word
                        when others => web <= "0000";
                    end case;
                when DMAS_BYTE =>
                    case position is
                        when "00" => web <= "0001"; -- Write the first byte
                        when "01" => web <= "0010"; -- Write the second byte
                        when "10" => web <= "0100"; -- Write the third byte
                        when "11" => web <= "1000"; -- Write the fourth byte
                        when others => web <= "0000";
                    end case;
              
                when DMAS_WORD => web <= "1111"; -- Write the whole word
                when others => web <= "0000"; 
            end case;
        else
            web <= "0000";
        end if;
    end process;
    -- Abortion
    DABORT <= 'Z' when DDE = '0' else
        '1' when a = '0' else
        '0';
 -- Abortion instruction
    IABORT <= 'Z' when IDE = '0' else
        '1' when unsigned(IA) & "00" < unsigned(INST_LOW_ADDR) else
        '1' when unsigned(IA) & "00" > unsigned(INST_HIGH_ADDR) else
        '0';

   -- PortB Output
    DDOUT <= dob when DDE = '1' and DnRW = '0' else (others => 'Z');

    -- PortA Output
    ID <= doa when IDE = '1' else (others => 'Z');


end architecture behave;


