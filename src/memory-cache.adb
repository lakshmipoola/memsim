
with Ada.Unchecked_Deallocation;
with Ada.Assertions; use Ada.Assertions;
with Random_Enum;

package body Memory.Cache is

   function Create_Cache(mem           : access Memory_Type'Class;
                         line_count    : Positive := 1;
                         line_size     : Positive := 8;
                         associativity : Positive := 1;
                         latency       : Time_Type := 1;
                         policy        : Policy_Type := LRU;
                         exclusive     : Boolean := False;
                         write_back    : Boolean := True)
                         return Cache_Pointer is
      result : constant Cache_Pointer := new Cache_Type;
   begin
      Set_Memory(result.all, mem);
      result.line_size     := line_size;
      result.line_count    := line_count;
      result.associativity := associativity;
      result.latency       := latency;
      result.policy        := policy;
      result.exclusive     := exclusive;
      result.write_back    := write_back;
      result.data.Set_Length(Count_Type(result.line_count));
      for i in 0 .. result.line_count - 1 loop
         result.data.Replace_Element(i, new Cache_Data);
      end loop;
      return result;
   end Create_Cache;

   function Random_Policy is new Random_Enum(Policy_Type);

   function Random_Boolean is new Random_Enum(Boolean);

   function Random_Cache(generator  : RNG.Generator;
                         max_cost   : Cost_Type)
                         return Memory_Pointer is
      result : Cache_Pointer := new Cache_Type;
   begin

      -- Start with everything set to the minimum.
      result.line_size     := 1;
      result.line_count    := 1;
      result.associativity := 1;
      result.latency       := 1;
      result.policy        := Random;
      result.exclusive     := False;
      result.write_back    := True;

      -- If even the minimum cache is too costly, return nulll.
      if Get_Cost(result.all) > max_cost then
         Destroy(Memory_Pointer(result));
         return null;
      end if;

      -- Randomly increase parameters, reverting them if we exceed the cost.
      loop

         -- Line size.
         declare
            line_size : constant Positive := result.line_size;
         begin
            if Random_Boolean(RNG.Random(generator)) then
               result.line_size := line_size * 2;
               if Get_Cost(result.all) > max_cost then
                  result.line_size := line_size;
               end if;
            end if;
         end;

         -- Line count.
         declare
            line_count : constant Positive := result.line_count;
         begin
            if Random_Boolean(RNG.Random(generator)) then
               result.line_count := 2 * line_count;
               if Get_Cost(result.all) > max_cost then
                  result.line_count := line_count;
               end if;
            end if;
         end;

         -- Associativity.
         declare
            associativity : constant Positive := result.associativity;
         begin
            if Random_Boolean(RNG.Random(generator)) then
               result.associativity := result.associativity * 2;
               if result.associativity > result.line_count or else
                  Get_Cost(result.all) > max_cost then
                  result.associativity := associativity;
               end if;
            end if;
         end;

         -- Policy.
         declare
            policy : constant Policy_Type := result.policy;
         begin
            result.policy := Random_Policy(RNG.Random(generator));
            if Get_Cost(result.all) > max_cost then
               result.policy := policy;
            end if;
         end;

         -- Type.
         declare
            exclusive   : constant Boolean := result.exclusive;
            write_back  : constant Boolean := result.write_back;
         begin
            result.exclusive  := Random_Boolean(RNG.Random(generator));
            result.write_back := Random_Boolean(RNG.Random(generator));
            if Get_Cost(result.all) > max_cost then
               result.exclusive := exclusive;
               result.write_back := write_back;
            end if;
         end;

         -- 1 in 16 chance of exiting after adjusting parameters.
         exit when (RNG.Random(generator) mod 16) = 0;

      end loop;

      -- No point in creating a worthless cache.
      Assert(Get_Cost(result.all) <= max_cost, "Invalid cache");
      if result.line_size = 1 and result.line_count = 1 then
         Destroy(Memory_Pointer(result));
         return null;
      else
         result.data.Set_Length(Count_Type(result.line_count));
         for i in 0 .. result.line_count - 1 loop
            result.data.Replace_Element(i, new Cache_Data);
         end loop;
         return Memory_Pointer(result);
      end if;

   end Random_Cache;

   function Clone(mem : Cache_Type) return Memory_Pointer is
      result : constant Cache_Pointer := new Cache_Type'(mem);
   begin
      return Memory_Pointer(result);
   end Clone;

   procedure Permute(mem         : in out Cache_Type;
                     generator   : in RNG.Generator;
                     max_cost    : in Cost_Type) is

      param          : Natural := RNG.Random(generator) mod 8;
      line_size      : constant Positive := mem.line_size;
      line_count     : constant Positive := mem.line_count;
      associativity  : constant Positive := mem.associativity;
      policy         : constant Policy_Type := mem.policy;
      exclusive      : constant Boolean := mem.exclusive;
      write_back     : constant Boolean := mem.write_back;

   begin

      -- Loop until we either change a parameter or we are unable to
      -- change any parameter.
      for i in 1 .. 8 loop
         case param is
            when 0 =>      -- Increase line size
               mem.line_size := line_size * 2;
               exit when Get_Cost(mem) <= max_cost;
               mem.line_size := line_size;
            when 1 =>      -- Decrease line size
               if line_size > 1 then
                  mem.line_size := line_size / 2;
                  exit when Get_Cost(mem) <= max_cost;
                  mem.line_size := line_size;
               end if;
            when 2 =>      -- Increase line count
               mem.line_count := line_count * 2;
               exit when Get_Cost(mem) <= max_cost;
               mem.line_count := line_count;
            when 3 =>      -- Decrease line count
               if line_count > 1 then
                  mem.line_count := line_count / 2;
                  if mem.associativity > mem.line_count then
                     mem.associativity := mem.line_count;
                  end if;
                  exit;
               end if;
            when 4 =>      -- Increase associativity
               if associativity < line_count then
                  mem.associativity := associativity * 2;
                  exit when Get_Cost(mem) <= max_cost;
                  mem.associativity := associativity;
               end if;
            when 5 =>      -- Decrease associativity
               if associativity > 1 then
                  mem.associativity := associativity / 2;
                  exit;
               end if;
            when 6 =>      -- Change policy
               mem.policy := Random_Policy(RNG.Random(generator));
               exit when Get_Cost(mem) <= max_cost;
               mem.policy := policy;
            when others => -- Change type
               mem.exclusive  := Random_Boolean(RNG.Random(generator));
               mem.write_back := Random_Boolean(RNG.Random(generator));
               exit when Get_Cost(mem) <= max_cost;
               mem.exclusive := exclusive;
               mem.write_back := write_back;
         end case;
         param := (param + 1) mod 8;
      end loop;

      mem.data.Set_Length(Count_Type(mem.line_count));
      for i in line_count .. mem.line_count - 1 loop
         mem.data.Replace_Element(i, new Cache_Data);
      end loop;

      Assert(Get_Cost(mem) <= max_cost, "Invalid cache permutation");

   end Permute;

   function Get_Tag(mem       : Cache_Type;
                    address   : Address_Type) return Address_Type is
      mask : constant Address_Type := not Address_Type(mem.line_size - 1);
   begin
      return address and mask;
   end Get_Tag;

   function Get_Index(mem     : Cache_Type;
                      address : Address_Type) return Natural is
      line_size   : constant Address_Type := Address_Type(mem.line_size);
      line_count  : constant Address_Type := Address_Type(mem.line_count);
      assoc       : constant Address_Type := Address_Type(mem.associativity);
      set_count   : constant Address_Type := line_count / assoc;
      base        : constant Address_Type := address / line_size;
   begin
      return Natural(base mod set_count);
   end Get_Index;

   procedure Get_Data(mem      : in out Cache_Type;
                      address  : in Address_Type;
                      is_read  : in Boolean) is

      data        : Cache_Data_Pointer;
      tag         : constant Address_Type := Get_Tag(mem, address);
      first       : constant Natural := Get_Index(mem, address);
      line        : Natural;
      to_replace  : Natural := 0;
      age         : Long_Integer;

   begin

      -- Update the age of all items in this set.
      for i in 0 .. mem.associativity - 1 loop
         line := first + i * mem.line_count / mem.associativity;
         data := mem.data.Element(line);
         data.age := data.age + 1;
      end loop;

      -- First check if this address is already in the cache.
      -- Here we also keep track of the line to be replaced.
      if mem.policy = MRU then
         age := Long_Integer'Last;
      else
         age := Long_Integer'First;
      end if;
      for i in 0 .. mem.associativity - 1 loop
         line := first + i * mem.line_count / mem.associativity;
         data := mem.data.Element(line);
         if tag = data.address then
            if mem.policy /= FIFO then
               data.age := 0;
            end if;
            if is_read or mem.write_back then
               Advance(mem, mem.latency);
               data.dirty := data.dirty or not is_read;
            else
               Write(Container_Type(mem), tag, mem.line_size);
            end if;
            return;
         elsif mem.policy = MRU then
            if data.age < age then
               to_replace := line;
               age := data.age;
            end if;
         else
            if data.age > age then
               to_replace := line;
               age := data.age;
            end if;
         end if;
      end loop;
      if mem.policy = Random then
         line := RNG.Random(mem.generator.all) mod mem.associativity;
         to_replace := first + line * mem.line_count / mem.associativity;
      end if;

      -- If we got here, the item is not in the cache.
      -- If this is a read on an exclusive cache, we just forward the
      -- read the return without caching, otherwise we need to evict the
      -- oldest entry.
      if mem.exclusive and is_read then

         Read(Container_Type(mem), tag, mem.line_size);

      else

         -- Evict the oldest entry.
         -- On write-through caches, the dirty flag will never be set.
         data := mem.data.Element(to_replace);
         if data.dirty then
            Write(Container_Type(mem), data.address, mem.line_size);
            data.dirty := False;
         end if;

         -- Read the new entry.
         data.address := tag;
         Read(Container_Type(mem), data.address, mem.line_size);
         data.age := 0;
         data.dirty := not is_read;

      end if;

   end Get_Data;

   procedure Reset(mem : in out Cache_Type) is
      data : Cache_Data_Pointer;
   begin
      Reset(Container_Type(mem));
      for i in 0 .. mem.line_count - 1 loop
         data := mem.data.Element(i);
         data.address   := Address_Type'Last;
         data.age       := 0;
         data.dirty     := False;
      end loop;
   end Reset;

   procedure Read(mem      : in out Cache_Type;
                  address  : in Address_Type;
                  size     : in Positive) is
      extra : constant Natural := size / mem.line_size;
   begin
      for i in 0 .. extra loop
         Get_Data(mem, address + Address_Type(i * mem.line_size), True);
      end loop;
   end Read;

   procedure Write(mem     : in out Cache_Type;
                   address : in Address_Type;
                   size    : in Positive) is
      extra : constant Natural := size / mem.line_size;
   begin
      for i in 0 .. extra loop
         Get_Data(mem, address + Address_Type(i * mem.line_size), False);
      end loop;
   end Write;

   function To_String(mem : Cache_Type) return Unbounded_String is
      result : Unbounded_String;
   begin
      Append(result, "(cache ");
      Append(result, "(line_size" & Positive'Image(mem.line_size) & ")");
      Append(result, "(line_count" & Positive'Image(mem.line_count) & ")");
      Append(result, "(associativity" &
             Positive'Image(mem.associativity) & ")");
      Append(result, "(latency" & Time_Type'Image(mem.latency) & ")");
      Append(result, "(policy ");
      case mem.policy is
         when LRU    => Append(result, "lru");
         when MRU    => Append(result, "mru");
         when FIFO   => Append(result, "fifo");
         when Random => Append(result, "random");
      end case;
      Append(result, ")");
      if mem.exclusive then
         Append(result, "(exclusive true)");
      else
         Append(result,  "(exclusive false)");
      end if;
      if mem.write_back then
         Append(result, "(write_back true)");
      else
         Append(result, "(write_back false)");
      end if;
      Append(result, "(memory ");
      Append(result, To_String(Container_Type(mem)));
      Append(result, "))");
      return result;
   end To_String;

   function Get_Cost(mem : Cache_Type) return Cost_Type is

      -- Number of transistors to store the data.
      lines    : constant Cost_Type := Cost_Type(mem.line_count);
      lsize    : constant Cost_Type := Cost_Type(mem.line_size);
      assoc    : constant Cost_Type := Cost_Type(mem.associativity);
      cells    : constant Cost_Type := 6 * lines * lsize * 8 * assoc;

      -- Number of transistors needed for the address decoder.
      decoder  : constant Cost_Type := 2 * (Address_Type'Size +
                                            Cost_Type(Log2(mem.line_count)));

      -- Number of transistors needed to store tags.
      tag_size : constant Cost_Type
                  := Cost_Type(Address_Type'Size / mem.line_size +
                               mem.associativity);
      tags     : constant Cost_Type := 6 * tag_size * lines;

      -- Number of transistors needed to store age data.
      age      : constant Cost_Type := 6 * (assoc - 1);

      -- Number of transistors needed to store dirty bits.
      dirty    : constant Cost_Type := 6 * lines;

      -- Number of transistors needed for comparators.
      compare  : constant Cost_Type := 8 * (assoc - 1) * tag_size;

      -- Number of transistors for the cache with no policy.
      base     : constant Cost_Type := cells + decoder + tags + compare;

      -- Cost of the contained memory.
      con      : constant Cost_Type := Get_Cost(Container_Type(mem));

      result   : Cost_Type := base + con;

   begin
      case mem.policy is
         when LRU    => result := result + age;
         when MRU    => result := result + age;
         when FIFO   => result := result + age;
         when Random => null;
      end case;
      if mem.write_back then
         result := result + dirty;
      end if;
      return result;
   end Get_Cost;

   procedure Adjust(mem : in out Cache_Type) is
      ptr : Cache_Data_Pointer;
   begin
      for i in mem.data.First_Index .. mem.data.Last_Index loop
         ptr := new Cache_Data'(mem.data.Element(i).all);
         mem.data.Replace_Element(i, ptr);
      end loop;
      mem.generator := new RNG.Generator;
   end Adjust;

   procedure Free is
      new Ada.Unchecked_Deallocation(Cache_Data, Cache_Data_Pointer);

   procedure Finalize(mem : in out Cache_Type) is
   begin
      for i in mem.data.First_Index .. mem.data.Last_Index loop
         declare
            ptr : Cache_Data_Pointer := mem.data.Element(i);
         begin
            Free(ptr);
         end;
      end loop;
      Destroy(mem.generator);
   end Finalize;

end Memory.Cache;
