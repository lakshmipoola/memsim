
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Memory.RAM; use Memory.RAM;
use Memory;

package body Test.RAM is

   procedure Run_Tests is

      mem : RAM_Pointer := Create_RAM(latency   => 100,
                                      word_size => 4);
      other : Memory_Pointer := null;

   begin

      Check(Get_Time(mem.all) = 0, "ram1");
      Check(Get_Writes(mem.all) = 0, "ram2");

      Read(mem.all, 0, 4);
      Check(Get_Time(mem.all) = 100, "ram3");
      Check(Get_Writes(mem.all) = 0, "ram4");

      Read(mem.all, 2, 4);
      Check(Get_Time(mem.all) = 300, "ram5");

      Write(mem.all, 1, 8);
      Check(Get_Time(mem.all) = 600, "ram6");
      Check(Get_Writes(mem.all) = 1, "ram7");

      Reset(mem.all);
      Check(Get_Time(mem.all) = 0, "ram8");

      Check(To_String(mem.all) = "(ram (latency 100)(word_size 4))", "ram9");

      other := Clone(mem.all);
      Check(To_String(other.all) = To_String(mem.all), "ram10");

      Destroy(Memory_Pointer(mem));

   end Run_Tests;

end Test.RAM;