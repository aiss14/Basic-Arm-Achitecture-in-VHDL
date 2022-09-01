--------------------------------------------------------------------------------
--	Decoder zur Ermittlung der Instruktionsgruppe der aktuellen
--	Instruktion im der ID-Stufe im Kontrollpfad des HWPR-Prozessors.
--------------------------------------------------------------------------------
--	Datum:		??.??.2014
--	Version:	?.?
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

library work;
use work.ArmTypes.all;

--------------------------------------------------------------------------------
--	17 Instruktionsgruppen:
--	CD_UNDEFINED
--	CD_SWI
--	CD_COPROCESSOR
--	CD_BRANCH
--	CD_LOAD_STORE_MULTIPLE
--	CD_LOAD_STORE_UNSIGNED_IMMEDIATE
--	CD_LOAD_STORE_UNSIGNED_REGISTER
--	CD_LOAD_STORE_SIGNED_IMMEDIATE
--	CD_LOAD_STORE_UNSIGNED_REGISTER
--	CD_ARITH_IMMEDIATE
--	CD_ARITH_REGISTER
--	CD_ARITH_REGISTER_REGISTER
--	CD_MSR_IMMEDIATE
--	CD_MSR_REGISTER
--	CD_MRS
--	CD_MULTIPLY
--	CD_SWAP

-- 	UNDEFINED wird durch den Nullvektor angezeigt, die anderen
--	Befehlsgruppen durch einen 1-aus-16-Code.
--------------------------------------------------------------------------------

entity ArmCoarseInstructionDecoder is
	port(
		CID_INSTRUCTION		: in std_logic_vector(31 downto 0);
		CID_DECODED_VECTOR	: out std_logic_vector(15 downto 0)
	    );
end entity ArmCoarseInstructionDecoder;

architecture behave of ArmCoarseInstructionDecoder is
	signal CID_INSTRUCTION_7_4 : std_logic_vector(1 downto 0);
	signal CID_INSTRUCTION_23_21_20 : std_logic_vector(2 downto 0);
	signal CID_INSTRUCTION_20_6 : std_logic_vector(1 downto 0);

	signal DECV	: COARSE_DECODE_TYPE;
begin
	CID_INSTRUCTION_7_4 <= CID_INSTRUCTION(7) & CID_INSTRUCTION(4);
	CID_INSTRUCTION_23_21_20 <= CID_INSTRUCTION(23) & CID_INSTRUCTION(21 downto 20);
	CID_INSTRUCTION_20_6 <= CID_INSTRUCTION(20) & CID_INSTRUCTION(6);

	process (CID_INSTRUCTION, CID_INSTRUCTION_7_4, CID_INSTRUCTION_23_21_20, CID_INSTRUCTION_20_6) begin
		if Is_X(CID_INSTRUCTION) then
			-- If the instruction is invalid, use the undefined group
			DECV <= CD_UNDEFINED;
		else
			-- Check the instruction bits to choose a group
			case CID_INSTRUCTION(27 downto 25) is
				when "111" =>--x
					case CID_INSTRUCTION(24) is
						when '1' => DECV <= CD_SWI;--x
						when '0' => DECV <= CD_COPROCESSOR;--x
						when others => DECV <= CD_UNDEFINED;
					end case;
				when "110" => DECV <= CD_COPROCESSOR;--x
				when "101" => DECV <= CD_BRANCH;--x
				when "100" => DECV <= CD_LOAD_STORE_MULTIPLE;--x
				when "011" =>--x
					case CID_INSTRUCTION(4) is
						when '1' => DECV <= CD_UNDEFINED;
						when '0' => DECV <= CD_LOAD_STORE_UNSIGNED_REGISTER;--x
						when others => DECV <= CD_UNDEFINED;
					end case;
				when "010" => DECV <= CD_LOAD_STORE_UNSIGNED_IMMEDIATE;--x
				when "001" =>--x
					case CID_INSTRUCTION(24 downto 23) is
						when "10" =>--x
							case CID_INSTRUCTION(21 downto 20) is
								when "10" => DECV <= CD_MSR_IMMEDIATE;--x
								when "00" => DECV <= CD_UNDEFINED;
								when others => DECV <= CD_ARITH_IMMEDIATE;--x
							end case;
						when others => DECV <= CD_ARITH_IMMEDIATE;--x
					end case;
				when "000" =>--x
					case CID_INSTRUCTION_7_4 is
						when "11" =>--x
							case CID_INSTRUCTION(6 downto 5) is
								when "00" =>
									case CID_INSTRUCTION(24) is
										when '0' => DECV <= CD_MULTIPLY;
										when '1' =>
											case CID_INSTRUCTION_23_21_20 is
												when "000" => DECV <= CD_SWAP;
												when others => DECV <= CD_UNDEFINED;
											end case;
										when others => DECV <= CD_UNDEFINED;
									end case;
								when others =>--x
									case CID_INSTRUCTION_20_6 is
										when "01" => DECV <= CD_UNDEFINED;
										when others =>--x
											case CID_INSTRUCTION(22) is
												when '1' => DECV <= CD_LOAD_STORE_SIGNED_IMMEDIATE;--x
												when '0' => DECV <= CD_LOAD_STORE_SIGNED_REGISTER;--x
												when others => DECV <= CD_UNDEFINED;
											end case;
									end case;
							end case;
						when "10" =>
							case CID_INSTRUCTION(24 downto 23) is
								when "10" =>
									case CID_INSTRUCTION(20) is
										when '1' => DECV <= CD_ARITH_REGISTER;
										when '0' => DECV <= CD_UNDEFINED;
										when others => DECV <= CD_UNDEFINED;
									end case;
								when others => DECV <= CD_ARITH_REGISTER;
							end case;
						when "01" =>
							case CID_INSTRUCTION(24 downto 23) is
								when "10" =>
									case CID_INSTRUCTION(20) is
										when '1' => DECV <= CD_ARITH_REGISTER_REGISTER;
										when '0' => DECV <= CD_UNDEFINED;
										when others => DECV <= CD_UNDEFINED;
									end case;
								when others => DECV <= CD_ARITH_REGISTER_REGISTER;
							end case;
						when "00" =>--x
							case CID_INSTRUCTION(24 downto 23) is
								when "10" =>--x
									case CID_INSTRUCTION(20) is
										when '1' => DECV <= CD_ARITH_REGISTER;
										when '0' =>--x
											case CID_INSTRUCTION(21) is
												when '1' => DECV <= CD_MSR_REGISTER;--x
												when '0' => DECV <= CD_MRS;--x
												when others => DECV <= CD_UNDEFINED;
											end case;
										when others => DECV <= CD_UNDEFINED;
									end case;
								when others => DECV <= CD_ARITH_REGISTER;
							end case;
						when others => DECV <= CD_UNDEFINED;
					end case;
				when others => DECV <= CD_UNDEFINED;
			end case;
		end if;
	end process;

	CID_DECODED_VECTOR <= DECV;


--------------------------------------------------------------------------------
--	Test fuer die Verhaltenssimulation.
--------------------------------------------------------------------------------
-- synthesis translate_off
 	CHECK_NR_OF_SIGNALS : process(CID_INSTRUCTION,DECV)IS
 		variable NR : integer range 0 to 16 := 0;
 	begin
 		NR := 0;
 		for i in DECV'range loop
 			if DECV(i) = '1' then
 				NR := NR + 1;
 			end if;
 		end loop;
  		assert NR <= 1 report "Fehler in ArmCoarseInstructionDecoder: Instruktion nicht eindeutig erkannt." severity error;
 	end process CHECK_NR_OF_SIGNALS;
-- synthesis translate_on
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
end architecture behave;
