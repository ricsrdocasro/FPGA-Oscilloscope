library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity adc_teste is
    port(
        MAX10_CLK1_50   : in  std_logic;
        -- Sinais para comunicação com o módulo VGA
        adc_data_out    : out std_logic_vector(11 downto 0);  -- Dados ADC para VGA
        adc_data_valid  : out std_logic;                      -- Sinal de dados válidos
        adc_clk_out     : out std_logic;                      -- Clock de amostragem
        -- Opcional: Display 7-segmentos para debug
        HEX2           : out std_logic_vector(0 to 6);
        HEX1           : out std_logic_vector(0 to 6);
        HEX0           : out std_logic_vector(0 to 6)
    );
end entity;

architecture comportamental of adc_teste is
    component adcteste is
        port (
            CLOCK : in  std_logic := 'X';
            RESET : in  std_logic := 'X';
            CH0   : out std_logic_vector(11 downto 0);
            CH1   : out std_logic_vector(11 downto 0);
            CH2   : out std_logic_vector(11 downto 0);
            CH3   : out std_logic_vector(11 downto 0);
            CH4   : out std_logic_vector(11 downto 0);
            CH5   : out std_logic_vector(11 downto 0);
            CH6   : out std_logic_vector(11 downto 0);
            CH7   : out std_logic_vector(11 downto 0)
        );
    end component adcteste;
    
    -- Sinais internos
    signal data_raw         : std_logic_vector(11 downto 0);
    signal data_reg         : std_logic_vector(11 downto 0);
    signal data_valid_reg   : std_logic;
    
    -- Divisor de clock para controle da taxa de amostragem
    -- Para uma taxa de amostragem de ~1MHz (50MHz/50 = 1MHz)
    -- Ajuste conforme necessário para sua aplicação
    constant SAMPLE_DIVIDER : integer := 50;
    signal clk_divider      : integer range 0 to SAMPLE_DIVIDER-1 := 0;
    signal sample_clk       : std_logic := '0';
    
    -- Mapa para display 7-segmentos
    type seven_seg_type is array (0 to 15) of std_logic_vector(6 downto 0);
    constant SEGMENT_MAP : seven_seg_type := (
        "0000001", "1001111", "0010010", "0000110",
        "1001100", "0100100", "0100000", "0001111",
        "0000000", "0000100", "0001000", "1100000",
        "0110001", "1000010", "0110000", "0111000"
    );

begin
    -- Instância do componente ADC
    u0 : component adcteste
        port map (
            CLOCK => MAX10_CLK1_50,
            RESET => '0',
            CH0   => data_raw,    -- Canal 0 conectado
            CH1   => open,
            CH2   => open,
            CH3   => open,
            CH4   => open,
            CH5   => open,
            CH6   => open,
            CH7   => open
        );
    
    -- Processo para geração do clock de amostragem
    -- Este processo controla a taxa na qual os dados são enviados para o VGA
    SAMPLE_CLOCK_GEN: process(MAX10_CLK1_50)
    begin
        if rising_edge(MAX10_CLK1_50) then
            if clk_divider = SAMPLE_DIVIDER-1 then
                clk_divider <= 0;
                sample_clk <= not sample_clk;  -- Toggle do clock de amostragem
            else
                clk_divider <= clk_divider + 1;
            end if;
        end if;
    end process;
    
    -- Processo para registrar os dados e gerar sinal de validação
    -- Os dados são capturados na borda de subida do clock de amostragem
    DATA_REGISTER: process(MAX10_CLK1_50)
    begin
        if rising_edge(MAX10_CLK1_50) then
            if clk_divider = 0 then  -- Sincronizado com sample_clk
                data_reg <= data_raw;        -- Registra o dado atual
                data_valid_reg <= '1';       -- Sinaliza dado válido
            else
                data_valid_reg <= '0';       -- Limpa sinal de validação
            end if;
        end if;
    end process;
    
    -- Saídas para o módulo VGA
    adc_data_out   <= data_reg;
    adc_data_valid <= data_valid_reg;
    adc_clk_out    <= sample_clk;
    
    -- Display 7-segmentos para debug (mostra o valor atual do ADC)
    HEX0 <= SEGMENT_MAP(to_integer(unsigned(data_reg(3 downto 0))));
    HEX1 <= SEGMENT_MAP(to_integer(unsigned(data_reg(7 downto 4))));
    HEX2 <= SEGMENT_MAP(to_integer(unsigned(data_reg(11 downto 8))));
    
end architecture;