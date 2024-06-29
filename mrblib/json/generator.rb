module JSON
  class GeneratorError < StandardError; end

  class Generator
    DEFAULT_MAX_NESTING = 19
    INDENT_WIDTH = 2

    class << self
      ANSI_COLORS = {
        black: 30,
        red: 31,
        green: 32,
        yellow: 33,
        blue: 34,
        magenta: 35,
        cyan: 36,
        white: 37,
        gray: 90
      }.freeze
      attr_writer :color_object_key, :color_string, :color_null

      def color_object_key
        @color_object_key ||= :blue
      end

      def color_string
        @color_string ||= :green
      end

      def color_null
        @color_null ||= :gray
      end

      def colorize(str, color)
        color_code = ANSI_COLORS[color.to_sym]
        return str unless color_code

        "\e[#{color_code}m#{str}\e[m"
      end
    end

    attr_reader :max_nesting, :pretty_print, :colorize
    alias colorize? colorize

    def initialize(opts = {})
      @depth = 0
      @max_nesting = opts[:max_nesting] || DEFAULT_MAX_NESTING
      @pretty_print = opts[:pretty_print] || false
      @colorize = opts[:colorize] || false
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
        maybe_colorize('null', Generator.color_null)
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
        maybe_colorize(escape(obj), Generator.color_string)
      when Symbol
        maybe_colorize(escape(obj.to_s), Generator.color_string)
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
          k = maybe_colorize(monochrome { obj_to_json(key) }, Generator.color_object_key)
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

    def maybe_colorize(str, color)
      return str unless colorize?

      Generator.colorize(str, color)
    end

    def monochrome
      old_colorize = @colorize
      @colorize = false
      yield
    ensure
      @colorize = old_colorize
    end
  end
end
