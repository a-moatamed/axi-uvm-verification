# Vivado xsim projectless run script
proc getopt {argv name default} {
  set idx [lsearch -exact $argv $name]
  if {$idx >= 0 && [expr {$idx+1}] < [llength $argv]} {return [lindex $argv [expr {$idx+1}]]}
  return $default
}

set argv_copy $argv
set mode [getopt $argv_copy mode batch]
set sim_time [getopt $argv_copy sim_time 1ms]
set view_only [getopt $argv_copy view 0]

# Collect plusargs
set plusargs {}
foreach a $argv_copy { if {[string match "+*" $a]} { lappend plusargs $a } }

# Directories
set RUN_DIR     [file normalize [file join [pwd] sim]]
file mkdir $RUN_DIR
set FILELIST [file normalize [file join [pwd] files.f]]

if {![file exists $FILELIST]} {
  puts "ERROR: files.f not found at $FILELIST"
  exit 1
}

# Read filelist
set files {}
set fh [open $FILELIST r]
while {[gets $fh line] >= 0} {
  set t [string trim $line]
  if {$t eq "" || [string match "#*" $t]} {continue}
  lappend files [file normalize [file join [pwd] $t]]
}
close $fh

cd $RUN_DIR

# 1. COMPILE (xvlog/xvhdl)
puts "[clock format [clock seconds]]: Compiling..."
foreach f $files {
  if {[string match *.vhd $f]} {
    if {[catch {exec xvhdl $f} res]} { puts "ERROR xvhdl $f: $res"; exit 1 }
  } else {
    # Default to SystemVerilog for .sv and .v
    if {[catch {exec xvlog -sv -L uvm -incr $f} res]} { puts "ERROR xvlog $f: $res"; exit 1 }
  }
}

# 2. ELABORATE (xelab)
puts "[clock format [clock seconds]]: Elaborating..."
set xelab_cmd [list xelab work.top -s top -L unisims_ver -L unimacro_ver -L xpm -L secureip -L uvm -debug typical -timescale 1ns/1ps]
if {[catch {eval exec $xelab_cmd} res]} {
  puts "ERROR during xelab: $res"
  exit 1
}

# 3. SIMULATE (xsim)
if {$mode eq "batch"} {
  puts "[clock format [clock seconds]]: Running batch simulation..."
  
  # Create batch script
  set sim_tcl [file join $RUN_DIR run_batch.tcl]
  set fh [open $sim_tcl w]
  puts $fh "log_wave -recursive /*"
  puts $fh "run $sim_time"
  puts $fh "quit"
  close $fh

  # Construct command
  set cmd [list xsim top -tclbatch $sim_tcl -wdb xsim.wdb]
  foreach p $plusargs { lappend cmd -testplusarg [string range $p 1 end] }
  
  if {[catch {exec -- {*}$cmd} res]} {
    puts "ERROR during xsim: $res"
    exit 1
  }
  puts "Simulation finished. Wave: xsim.wdb"

} else {
  # GUI Mode
  puts "Launching GUI..."
  exec xsim top -gui -wdb xsim.wdb &
}
exit 0
