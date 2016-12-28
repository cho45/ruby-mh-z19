#!/usr/bin/env ruby

$LOAD_PATH << "#{File.dirname(__FILE__)}/../lib"

require 'mh-z19'

require 'mqtt'
require 'optparse'
require 'pathname'
require 'psych'
require "logger"

class CLI
	def self.run(argv)
		new(argv).run
	end

	def initialize(argv)
		@argv = argv
		@config = {
			"host"=> "127.0.0.1",
			"port"=> 8883,
			"ssl"=> true,
			"username"=> "guest",
			"password"=> "guest",
		}
		@logger = Logger.new($stdout)
		$stdout.sync = true
	end

	def load_rc
		file = Pathname("~/.mqttrc").expand_path

		begin
			config = Psych.load_file(file)
			@config.merge!(config)
		rescue Errno::ENOENT
			# ignore
		rescue Psych::SyntaxError => e
			@logger.fatal e.file
			@logger.fatal e.message
		end
	end

	def run
		load_rc
		OptionParser.new do |opts|
			opts.banner = "Usage: #{$0} [options]"
			opts.on("-h", "--help", "Prints this help") do
				puts opts
				exit
			end

			opts.on("-tTOPIC", "--topic=TOPIC", "MQTT topic path") do |t|
				@config["topic"] = t
			end

			opts.on("-pPIN", "--pin=PIN", "MH-Z19 PWM Pin") do |pin|
				@config["pin"] = pin.to_i
			end

			opts.on("-sPORT", "--serial=PORT", "MH-Z19 Serial Port") do |port|
				@config["serial"] = port
			end
		end.parse!(@argv)

		if !@config["topic"] || @config["topic"].empty?
			warn "topic is required"
			exit 1
		end

		if !@config["pin"] && !@config["serial"]
			warn "pin or port is required"
			exit 1
		end

		start
	end

	def start
		co2 = case
			when @config["serial"]
				MH_Z19::Serial.new(@config["serial"])
			when @config["pin"]
				MH_Z19::PWM.new(@config["pin"])
		end

		MQTT::Client.connect(
			host: @config["host"],
			port: @config["port"],
			ssl: @config["ssl"],
			username: @config["username"],
			password: @config["password"],
		) do |client|
			loop do
				sleep 1
				val = co2.gas_concentration
				if val
					@logger.info "#{val} ppm"
					client.publish(@config["topic"], val, false) 
				end
			end
		end
	rescue Interrupt => e
		exit
	rescue Exception => e
		p e
		sleep 1
		retry
	end
end

CLI.run(ARGV)

__END__
