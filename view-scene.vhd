library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity game_logic_and_rgb_gen is
    generic(
-- ATUR SCREEN SIZE 640x480		
        --crappy sreen resolution for vga
        screen_width        : integer := 640;  
        screen_height       : integer := 480;
        food_width          : integer := 20;
        head_width          : integer := 20;
        snake_begin_x       : integer := 500;
        snake_begin_y       : integer := 100;
        snake_length_begin  : integer := 1;
        snake_length_max    : integer := 20;
        food_begin_x        : integer := 100;
        food_begin_y        : integer := 300);
    port(
        --game logic part
        clk_60hz            : in  std_logic;
        direction           : in  std_logic_vector(1 downto 0);
        stop                : in  std_logic;
        reset               : in  std_logic;
        --rgb generation part
        clk_50mhz           : in  std_logic;
        en                  : in  std_logic;
        row, col            : in  std_logic_vector(15 downto 0);
        debug_led           : out std_logic_vector(7 downto 0);
        rout, gout, bout    : out std_logic);
end entity;

architecture main of game_logic_and_rgb_gen is
    --                                -----------------------------------------
    --components of 32 bit body part: | 16bit: x position | 16bit: y position |
    --                                -----------------------------------------
    subtype xy is std_logic_vector(31 downto 0);
    type xys is array (integer range <>) of xy;

    --assume the left most xy is the head position
    signal snake_length         : integer range 0 to snake_length_max;
    signal snake_mesh_xy        : xys(0 to snake_length_max - 1);
    signal food_xy              : xy;
    signal random_xy            : unsigned(31 downto 0);
begin

snake_move:
    process(clk_60hz, reset, random_xy)
        --speed in pixel
        constant snake_speed    : signed(15 downto 0) := to_signed(1, 16);

        variable inited                     : std_logic := '0';
        variable snake_head_xy_future       : xy := (others => '0');
        variable food_xy_future             : xy := (others => '0');
        variable snake_length_future        : integer := 0;
        variable dx, dy                     : signed(15 downto 0) := (others => '0');
    begin
        food_xy         <= food_xy_future;
        snake_length    <= snake_length_future;
        if (reset = '1' or inited = '0') then
            --reset snake length
            snake_length_future := snake_length_begin;

            --set food position
            food_xy_future(31 downto 16) := std_logic_vector(to_signed(food_begin_x, 16));
            food_xy_future(15 downto 0) := std_logic_vector(to_signed(food_begin_y, 16));

            --set head position
            snake_head_xy_future(31 downto 16)  := std_logic_vector(to_signed(snake_begin_x , 16));
            snake_head_xy_future(15 downto 0)   := std_logic_vector(to_signed(snake_begin_y , 16));

            --set snake position
            for i in 0 to snake_length_max - 1 loop
                snake_mesh_xy(i) <= snake_head_xy_future;
            end loop;
            
            inited := '1';
        
		  elsif (clk_60hz'event and clk_60hz = '1') then
            if (stop = '0') then
                --move
                case direction is
                    when("00") =>       --up
                        snake_head_xy_future(15 downto 0) := std_logic_vector(signed(snake_head_xy_future(15 downto 0)) - snake_speed);
                    when("01") =>       --right
                        snake_head_xy_future(31 downto 16) := std_logic_vector(signed(snake_head_xy_future(31 downto 16)) + snake_speed);
                    when("10") =>       --down
                        snake_head_xy_future(15 downto 0) := std_logic_vector(signed(snake_head_xy_future(15 downto 0)) + snake_speed);
                    when others =>       --left
                        snake_head_xy_future(31 downto 16) := std_logic_vector(signed(snake_head_xy_future(31 downto 16)) - snake_speed);
                end case;
					 
                for i in snake_length_max - 1 downto 1 loop
                    snake_mesh_xy(i) <= snake_mesh_xy(i - 1);
                end loop;
                snake_mesh_xy(0) <= snake_head_xy_future; --push new head to snake body queue

                --boundary check
                if (signed(snake_head_xy_future(31 downto 16)) < 0 or 
                    signed(snake_head_xy_future(31 downto 16)) >= screen_width or
                    signed(snake_head_xy_future(15 downto 0)) < 0 or
                    signed(snake_head_xy_future(15 downto 0)) >= screen_height) then
                    inited := '0';
                end if;

                --food check
                dx := abs(signed(snake_head_xy_future(31 downto 16)) - signed(food_xy_future(31 downto 16)));
                dy := abs(signed(snake_head_xy_future(15 downto 0))  - signed(food_xy_future(15 downto 0)));
                if (dy < (food_width + head_width) / 2 and
                    dx < (food_width + head_width) / 2) then
                    snake_length_future := snake_length_future + 1;
                    --change food position 
                    food_xy_future := std_logic_vector(random_xy);
                end if;
            end if;
        end if;
    end process;

random_number_gen:
    process(clk_50mhz)
        variable random_x : unsigned(15 downto 0) := (others => '0');
        variable random_y : unsigned(15 downto 0) := (others => '0');
    begin
        if (clk_50mhz'event and clk_50mhz = '1') then
            if (random_x = to_unsigned(screen_width - 14, 16)) then 
                random_x := (others => '0');
            end if;
            if (random_y = to_unsigned(screen_height - 14, 16)) then 
                random_y := (others => '0');
            end if;
            random_x := random_x + 1;
            random_y := random_y + 1;
            random_xy(31 downto 16) <= random_x + 7;
            random_xy(15 downto 0) <= random_y + 7;
        end if;
    end process;
	 
-- for debugging purpose only
debug_led <= std_logic_vector(random_xy(23 downto 16));
--debug_led <= std_logic_vector(random_xy(27)) & std_logic_vector(random_xy(24)) & std_logic_vector(random_xy(19)) & std_logic_vector(random_xy(16)) & std_logic_vector(random_xy(11)) & std_logic_vector(random_xy(8)) & std_logic_vector(random_xy(3)) & std_logic_vector(random_xy(0));

draw:
    process(snake_length, snake_mesh_xy, food_xy, row, col, en)
        --x and y distance from body part or food
        variable dx, dy             : signed(15 downto 0) := (others => '0');
        --if current pixel is belong to body or food
        variable is_body, is_food   : std_logic := '0';
    begin
        if (en = '1') then 
            --draw body
            is_body := '0';
            for i in 0 to snake_length_max - 1 loop
                dx := abs(signed(col) - signed(snake_mesh_xy(i)(31 downto 16)));
                dy := abs(signed(row) - signed(snake_mesh_xy(i)(15 downto 0)));
                if (i < snake_length) then  --if is valid snake body
                    if (dx < head_width / 2 and dy < head_width / 2) then
                        is_body := '1';
                    end if;
                end if;
            end loop;
            --draw food
            dx := abs(signed(col) - signed(food_xy(31 downto 16)));
            dy := abs(signed(row) - signed(food_xy(15 downto 0)));
            if (dx < food_width / 2 and dy < food_width / 2) then
                is_food := '1';
            else 
                is_food := '0';
            end if;

            if (is_body = '1') then
                rout <= '1';
                gout <= '0';
                bout <= '0';
            elsif (is_food = '1') then
                rout <= '0';
                gout <= '0';
                bout <= '1';
            else 
                rout <= '0';
                gout <= '0';
                bout <= '0';
            end if;
        else 
            rout <= '0';
            gout <= '0';
            bout <= '0';
        end if;
		  
--		  if (en='1') then
--				rout <= '0';	
--				gout <= '1';
--				bout <= '0';
--			else
--				rout <= '0';	
--				gout <= '0';
--				bout <= '0';
--			end if;
		  
    end process;
end main;
