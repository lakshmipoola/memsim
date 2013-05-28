
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spm is
   generic (
      ADDR_WIDTH  : in natural := 64;
      WORD_WIDTH  : in natural := 64;
      SIZE        : in natural := 128
   );
   port (
      clk      : in std_logic;
      rst      : in std_logic;
      addr     : in std_logic_vector(ADDR_WIDTH - 1 downto 0);
      din      : in std_logic_vector(WORD_WIDTH - 1 downto 0);
      dout     : out std_logic_vector(WORD_WIDTH - 1 downto 0);
      re       : in std_logic;
      we       : in std_logic;
      ready    : out std_logic;
      maddr    : out std_logic_vector(ADDR_WIDTH - 1 downto 0);
      mout     : out std_logic_vector(WORD_WIDTH - 1 downto 0);
      min      : in std_logic_vector(WORD_WIDTH - 1 downto 0);
      mre      : out std_logic;
      mwe      : out std_logic;
      mready   : in std_logic
   );
end spm;

architecture spm_arch of spm is

   subtype word_type is std_logic_vector(WORD_WIDTH - 1 downto 0);
   type word_array_type is array(0 to  SIZE - 1) of word_type;

   signal data    : word_array_type;
   signal value   : word_type;
   signal raddr   : natural;
   signal rin     : std_logic_vector(WORD_WIDTH - 1 downto 0);
   signal rre     : std_logic;
   signal rwe     : std_logic;

begin

   process(clk)
   begin
      if clk'event and clk = '1' and rst = '0' then
         if rre = '1' then
            value <= data(raddr);
         elsif rwe = '1' then
            data(raddr) <= rin;
         end if;
      end if;
   end process;

   process(clk)
   begin
      if clk'event and clk = '1' then
         if rst = '1' then
            rre <= '0';
            rwe <= '0';
         else
            if ADDR_WIDTH > 31 then
               raddr <= to_integer(unsigned(addr(30 downto 0)));
            else
               raddr <= to_integer(unsigned(addr));
            end if;
            if unsigned(addr) < SIZE then
               rre <= re;
               rwe <= we;
               rin <= din;
            else
               rre <= '0';
               rwe <= '0';
            end if;
         end if;
      end if;
   end process;

   maddr <= addr;
   mre   <= re when unsigned(addr) >= SIZE else '0';
   mwe   <= we when unsigned(addr) >= SIZE else '0';
   dout  <= value when unsigned(addr) < SIZE else min;
   mout  <= din;
   ready <= mready when rre = '0' and rwe = '0' else '0';

end spm_arch;
