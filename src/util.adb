
package body Util is

   function Log2(n : Natural) return Natural is
      i  : Natural := n;
      r  : Natural := 0;
   begin
      while i > 0 loop
         r := r + 1;
         i := i / 2;
      end loop;
      return r;
   end Log2;

   function To_String(i : Integer) return String is
      str : constant String := Integer'Image(i);
   begin
      if str(str'First) = ' ' then
         return str(str'First + 1 .. str'Last);
      else
         return str;
      end if;
   end To_String;

end Util;
