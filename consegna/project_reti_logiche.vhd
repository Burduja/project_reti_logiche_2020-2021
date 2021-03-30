library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity project_reti_logiche is
port (
        i_clk : in std_logic;                           --segnale di clock generato da TestBench
        i_rst : in std_logic;                           --segnale di reset generato da TestBench
        i_start : in std_logic;                         --segnale di start generato da TestBench
        i_data : in std_logic_vector(7 downto 0);       --segnale generato da TestBench dopo una richiesta di read
        o_address : out std_logic_vector(15 downto 0);  --indirizzo della memoria a cui voglio accedere
        o_done : out std_logic;                         --diventa 1 quando ho finito l'elaborazione
        o_en : out std_logic;                           --deve essere 1 per poter leggere/scrivere
        o_we : out std_logic;                           --deve essere 1 per poter scrivere
        o_data : out std_logic_vector (7 downto 0)      --segnale che verrà scritto in memoria
);
end project_reti_logiche;
architecture Behavioral of project_reti_logiche is
    type stateType is (IDLE, FETCH_DIM, LOAD_DIM ,WAIT_WRITE, WAIT_RAM, WRITE, SHIFT, UPDATE_ADDR, CHECK_DIM, CALC_SHIFT,COMPARE,LOAD_CURR, FETCH_CURR, DONE);
    signal currState, nextState : stateType;
    signal haveX, haveX_next                    : std_logic := '0';                                     --flag per indicare se ho trovato x
    signal haveY, haveY_next                    : std_logic := '0';                                     --flag per indicare se ho trovato y
    signal foundDelta, foundDelta_next          : std_logic := '0';                                     --flag per sapere se ho gia trovasto il delta
    signal foundShift, foundShift_next          : std_logic := '0';                                     --flag per sapere se ho trovato shiftLvl                                        
    signal o_done_next, o_en_next, o_we_next    : std_logic := '0';                                     --flag per il componente
    signal foundDim, foundDim_next              : std_logic := '0';
    signal foundFullRange, foundFullRange_next  : std_logic := '0';
    signal n_col, n_col_next                      : std_logic_vector(7 downto 0):= "00000000";          --la dimensione della mia X
    signal n_rig, n_rig_next                      : std_logic_vector(7 downto 0):= "00000000";          --la dimensione della mia Y
    signal o_data_next                          : std_logic_vector(7 downto 0):= "00000000";            --valore da mandare alla memoria
    signal tempPixel, tempPixel_next            : std_logic_vector(15 downto 0):= "0000000000000000";   --pixel tempeoraneo elaborato
    signal o_address_next                       : std_logic_vector(15 downto 0) := "0000000000000000";  --prossimo indirizzo della memoria
    signal piccolo, piccolo_next                : unsigned(7 downto 0):= "00000000";
    signal grande, grande_next                  : unsigned(7 downto 0):= "00000000";
    signal n_colCopy, n_colCopy_next              : unsigned(7 downto 0):= "00000000";                  --copia della dim X
    signal n_rigCopy, n_rigCopy_next              : unsigned(7 downto 0):= "00000000";                  --copia della dim Y
    signal shiftLvl, shiftLvl_next              : unsigned(7 downto 0):= "00000000";    
    signal min, min_next                        : unsigned(7 downto 0):= "00000000";                    --pixel a valore minimo
    signal max, max_next                        : unsigned(7 downto 0):= "00000000";                    --pixel a valore massimo
    signal delta, delta_next                    : unsigned(7 downto 0):= "00000000";                    --delta tra massimo e min
    signal dimension, dimension_next            : unsigned(15 downto 0):= "0000000000000000";           --dimensione della Immagine   
    signal dimensionCopy, dimensionCopy_next    : unsigned(15 downto 0):= "0000000000000000";           --copia della dimensione
    signal currPix, currPix_next                : unsigned(15 downto 0):= "0000000000000000";           --pixel corrente che sto analizzando
    signal address_reg, address_next            : unsigned(15 downto 0):= "0000000000000000";           --copia dell'indirizzo di memoria


begin
    -- processo per far cambiare stato alla mia FSM ogni ciclo di clock
    -- RESET ASINCRONO
    SYNC : process (i_clk, i_rst)
    begin
            if( i_rst = '1') then   -- resetto tutto ai valori iniziali
                n_col            <= "00000000";
                n_rig            <= "00000000";
                n_colCopy        <= "00000000";
                n_rigCopy        <= "00000000";
                grande          <= "00000000";
                piccolo         <= "00000000";
                dimension       <= "0000000000000000";
                dimensionCopy   <= "0000000000000000";
                min             <= "11111111";
                max             <= "00000000";
                delta           <= "00000000";
                address_reg     <= "0000000000000000";
                haveX           <= '0';
                haveY           <= '0';
                foundDelta      <= '0';
                foundShift      <= '0';
                foundFullRange  <= '0';
                foundDim        <= '0';
                shiftLvl        <= "00000000";
                currPix         <= "0000000000000000";
                tempPixel       <= "0000000000000000";
                currState       <= IDLE;
            elsif(rising_edge(i_clk)) then  -- curr = next
                o_done          <= o_done_next;
                o_en            <= o_en_next;
                o_we            <= o_we_next;
                o_data          <= o_data_next;
                o_address       <= o_address_next;
                address_reg     <= address_next;
                n_col            <= n_col_next;
                n_rig            <= n_rig_next;
                n_colCopy        <= n_colCopy_next;
                n_rigCopy        <= n_rigCopy_next;
                dimension       <= dimension_next;
                dimensionCopy   <= dimensionCopy_next;                
                min             <= min_next;
                max             <= max_next;
                delta           <= delta_next;
                haveX           <= haveX_next;
                haveY           <= haveY_next;
                foundDelta      <= foundDelta_next;
                foundShift      <= foundShift_next;
                shiftLvl        <= shiftLvl_next;
                currPix         <= currPix_next;
                tempPixel       <= tempPixel_next;
                grande          <= grande_next;
                piccolo         <= piccolo_next;
                foundDim        <= foundDim_next;
                foundFullRange  <= foundFullRange_next;
                currState       <= nextState;
            end if;
    end process SYNC;
    
    -- processo per gestire la logica di ogni stato della FSM
    COMB : process(i_start, currState, i_data, address_reg, n_col, n_rig, dimension, dimensionCopy, delta, min, max, haveX, haveY, shiftLvl, foundShift, foundDelta, currPix,n_colCopy, n_rigCopy,grande, piccolo,  foundFullRange, foundDim, tempPixel)
    begin
        o_done_next         <= '0'; -- metto ai valori default oppure next = curr
        o_en_next           <= i_start;
        o_we_next           <= '0';
        o_data_next         <= "00000000";
        o_address_next      <= "0000000000000000";
        address_next        <= address_reg;
        grande_next         <= grande;
        piccolo_next        <= piccolo;
        n_col_next           <= n_col;
        n_rig_next           <= n_rig;
        n_colCopy_next       <= n_colCopy;
        n_rigCopy_next       <= n_rigCopy;
        dimension_next      <= dimension;
        dimensionCopy_next  <= dimensionCopy;
        delta_next          <= delta;
        min_next            <= min;
        max_next            <= max;
        haveX_next          <= haveX;
        haveY_next          <= haveY;
        shiftLvl_next       <= shiftLvl;
        foundShift_next     <= foundShift;
        foundDelta_next     <= foundDelta;
        currPix_next        <= currPix;
        tempPixel_next      <= tempPixel;
        nextState           <= currState;
        foundFullRange_next <= foundFullRange;
        foundDim_next       <= foundDim;
        
        case currState is
            WHEN IDLE =>
                            if (i_start = '1') then   
                                nextState   <= FETCH_DIM;
                            end if;
                            
           WHEN FETCH_DIM =>  --Stato imposto l'indirizzo della X poi Y
                            if(haveX = '0') then
                                o_address_next <= "0000000000000000";
                            elsif(haveY = '0') then
                                o_address_next <= "0000000000000001";
                            end if;
                            o_en_next <= '1';
                            o_we_next <= '0';
                            nextState <= WAIT_RAM;
            
           WHEN WAIT_RAM =>  --Stato per permettere alla ram di rispondere
                            if(haveX = '1' and haveY = '1') then
                                if(foundShift = '0')then
                                    if(foundDim = '0')then
                                        if(piccolo > 0)then
                                            dimension_next <= dimension + grande;
                                            piccolo_next <= piccolo - 1;
                                            if(piccolo = 1)then
                                                foundDim_next <= '1';
                                            end if;
                                        else
                                            foundDim_next <= '1';
                                        end if;
                                    end if;
                                    nextState <= COMPARE;
                                else
                                    nextState <= LOAD_CURR;
                                end if;
                            else
                                nextState <= LOAD_DIM;
                            end if;
                
           WHEN LOAD_DIM =>  --Stato dove salvo X e Y
                            if(haveX = '0') then
                                n_col_next       <= i_data;
                                n_colCopy_next   <= unsigned(i_data);
                                haveX_next      <= '1';
                                nextState       <= FETCH_DIM;
                            elsif(haveY = '0') then
                                n_rig_next       <= i_data;
                                n_rigCopy_next   <= unsigned(i_data);
                                haveY_next      <= '1';    
                                nextState       <= CHECK_DIM;
                            end if;

            WHEN LOAD_CURR =>
            
                            dimensionCopy_next  <= dimensionCopy - 1;
                            if(shiftLvl = 8)then
                                currPix_next(15 downto 0) <= "0000000000000000";
                            else
                                currPix_next(15 downto 8) <= "00000000";
                                currPix_next (7 downto 0) <= unsigned(i_data) - min;
                            end if;

                            if(shiftLvl = 0 or shiftLvl = 8)then        -- da fare  quando delta è zero, scrivo sempre zero, non leggo neanche 
                                nextState <= WRITE;
                            else
                                nextState <= SHIFT;
                            end if;
                
            WHEN SHIFT =>
                            tempPixel_next <= std_logic_vector(shift_left((currPix), to_integer(shiftLvl)));
                            nextState <= WRITE;
                
            WHEN WRITE =>
                            o_we_next <= '1';
                            o_en_next <= '1';
                            o_address_next <= std_logic_vector( 1 + dimension + dimension - dimensionCopy);
                            address_next <= ( 1 + dimension + dimension - dimensionCopy);
                            --dimensionCopy_next  <= dimensionCopy - 1;
                            if(shiftLvl = 0 or shiftLvl = 8)then
                                o_data_next <= std_logic_vector(currPix (7 downto 0));
                            else
                                if( unsigned(tempPixel) > 255 )then
                                    o_data_next <= "11111111";
                                else
                                    o_data_next <= std_logic_vector(tempPixel(7 downto 0));
                                end if;
                            end if;
                            nextState <= WAIT_WRITE;
                
            when WAIT_WRITE =>
                            if(dimensionCopy = 0) then
                                o_done_next <= '1';
                                nextState   <= DONE;
                            else
                                if(shiftLvl = 8)then
                                    nextState   <= LOAD_CURR;
                                else 
                                    nextState   <= FETCH_CURR;
                                end if;

                            end if;
            
            WHEN FETCH_CURR =>
                            address_next        <= (2 + dimension - dimensionCopy);
                            o_address_next      <= std_logic_vector( 2 + dimension - dimensionCopy);
                            --dimensionCopy_next  <= dimensionCopy - 1;
                            o_en_next           <= '1';
                            nextState           <= WAIT_RAM;    

            when CHECK_DIM =>  
                            if(n_col = "00000000" or n_rig = "00000000")then
                                o_done_next <= '1';
                                nextState   <= DONE;
                            else
                                if(n_colCopy > n_rigCopy)then
                                    grande_next                 <= n_colCopy;
                                    piccolo_next                <= n_rigCopy - 1;
                                    dimension_next(15 downto 8) <= "00000000";
                                    dimension_next(7 downto 0)  <= n_colCopy;
                                else
                                    grande_next                 <= n_rigCopy;
                                    piccolo_next                <= n_colCopy - 1;
                                    dimension_next(15 downto 8) <= "00000000";
                                    dimension_next(7 downto 0)  <= n_rigCopy;
                                end if;
                                o_en_next       <= '1';
                                o_we_next       <= '0';
                                address_next    <= "0000000000000010";
                                o_address_next  <= "0000000000000010";
                                nextState       <= WAIT_RAM;
                            end if;
                            
            WHEN COMPARE =>
                            if(foundDim = '0')then
                                if(piccolo > 0)then
                                    dimension_next <= dimension + grande;
                                    piccolo_next <= piccolo - 1;
                                    if(piccolo = 1)then
                                        foundDim_next <= '1';
                                    end if;
                                else
                                    foundDim_next <= '1';
                                end if;
                            end if;
                            if(unsigned(i_data) < min)then
                                min_next <= unsigned(i_data);
                                if(i_data = "00000000" and max = "11111111")then
                                    foundFullRange_next <= '1';
                                end if;
                            end if;                             -- cercando minimo e massimo
                            if(unsigned(i_data) > max) then
                                max_next <= unsigned(i_data);
                                if(i_data = "11111111" and min = "00000000")then
                                    foundFullRange_next <= '1';
                                end if;
                            end if;
                                 
                            if(foundFullRange = '1' and foundDim = '1')then
                                nextState <= CALC_SHIFT;
                            else
                                if(n_rigCopy > 1)then
                                    if(n_colCopy > 1)then
                                        n_colCopy_next   <= n_colCopy - 1;
                                        nextState       <= UPDATE_ADDR;
                                    else
                                        n_colCopy_next   <= unsigned(n_col);
                                        n_rigCopy_next   <= n_rigCopy - 1;
                                        nextState       <= UPDATE_ADDR;
                                    end if;
                                else
                                    if(n_colCopy > 1)then
                                        n_colCopy_next   <= n_colCopy - 1;
                                        nextState       <= UPDATE_ADDR;
                                    else
                                        nextState <= CALC_SHIFT;
                                    end if;
                                end if;
                            end if;
                           
            WHEN CALC_SHIFT =>
                            dimensionCopy_next <= dimension;
                            if(foundDelta = '0')then
                                delta_next      <= max - min;
                                foundDelta_next <= '1';
                                nextState       <= CALC_SHIFT;
                            elsif(foundShift = '0')then
                                case to_integer(delta) is
                                    WHEN 0 =>
                                         shiftLvl_next <= "00001000"; --8 -- QUINDI scrivo SEMPRE 0 
                                    WHEN 1 to 2 =>
                                         shiftLvl_next <= "00000111"; --7
                                    WHEN 3 to 6 =>
                                         shiftLvl_next <= "00000110"; --6
                                    WHEN 7 to 14 =>
                                         shiftLvl_next <= "00000101"; --5
                                    WHEN 15 to 30 =>
                                         shiftLvl_next <= "00000100"; --4                        
                                    WHEN 31 to 62 =>
                                         shiftLvl_next <= "00000011";--3
                                    WHEN 63 to 126 =>
                                         shiftLvl_next <= "00000010";--2
                                    WHEN 127 to 254 =>
                                         shiftLvl_next <= "00000001";--1
                                    WHEN OTHERS => 
                                         shiftLvl_next <= "00000000"; --0 --quindi RIscrivo il valore originale
                                end case;
                                foundShift_next <= '1';
                                n_colCopy_next   <= unsigned(n_col);
                                n_rigCopy_next   <= unsigned(n_rig);
                                nextState       <= CALC_SHIFT;
                            else
                                if(shiftLvl = "00001000")then
                                    nextState <= LOAD_CURR;
                                else
                                    nextState <= FETCH_CURR;
                                end if;

                            end if;
    
            WHEN UPDATE_ADDR =>
                            if(foundDim = '0')then
                                if(piccolo > 0)then
                                    dimension_next <= dimension + grande;
                                    piccolo_next <= piccolo - 1;
                                    if(piccolo = 1)then
                                        foundDim_next <= '1';
                                    end if;
                                else
                                    foundDim_next <= '1';
                                end if;
                            end if;
                            o_address_next  <= std_logic_vector((address_reg) + 1);
                            address_next    <= ((address_reg) + 1);
                            o_en_next       <= '1';
                            if(foundDim = '1' and foundFullRange = '1')then
                                nextState   <= CALC_SHIFT;
                            else
                                nextState   <= WAIT_RAM;
                            end if; 
            WHEN DONE =>
                            n_col_next           <= "00000000";
                            n_rig_next           <= "00000000";
                            n_colCopy_next       <= "00000000";
                            n_rigCopy_next       <= "00000000";
                            dimension_next      <= "0000000000000000";
                            dimensionCopy_next  <= "0000000000000000";
                            min_next            <= "11111111";
                            max_next            <= "00000000";
                            delta_next          <= "00000000";
                            address_next        <= "0000000000000000";
                            haveX_next          <= '0';
                            haveY_next          <= '0';
                            foundDelta_next     <= '0';
                            foundShift_next     <= '0';
                            shiftLvl_next       <= "00000000";
                            currPix_next        <= "0000000000000000";
                            tempPixel_next      <= "0000000000000000";
                            foundDim_next       <= '0';
                            foundFullRange_next <= '0';
                            piccolo_next        <= "00000000";
                            grande_next         <= "00000000";
                            if(i_start = '0')then
                                o_done_next <= '0';
                                nextState           <= IDLE;
                            else
                                o_done_next <= '1';
                                nextState           <= DONE;
                            end if;
                            
        when others =>
                           nextState <= IDLE;
       end case;
    end process COMB;
end Behavioral;