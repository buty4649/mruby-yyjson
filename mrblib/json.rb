module JSON
  class GeneratorError < StandardError; end
  class NestingError < StandardError; end
  class ParserError < StandardError; end

  def self.[](obj, opts = {})
    if obj.respond_to?(:to_str)
      parse(obj.to_str, opts)
    else
      generate(obj)
    end
  end

  def self.dump(obj, io = nil)
    if io && !io.respond_to?(:write)
      raise TypeError, "io must respond to `write'"
    end

    json = generate(obj)
    return json unless io

    io.write(json)
    io
  end

  def self.load(obj, opts = {})
    unless obj.is_a?(String)
      return load(obj.to_str) if obj.respond_to?(:to_str)
      return load(obj.read) if obj.respond_to?(:read)
      return load(obj.to_io) if obj.respond_to?(:to_io)
    end

    parse(obj, opts)
  end

  if Object.const_defined?(:File)
    def self.load_file(filename, opts = {})
      JSON.parse(File.read(filename), opts)
    end
  end
end
