=begin
##########################################################################
#
#  INFIVERVE TECHNOLOGIES PTE LIMITED CONFIDENTIAL
#  __________________
# 
#  (C) INFIVERVE TECHNOLOGIES PTE LIMITED, SINGAPORE
#  All Rights Reserved.
#  Product / Project: Flint IT Automation Platform
#  NOTICE:  All information contained herein is, and remains
#  the property of INFIVERVE TECHNOLOGIES PTE LIMITED.
#  The intellectual and technical concepts contained
#  herein are proprietary to INFIVERVE TECHNOLOGIES PTE LIMITED.
#  Dissemination of this information or any form of reproduction of this material
#  is strictly forbidden unless prior written permission is obtained
#  from INFIVERVE TECHNOLOGIES PTE LIMITED, SINGAPORE.
=end

#!/usr/bin/ruby
require 'net/http'
require 'json'
require 'base64'

script_input = STDIN.read
script_input = JSON.parse(script_input)[0]
if script_input != nil && script_input != ''
	begin
	
	@event_name = script_input['Name']
	puts "Executing handler for event : #{@event_name}"
	
	if @event_name != nil && @event_name != ''
		@consul_get_value_url = "http://localhost:8500/v1/kv/flint/events/#{@event_name}"
		@consul_get_uri_url = "http://localhost:8500/v1/kv/flint/hostname"
		@consul_get_username_url = "http://localhost:8500/v1/kv/flint/username"
		@consul_get_password_url = "http://localhost:8500/v1/kv/flint/password"
		@flint_bit_url_prefix = "/v1/bit/run/"
		@consul_get_leader_url = "http://localhost:8500/v1/status/leader"
		@consul_get_self_info_url = "http://localhost:8500/v1/agent/self"
		headers = {
			'Content-Type' => 'application/json'
		}
		@flintbit_input = script_input.to_json
		@leader_address = nil
		@agent_address = nil

		# Getting leader address
		leader_output = Net::HTTP.get(URI.parse(@consul_get_leader_url))
		if leader_output == nil
			puts "Output is nil"
		else
			leader_output = leader_output.split(":")
			leader_output = leader_output[0]
			leader_output[0] = ''
			@leader_address = leader_output
			puts "Leader address : #{@leader_address}"
		end
		
		# Getting self address
		self_output = Net::HTTP.get(URI.parse(@consul_get_self_info_url))
		if self_output == nil
			puts "Output is nil"
		else
			@agent_address = JSON.parse(self_output)['Config']['AdvertiseAddr']
			puts "Agent address : #{@agent_address}"
		end
	
		# Getting flint hostname from consul keystore
		hostname_api_output = Net::HTTP.get(URI.parse(@consul_get_uri_url))
		if hostname_api_output != nil && hostname_api_output != ''
			@flint_uri = JSON.parse(hostname_api_output)[0]['Value']
			@flint_uri = Base64.decode64(@flint_uri)
			@flint_uri = URI(@flint_uri)
			@flint_hostname = @flint_uri.host
			@flint_api_port = @flint_uri.port
			puts "Flint uri : #{@flint_uri}"
			#puts "Flint hostname : #{@flint_hostname}"
			#puts "Flint port : #{@flint_api_port}"
	
			# Getting flint username from consul keystore
			username_api_output = Net::HTTP.get(URI.parse(@consul_get_username_url))
			if username_api_output != nil && username_api_output != ''
				@flint_username = JSON.parse(username_api_output)[0]['Value']
				@flint_username = Base64.decode64(@flint_username)
				headers['x-flint-username'] = @flint_username
				puts "Flint username : #{@flint_username}"
			else
				puts "Consul error : connot find value for flint username"
			end
			
			# Getting flint password from consul keystore
			password_api_output = Net::HTTP.get(URI.parse(@consul_get_password_url))
			if password_api_output != nil && password_api_output != ''
				@flint_password = JSON.parse(password_api_output)[0]['Value']
				@flint_password = Base64.decode64(@flint_password)
				headers['x-flint-password'] = @flint_password
				puts "Flint password : #{@flint_password}"
			else
				puts "Consul error : connot find value for flint password"
			end
			
			# Getting flintbit name from consul keystore
			value_output = Net::HTTP.get(URI.parse(@consul_get_value_url))
			if(value_output == nil || value_output == '')
				puts "Cannot find value for event : #{@event_name}"
			else
				puts "Getting flintbit path"
				@flintbit_name = JSON.parse(value_output)[0]['Value']
				@flintbit_name = Base64.decode64(@flintbit_name)
				puts "Flintbit name : #{@flintbit_name}"
	
				if @leader_address != nil && @agent_address != nil
					if @leader_address == @agent_address
						puts "This agent is leader !!"
						puts "Calling flintbit"
						begin
							# Calling flintbit with provided configuration
							http = Net::HTTP.new(@flint_hostname, @flint_api_port)
			
							puts "Header : #{headers}"
							resp = http.post(@flint_bit_url_prefix + @flintbit_name, @flintbit_input, headers)
							puts "Flintbit input : #{@flintbit_input}"
							puts "Response : #{resp.body}"
							
						rescue Exception => e
							puts "Error occured while connecting to flint : #{e}"
						end
					else
						puts "This agent is not leader?"
					end
				else
					puts "ERROR: Leader address or agent address is null.."
				end
			end
		else
			puts "Consul error : flint hostname is null"
		end
	
	else
		puts "Consul error : Event name is blank or null"
	end

	rescue Exception => e
		puts "Consul error : #{e}"
	end
else
	puts "Consul error : received blank input"
end
