#!/usr/bin/env ruby

$LOAD_PATH << "#{File.dirname(__FILE__)}/../lib"

require 'mh-z19'

require 'net/http'
require 'uri'

uri = URI(ENV['GF_URI']) rescue nil

case
when ENV['PORT']
	co2 = MH_Z19::Serial.new(ENV['PORT'])
	loop do
		begin
			ppm = co2.gas_concentration
			p ppm
			unless uri.nil?
				res = Net::HTTP.post_form(uri, 'number' => ppm)
				p res
			end
		rescue Exception => e
			p e
			puts e.backtrace
		end
		sleep 1
	end
when ENV['PIN']
	co2 = MH_Z19::PWM.new(ENV['PIN'].to_i)
	loop do
		sleep 1
		begin
			ppm = co2.gas_concentration
			if ppm.nil?
				next
			end
			p ppm
			unless uri.nil?
				res = Net::HTTP.post_form(uri, 'number' => ppm)
				p res
			end
		rescue Exception => e
			p e
			puts e.backtrace
		end
	end
end
