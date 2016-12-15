#!/usr/bin/env ruby

module MH_Z19
	class PWM
		module GPIO
			def self.export(pin)
				File.open("/sys/class/gpio/export", "w") do |f|
					f.syswrite(pin)
				end
				true
			rescue Errno::EBUSY
				false
			end

			def self.unexport(pin)
				File.open("/sys/class/gpio/unexport", "w") do |f|
					f.syswrite(pin)
				end
			end

			def self.direction(pin, direction)
				File.open("/sys/class/gpio/gpio#{pin}/direction", "w") do |f|
					f.syswrite(direction)
				end
			end

			def self.read(pin)
				File.open("/sys/class/gpio/gpio#{pin}/value", "r") do |f|
					f.sysread(1).to_i
				end
			end

			def self.syswrite(pin, val)
				File.open("/sys/class/gpio/gpio#{pin}/value", "w") do |f|
					f.syswrite(val && val.nonzero? ? "1" : "0")
				end
			end

			def self.edge(pin, val)
				File.open("/sys/class/gpio/gpio#{pin}/edge", "w") do |f|
					f.syswrite(val)
				end
			end

			def self.trigger(pin, edge, timeout=nil, &block)
				self.direction(pin, :in)
				self.edge(pin, edge)
				File.open("/sys/class/gpio/gpio#{pin}/value", "r") do |f|
					fds = [f]
					buf = " "
					while true
						rs, ws, es = IO.select(nil, nil, fds, timeout)
						if es
							f.sysread(1, buf)
							block.call(buf.to_i)
							f.sysseek(0)
						else
							break
						end
					end
				end
			end
		end

		def initialize(pin)
			@pin = pin
			start
		end

		def start
			GPIO.export(@pin)
			begin
				GPIO.direction(@pin, :in)
			rescue Errno::EACCES => e
				retry
			end

			@queue = Queue.new
			@read_thread = Thread.start do
				Thread.abort_on_exception = true
				prev = nil
				th = 0; tl = 0
				GPIO.trigger(26, :both) do |v|
					unless prev
						prev = Time.now
						next
					end

					now = Time.now
					interval = now - prev
					prev = now

					case v
					when 1
						tl = interval
						@queue << [th, tl] if @queue.empty?
					when 0
						th = interval
					end
				end
			end

			@gas_concentration = nil
			@process_thread = Thread.start do
				loop do
					th, tl = *@queue.pop
					cycle = th + tl
					if 1004e-3 * 0.95 < cycle && cycle < 1004e-3 * 1.05
						ppm = 5000 * (th - 2e-3) / (cycle - 4e-3)
						@gas_concentration = ppm.round
					end
				end
			end
		end

		def gas_concentration
			@gas_concentration
		end

		def finish
			@queue.clear
			@read_thread.kill
			@process_thread.kill
		end
	end
end


if $0 == __FILE__
	co2 = MH_Z19::PWM.new(26)
	loop do
		p co2.gas_concentration
		sleep 1
	end
end
