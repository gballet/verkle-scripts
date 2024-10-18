#!/usr/bin/env ruby

require 'json'

geth = File.open(ARGV[0])
reth = File.read(ARGV[1])

reth = JSON.parse(reth)
p reth[1]
working_logs =  reth["result"]["structLogs"]


geth.each_line.each_with_index { |line, idx|
  log = JSON.parse(line)

  work_pc = working_logs[idx]["pc"].to_i
  fail_pc = log["pc"].to_i

  work_gas = working_logs[idx]["gas"].to_i
  fail_gas = log["gas"].hex

  work_stack = working_logs[idx]["stack"]
  fail_stack = log["stack"]

  if work_stack != fail_stack
    puts "stack diff at line #{idx+1}, stack: working=#{work_stack}, failing=#{fail_stack}"
    break
  end

  if work_gas != fail_gas
    puts "gas diff at line #{idx+1}, gas: working=#{work_gas}, failing=#{fail_gas}"
    break
  end

  if work_pc != fail_pc
    puts "pc diff at line #{idx+1}, pc: working=#{work_pc}, faling=#{fail_pc} (gas: w: #{work_gas} f: #{fail_gas})"
    break
  end
}
