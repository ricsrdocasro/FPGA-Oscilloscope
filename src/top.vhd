library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top is
    port(
        -- Clock principal da placa
        MAX10_CLK1_50 : in  std_logic;
        
        -- Sinais VGA
        VGA_R         : out std_logic_vector(3 downto 0);
        VGA_G         : out std_logic_vector(3 downto 0);
        VGA_B         : out std_logic_vector(3 downto 0);
        VGA_HS        : out std_logic;
        VGA_VS        : out std_logic;
        
        -- Display 7-segmentos (opcional, para debug)
        HEX0         : out std_logic_vector(0 to 6);
        HEX1         : out std_logic_vector(0 to 6);
        HEX2         : out std_logic_vector(0 to 6)
    );
end entity;

architecture structural of top is
    -- Componente ADC reformulado
    component adc_teste is
        port(
            MAX10_CLK1_50  : in  std_logic;
            adc_data_out   : out std_logic_vector(11 downto 0);
            adc_data_valid : out std_logic;
            adc_clk_out    : out std_logic;
            HEX2          : out std_logic_vector(0 to 6);
            HEX1          : out std_logic_vector(0 to 6);
            HEX0          : out std_logic_vector(0 to 6)
        );
    end component;
    
    -- Componente VGA reformulado
    component vga_teste is
        port(
            MAX10_CLK1_50  : in  std_logic;
            adc_data_in    : in  std_logic_vector(11 downto 0);
            adc_data_valid : in  std_logic;
            VGA_R         : out std_logic_vector(3 downto 0);
            VGA_G         : out std_logic_vector(3 downto 0);
            VGA_B         : out std_logic_vector(3 downto 0);
            VGA_HS        : out std_logic;
            VGA_VS        : out std_logic
        );
    end component;
    
    -- Sinais de interconexão entre ADC e VGA
    signal adc_data       : std_logic_vector(11 downto 0);
    signal adc_data_valid : std_logic;
    signal adc_clk        : std_logic;

begin
    -- Instância do módulo ADC
    ADC_INST: adc_teste
        port map(
            MAX10_CLK1_50  => MAX10_CLK1_50,
            adc_data_out   => adc_data,
            adc_data_valid => adc_data_valid,
            adc_clk_out    => adc_clk,
            HEX2          => HEX2,
            HEX1          => HEX1,
            HEX0          => HEX0
        );
    
    -- Instância do módulo VGA
    VGA_INST: vga_teste
        port map(
            MAX10_CLK1_50  => MAX10_CLK1_50,
            adc_data_in    => adc_data,
            adc_data_valid => adc_data_valid,
            VGA_R         => VGA_R,
            VGA_G         => VGA_G,
            VGA_B         => VGA_B,
            VGA_HS        => VGA_HS,
            VGA_VS        => VGA_VS
        );

end architecture;