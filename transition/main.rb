#!/usr/bin/env ruby
# frozen_string_literal: true

require 'sinatra'
require 'sinatra/config_file'
require 'json'
require 'net/http'
require 'uri'
require 'sequel'

config_file './config.yml'

fork_block = settings.fork_block
mpt_url = settings.mpt_url
vkt_url = settings.vkt_url
provider_url = settings.provider_url


POLL_PERIOD = 600

# A helper function to call one of the backends
def forward_call url, data
  uri = URI(url)
  https = Net::HTTP.new(uri.host, uri.port)
  https.use_ssl = true

  req =  Net::HTTP::Post.new(uri.path)
  req.body = data
  req['Content-Type'] = 'application/json'
  https.request(req).body.read
end

# Create the db connection
DB = Sequel.connect('sqlite://transition.db')

# Create the payloads table if it doesn't exist
DB.create_table? :payloads do
  primary_key :id
  String :data
end

# Create the status table if it doesn't exist
DB.create_table? :status do
  primary_key :id
  Integer :mode, default: 0
end

# Reads the mode from the database
if DB[:status].count == 0
  DB[:status].insert
end
status = DB[:status].first
mode = status[:mode]

def set_mode number
  mode = number
  status.update(mode: mode)
end

# Start a thread to poll a data delivery address
Thread.new do
  while mode == 0
    # uri = URI(provider_url)
    # response = Net::HTTP.get_response(uri)
    # if response.code == "200"
    #   # check if the conversion has completed
    #   resp = JSON.body.parse(response.body.read)
    #   next if resp["done"] == false

    if File.exist?("converted.tgz")
      system("tar xfz converted.tgz -C #{ENV["PWD"]}/converted")
      pid = Process.spawn("geth --datadir=#{ENV["PWD"]}/converted")

      # replay all the payloads in the db
      DB[:payloads].order(:id).each do |row|
        forward_call(vkt_url, row[:payload])
      end

      # Terminate geth for now, i.e. mode 2 won't be attempted
      Process.kill("TERM", pid)
      Process.wait(pid)

      DB[:payloads].truncate
      set_mode 1
      break
    end
    sleep POLL_PERIOD
  end
end

# This implements a post handler, that redirects
# each RPC call to both the verkle and MPT backends,
# until the transition block is reached.
post '/' do
  data = request.body.read
  command = JSON.parse(data)
  parameters = command['params']
  number = parameters['number'].to_i(16)  
  
  set_mode(2) if number >= fork_block && mode < 2
  
  case mode
    when 0
      # Ongoing conversion, save the data to the DB in
      # order to replay it later.
      forward_call(mpt_url, data)
      DB[:payloads].insert(data: data, id: number)
    when 1
      # Conversion results were downloaded and applied,
      # forward to both endpoints.
      response_vkt = forward_call(vkt_url, data)
      if response_vkt["error"]
        puts "Warning: backend B returned non-null error field: #{response_vkt["error"]}"
      end
      forward_call(mpt_url, data)
  else
    # Switch block arrived, only forward to the verkle backend
    forward_call(vkt_url, data)
  end

end
