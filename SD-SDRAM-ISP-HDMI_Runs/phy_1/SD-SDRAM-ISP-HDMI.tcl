# Script Created by Tang Dynasty.
proc step_begin { step } {
  set stopFile ".stop.f"
  if {[file isfile .stop.f]} {
    puts ""
    puts " #Halting run"
    puts ""
    return -code error
  }
  set beginFile ".$step.begin.f"
  set platform "$::tcl_platform(platform)"
  set user "$::tcl_platform(user)"
  set pid [pid]
  set host ""
  if { [string equal $platform unix] } {
    if { [info exists ::env(HOSTNAME)] } {
      set host $::env(HOSTNAME)
    }
  } else {
    if { [info exists ::env(COMPUTERNAME)] } {
      set host $::env(COMPUTERNAME)
    }
  }
  set ch [open $beginFile w]
  puts $ch "<?xml version=\"1.0\"?>"
  puts $ch "<ProcessHandle Version=\"1\" Minor=\"0\">"
  puts $ch "    <Process Ownner=\"$user\" Host=\"$host\" Pid=\"$pid\">"
  puts $ch "    </Process>"
  puts $ch "</ProcessHandle>"
  close $ch
}
proc step_end { step } {
  set endFile ".$step.end.f"
  set ch [open $endFile w]
  close $ch
}
proc step_error { step } {
  set errorFile ".$step.error.f"
  set ch [open $errorFile w]
  close $ch
}
step_begin opt_place
set ACTIVESTEP opt_place
set rc [catch {
  open_project {SD-SDRAM-ISP-HDMI.prj}
  import_device eagle_s20.db -package EG4S20BG256
  import_db {../syn_1/SD-SDRAM-ISP-HDMI_gate.db}
  read_sdc -ip SOFTFIFO ../../import/ddr3-al_ip/SOFTFIFO.tcl
  config_chipwatcher "../../sd_HDMI.cwc" -dir ""
  compile_watcher
  place
  export_db {SD-SDRAM-ISP-HDMI_place.db}
} RESULT]
if {$rc} {
  step_error opt_place
  return -code error $RESULT
} else {
  step_end opt_place
  unset ACTIVESTEP
}
step_begin opt_route
set ACTIVESTEP opt_route
set rc [catch {
  route
  report_area -io_info -file SD-SDRAM-ISP-HDMI_phy.area
  export_db {SD-SDRAM-ISP-HDMI_pr.db}
  start_timer
  report_timing -mode FINAL -net_info  -rpt_autogen true -file SD-SDRAM-ISP-HDMI_phy.timing
} RESULT]
if {$rc} {
  step_error opt_route
  return -code error $RESULT
} else {
  step_end opt_route
  unset ACTIVESTEP
}
step_begin bitgen
set ACTIVESTEP bitgen
set rc [catch {
  export_bid SD-SDRAM-ISP-HDMI_inst.bid
  bitgen -bit "SD-SDRAM-ISP-HDMI.bit"
} RESULT]
if {$rc} {
  step_error bitgen
  return -code error $RESULT
} else {
  step_end bitgen
  unset ACTIVESTEP
}
