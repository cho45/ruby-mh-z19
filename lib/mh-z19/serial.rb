#!/usr/bin/env ruby

require 'serialport'

module MH_Z19
	class Serial
		STARTING_BYTE = 0xff
		CMD_GAS_CONCENTRATION = 0x86
		CMD_CALIBRATE_ZERO_POINT = 0x87
		CMD_CALIBRATE_SPAN_POINT = 0x88

		class GenericException < Exception; end
		class InvalidPacketException < GenericException; end

		def initialize(io, sensor_id: 0x01)
			if io.is_a? String
				@io = SerialPort.new(
					io,
					9600,
					8,
					1,
					0
				)
				@io.flow_control = SerialPort::NONE
				@io.set_encoding(Encoding::BINARY)
			else
				@io = io
			end
			@sensor_id = sensor_id
		end

		def close
			@io.close
		end

		def gas_concentration
			read_concentration_detail[:concentration]
		end

		def read_concentration_detail
			packet = Array.new(9) { 0 }
			packet[0] = STARTING_BYTE
			packet[1] = @sensor_id
			packet[2] = CMD_GAS_CONCENTRATION
			packet[8] = checksum(packet)

			@io.write packet.pack("C*")
			raw_packet = @io.read(9)
			raise InvalidPacketException, "packet seems nil" if raw_packet.nil?

			packet = raw_packet.unpack("C*")
			sum = checksum(packet)
			unless packet[8] == sum
				raise InvalidPacketException, "packet checksum is invalid"
			end
			{
				concentration: (packet[2] << 8) | packet[3],
				temperature: (packet[4] - 40),
				status: packet[5],
			}
		end

		def calibrate_zero_point
			packet = Array.new(9) { 0 }
			packet[0] = STARTING_BYTE
			packet[1] = @sensor_id
			packet[2] = CMD_CALIBRATE_ZERO_POINT
			packet[8] = checksum(packet)
			@io.write packet.pack("C*")
			# no return value
			nil
		end

		def calibrate_span_point(span_point)
			packed = [span_point].pack("n")

			packet = Array.new(9) { 0 }
			packet[0] = STARTING_BYTE
			packet[1] = @sensor_id
			packet[2] = CMD_CALIBRATE_SPAN_POINT
			packet[3] = packed[0].ord
			packet[4] = packed[1].ord
			packet[8] = checksum(packet)
			@io.write packet.pack("C*")
			# no return value
			nil
		end

		private
		def checksum(packet)
			raise InvalidPacketException, "invalid packet size" unless packet.size == 9
			sum = 0
			(1...8).each do |i|
				sum = (sum + packet[i]) & 0xff
			end
			sum = 0xff - sum
			sum += 1
			sum
		end
	end
end

if $0 == __FILE__
	co2 = MH_Z19::Serial.new(ENV['PORT'])
	loop do
		ppm = co2.gas_concentration
		p ppm
		sleep 1
	end
end
