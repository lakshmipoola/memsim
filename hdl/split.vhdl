
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity split is
   generic (
      ADDR_WIDTH  : in natural := 64;
      WORD_WIDTH  : in natural := 64;
      OFFSET      : in natural := 128;
   );
   port (
      clk      : in  std_logic;
      rst      : in  std_logic;
      addr     : in  std_logic_vector(ADDR_WIDTH - 1 downto 0);
      din      : in  std_logic_vector(WORD_WIDTH - 1 downto 0);
      dout     : out std_logic_vector(WORD_WIDTH - 1 downto 0);
      re       : in  std_logic;
      we       : in  std_logic;
      ready    : out std_logic;
      maddr0   : in  std_logic_vector(ADDR_WIDTH - 1 downto 0);
      min0     : in  std_logic_vector(WORD_WIDTH - 1 downto 0);
      mout0    : out std_logic_vector(WORD_WIDTH - 1 downto 0);
      mre0     : in  std_logic;
      mwe0     : in  std_logic;
      mready0  : out std_logic;
      maddr1   : out std_logic_vector(ADDR_WIDTH - 1 downto 0);
      mout1    : out std_logic_vector(WORD_WIDTH - 1 downto 0);
      min1     : in  std_logic_vector(WORD_WIDTH - 1 downto 0);
      mre1     : out std_logic;
      mwe1     : out std_logic;
      mready1  : in  std_logic
   );
end split;

architecture split_arch of split is

   signal bank0 : std_logic;

begin

   bank0 <= '1' when unsigned(addr) < OFFSET else '0';

   maddr0   <= addr;
   maddr1   <= std_logic_vector(unsigned(addr) - OFFSET);
   mout0    <= din;
   mout1    <= din;
   dout     <= min0 when bank0 = '1' else min1;
   mre0     <= '1' when bank0 = '1' and re = '1' else '0';
   mre1     <= '1' when bank0 = '0' and re = '1' else '0';
   mwe0     <= '1' when bank0 = '1' and we = '1' else '0';
   mwe1     <= '1' when bank0 = '0' and we = '1' else '0';
   ready    <= '1' when mready0 = '1' and mready1 = '1' else '0';

end split_arch;
