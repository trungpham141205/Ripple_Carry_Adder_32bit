set OUTPUT_DIR "results/sim"

if { ![file isdirectory $OUTPUT_DIR] } {
    file mkdir $OUTPUT_DIR
}

transcript file ${OUTPUT_DIR}/transcript

cd $OUTPUT_DIR
file delete ../../transcript

vlog ../../src/fullAdder.v
vlog ../../src/rippleCarryAdder32bit.v
vlog ../../sim/tbRippleCarryAdder32bit.v

vsim -voptargs="+acc" work.tbRippleCarryAdder32bit

add wave *
run -all
wave zoom full