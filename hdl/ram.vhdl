
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ram is
   generic (
      ADDR_WIDTH  : in natural := 64;
      WORD_WIDTH  : in natural := 64;
      SIZE        : in natural := 65536;
      LATENCY     : in natural := 10
   );
   port (
      clk      : in std_logic;
      rst      : in std_logic;
      addr     : in std_logic_vector(ADDR_WIDTH - 1 downto 0);
      din      : in std_logic_vector(WORD_WIDTH - 1 downto 0);
      dout     : out std_logic_vector(WORD_WIDTH - 1 downto 0);
      re       : in std_logic;
      we       : in std_logic;
      ready    : out std_logic
   );
end ram;

architecture ram_arch of ram is

   subtype word_type is std_logic_vector(WORD_WIDTH - 1 downto 0);
   type word_array_type is array (0 to SIZE - 1) of word_type;

   signal data       : word_array_type;
   signal value      : word_type;
   signal counter    : natural;
   signal nat_addr   : natural;
   signal do_read    : std_logic;
   signal do_write   : std_logic;

begin

   process(clk)
   begin
      if clk'event and clk = '1' then
         do_read <= '0';
         do_write <= '0';
         if rst = '1' then
            counter <= 0;
         elsif re = '1' then
            counter <= LATENCY - 1;
            do_read <= '1';
         elsif we = '1' then
            counter <= LATENCY - 1;
            do_write <= '1';
            value <= din;
         elsif counter > 0 then
            counter <= counter - 1;
         end if;
         if do_read = '1' then
            value <= data(nat_addr);
         elsif do_write = '1' then
            data(nat_addr) <= din;
         end if;
      end if;
   end process;

   process(clk)
   begin
      if clk'event and clk = '1' then
         if ADDR_WIDTH > 32 then
            nat_addr <= to_integer(unsigned(addr(31 downto 0)));
         else
            nat_addr <= to_integer(unsigned(addr));
         end if;
      end if;
   end process;

   ready <= '1' when counter = 0 else '0';
   dout  <= value when counter = 0 else (others => 'Z');

end ram_arch;