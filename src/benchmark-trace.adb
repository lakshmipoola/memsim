
with Ada.Text_IO;                use Ada.Text_IO;
with Ada.Exceptions;             use Ada.Exceptions;
with Ada.Streams.Stream_IO;

package body Benchmark.Trace is

   type Byte_Count_Type is mod 2 ** 64;

   type Access_Type is (Read, Write, Modify, Idle);

   type Memory_Access is record
      t     : Access_Type;
      value : Address_Type;
      size  : Natural;
   end record;

   type Parse_State_Type is (State_Action,
                             State_Pre_Address,
                             State_Address,
                             State_Pre_Size,
                             State_Size);

   procedure Parse_Action(benchmark : in out Trace_Type;
                          mdata     : in out Memory_Access;
                          state     : in out Parse_State_Type);

   function To_Address(ch : Character) return Address_Type is
      pos : constant Integer := Character'Pos(ch);
   begin
      if ch in '0' .. '9' then
         return Address_Type(pos - Character'Pos('0'));
      elsif ch in 'a' .. 'f' then
         return Address_Type(pos - Character'Pos('a') + 10);
      else
         return 16;
      end if;
   end To_Address;

   procedure Process_Action(benchmark  : in Trace_Type;
                            mdata      : in Memory_Access) is
   begin
      case mdata.t is
         when Read   =>
            Read(benchmark, mdata.value, mdata.size);
         when Write  =>
            Write(benchmark, mdata.value, mdata.size);
         when Modify =>
            Read(benchmark, mdata.value, mdata.size);
            Write(benchmark, mdata.value, mdata.size);
         when Idle   =>
            Idle(benchmark, Time_Type(mdata.value));
      end case;
      if benchmark.spacing > 0 then
         Idle(benchmark, benchmark.spacing);
      end if;
   end Process_Action;

   procedure Parse_Action(benchmark : in out Trace_Type;
                          mdata     : in out Memory_Access;
                          state     : in out Parse_State_Type) is

      value : Address_Type;
      ch    : Character;

   begin
      while benchmark.last >= benchmark.pos loop
         ch := Character'Val(benchmark.buffer(benchmark.pos));
         case state is
            when State_Action =>
               state := State_Pre_Address;
               case ch is
                  when 'R'    => mdata.t := Read;
                  when 'W'    => mdata.t := Write;
                  when 'M'    => mdata.t := Modify;
                  when 'I'    => mdata.t := Idle;
                  when others => state := State_Action;
               end case;
               benchmark.pos := benchmark.pos + 1;
            when State_Pre_Address =>
               mdata.value := To_Address(ch);
               if mdata.value < 16 then
                  state := State_Address;
                  benchmark.pos := benchmark.pos + 1;
               else
                  state := State_Action;
               end if;
            when State_Address =>
               value := To_Address(ch);
               if value < 16 then
                  mdata.value := mdata.value * 16 + value;
                  benchmark.pos := benchmark.pos + 1;
               elsif mdata.t = Idle then
                  mdata.size := 1;
                  state := State_Action;
                  Process_Action(benchmark, mdata);
               else
                  state := State_Pre_Size;
                  benchmark.pos := benchmark.pos + 1;
               end if;
            when State_Pre_Size =>
               mdata.size := Natural(To_Address(ch));
               if mdata.size < 16 then
                  state := State_Size;
               end if;
               benchmark.pos := benchmark.pos + 1;
            when State_Size =>
               value := To_Address(ch);
               if value < 16 then
                  mdata.size := mdata.size * 16 + Natural(value);
                  benchmark.pos := benchmark.pos + 1;
               else
                  state := State_Action;
                  Process_Action(benchmark, mdata);
               end if;
         end case;
      end loop;
   end Parse_Action;

   function Create_Trace return Benchmark_Pointer is
      result : constant Trace_Pointer := new Trace_Type;
   begin
      result.spacing := 0;
      return Benchmark_Pointer(result);
   end Create_Trace;

   procedure Set_Argument(benchmark : in out Trace_Type;
                          arg       : in String) is
      value : constant String := Extract_Argument(arg);
   begin
      if Check_Argument(arg, "file") then
         benchmark.file_name := To_Unbounded_String(value);
      elsif Check_Argument(arg, "iterations") then
         benchmark.iterations := Long_Integer'Value(value);
      else
         Set_Argument(Benchmark_Type(benchmark), arg);
      end if;
   exception
      when others =>
         raise Invalid_Argument;
   end Set_Argument;

   procedure Run(benchmark : in out Trace_Type) is
      file     : Stream_IO.File_Type;
      done     : Boolean;
      mdata    : Memory_Access;
      state    : Parse_State_Type := State_Action;
      total    : Byte_Count_Type := 0;
   begin
      Stream_IO.Open(File => file,
                     Mode => Stream_IO.In_File,
                     Name => To_String(benchmark.file_name));
      for count in 1 .. benchmark.iterations loop
         Put_Line("Iteration" & Long_Integer'Image(count) & " /" &
                  Long_Integer'Image(benchmark.iterations));
         done := False;
         while not done loop
            Stream_IO.Read(file, benchmark.buffer, benchmark.last);
            exit when benchmark.last < benchmark.buffer'First;
            benchmark.pos := benchmark.buffer'First;
            begin
               Parse_Action(benchmark, mdata, state);
            exception
               when Prune_Error =>
                  done := True;
            end;
            total := total + Byte_Count_Type(benchmark.last
                                          - benchmark.buffer'First + 1);
            Put_Line("Processed" & Byte_Count_Type'Image(total) & " bytes");
         end loop;
         if not done then
            benchmark.buffer(benchmark.buffer'First) := 0;
            benchmark.pos := benchmark.buffer'First;
            benchmark.last := benchmark.pos;
            begin
               Parse_Action(benchmark, mdata, state);
            exception
               when Prune_Error =>
                  done := True;
            end;
         end if;
         if count < benchmark.iterations then
            Show_Stats(benchmark.mem.all);
            Reset(benchmark.mem.all);
            state := State_Action;
            Stream_IO.Reset(file);
         end if;
      end loop;
      Stream_IO.Close(file);
   exception
      when ex: others =>
         Put_Line("error: could not read " & To_String(benchmark.file_name) &
                  ": " & Exception_Name(ex) & ": " & Exception_Message(ex));
         Stream_IO.Close(file);
   end Run;

end Benchmark.Trace;

