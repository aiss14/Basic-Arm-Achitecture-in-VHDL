--------------------------------------------------------------------------------
--	ALU des ARM-Datenpfades
--------------------------------------------------------------------------------
--	Datum:		??.??.14
--	Version:	?.?
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

library work;
use work.ArmTypes.all;

entity ArmALU is
    Port ( ALU_OP1 		: in	std_logic_vector(31 downto 0);
           ALU_OP2 		: in 	std_logic_vector(31 downto 0);           
    	   ALU_CTRL 	: in	std_logic_vector(3 downto 0);
    	   ALU_CC_IN 	: in	std_logic_vector(1 downto 0);
		   ALU_RES 		: out	std_logic_vector(31 downto 0);
		   ALU_CC_OUT	: out	std_logic_vector(3 downto 0)
   	);
end entity ArmALU;

architecture behave of ArmALU is
 
	-- Using Aliases for Condition-Code
        alias C_IN : std_logic is ALU_CC_IN(1);
	alias V_IN : std_logic is ALU_CC_IN(0);
	alias N_OUT : std_logic is ALU_CC_OUT(3);
        alias Z_OUT : std_logic is ALU_CC_OUT(2);
	alias C_OUT : std_logic is ALU_CC_OUT(1);
	alias V_OUT : std_logic is ALU_CC_OUT(0);
        -- the carries needed for the calculations
	signal car : std_logic_vector(31 downto 0) := (0 => C_IN, others => '0');
        signal not_car : std_logic_vector(31 downto 0) := (0 => not C_IN, others => '0');
        -- The result of calculations
	signal output_res : std_logic_vector(31 downto 0);
begin
	-- Doing the calculations
	process (ALU_CTRL, ALU_OP1, ALU_OP2, C_IN) is

	begin

		case ALU_CTRL is
                        when OP_ADC => output_res <= std_logic_vector(unsigned(ALU_OP1) + unsigned(ALU_OP2) + unsigned(car));
			when OP_SBC => output_res <= std_logic_vector(unsigned(ALU_OP1) - unsigned(ALU_OP2) - unsigned(not_car));
			when OP_RSC => output_res <= std_logic_vector(unsigned(ALU_OP2) - unsigned(ALU_OP1) - unsigned(not_car));
			when OP_SUB | OP_CMP => output_res <= std_logic_vector(unsigned(ALU_OP1) - unsigned(ALU_OP2));
			when OP_RSB => output_res <= std_logic_vector(unsigned(ALU_OP2) - unsigned(ALU_OP1));
			when OP_ADD | OP_CMN => output_res <= std_logic_vector(unsigned(ALU_OP1) + unsigned(ALU_OP2));
			when OP_ORR => output_res <= ALU_OP1 or ALU_OP2;
                        when OP_BIC => output_res <= ALU_OP1 and not ALU_OP2;
                        when OP_AND | OP_TST => output_res <= ALU_OP1 and ALU_OP2;
			when OP_EOR | OP_TEQ => output_res <= ALU_OP1 xor ALU_OP2;
			when OP_MOV => output_res <= ALU_OP2;
			when OP_MVN => output_res <= not ALU_OP2;
			when others => output_res <= (others => '0');
		end case;
	end process;

	Z_OUT <= '1' when unsigned(result) = 0 else '0';
        N_OUT <= result(31);

	-- Updating Carry/Overflow
	process (ALU_CTRL, ALU_OP1(31), ALU_OP2(31), result(31), C_IN, V_IN) is
                alias z : std_logic is result(31);
                alias b : std_logic is ALU_OP2(31);
		alias a : std_logic is ALU_OP1(31);
	begin
		case ALU_CTRL is
                        --Addition
			when OP_ADD | OP_CMN | OP_ADC =>
                                --Carry
				C_OUT <= (a and b) or (not a and b and not z) or (a and not b and not z);
				--Overflow/Underflow
				V_OUT <= (not a and not b and z) or (a and b and not z);
                        --Subtraction
			when OP_SUB | OP_CMP | OP_SBC => -- Subtract
				--Carry
				C_OUT <= (a and not b) or (a and b and not z) or (not a and not b and not z);
                                --Overflow/Underflow
				V_OUT <= (a and not b and not z) or (not a and b and z);
			when OP_RSB | OP_RSC => 
				C_OUT <= (b and not a) or (b and a and not z) or (not b and not a and not z);
				V_OUT <= (b and not a and not z) or (not b and a and z);
			when others => 
				C_OUT <= C_IN;
				V_OUT <= V_IN;
		end case;
	end process;
	ALU_RES <= output_res; --result
end architecture behave;
