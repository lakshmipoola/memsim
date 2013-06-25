
with Ada.Text_IO;             use Ada.Text_IO;
with Ada.Assertions;          use Ada.Assertions;
with Ada.Numerics.Generic_Elementary_Functions;
with Ada.Unchecked_Deallocation;
with Memory.Cache;            use Memory.Cache;
with Memory.SPM;              use Memory.SPM;
with Memory.Transform;        use Memory.Transform;
with Memory.Transform.Flip;   use Memory.Transform.Flip;
with Memory.Transform.Offset; use Memory.Transform.Offset;
with Memory.Transform.Shift;  use Memory.Transform.Shift;
with Memory.Transform.EOR;    use Memory.Transform.EOR;
with Memory.Prefetch;         use Memory.Prefetch;
with Memory.Split;            use Memory.Split;
with Memory.Join;             use Memory.Join;
with Applicative;             use Applicative;

package body Memory.Super is

   package Float_Math is new Ada.Numerics.Generic_Elementary_Functions(Float);

   function Create_Memory(mem       : Super_Type;
                          next      : access Memory_Type'Class;
                          cost      : Cost_Type;
                          in_bank   : Boolean)
                          return Memory_Pointer;

   function Create_Split(mem     : Super_Type;
                         next    : access Memory_Type'Class;
                         cost    : Cost_Type;
                         in_bank : Boolean)
                         return Memory_Pointer;

   function Create_Transform(mem       : Super_Type;
                             next      : access Memory_Type'Class;
                             cost      : Cost_Type;
                             in_bank   : Boolean)
                             return Memory_Pointer;

   function Create_Memory(mem       : Super_Type;
                          next      : access Memory_Type'Class;
                          cost      : Cost_Type;
                          in_bank   : Boolean)
                          return Memory_Pointer is
      tcost    : constant Cost_Type := cost + Get_Cost(next.all);
      result   : Memory_Pointer := null;
   begin
      case Random(mem.generator.all) mod 5 is
         when 0      =>
            result := Create_Transform(mem, next, cost, in_bank);
         when 1      =>
            result := Random_Prefetch(next, mem.generator.all, tcost);
         when 2      =>
            result := Random_SPM(next, mem.generator.all, tcost);
         when 3      =>
            result := Random_Cache(next, mem.generator.all, tcost);
         when others =>
            result := Create_Split(mem, next, cost, in_bank);
      end case;
      Assert(result /= null, "Memory.Super.Create_Memory returning null");
      return result;
   end Create_Memory;

   function Create_Split(mem     : Super_Type;
                         next    : access Memory_Type'Class;
                         cost    : Cost_Type;
                         in_bank : Boolean)
                         return Memory_Pointer is
      result   : Split_Pointer;
      join0    : Join_Pointer;
      cost0    : Cost_Type;
      bank0    : Memory_Pointer;
      join1    : Join_Pointer;
      cost1    : Cost_Type;
      bank1    : Memory_Pointer;
   begin
      result   := Split_Pointer(Random_Split(next, mem.generator.all, cost));
      join0    := Create_Join(result, 0);
      cost0    := (cost + 1) / 2;
      Push_Limit(mem.generator.all, 0, Get_Offset(result.all));
      bank0    := Create_Memory(mem, join0, cost0, True);
      Pop_Limit(mem.generator.all);
      join1    := Create_Join(result, 1);
      cost1    := cost - cost0;
      Push_Limit(mem.generator.all, Get_Offset(result.all),
                 Address_Type'Last);
      bank1    := Create_Memory(mem, join1, cost1, True);
      Pop_Limit(mem.generator.all);
      Set_Bank(result.all, 0, bank0);
      Set_Bank(result.all, 1, bank1);
      return Memory_Pointer(result);
   end Create_Split;

   function Create_Transform(mem       : Super_Type;
                             next      : access Memory_Type'Class;
                             cost      : Cost_Type;
                             in_bank   : Boolean)
                             return Memory_Pointer is
      result   : Memory_Pointer;
      trans    : Transform_Pointer;
      join     : Join_Pointer;
      bank     : Memory_Pointer;
   begin
      case Random(mem.generator.all) mod 4 is
         when 0 =>
            result := Random_Flip(next, mem.generator.all, cost);
         when 1 =>
            result := Random_Offset(next, mem.generator.all, cost);
         when 2 =>
            result := Random_EOR(next, mem.generator.all, cost);
         when others =>
            result := Random_Shift(next, mem.generator.all, cost);
      end case;
      trans := Transform_Pointer(result);
      if in_bank or (Random(mem.generator.all) mod 2) = 0 then
         join := Create_Join(trans, 0);
         Push_Transform(mem.generator.all, Applicative_Pointer(trans));
         bank := Create_Memory(mem, join, cost, True);
         Pop_Transform(mem.generator.all);
         Set_Bank(trans.all, bank);
      end if;
      return result;
   end Create_Transform;

   function Clone(mem : Super_Type) return Memory_Pointer is
      result : constant Super_Pointer := new Super_Type'(mem);
   begin
      return Memory_Pointer(result);
   end Clone;

   function Done(mem : Super_Type) return Boolean is
   begin
      return mem.iteration > mem.max_iterations;
   end Done;

   function Count_Memories(ptr : Memory_Pointer) return Natural is
   begin
      if ptr /= null then
         if ptr.all in Split_Type'Class then
            declare
               sp : constant Split_Pointer   := Split_Pointer(ptr);
               a  : constant Memory_Pointer  := Get_Bank(sp.all, 0);
               ac : constant Natural         := Count_Memories(a);
               b  : constant Memory_Pointer  := Get_Bank(sp.all, 1);
               bc : constant Natural         := Count_Memories(b);
               n  : constant Memory_Pointer  := Get_Memory(sp.all);
               nc : constant Natural         := Count_Memories(n);
            begin
               return 1 + ac + bc + nc;
            end;
         elsif ptr.all in Transform_Type'Class then
            declare
               tp : constant Transform_Pointer  := Transform_Pointer(ptr);
               bp : constant Memory_Pointer     := Get_Bank(tp.all);
               bc : constant Natural            := Count_Memories(bp);
               np : constant Memory_Pointer     := Get_Memory(tp.all);
               nc : constant Natural            := Count_Memories(np);
            begin
               return 1 + bc + nc;
            end;
         elsif ptr.all in Container_Type'Class then
            declare
               cp : constant Container_Pointer := Container_Pointer(ptr);
            begin
               return 1 + Count_Memories(Get_Memory(cp.all));
            end;
         end if;
      end if;
      return 0;
   end Count_Memories;

   procedure Reset(mem : in out Super_Type) is
   begin
      Put_Line("Iteration:" & Long_Integer'Image(mem.iteration) &
               " (" & To_String(mem.total) & " evaluations)");
      mem.current_length := 0;
      Reset(Container_Type(mem));
   end Reset;

   procedure Read(mem      : in out Super_Type;
                  address  : in Address_Type;
                  size     : in Positive) is
   begin
      mem.current_length := mem.current_length + 1;
      Read(Container_Type(mem), address, size);
      if mem.total = 0 then
         Insert(mem.generator.all, address, size);
      elsif Get_Value(mem'Access) >= mem.best_value * 2 then
         if mem.current_length > mem.total_length / 4 then
            raise Prune_Error;
         end if;
      end if;
   end Read;

   procedure Write(mem     : in out Super_Type;
                   address : in Address_Type;
                   size    : in Positive) is
   begin
      mem.current_length := mem.current_length + 1;
      Write(Container_Type(mem), address, size);
      if mem.total = 0 then
         Insert(mem.generator.all, address, size);
      elsif Get_Value(mem'Access) >= mem.best_value * 2 then
         if mem.current_length > mem.total_length / 4 then
            raise Prune_Error;
         end if;
      end if;
   end Write;

   procedure Remove_Memory(ptr   : in out Memory_Pointer;
                           index : in Natural) is
   begin

      Assert(ptr /= null, "null ptr in Remove_Memory");

      if index = 0 then

         -- Remove this memory.
         if ptr.all in Container_Type'Class then
            declare
               cp    : constant Container_Pointer  := Container_Pointer(ptr);
               next  : constant Memory_Pointer     := Get_Memory(cp.all);
            begin
               Set_Memory(cp.all, null);
               Destroy(ptr);
               ptr := next;
            end;
         else
            Destroy(ptr);
            ptr := null;
         end if;

      elsif ptr.all in Split_Type'Class then
         declare
            sp : constant Split_Pointer   := Split_Pointer(ptr);
            a  : Memory_Pointer           := Get_Bank(sp.all, 0);
            ac : constant Natural         := Count_Memories(a);
            b  : Memory_Pointer           := Get_Bank(sp.all, 1);
            bc : constant Natural         := Count_Memories(b);
            n  : Memory_Pointer           := Get_Memory(sp.all);
         begin

            if 1 + ac > index then

               -- The memory to remove is in the first bank.
               Remove_Memory(a, index - 1);
               Set_Bank(sp.all, 0, a);

            elsif 1 + ac + bc > index then

               -- The memory to remove is in the second bank.
               Remove_Memory(b, index - ac - 1);
               Set_Bank(sp.all, 1, b);

            else

               -- The memory to remove follows this memory.
               Remove_Memory(n, index - ac - bc - 1);
               Set_Memory(sp.all, n);

            end if;
         end;

      elsif ptr.all in Transform_Type'Class then

         declare
            tp    : constant Transform_Pointer  := Transform_Pointer(ptr);
            bank  : Memory_Pointer              := Get_Bank(tp.all);
            count : constant Natural            := Count_Memories(bank);
            next  : Memory_Pointer              := Get_Memory(tp.all);
         begin

            if 1 + count > index then

               -- Remove from the bank.
               Remove_Memory(bank, index - 1);
               Set_Bank(tp.all, bank);

            else

               -- The memory to remove follows this memory.
               Remove_Memory(next, index - count - 1);
               Set_Memory(tp.all, next);

            end if;

         end;

      elsif ptr.all in Container_Type'Class then

         declare
            cp : constant Container_Pointer  := Container_Pointer(ptr);
            n  : Memory_Pointer              := Get_Memory(cp.all);
         begin
            Remove_Memory(n, index - 1);
            Set_Memory(cp.all, n);
         end;

      end if;
   end Remove_Memory;

   procedure Insert_Memory(mem      : in Super_Type;
                           ptr      : in out Memory_Pointer;
                           index    : in Natural;
                           cost     : in Cost_Type;
                           in_bank  : in Boolean) is
   begin

      if index = 0 then

         -- Insert other before ptr.
         ptr := Create_Memory(mem, ptr, cost, in_bank);

      elsif ptr.all in Split_Type'Class then

         declare
            sp : constant Split_Pointer   := Split_Pointer(ptr);
            a  : Memory_Pointer           := Get_Bank(sp.all, 0);
            ac : constant Natural         := Count_Memories(a);
            b  : Memory_Pointer           := Get_Bank(sp.all, 1);
            bc : constant Natural         := Count_Memories(b);
            n  : Memory_Pointer           := Get_Memory(sp.all);
         begin
            if 1 + ac > index then

               -- Insert to the first bank.
               Push_Limit(mem.generator.all, 0, Get_Offset(sp.all));
               Insert_Memory(mem, a, index - 1, cost, True);
               Pop_Limit(mem.generator.all);
               Set_Bank(sp.all, 0, a);

            elsif 1 + ac + bc > index then

               -- Insert to the second bank.
               Push_Limit(mem.generator.all, Get_Offset(sp.all),
                          Address_Type'Last);
               Insert_Memory(mem, b, index - ac - 1, cost, True);
               Pop_Limit(mem.generator.all);
               Set_Bank(sp.all, 1, b);

            else

               -- Insert after the split.
               Insert_Memory(mem, n, index - ac - bc - 1, cost, in_bank);
               Set_Memory(sp.all, n);

            end if;
         end;

      elsif ptr.all in Transform_Type'Class then

         declare
            tp    : constant Transform_Pointer  := Transform_Pointer(ptr);
            bank  : Memory_Pointer              := Get_Bank(tp.all);
            count : constant Natural            := Count_Memories(bank);
            next  : Memory_Pointer              := Get_Memory(tp.all);
         begin
            if 1 + count > index then

               -- Insert to the bank.
               Push_Transform(mem.generator.all, Applicative_Pointer(tp));
               Insert_Memory(mem, bank, index - 1, cost, True);
               Pop_Transform(mem.generator.all);
               Set_Bank(tp.all, bank);

            else

               -- Insert after the transform.
               if Get_Bank(tp.all) = null then
                  Push_Transform(mem.generator.all, Applicative_Pointer(tp));
                  Insert_Memory(mem, next, index - count - 1, cost, in_bank);
                  Pop_Transform(mem.generator.all);
               else
                  Insert_Memory(mem, next, index - count - 1, cost, in_bank);
               end if;
               Set_Memory(tp.all, next);

            end if;
         end;

      elsif ptr.all in Container_Type'Class then

         declare
            cp : constant Container_Pointer  := Container_Pointer(ptr);
            n  : Memory_Pointer              := Get_Memory(cp.all);
         begin
            Insert_Memory(mem, n, index - 1, cost, in_bank);
            Set_Memory(cp.all, n);
         end;

      end if;

   end Insert_Memory;

   procedure Permute_Memory(mem     : in Super_Type;
                            ptr     : in Memory_Pointer;
                            index   : in Natural;
                            cost    : in Cost_Type) is
   begin

      if index = 0 then

         Permute(ptr.all, mem.generator.all, cost + Get_Cost(ptr.all));

      elsif ptr.all in Split_Type'Class then

         declare
            sp : constant Split_Pointer   := Split_Pointer(ptr);
            a  : constant Memory_Pointer  := Get_Bank(sp.all, 0);
            ac : constant Natural         := Count_Memories(a);
            b  : constant Memory_Pointer  := Get_Bank(sp.all, 1);
            bc : constant Natural         := Count_Memories(b);
            n  : constant Memory_Pointer  := Get_Memory(sp.all);
         begin
            if 1 + ac > index then
               Push_Limit(mem.generator.all, 0, Get_Offset(sp.all));
               Permute_Memory(mem, a, index - 1, cost);
               Pop_Limit(mem.generator.all);
            elsif 1 + ac + bc > index then
               Push_Limit(mem.generator.all, Get_Offset(sp.all),
                          Address_Type'Last);
               Permute_Memory(mem, b, index - ac - 1, cost);
               Pop_Limit(mem.generator.all);
            else
               Permute_Memory(mem, n, index - ac - bc - 1, cost);
            end if;
         end;

      elsif ptr.all in Transform_Type'Class then

         declare
            tp    : constant Transform_Pointer  := Transform_Pointer(ptr);
            bank  : constant Memory_Pointer     := Get_Bank(tp.all);
            count : constant Natural            := Count_Memories(bank);
            next  : constant Memory_Pointer     := Get_Memory(tp.all);
         begin
            if 1 + count > index then
               Push_Transform(mem.generator.all, Applicative_Pointer(tp));
               Permute_Memory(mem, bank, index - 1, cost);
               Pop_Transform(mem.generator.all);
            else
               if Get_Bank(tp.all) = null then
                  Push_Transform(mem.generator.all, Applicative_Pointer(tp));
                  Permute_Memory(mem, next, index - count - 1, cost);
                  Pop_Transform(mem.generator.all);
               else
                  Permute_Memory(mem, next, index - count - 1, cost);
               end if;
            end if;
         end;

      elsif ptr.all in Container_Type'Class then

         declare
            cp : constant Container_Pointer  := Container_Pointer(ptr);
            n  : constant Memory_Pointer     := Get_Memory(cp.all);
         begin
            Permute_Memory(mem, n, index - 1, cost);
         end;

      end if;
   end Permute_Memory;

   function Simplify_Memory(ptr : Memory_Pointer) return Memory_Pointer is
   begin
      if ptr.all in Split_Type'Class then
         declare
            sp : Split_Pointer   := Split_Pointer(ptr);
            b0 : Memory_Pointer  := Get_Bank(sp.all, 0);
            b1 : Memory_Pointer  := Get_Bank(sp.all, 1);
            n  : Memory_Pointer  := Get_Memory(sp.all);
         begin
            b0 := Simplify_Memory(b0);
            Set_Bank(sp.all, 0, b0);
            b1 := Simplify_Memory(b1);
            Set_Bank(sp.all, 1, b1);
            n := Simplify_Memory(n);
            if b0.all in Join_Type'Class and b1.all in Join_Type'Class then
               Set_Memory(sp.all, null);
               Destroy(Memory_Pointer(sp));
               return n;
            else
               Set_Memory(sp.all, n);
               return ptr;
            end if;
         end;
      elsif ptr.all in Transform_Type'Class then
         declare
            tp    : Transform_Pointer  := Transform_Pointer(ptr);
            bank  : Memory_Pointer     := Get_Bank(tp.all);
            next  : Memory_Pointer     := Get_Memory(tp.all);
         begin
            if bank /= null then
               bank := Simplify_Memory(bank);
               Set_Bank(tp.all, bank);
            end if;
            next := Simplify_Memory(next);
            if tp.Is_Empty then
               Set_Memory(tp.all, null);
               Destroy(Memory_Pointer(tp));
               return next;
            else
               Set_Memory(tp.all, next);
               return ptr;
            end if;
         end;
      elsif ptr.all in Container_Type'Class then
         declare
            cp : constant Container_Pointer  := Container_Pointer(ptr);
            n  : Memory_Pointer              := Get_Memory(cp.all);
         begin
            n := Simplify_Memory(n);
            Set_Memory(cp.all, n);
            return ptr;
         end;
      else
         return ptr;
      end if;
   end Simplify_Memory;

   procedure Randomize(mem : in out Super_Type) is
      len   : constant Natural := Count_Memories(mem.current);
      pos   : Natural;
      cost  : constant Cost_Type := Get_Cost(mem.current.all);
      left  : constant Cost_Type := mem.max_cost - cost;
   begin

      -- Select an action to take.
      -- Here we give extra weight to modifying an existing subsystem
      -- rather than adding or removing components.
      case Random(mem.generator.all) mod 16 is
         when 0      =>    -- Insert a component.
            if Cost_Type(len) >= mem.max_cost then
               pos := Random(mem.generator.all) mod len;
               Remove_Memory(mem.current, pos);
            else
               pos := Random(mem.generator.all) mod (len + 1);
               Insert_Memory(mem, mem.current, pos, left, False);
            end if;
         when 1 .. 3 =>    -- Remove a component.
            if len = 0 then
               Insert_Memory(mem, mem.current, 0, left, False);
            else
               pos := Random(mem.generator.all) mod len;
               Remove_Memory(mem.current, pos);
            end if;
         when others =>    -- Modify a component.
            if len = 0 then
               Insert_Memory(mem, mem.current, 0, left, False);
            else
               pos := Random(mem.generator.all) mod len;
               Permute_Memory(mem, mem.current, pos, left);
            end if;
      end case;
      Set_Memory(mem, mem.current);

      Assert(Get_Cost(mem) <= mem.max_cost, "Invalid randomize");

   end Randomize;

   function Create_Super(mem              : not null access Memory_Type'Class;
                         max_cost         : Cost_Type;
                         seed             : Integer;
                         max_iterations   : Long_Integer)
                         return Super_Pointer is
      result : constant Super_Pointer := new Super_Type;
   begin
      result.max_cost         := max_cost;
      result.max_iterations   := max_iterations;
      result.last             := Memory_Pointer(mem);
      result.current          := Clone(mem.all);
      result.generator        := new Distribution_Type;
      Set_Seed(result.generator.all, seed);
      Set_Memory(result.all, result.current);
      return result;
   end Create_Super;

   procedure Update_Memory(mem   : in out Super_Type;
                           value : in Value_Type) is
      eold  : constant Float := Float(mem.last_value);
      enew  : constant Float := Float(value);
      dele  : constant Float := abs(enew - eold);
      prob  : constant Float := Float_Math.Exp(-dele / mem.temperature);
      rand  : constant Float := Float(Random(mem.generator.all)) /
                                Float(Natural'Last);
   begin

      -- Update the temperature.
      mem.temperature := mem.temperature * 0.99;
      if mem.temperature < 1.0 / Float(Natural'Last) then
         mem.temperature := enew * 2.0;
      end if;

      if value <= mem.last_value or rand < prob or mem.total = 0 then

         -- Keep the current memory.
         mem.last_value := value;
         Destroy(mem.last);
         mem.last := Clone(mem.current.all);

      else

         -- Revert to the previous memory.
         Destroy(mem.current);
         mem.current := Clone(mem.last.all);

      end if;

      -- Make a random modification to the memory.
      Set_Memory(mem, mem.current);
      Randomize(mem);

   end Update_Memory;

   procedure Track_Best(mem   : in out Super_Type;
                        cost  : in Cost_Type;
                        value : in Value_Type) is
      simp_mem    : Memory_Pointer;
      simp_cost   : Cost_Type;
      simp_name   : Unbounded_String;
   begin

      -- Value can't change from simplification, so we check it first.
      if value > mem.best_value then
         return;
      end if;

      -- Value is at least as good; so simplify the memory.
      simp_mem    := Simplify_Memory(Clone(mem.current.all));
      simp_cost   := Get_Cost(simp_mem.all);

      -- If the value is the same, we will only accept the memory if
      -- the cost is at least as good.
      if value = mem.best_value and cost > mem.best_cost then
         Destroy(simp_mem);
         return;
      end if;

      -- Get the name of the simplified memory.
      simp_name := To_String(simp_mem.all);

      -- If the cost and value are the same, we accept the memory
      -- only if the name is shorter.
      if value = mem.best_value and then cost = mem.best_cost and then
         Length(simp_name) > Length(mem.best_name) then
         Destroy(simp_mem);
         return;
      end if;

      -- If we get here, we have a better memory subsystem.
      mem.iteration  := 0;
      mem.best_value := value;
      mem.best_cost  := simp_cost;
      mem.best_name  := simp_name;
      Destroy(simp_mem);

   end Track_Best;

   procedure Cache_Result(mem    : in out Super_Type;
                          value  : in Value_Type) is
      simp_mem    : Memory_Pointer;
      simp_name   : Unbounded_String;
   begin
      simp_mem    := Simplify_Memory(Clone(mem.current.all));
      simp_name   := To_String(simp_mem.all);
      mem.table.Insert(simp_name, value);
      Destroy(simp_mem);
   end Cache_Result;

   function Check_Cache(mem : Super_Type) return Value_Type is
      simp_mem    : Memory_Pointer;
      simp_name   : Unbounded_String;
      cursor      : Value_Maps.Cursor;
   begin
      simp_mem    := Simplify_Memory(Clone(mem.current.all));
      simp_name   := To_String(simp_mem.all);
      Destroy(simp_mem);
      cursor      := mem.table.Find(simp_name);
      if Value_Maps."="(cursor, Value_Maps.No_Element) then
         return 0;
      else
         return Value_Maps.Element(cursor);
      end if;
   end Check_Cache;

   procedure Finish_Run(mem : in out Super_Type) is
      cost  : constant Cost_Type := Get_Cost(mem);
      value : Value_Type := Get_Value(mem'Access);
   begin

      -- Scale the result if necessary.
      if mem.current_length > mem.total_length then
         mem.total_length := mem.current_length;
      end if;
      if mem.current_length /= mem.total_length then
         Put_Line("Prune");
         declare
            mult : constant Long_Float := Long_Float(mem.total_length) *
                                          Long_Float(mem.current_length);
            fval : constant Long_Float := Long_Float(value) * mult;
         begin
            if fval >= Long_Float(Value_Type'Last) then
               value := Value_Type'Last;
            else
               value := Value_Type(fval);
            end if;
         end;
         if value < mem.best_value then
            Put_Line("Prune overflow");
            value := mem.best_value + 1;
         end if;
      end if;

      -- Keep track of the best memory.
      Track_Best(mem, cost, value);

      -- Keep track of the result of running with this memory.
      Cache_Result(mem, value);

      -- Generate new memories until we find a new one.
      Put_Line("Temperature:" & Float'Image(mem.temperature));
      loop
         Update_Memory(mem, value);
         value := Check_Cache(mem);
         exit when value = 0;
      end loop;
      Put_Line(To_String(To_String(mem)));

      -- Keep track of the number of iterations.
      mem.iteration  := mem.iteration + 1;
      mem.total      := mem.total + 1;

   end Finish_Run;

   procedure Show_Access_Stats(mem : in out Super_Type) is
   begin
      Finish_Run(mem);
      Put_Line("Best Memory: " & To_String(mem.best_name));
      Put_Line("Best Value:  " & Value_Type'Image(mem.best_value));
      Put_Line("Best Cost:   " & Cost_Type'Image(mem.best_cost));
   end Show_Access_Stats;

   procedure Adjust(mem : in out Super_Type) is
   begin
      Adjust(Container_Type(mem));
      mem.generator  := new Distribution_Type;
      mem.last       := null;
      mem.current    := null;
   end Adjust;

   procedure Destroy is new Ada.Unchecked_Deallocation(Distribution_Type,
                                                       Distribution_Pointer);

   procedure Finalize(mem : in out Super_Type) is
   begin
Print(mem.generator.all);
      Set_Memory(mem, null);
      Finalize(Container_Type(mem));
      Destroy(mem.generator);
      Destroy(mem.last);
      Destroy(mem.current);
   end Finalize;

end Memory.Super;
