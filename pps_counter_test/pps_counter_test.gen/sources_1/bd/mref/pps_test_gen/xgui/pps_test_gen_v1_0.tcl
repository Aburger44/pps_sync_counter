# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "HIGH_CYCLES" -parent ${Page_0}
  ipgui::add_param $IPINST -name "PERIOD_CYCLES" -parent ${Page_0}


}

proc update_PARAM_VALUE.HIGH_CYCLES { PARAM_VALUE.HIGH_CYCLES } {
	# Procedure called to update HIGH_CYCLES when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.HIGH_CYCLES { PARAM_VALUE.HIGH_CYCLES } {
	# Procedure called to validate HIGH_CYCLES
	return true
}

proc update_PARAM_VALUE.PERIOD_CYCLES { PARAM_VALUE.PERIOD_CYCLES } {
	# Procedure called to update PERIOD_CYCLES when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.PERIOD_CYCLES { PARAM_VALUE.PERIOD_CYCLES } {
	# Procedure called to validate PERIOD_CYCLES
	return true
}


proc update_MODELPARAM_VALUE.PERIOD_CYCLES { MODELPARAM_VALUE.PERIOD_CYCLES PARAM_VALUE.PERIOD_CYCLES } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.PERIOD_CYCLES}] ${MODELPARAM_VALUE.PERIOD_CYCLES}
}

proc update_MODELPARAM_VALUE.HIGH_CYCLES { MODELPARAM_VALUE.HIGH_CYCLES PARAM_VALUE.HIGH_CYCLES } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.HIGH_CYCLES}] ${MODELPARAM_VALUE.HIGH_CYCLES}
}

