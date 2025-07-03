library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vga_teste is
    port(
        MAX10_CLK1_50   : in  std_logic;
        adc_data_in     : in  std_logic_vector(11 downto 0);
        adc_data_valid  : in  std_logic;
        VGA_R           : out std_logic_vector(3 downto 0);
        VGA_G           : out std_logic_vector(3 downto 0);
        VGA_B           : out std_logic_vector(3 downto 0);
        VGA_HS, VGA_VS  : out std_logic
    );
end entity;

architecture rtl of vga_teste is
    -- VGA 640x480 @ 60Hz
    constant H_ACTIVE_VIDEO : integer := 640;
    constant H_FRONT_PORCH  : integer := H_ACTIVE_VIDEO + 16;
    constant H_SYNC         : integer := H_FRONT_PORCH + 96;
    constant H_BACK_PORCH   : integer := H_SYNC + 48;
    constant H_PIXELS       : integer := 800;

    constant V_ACTIVE_VIDEO : integer := 480;
    constant V_FRONT_PORCH  : integer := V_ACTIVE_VIDEO + 10;
    constant V_SYNC         : integer := V_FRONT_PORCH + 2;
    constant V_BACK_PORCH   : integer := V_SYNC + 33;
    constant V_LINES        : integer := 525;

    -- Clock VGA: 25MHz
    signal vga_clk : std_logic := '0';
    signal clk_div : std_logic := '0';

    -- Contadores VGA
    signal h_count : integer range 0 to H_PIXELS-1 := 0;
    signal v_count : integer range 0 to V_LINES-1 := 0;
    signal video_active : std_logic;

    -- Buffers
    constant BUFFER_SIZE : integer := 640;
    type sample_buffer_t is array (0 to BUFFER_SIZE-1) of std_logic_vector(11 downto 0);
    signal sample_buffer : sample_buffer_t;
    signal write_ptr : integer range 0 to BUFFER_SIZE-1 := 0;

    type display_buffer_t is array (0 to BUFFER_SIZE-1) of std_logic_vector(11 downto 0);
    signal display_buffer : display_buffer_t;
    signal display_write_ptr : integer range 0 to BUFFER_SIZE-1 := 0;

    -- Intervalo para atualizar a tela (10s por tela)
    constant DISPLAY_SCROLL_INTERVAL : integer := 781250; -- 50 MHz / 64
    signal scroll_counter : integer range 0 to DISPLAY_SCROLL_INTERVAL := 0;

    -- VGA coordenadas e controle
    signal pixel_x : integer range 0 to H_ACTIVE_VIDEO-1;
    signal pixel_y : integer range 0 to V_ACTIVE_VIDEO-1;
    signal draw_waveform : std_logic;
    signal draw_grid : std_logic;

    -- Cores
    constant COLOR_WAVEFORM : std_logic_vector(11 downto 0) := x"0F0"; -- Verde
    constant COLOR_GRID     : std_logic_vector(11 downto 0) := x"333"; -- Cinza escuro
    constant COLOR_BG       : std_logic_vector(11 downto 0) := x"000"; -- Preto

begin

    -- Clock VGA 25MHz
    VGA_CLK_GEN: process(MAX10_CLK1_50)
    begin
        if rising_edge(MAX10_CLK1_50) then
            clk_div <= not clk_div;
        end if;
    end process;
    vga_clk <= clk_div;

    -- Amostragem contínua do ADC
    ADC_BUFFER: process(MAX10_CLK1_50)
    begin
        if rising_edge(MAX10_CLK1_50) then
            if adc_data_valid = '1' then
                sample_buffer(write_ptr) <= adc_data_in;
                if write_ptr = BUFFER_SIZE-1 then
                    write_ptr <= 0;
                else
                    write_ptr <= write_ptr + 1;
                end if;
            end if;
        end if;
    end process;

    -- Copiar 1 amostra do sample_buffer para o display_buffer lentamente
    SCROLL_DISPLAY: process(MAX10_CLK1_50)
        variable sample_index : integer;
    begin
        if rising_edge(MAX10_CLK1_50) then
            if scroll_counter = DISPLAY_SCROLL_INTERVAL then
                scroll_counter <= 0;

                -- Copia a última amostra para o próximo pixel visível
                sample_index := (write_ptr - 1 + BUFFER_SIZE) mod BUFFER_SIZE;
                display_buffer(display_write_ptr) <= sample_buffer(sample_index);

                if display_write_ptr = BUFFER_SIZE - 1 then
                    display_write_ptr <= 0;
                else
                    display_write_ptr <= display_write_ptr + 1;
                end if;
            else
                scroll_counter <= scroll_counter + 1;
            end if;
        end if;
    end process;

    -- Sinais de sincronismo VGA
    VGA_SYNC: process(vga_clk)
    begin
        if rising_edge(vga_clk) then
            if h_count = H_PIXELS-1 then
                h_count <= 0;
                if v_count = V_LINES-1 then
                    v_count <= 0;
                else
                    v_count <= v_count + 1;
                end if;
            else
                h_count <= h_count + 1;
            end if;

            if h_count >= H_FRONT_PORCH and h_count < H_SYNC then
                VGA_HS <= '0';
            else
                VGA_HS <= '1';
            end if;

            if v_count >= V_FRONT_PORCH and v_count < V_SYNC then
                VGA_VS <= '0';
            else
                VGA_VS <= '1';
            end if;

            if h_count < H_ACTIVE_VIDEO and v_count < V_ACTIVE_VIDEO then
                video_active <= '1';
                pixel_x <= h_count;
                pixel_y <= v_count;
            else
                video_active <= '0';
            end if;
        end if;
    end process;

    -- Lógica de desenho da forma de onda
    WAVEFORM_LOGIC: process(vga_clk)
        variable sample_data : std_logic_vector(11 downto 0);
        variable scaled_y : integer;
    begin
        if rising_edge(vga_clk) then
            draw_waveform <= '0';
            draw_grid <= '0';

            if video_active = '1' then
                if (pixel_x mod 64 = 0) or (pixel_y mod 48 = 0) then
                    draw_grid <= '1';
                end if;

                if pixel_x < BUFFER_SIZE then
                    sample_data := display_buffer(pixel_x);
                    scaled_y := V_ACTIVE_VIDEO - 1 - (to_integer(unsigned(sample_data)) * V_ACTIVE_VIDEO / 2703);

                    if pixel_y >= scaled_y-2 and pixel_y <= scaled_y+2 then
                        draw_waveform <= '1';
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- Geração de cor
    COLOR_OUTPUT: process(vga_clk)
        variable color_out : std_logic_vector(11 downto 0);
    begin
        if rising_edge(vga_clk) then
            if video_active = '1' then
                if draw_waveform = '1' then
                    color_out := COLOR_WAVEFORM;
                elsif draw_grid = '1' then
                    color_out := COLOR_GRID;
                else
                    color_out := COLOR_BG;
                end if;
            else
                color_out := (others => '0');
            end if;

            VGA_R <= color_out(11 downto 8);
            VGA_G <= color_out(7 downto 4);
            VGA_B <= color_out(3 downto 0);
        end if;
    end process;

end architecture;
