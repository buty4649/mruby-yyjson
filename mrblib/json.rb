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
    raise TypeError, "io must respond to `write'" if io && !io.respond_to?(:write)

    json = generate(obj)
    return json unless io

    io.write(json)
    io
  end

  def self.fast_generate(obj)
    generate(obj)
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

  def self.color_object_key
    @color_object_key ||= :blue
  end

  def self.color_object_key=(color)
    @color_object_key = color
  end

  def self.color_string
    @color_string ||= :green
  end

  def self.color_string=(color)
    @color_string = color
  end

  def self.color_null
    @color_null ||= :gray
  end

  def self.color_null=(color)
    @color_null = color
  end
end
