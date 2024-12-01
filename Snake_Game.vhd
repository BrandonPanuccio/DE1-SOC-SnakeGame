	 ----------------------IMPORTANT-------------------------
	 -- Width, height, and pixels will be monitor dependent--
	 ------ Clock made by PLL is also monitor dependent -----
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Snake_Game is
    port(
        CLOCK_50    : in std_logic;
        SW          : in std_logic_vector(9 downto 0);  -- Switches, only SW(9) has inverse functionality for Reset
        KEY         : in std_logic_vector(3 downto 0);  -- Keys for direction 3->Up 2->Down 1->Left 0->Right
        VGA_R       : out std_logic_vector(7 downto 0);
        VGA_G       : out std_logic_vector(7 downto 0);
        VGA_B       : out std_logic_vector(7 downto 0);
        VGA_CLK     : out std_logic;
        VGA_BLANK_N : out std_logic;
        VGA_HS      : out std_logic;
        VGA_VS      : out std_logic
    );
end entity;

architecture Behavioral of Snake_Game is
    alias clock : std_logic is CLOCK_50;
    alias reset : std_logic is SW(9);

    -- Constants for game grid and colors

    constant grid_width    : integer := 160; -- Number of cells horizontally for full screen
    constant grid_height   : integer := 120; -- Number of cells vertically for full screen
    constant cell_size     : integer := 4;   -- Size of each cell in pixels
    constant snake_color   : std_logic_vector(2 downto 0) := "010"; -- Green color for the snake
    constant food_color    : std_logic_vector(2 downto 0) := "100"; -- Red color for the food
    constant background    : std_logic_vector(2 downto 0) := "000"; -- Black color for the background

    -- Snake state variables, Cap Snake Size to 200
    type snake_array is array (0 to 199) of std_logic_vector(15 downto 0); -- Array to store the position of the snake segments
    signal snake_body : snake_array := (others => (others => '0')); -- Initialize snake body
    signal snake_length : integer := 5; -- Initial length of the snake

    -- Head and tail positions
    signal snake_head_x : integer := 10; -- Initial X position of the snake head
    signal snake_head_y : integer := 7;  -- Initial Y position of the snake head

    -- Direction control signals
    signal direction : std_logic_vector(1 downto 0) := "00"; -- Current direction (00=Right, 01=Up, 10=Left, 11=Down)

    -- Food position
    signal food_x : integer := 5; -- Initial X position of the food
    signal food_y : integer := 5; -- Initial Y position of the food

    -- VGA memory interface signals
    signal mem_adr : std_logic_vector(14 downto 0) := (others => '0'); -- Memory address for VGA display
    signal mem_in  : std_logic_vector(2 downto 0) := background; -- Data to write to memory
    signal mem_wr  : std_logic := '0'; -- Write enable for memory

    -- VGA pixel position
    signal pixel_x : integer range 0 to 639 := 0; -- Horizontal pixel coordinate for VGA
    signal pixel_y : integer range 0 to 479 := 0; -- Vertical pixel coordinate for VGA

    -- Game clock for player visibility
    signal game_clock : std_logic;

begin
    -- VGA Memory Interface: Maps the internal memory signals to the VGA output
    vga_interface: entity work.vga_mem port map(
        clock    => clock,
        reset    => not reset,
        mem_adr  => mem_adr,
        mem_in   => mem_in,
        mem_wr   => mem_wr,
        vga_hs   => VGA_HS,
        vga_vs   => VGA_VS,
        blank    => VGA_BLANK_N,
        r        => VGA_R,
        g        => VGA_G,
        b        => VGA_B,
        pclock   => VGA_CLK
    );

    -- clock divider for game
    game_speed: process(clock, reset)
        variable counter : integer := 0;
    begin
        if reset = '0' then
            counter := 0;
            game_clock <= '0';
        elsif rising_edge(clock) then
            if counter = 599999 then -- Adjust counter value for desired speed
                counter := 0;
                game_clock <= not game_clock; -- Toggle the game clock
            else
                counter := counter + 1;
            end if;
        end if;
    end process;

    -- Direction Control: Updates the direction of the snake based on key presses
    direction_control: process(game_clock, reset)
    begin
        if reset = '0' then
            direction <= "00"; -- Reset to moving right
        elsif rising_edge(game_clock) then
            if KEY(3) = '0' then
                direction <= "01"; -- Move up
            elsif KEY(2) = '0' then
                direction <= "11"; -- Move down
            elsif KEY(1) = '0' then
                direction <= "10"; -- Move left
            elsif KEY(0) = '0' then
                direction <= "00"; -- Move right
            end if;
        end if;
    end process;

    -- Snake Movement and Growth: Handles the movement and growth of the snake, as well as food collision
    snake_logic: process(game_clock, reset)
        variable i : integer;
    begin
        if reset = '0' then
            -- Reset snake properties on reset
            snake_length <= 5;
            snake_head_x <= 10;
            snake_head_y <= 7;
            snake_body(0) <= std_logic_vector(to_unsigned(10, 8)) & std_logic_vector(to_unsigned(7, 8));
            food_x <= 5;
            food_y <= 5;
        elsif rising_edge(game_clock) then
            -- Move the snake by shifting body segments
            for i in 1 to 199 loop
                if i < snake_length then
                    snake_body(i) <= snake_body(i-1); -- Shift body segments forward
                end if;
            end loop;

            -- Update the head position based on the current direction
            case direction is
                when "00" => snake_head_x <= (snake_head_x + 1) mod grid_width; -- Move right
                when "01" => snake_head_y <= (snake_head_y - 1 + grid_height) mod grid_height; -- Move up
                when "10" => snake_head_x <= (snake_head_x - 1 + grid_width) mod grid_width; -- Move left
                when "11" => snake_head_y <= (snake_head_y + 1) mod grid_height; -- Move down
                when others => null;
            end case;
            -- Update snake head position in the body array
            snake_body(0) <= std_logic_vector(to_unsigned(snake_head_x, 8)) & std_logic_vector(to_unsigned(snake_head_y, 8));

            -- Check for food collision and grow the snake if necessary
            if (snake_head_x >= food_x and snake_head_x < food_x + 2) and
               (snake_head_y >= food_y and snake_head_y < food_y + 2) then
                if snake_length < 200 then
                    snake_length <= snake_length + 1;
                end if;
                -- Generate new food position with added randomness
                food_x <= (food_x + 10 + snake_length) mod grid_width;
                food_y <= (food_y + 7 + snake_length) mod grid_height;
            end if;

            -- Check for collisions with itself
            for i in 1 to 199 loop
                if i < snake_length then
                    if snake_head_x = to_integer(unsigned(snake_body(i)(15 downto 8))) and
                       snake_head_y = to_integer(unsigned(snake_body(i)(7 downto 0))) then
                        snake_length <= 5; -- Collision detected: Reset snake length
                    end if;
                end if;
            end loop;
        end if;
    end process;

    -- VGA Rendering: Renders the game objects (snake, food, background) to the VGA display
    vga_render: process(reset, pixel_x, pixel_y)
        variable i : integer;
    begin
        if reset = '0' then
            mem_wr <= '0'; -- Clear the screen when reset
            mem_in <= background;
        else
            mem_adr <= std_logic_vector(to_unsigned(pixel_y / cell_size, 7)) & std_logic_vector(to_unsigned(pixel_x / cell_size, 8));
            mem_wr <= '1';

            -- Draw the food (rendered as a larger 2x2 block)
            if (pixel_x / cell_size >= food_x and pixel_x / cell_size < food_x + 2) and
               (pixel_y / cell_size >= food_y and pixel_y / cell_size < food_y + 2) then
                mem_in <= food_color;
            else
                -- Draw the snake
                mem_in <= background;
                for i in 0 to 199 loop
                    if i < snake_length then
                        if pixel_x / cell_size = to_integer(unsigned(snake_body(i)(15 downto 8))) and
                           pixel_y / cell_size = to_integer(unsigned(snake_body(i)(7 downto 0))) then
                            mem_in <= snake_color;
                        end if;
                    end if;
                end loop;
            end if;
        end if;
    end process;

    -- VGA Pixel Position Update: Updates pixel positions for rendering
    pixel_position: process(clock, reset)
    begin
        if reset = '0' then
            pixel_x <= 0;
            pixel_y <= 0;
        elsif rising_edge(clock) then
            if pixel_x = 639 then
                pixel_x <= 0;
                if pixel_y = 479 then
                    pixel_y <= 0;
                else
                    pixel_y <= pixel_y + 1;
                end if;
            else
                pixel_x <= pixel_x + 1;
            end if;
        end if;
    end process;
end architecture;
