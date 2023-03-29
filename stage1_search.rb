def find_hex_value_in_file(filename, hex_string)
  File.open(filename, "rb") do |file|
    while entry = file.read(64) # read 64 bytes at a time (32 bytes key + 32 bytes value)
      key = entry[0..31].unpack("H*")[0]
      value = entry[32..-1].unpack("H*")[0] # extract value and convert to integer
      if key.include?(hex_string)
        puts "Found hex key #{key} in #{filename} at offset #{file.pos - 64} and value #{value}"
      end
      if value.include?(hex_string)
        puts "Found hex value #{value} in #{filename} at offset #{file.pos - 32} and key #{key}"
        return
      end
    end
  end
end

# Example usage:
str = ARGV[0]
Dir.foreach(".") do |filename|
  next unless filename =~ /^..\.bin/
  next unless File.size(filename) > 0
  find_hex_value_in_file(filename, str)
end
