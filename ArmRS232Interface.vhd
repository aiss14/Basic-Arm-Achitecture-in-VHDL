--------------------------------------------------------------------------------
--  UART einer EIA-232-Schnittstelle des HWPR-Prozessorsystems.
--------------------------------------------------------------------------------
--  Datum:      ??.??.2013
--  Version:    ?.?
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library work;
	use work.ArmTypes.all;
	use work.ArmConfiguration.all;

--------------------------------------------------------------------------------
--  Funktionsweise der Schnittstellenkomponente zum Datenbus: 
--  Das Interface verfuegt ueber 4 sichbare Register:
--      Senderegister       (RS232_TRM_REG)
--      Empfangsregister    (RS232_RCV_REG)
--  Statusregister      (RS232_STAT_REG)
--  Steuerregister      (RS232_CTRL_REG)
--------------------------------------------------------------------------------
--  Das Ansprechen der Register erfolgt entweder Wort- oder Byteweise,
--  tatsaechlich wird aber immer nur das nur das niederwertigste Byte eines
--  Zugriffs beruecksichtigt.
--  In das Sendregegister sollte nur geschrieben werden, beim Lesen werden
--  Nullen ausgegeben. Empfangs- und Statusregister koennen nur gelesen
--  werden, Schreiboperationen sind wirkungslos.
--  Das Schreiben eines Datums vom Datenbus ins Senderegister wird als
--  Sendebefehl interpretiert, das Lesen eines Datums aus dem Empfangs-
--  register als Leseoperation.
--------------------------------------------------------------------------------
--  Interpretation des Statusregister:
--  Bit 0 zeigt an, dass ein neues Datum gelesen wurde und im Empfangs-
--  register liegt. Eine Leseoperation auf dem Empfangsregister setzt das
--  Bit zurueck. Bit 4 zeigt an, dass das Sendemodul mit der aktuellen
--  Uebertragung beschaeftigt ist, eine Schreiboperation auf das Sende-
--  register bleibt waehrenddessen wirkungslos. Ist das Bit = 0 und erfolgt
--  ein Schreibzugriff auf das Senderegister, wird das Bit im gleichen Takt
--  neu gesetzt.
--
--  Das Steuerregister hat vorlaeufig keine besondere Wirkung, kann aber
--  beschrieben werden.
--------------------------------------------------------------------------------    

entity ArmRS232Interface is
    port(
        SYS_CLK     : in std_logic;
        SYS_RST     : in std_logic;
--  Schnittstelle zum Datenbus
        RS232_CS    : in std_logic;
        RS232_DnRW  : in std_logic;
        RS232_DMAS  : IN std_logic_vector(1 downto 0);
        RS232_DA    : in std_logic_vector(3 downto 0);
        RS232_DDIN  : in std_logic_vector(31 downto 0);
        RS232_DDOUT : out std_logic_vector(31 downto 0);
        RS232_DABORT    : out std_logic;
        RS232_IRQ   : out std_logic;
--  Serielle Empfangs- und Sendeleitungen
        RS232_RXD   : in std_logic;
        RS232_TXD   : out std_logic 
        );
end entity ArmRS232Interface;

architecture behave of ArmRS232Interface is
--------------------------------------------------------------------------------
--  Lokale Schnittstellensignale zum Datenbus zur Realisierung der
--  Tristate-Ausgaenge.
--------------------------------------------------------------------------------
    signal DABORT_INTERNAL  : std_logic;    
    signal DDOUT_INTERNAL   : std_logic_vector(31 downto 0);

--------------------------------------------------------------------------------
--  Definition der lokalen, am Datenbus adressierbaren Register der
--  seriellen Schnittstelle. Sie werden Ausschliesslich im Block
--  INTERFACE_COMMUNICATION beschrieben!
--------------------------------------------------------------------------------
    type RS232_REGISTER_SET_LOCAL_TYPE is array ( 0 to 2 ) of std_logic_vector(7 downto 0);
    signal REGISTER_SET : RS232_REGISTER_SET_LOCAL_TYPE := (others => (others => '0')); 

--------------------------------------------------------------------------------
--  Aliase fuer den Zugriff auf die 4 Register der RS232-Schnittstelle.
--  RS232_CTRL_REG ist aktuell funktionslos, liefert beim Lesen immer
--  0 und Schreibzugriff haben keine Wirkung -> Beschreibung als Konstante.
--------------------------------------------------------------------------------
    alias RS232_RCV_REG : std_logic_vector(7 downto 0) is REGISTER_SET(0);
    alias RS232_TRM_REG : std_logic_vector(7 downto 0) is REGISTER_SET(1);
    alias RS232_STAT_REG    : std_logic_vector(7 downto 0) is REGISTER_SET(2);
    constant RS232_CTRL_REG : std_logic_vector(7 downto 0) := (others => '0');

--------------------------------------------------------------------------------
--  Signale fuer die Kommunikation zwischen den 3 Bloecken im Modul.
--------------------------------------------------------------------------------
--  Signale vom RS232-Receiver zur Busschnittstelle INTERFACE_COMMUNICATION
    signal DATA_RECEIVED    : std_logic;
    signal RECEIVER_DATA    : std_logic_vector(7 downto 0);
--------------------------------------------------------------------------------
--  Steuer- und Statussignale zwischen RS232-Transmitter und
--  Busschnittstelle. Der Transmitter liest zusaetzlich Daten aus dem
--  lokalen Register RS232_TRM_REG.
--------------------------------------------------------------------------------
    signal START_TRANSMISSION   : std_logic;
    signal TRANSMITTER_BUSY     : std_logic;
--------------------------------------------------------------------------------
begin
--------------------------------------------------------------------------------
--  Kommunikationsschnittstelle, stellt die Verbindung zwischen Datenbus
--  und den RS232-Komponenten her.
--------------------------------------------------------------------------------

INTERFACE_COMMUNICATION : block is
    begin
--------------------------------------------------------------------------------
--  Data Abort, wenn eine Wortzugriff mit nicht ausgerichteter Adresse
--  erfolgt oder ein Bytezugriff auf die nicht verwendeten hochwertigen
--  24 Registerbits erfolgt.
--------------------------------------------------------------------------------
        DABORT_INTERNAL <= '1' when ((RS232_DMAS /= DMAS_BYTE) and (RS232_DMAS /= DMAS_WORD)) or RS232_DA(1 downto 0) /= "00" else '0';
--  Daten- und Abortsignale werden nur getrieben, wenn das Modul tatsaechlich aktiv sein soll
        RS232_DABORT    <= DABORT_INTERNAL when RS232_CS = '1' else 'Z';
        RS232_DDOUT <= DDOUT_INTERNAL when RS232_CS = '1' and RS232_DnRW = '0' else (others => 'Z');

--------------------------------------------------------------------------------
--  Interrupt ist bis auf weiteres direkt Bit 0 des Statusregistes, maskiert
--  wird ausschliesslich in Software durch das CPSR-IRQ-Maskenbit
--------------------------------------------------------------------------------
        RS232_IRQ <= RS232_STAT_REG(0);

--------------------------------------------------------------------------------
--  Die vier Register der RS232-Schnittstelle liegen an 4 Adressen
--  hintereinander. Die Adressbits (3:2) waehlen das Register aus.
--------------------------------------------------------------------------------
        GET_REGISTER : process(RS232_DA(3 downto 2), REGISTER_SET)
        begin
            case RS232_DA(3 downto 2) IS
                when "00" =>
                    DDOUT_INTERNAL <= X"000000" & RS232_RCV_REG;
                when "01" =>
                    DDOUT_INTERNAL <= (others => '0');

                when "10" =>
                    DDOUT_INTERNAL <= X"000000" & RS232_STAT_REG;
                when others =>  
                    DDOUT_INTERNAL <= (others => '0');
            end case;
        end process GET_REGISTER;   

--------------------------------------------------------------------------------
--  Schreibzugriffe vom Datenbus auf das Register RS232_TRM_REG setzen
--  dessen Inhalt und veranlassen das Senden des neuen Datums ueber die
--  TXD-Leitung.
--------------------------------------------------------------------------------
        SET_REGISTER : process(SYS_CLK, REGISTER_SET, START_TRANSMISSION)
        begin
            REGISTER_SET        <= REGISTER_SET;
            START_TRANSMISSION  <= START_TRANSMISSION;

            if SYS_CLK'event and SYS_CLK = '1' then
                if(SYS_RST = '1') then
                    REGISTER_SET        <= (others => (others => '0'));
                    START_TRANSMISSION  <= '0';
                else
                    START_TRANSMISSION      <= '0';
                    RS232_STAT_REG(7 downto 5)  <= "000";
                    RS232_STAT_REG(3 downto 1)  <= "000";
                    RS232_STAT_REG(4)       <= TRANSMITTER_BUSY or START_TRANSMISSION;
--  Gueltiger Schreibzugriff auf das Transmissionsregister loest die Uebertragung aus           
                    if(RS232_DnRW = '1' and RS232_CS = '1' and DABORT_INTERNAL = '0' and RS232_DA(3 downto 2) = "01" and START_TRANSMISSION = '0')then
                        if(TRANSMITTER_BUSY = '0')then
                            RS232_TRM_REG       <= RS232_DDIN(7 downto 0);
                            START_TRANSMISSION  <= '1';
                            RS232_STAT_REG(4)   <= '1';
                        end if;
                    end if; 
--------------------------------------------------------------------------------
--  Gueltiger Lesezugriff auf das Empfangsregister, setzt die Anzeige fuer
--  ein empfangenes Datum zurueck. Sollte im gleichen Takt erneut ein Datum
--  empfangen worden sein, bleibt das Bit gesetzt (naechster Abschnitt).
--------------------------------------------------------------------------------
                    if(RS232_DnRW = '0' and RS232_CS = '1' and DABORT_INTERNAL = '0' and RS232_DA(3 downto 2) = "00")then
                        RS232_STAT_REG(0)   <= '0';
                    end if; 
--------------------------------------------------------------------------------
--  Empfaenger zeigt an, dass ein neues Datum empfangen wurde, das
--  entsprechende Statusbit wird gesetzt.
--------------------------------------------------------------------------------
                    if(DATA_RECEIVED = '1')then
                        RS232_RCV_REG       <= RECEIVER_DATA;
                        RS232_STAT_REG(0)   <= '1';
                end if;
            end if; 
        end if;
    end process SET_REGISTER;
end block INTERFACE_COMMUNICATION;


--------------------------------------------------------------------------------
--  Block, der das Verhalten eines RS232-Empfaengers beschreibt.
--------------------------------------------------------------------------------
RS232_RECEIVER : block is
--------------------------------------------------------------------------------
--  Exklusive Typen und Signale des Empfaengers. Alle Ausgangssignale, die
--  die Statemachine setzt, werden durch einen zusaetzlichen Prozess
--  registriert.
--  Die Statemachine liest ein von ihr direkt oder indirekt gesetztes Signal
--  ausschliesslich auf dem Umweg ueber das Register wieder ein, um
--  asynchrone Rueckkopplungen zu vermeiden.
--------------------------------------------------------------------------------
        type RS232_RCV_STATE_TYPE is (RCV_IDLE, RCV_READ_BIT, RCV_STOPP);
        signal RCV_STATE, RCV_NEXT_STATE : RS232_RCV_STATE_TYPE := RCV_IDLE;
        constant DATA_REG_INIT_VALUE    : std_logic_vector(7 downto 0) := "10000000";
        signal RCV_DATA, RCV_DATA_REG   : std_logic_vector(7 downto 0) := DATA_REG_INIT_VALUE;
--  Flipflop zum Aufsynchronisieren des Eingangssignals
        signal DATA_IN_BIT_REG      : std_logic := '1';
        signal SET_DATA, SET_DATA_REG   : std_logic;
        signal DATA_RECEIVED_REG    : std_logic := '1';
        signal WSG_DELAY, WSG_DELAY_REG : std_logic_vector(31 downto 0); 
        signal WSG_START, WSG_START_REG : std_logic := '0';
--  WSG_WAIT wird von der Statemachine nur gelesen
        signal WSG_WAIT         : std_logic;
    begin
        WSG : entity work.ArmWaitStateGenAsync(BEHAVE)
        generic map(
            COUNT_VALUE_WIDTH => 32
        )
        port map(
            SYS_CLK     => SYS_CLK,
            SYS_RST     => SYS_RST,
            WSG_COUNT_INIT  => WSG_DELAY_REG,
            WSG_START   => WSG_START_REG,
            WSG_WAIT    => WSG_WAIT         
        );  

--  Setzen des Zustandsregisters
        SET_RCV_STATE_REG : process(SYS_CLK) is
        begin
            if SYS_CLK'event and SYS_CLK = '1' then
                if SYS_RST = '1' then
                    RCV_STATE <= RCV_IDLE;
                else
                    RCV_STATE <= RCV_NEXT_STATE;
                end if;
            end if;
        end process SET_RCV_STATE_REG;

--------------------------------------------------------------------------------
--  Setzen der Synchronisationsregister, nur aus formalen Gruenden geschieht
--  dies nicht in einem Prozess mit dem Zustandsregister.
--------------------------------------------------------------------------------
        SET_DATA_REGISTERS : process(SYS_CLK) is
        begin
            if SYS_CLK'event and SYS_CLK = '1' then
                if SYS_RST = '1' then
                    DATA_IN_BIT_REG     <= '1';
                    WSG_DELAY_REG       <= std_logic_vector(RS232_START_DELAY);
                    RCV_DATA_REG        <= (others => '0');
                    DATA_RECEIVED_REG   <= '0';
                    WSG_START_REG       <= '0';
                    SET_DATA_REG        <= '0';

                else
                    DATA_IN_BIT_REG     <= RS232_RXD;
                    WSG_DELAY_REG       <= WSG_DELAY;
                    RCV_DATA_REG        <= RCV_DATA;
                    DATA_RECEIVED_REG   <= '0';
                    WSG_START_REG       <= WSG_START;
                    SET_DATA_REG        <= SET_DATA;
                    if SET_DATA_REG = '1' then
                        RECEIVER_DATA       <= RCV_DATA_REG(7 downto 0);
                        DATA_RECEIVED_REG   <= '1';
                    end if;

                end if;
            end if;
        end process SET_DATA_REGISTERS;

--------------------------------------------------------------------------------
--  DATA_RECEIVED zeigt der Kommunkationsschnittstelle an, dass ein neues
--  Datum empfangen wurde.
--------------------------------------------------------------------------------
        DATA_RECEIVED <= DATA_RECEIVED_REG;
    
--------------------------------------------------------------------------------
--  Kern der FSM: Ermittlung des Nachfolgezustandes und Setzen der 
--  Ausgangssignale, die dann in SET_DATA_REGISTERS in Register geschrieben
--  werden. 
--------------------------------------------------------------------------------
    SET_OUTPUTS_AND_NEXT_STATE : process(RCV_STATE,DATA_IN_BIT_REG,WSG_WAIT, RCV_DATA_REG) IS
    begin
--------------------------------------------------------------------------------
--  Ausgangssignale die durch die FSM gesetzt und in jedem Zustand definiert
--  werden muessen:
--      RCV_NEXT_STATE
--      WSG_START
--      RCV_DATA    
--      WSG_DELAY
--      SET_DATA
--------------------------------------------------------------------------------

--  Defaultwerte:       
        RCV_NEXT_STATE  <= RCV_STATE;
        WSG_START   <= '0';
        RCV_DATA    <= RCV_DATA_REG;
        WSG_DELAY   <= std_logic_vector(RS232_DELAY);
        SET_DATA    <= '0';

        case RCV_STATE is
            when RCV_IDLE =>            
                if( DATA_IN_BIT_REG = '1' )then
                    RCV_NEXT_STATE  <= RCV_IDLE;
                    WSG_START   <= '0';
                else
--  Beginn eines Startbits erkannt -> Beginn des Lesevorgangs                   
                    RCV_NEXT_STATE  <= RCV_READ_BIT;
                    WSG_START   <= '1';
                end if;
                RCV_DATA    <= DATA_REG_INIT_VALUE;
--------------------------------------------------------------------------------
--  START_DELAY entspricht der 1,5-fachen Zeichendauer, sodass die 
--  Empfangsleitung ca. in der Mitte des ersten Datenbits wieder abgetastet
--  wird.   
--------------------------------------------------------------------------------
                WSG_DELAY   <= std_logic_vector(RS232_START_DELAY);
                SET_DATA    <= '0';

            when RCV_READ_BIT =>
                if( WSG_WAIT = '1' )then
                    RCV_NEXT_STATE  <= RCV_READ_BIT;
                    WSG_START   <= '0';
                    RCV_DATA    <= RCV_DATA_REG;
                else
                    RCV_DATA(7 downto 0)    <= DATA_IN_BIT_REG & RCV_DATA_REG(7 downto 1);
                    WSG_START       <= '1';
--------------------------------------------------------------------------------
--  RCV_DATA_REG wurde mit einer 1 im MSB initialisiert, die jetzt ganz
--  nach rechts geschoben wurde -> Schieberegister als Zaehler. 
--------------------------------------------------------------------------------
                    if RCV_DATA_REG(0) = '1' then
                        RCV_NEXT_STATE  <= RCV_STOPP;
                    else
                        RCV_NEXT_STATE  <= RCV_READ_BIT;
                    end if;
                end if; 
                WSG_DELAY   <= std_logic_vector(RS232_DELAY);
                SET_DATA    <= '0';

            when RCV_STOPP =>
                RCV_DATA <= RCV_DATA_REG;
                if( WSG_WAIT = '1' ) then
                    RCV_NEXT_STATE  <= RCV_STOPP;
                    WSG_START   <= '0';
                    SET_DATA    <= '0';
                    RCV_DATA    <= RCV_DATA_REG;
                else                    
                    if(DATA_IN_BIT_REG = '1')then
                        RCV_NEXT_STATE  <= RCV_IDLE;
                        WSG_START   <= '0';
                        SET_DATA    <= '1';
                    else
--------------------------------------------------------------------------------
--  0 wird als Startsignal des naechsten Datensatzes interpretiert,
--  das aktuelle Datum aber nicht in der Kommunikationsschnittstelle
--  bekannt gemacht da ein korrektes Stoppbit fehlt.                    
--------------------------------------------------------------------------------
                        RCV_NEXT_STATE <= RCV_READ_BIT;
                        WSG_START   <= '1';
                        SET_DATA    <= '0';
                    end if;
                end if; 
                WSG_DELAY <= std_logic_vector(RS232_DELAY);

            when others => 
                RCV_NEXT_STATE <= RCV_IDLE;
                WSG_START <= '0';
                RCV_DATA <= DATA_REG_INIT_VALUE;
                WSG_DELAY <= std_logic_vector(RS232_START_DELAY);
                SET_DATA <= '0';
        end case;
    end process SET_OUTPUTS_AND_NEXT_STATE;
end block RS232_RECEIVER;

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--  Block, der einen RS232-Sender beschreibt und von Ihnen zu ergaenzen
--  ist. Veraendern Sie die Vorgaben ausserhalb des Blocks _nicht_.
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

-- RS232_TRM_REG ist 8 Bit gross
RS232_TRANSMITTER : block is

    begin
WSG : entity work.ArmWaitStateGenAsync(BEHAVE)
        generic map (
            COUNT_VALUE_WIDTH => 32
        )
        port map (
            SYS_CLK => SYS_CLK,
            SYS_RST => SYS_RST,
            WSG_COUNT_INIT => WSG_DELAY,
            WSG_START => WSG_START_REG,
            WSG_WAIT => WSG_WAIT
        );

end block RS232_TRANSMITTER;

end architecture behave;