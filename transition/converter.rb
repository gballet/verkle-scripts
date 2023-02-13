#!/usr/bin/env ruby

require 'json'
require 'open3'
require 'sinatra'
require 'net/http'

THRESHOLD_BLOCK_NUMBER = 1000000 # Change this to your desired threshold

def json_rpc_request(method, params = [])
  {
    jsonrpc: "2.0",
    id: 1,
    method: method,
    params: params
  }.to_json
end

def send_request(request)
  uri = URI.parse(RPC_ENDPOINT)
  http = Net::HTTP.new(uri.host, uri.port)
  response = http.post(uri.path, request, { 'Content-Type' => 'application/json' })
  JSON.parse(response.body)
end

# Query the latest block number
def latest_block_number
  request = json_rpc_request("eth_blockNumber")
  response = send_request(request)
  response["result"].hex
end

def start_conversion
  cmd = 'geth verkle to-verkle'
  stdout, stderr, status = Open3.capture3(cmd)
  if status.success?
    puts "Successful conversion"
  else
    raise "Failed to start block export: #{stderr}"
  end
end

# Start go-ethereum client and poll its latest block number
# until the fork number is reached.
Open3.capture3('geth') do |stdin, stdout, stderr, wait_thr|

  # Periodically check the latest block number
  Thread.new do
    while true do
      latest_block_number = latest_block_number
      if latest_block_number >= THRESHOLD_BLOCK_NUMBER
        puts "Terminating the MPT client..."
        Process.kill("SIGTERM", wait_thr.pid)

        status = wait_thr.value
        puts "Starting conversion"

        start_conversion
        break
      end
  
      # Estimate how long before the next check
      delay = 11.5 * (THRESHOLD_BLOCK_NUMBER - latest_block_number)
      puts "Sleeping #{delay}s until the next check"
      sleep delay
    end
  end
end 

set :conversion_done, false

get '/status' do
  {
    :number => THRESHOLD_BLOCK_NUMBER,
    :done => settings.conversion_done.to_s
  }.to_json
end

get '/data' do
  raise "no available file" unless settings.conversion_done
  send_file CONVERTED_FILE_NAME
end