module JSON
  class NestingError < StandardError; end

  def self.load(obj)
    unless obj.is_a?(String)
      return load(obj.to_str) if obj.respond_to?(:to_str)
      return load(obj.read) if obj.respond_to?(:read)
      return load(obj.to_io) if obj.respond_to?(:to_io)
    end

    parse(obj)
  end

  if Object.const_defined?(:File)
    def self.load_file(filename)
      JSON.parse(File.read(filename))
    end
  end
end
