
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

package Benchmark.Trace is

   -- Memory traces are sequences of memory access actions separated by
   -- new lines.  The format of each line is:
   --
   --    <action> <value>
   --
   -- where <action> is 'R' for read, 'W' for write, and 'I' for idle.
   -- For reads and writes, <value> is a decimal value indicating the
   -- address.  For idle states, <value> is the number of idle cycles.
   -- Idle is used to separate reads and writes.

   type Trace_Type is new Benchmark_Type with private;

   function Create_Trace return Benchmark_Pointer;

   procedure Set_Argument(benchmark : in out Trace_Type;
                          arg       : in String);

   procedure Run(benchmark : in out Trace_Type);

private

   type Trace_Type is new Benchmark_Type with record
      file_name   : Unbounded_String := To_Unbounded_String("trace.txt");
      spacing     : Time_Type        := 0;
   end record;

end Benchmark.Trace;