library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vga_mem is
   port(
        clock      : in  std_logic;
        pclock     : buffer std_logic;
        reset      : in  std_logic;
        mem_adr    : in  std_logic_vector(14 downto 0);
        mem_out    : out std_logic_vector(2 downto 0);
        mem_in     : in  std_logic_vector(2 downto 0);
        mem_wr     : in  std_logic;
        vga_hs     : out std_logic;
        vga_vs     : out std_logic;
        blank      : out std_logic;
        r, g, b    : out std_logic_vector(7 downto 0)
    );
end entity;

architecture DE1_SoC of vga_mem is
   -- Signals for VGA processing
   signal hs1, hs2  : std_logic;
   signal vs1, vs2  : std_logic;
   signal b1        : std_logic;
   signal pdata     : std_logic_vector(2 downto 0);
   signal paddr     : std_logic_vector(14 downto 0);

begin
   -- Video RAM for Snake Game
   Video_RAM: entity work.vram port map(
        address_a => paddr,
        address_b => mem_adr(14 downto 0),
        clock_a => pclock,
        clock_b => clock,
        data_a => (others => '-'), -- Unused for read-only VGA
        data_b => mem_in,          -- Input data from game logic
        wren_a => '0',             -- Write disabled for VGA read
        wren_b => mem_wr,          -- Write enabled for game logic
        q_a => pdata,              -- Pixel data output to VGA
        q_b => mem_out             -- Data output to game logic
    );

   -- Map pixel colors to VGA output
   r <= (others => pdata(2)); -- Red component
   g <= (others => pdata(1)); -- Green component
   b <= (others => pdata(0)); -- Blue component

   -- VGA Timing Circuit
   Timing_Circuit: process(pclock, reset) is
      variable hcount : integer range 0 to 800; -- Horizontal counter
      variable vcount : integer range 0 to 525; -- Vertical counter
   begin
      if reset = '1' then
         hcount := 0;
         vcount := 0;
         vga_hs <= '1';
         vga_vs <= '1';
         paddr <= (others => '0');
      elsif rising_edge(pclock) then
         -- Address calculation for 4x4 pixel grid
         if (hcount >= 0 and hcount <= 639 and vcount >= 0 and vcount <= 479) then
            paddr <= std_logic_vector(to_unsigned(vcount / 4, 7))
                     & std_logic_vector(to_unsigned(hcount / 4, 8));
            b1 <= '1'; -- Display active area
         else
            b1 <= '0'; -- Blanking outside active area
         end if;

         -- Horizontal and vertical counters
         if hcount = 799 then
            hcount := 0;
            if vcount = 524 then
               vcount := 0;
            else
               vcount := vcount + 1;
            end if;
         else
            hcount := hcount + 1;
         end if;

         -- Horizontal sync pulse
         if hcount = 656 then
            hs1 <= '0';
         elsif hcount = 752 then
            hs1 <= '1';
         end if;

         -- Vertical sync pulse
         if vcount = 490 then
            vs1 <= '0';
         elsif vcount = 492 then
            vs1 <= '1';
         end if;

         -- Update VGA signals
         hs2 <= hs1;
         vs2 <= vs1;
         blank <= b1;
         vga_hs <= hs2;
         vga_vs <= vs2;
      end if;
   end process;

   -- PLL for pixel clock generation
   pll: work.VGAPLL port map(
        refclk => clock,
        rst => reset,
        outclk_0 => pclock
    );

end architecture;
