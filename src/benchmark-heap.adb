
package body Benchmark.Heap is

   procedure Init(benchmark : in out Heap_Type) is
   begin
      Write(benchmark, 0, 0);
   end Init;

   procedure Insert(benchmark : in out Heap_Type;
                    value     : in Integer) is

      size  : constant Integer := Read(benchmark, 0) + 1;
      ptr   : Integer := size;
 
   begin

      -- Increase the size of the heap.
      Write(benchmark, 0, size);

      -- Restore the heap property.
      while ptr > 1 loop
         declare
            parent   : constant Integer := ptr / 2;
            pv       : constant Integer := Read(benchmark, parent);
         begin
            exit when value >= pv;
            Write(benchmark, ptr, pv);
            ptr := parent;
         end;
      end loop;
      Write(benchmark, ptr, value);

   end Insert;

   procedure Remove(benchmark : in out Heap_Type;
                    value     : out Integer) is

      size        : constant Integer := Read(benchmark, 0);
      ptr         : Integer := 1;
      displaced   : constant Integer := Read(benchmark, size);

   begin

      -- Get the result.
      value := Read(benchmark, 1);

      -- Resize the heap.
      Write(benchmark, 0, size - 1);

      -- Restore the heap property.
      loop
         declare
            left  : constant Integer := ptr * 2;
            right : constant Integer := left + 1;
         begin
            if right < size then
               declare
                  lv : constant Integer := Read(benchmark, left);
                  rv : constant Integer := Read(benchmark, right);
               begin
                  if rv > lv and displaced > lv then
                     Write(benchmark, ptr, lv);
                     ptr := left;
                  elsif lv > rv and displaced > rv then
                     Write(benchmark, ptr, rv);
                     ptr := right;
                  else
                     exit;
                  end if;
               end;
            elsif left < size then
               declare
                  lv : constant Integer := Read(benchmark, left);
               begin
                  if displaced > lv then
                     Write(benchmark, ptr, lv);
                     ptr := left;
                  else
                     exit;
                  end if;
               end;
            else
               exit;
            end if;
         end;
      end loop;

      -- Place the value in its final position.
      Write(benchmark, ptr, displaced);

   end Remove;

   procedure Run(benchmark : in out Heap_Type) is
      length   : constant Positive := benchmark.length;
      size     : constant Positive := benchmark.size;
   begin

      Init(benchmark);

      for i in 1 .. size loop
         Insert(benchmark, Get_Random(benchmark));
      end loop;

      for i in 1 .. length loop
         declare
            value : Integer;
         begin
            Remove(benchmark, value);
         end;
         Insert(benchmark, Get_Random(benchmark));
      end loop;

   end Run;

end Benchmark.Heap;
