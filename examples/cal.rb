#!/usr/bin/env ruby

$LOAD_PATH << "#{File.dirname(__FILE__)}/../lib"

require 'mh-z19'

co2 = MH_Z19::Serial.new(ENV['PORT'])
# wait sensor startup
loop do
	detail =  co2.read_concentration_detail
	p detail
	case detail[:status]
	when 0
		p "booting"
	when 1
		p "startup"
	when 64
		break
	end
	sleep 1
end

co2.calibrate_zero_point

sleep 3

p co2.read_concentration_detail
