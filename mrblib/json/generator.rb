module JSON
  class GeneratorError < StandardError; end

  class Generator
    DEFAULT_MAX_NESTING = 19
    INDENT_WIDTH = 2

    attr_reader :max_nesting, :pretty_print

    def initialize(opts = {})
      @depth = 0
      @max_nesting = opts[:max_nesting] || DEFAULT_MAX_NESTING
      @pretty_print = opts[:pretty_print] || false
      validate
    end

    def validate
      raise TypeError, 'max_nesting must be an Integer' unless max_nesting.is_a?(Integer)
      raise ArgumentError, 'max_nesting must be a non-negative number' unless max_nesting >= 0
    end

    def generate(obj)
      @depth = 0
      obj_to_json(obj)
    end

    def obj_to_json(obj) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/MethodLength
      raise NestingError, "nesting of #{@depth} is too deep" if max_nesting > 0 && @depth > max_nesting

      case obj
      when NilClass
        'null'
      when TrueClass
        'true'
      when FalseClass
        'false'
      when Integer
        obj.to_s
      when Float
        if obj.nan?
          raise GeneratorError, 'NaN is not allowed in JSON'
        elsif obj.infinite?
          raise GeneratorError, 'Infinite is not allowed in JSON'
        end

        obj.to_s
      when String
        escape(obj)
      when Symbol
        escape(obj.to_s)
      when Array
        @depth += 1
        json = obj.map do |o|
          v = obj_to_json(o)
          pretty_print ? indent(deindent(v), @depth) : v
        end.join(@pretty_print ? ",\n" : ',')
        @depth -= 1

        if pretty_print
          [
            indent('[', @depth),
            json,
            indent(']', @depth)
          ].join("\n")
        else
          %([#{json}])
        end
      when Hash
        @depth += 1
        json = obj.map do |key, val|
          k = obj_to_json(key)
          v = obj_to_json(val)
          if pretty_print
            indent("#{k}: #{deindent(v)}", @depth)
          else
            "#{k}:#{v}"
          end
        end.join(@pretty_print ? ",\n" : ',')
        @depth -= 1

        if pretty_print
          [
            indent('{', @depth),
            json,
            indent('}', @depth)
          ].join("\n")
        else
          %({#{json}})
        end
      else
        obj_to_json(obj.to_s)
      end
    end

    def indent(str, level)
      "#{' ' * INDENT_WIDTH * level}#{str}"
    end

    def deindent(str)
      s = 0
      s += 1 while str[s] == ' '
      str[s..]
    end

    def escape(str)
      "\"#{str}\""
    end
  end
end
