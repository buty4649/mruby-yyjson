assert('JSON.#[]') do
  assert_equal({ 'mruby' => 'yyjson' }, JSON[%({"mruby":"yyjson"})])
  assert_equal({ mruby: 'yyjson' }, JSON[%({"mruby":"yyjson"}), symbolize_names: true])

  class TestStringLike
    def to_str
      %("TestStringLike#to_str")
    end
  end
  assert_equal 'TestStringLike#to_str', JSON[TestStringLike.new]

  assert_equal %({"mruby":"yyjson"}), JSON[{ 'mruby' => 'yyjson' }]
end

assert('JSON.#fast_generate') do
  JSON.stub(:generate, 'stub generate') do
    assert_equal 'stub generate', JSON.fast_generate({ mruby: 'yyjson' })
  end
end

assert('JSON.#dump') do
  class TestWriter
    def write(obj)
      obj
    end
  end
  test_writer = TestWriter.new
  assert_equal test_writer, JSON.dump({ mruby: 'yyjson' }, test_writer)

  class TestButWirter; end
  assert_raise(TypeError) { JSON.dump({ mruby: 'yyjson' }, TestButWirter.new) }
end

assert('JSON.#generate') do
  assert_equal 'null', JSON.generate(nil), 'nil'
  assert_equal 'false', JSON.generate(false), 'false'
  assert_equal 'true', JSON.generate(true), 'true'
  assert_equal '100', JSON.generate(100), 'Integer'
  assert_equal '-100', JSON.generate(-100), 'Integer'
  assert_equal '0.1', JSON.generate(0.1), 'Float'
  assert_raise(JSON::GeneratorError, 'Float::NAN') { JSON.generate(Float::NAN) }
  assert_raise(JSON::GeneratorError, 'Float::INFINITY') { JSON.generate(Float::INFINITY) }
  assert_equal %("mruby-yyjson"), JSON.generate('mruby-yyjson'), 'String'
  assert_equal %("JSON"), JSON.generate(:JSON), 'Symbol'
  assert_equal %("JSON"), JSON.generate(JSON), 'Class'
  assert_equal %("🍣"), JSON.generate('🍣'), 'Emoji'
  assert_equal %([true,1,"mruby-yyjson"]), JSON.generate([true, 1, 'mruby-yyjson']), 'Array'

  def nesting_array(count)
    return [] if count == 0

    [nesting_array(count - 1)]
  end

  # default max_nesting is 19
  assert_raise(JSON::NestingError, 'NestingError for deeply nested array') do
    JSON.generate(nesting_array(20))
  end

  # 0 is unlimited
  assert_nothing_raised('No error for max_nesting: 0 with deeply nested array') do
    JSON.generate(nesting_array(100), max_nesting: 0)
  end

  assert_raise(JSON::NestingError, 'NestingError for max_nesting: 9 with 10 levels of nesting') do
    JSON.generate(nesting_array(10), max_nesting: 9)
  end

  assert_raise(ArgumentError, 'ArgumentError for max_nesting: -1') do
    JSON.generate(nesting_array(10), max_nesting: -1)
  end

  assert_raise(TypeError, 'TypeError for max_nesting: true') do
    JSON.generate(nesting_array(10), max_nesting: true)
  end

  assert_equal "\e[32m\"mruby-yyjson\"\e[m", JSON.generate('mruby-yyjson', colorize: :green), 'Colorize with :green'
  got = JSON.generate({ 'mruby' => 'yyjson', foo: [%w[bar baz qux]] }, pretty_print: true)
  assert_equal <<~JSON.chomp, got, 'Pretty print'
    {
      "mruby": "yyjson",
      "foo": [
        [
          "bar",
          "baz",
          "qux"
        ]
      ]
    }
  JSON
end

assert('JSON.#parse') do
  assert_equal nil, JSON.parse('null')
  assert_equal false, JSON.parse('false')
  assert_equal true, JSON.parse('true')
  assert_equal 100, JSON.parse('100')
  assert_equal(-100, JSON.parse('-100'))
  assert_equal 0.1, JSON.parse('0.1')
  assert_equal 'mruby-yyjson', JSON.parse(%("mruby-yyjson"))
  assert_equal 'JSON', JSON.parse(%("JSON"))
  assert_equal '🍣', JSON.parse(%("🍣"))
  assert_equal [true, 1, 'mruby-yyjson'], JSON.parse(%([true,1,"mruby-yyjson"]))
  assert_equal({ 'mruby' => 'yyjson' }, JSON.parse(%({"mruby":"yyjson"})))

  assert_equal({ mruby: 'yyjson' }, JSON.parse(%({"mruby":"yyjson"}), symbolize_names: true))

  assert_raise(JSON::ParserError) { JSON.parse(%({"mruby":)) }
end

assert('JSON.#load') do
  stub = lambda do |obj, opts|
    assert_equal 'mruby-yyjson', obj, "Expected 'mruby-yyjson' as input to JSON.parse"
    assert_equal({ symbolize_names: true }, opts, 'Expected options { symbolize_names: true } for JSON.parse')
    'stub parse'
  end

  JSON.stub(:parse, stub) do
    assert_equal 'stub parse', JSON.load('mruby-yyjson', symbolize_names: true)
  end

  class TestStringLike
    def to_str
      %("TestStringLike#to_str")
    end
  end

  class TestReader
    def read
      %("TestReader#read")
    end
  end

  class TestIOWrapper
    def initialize(io)
      @io = io
    end

    def to_io
      @io
    end
  end

  assert_equal 'TestStringLike#to_str', JSON.load(TestStringLike.new)
  assert_equal 'TestReader#read', JSON.load(TestReader.new)
  assert_equal 'TestReader#read', JSON.load(TestIOWrapper.new(TestReader.new))
end

assert('JSON.#load_file') do
  skip unless Object.const_defined?(:File)

  assert_equal({ 'mruby' => 'yyjson' }, JSON.load_file('test/fixtures/test.json'))
  assert_equal({ mruby: 'yyjson' }, JSON.load_file('test/fixtures/test.json', symbolize_names: true))
end

assert('JSON.#pretty_generate') do
  assert_equal <<~JSON.chomp, JSON.pretty_generate({ 'mruby' => 'yyjson', foo: [%w[bar baz qux]] })
    {
      "mruby": "yyjson",
      "foo": [
        [
          "bar",
          "baz",
          "qux"
        ]
      ]
    }
  JSON
end

assert('JSON.#colorize') do
  assert_equal "\e[30mmruby-yyjson\e[m", JSON.colorize('mruby-yyjson', :black), 'Colorize with :black'
  assert_equal "\e[31mmruby-yyjson\e[m", JSON.colorize('mruby-yyjson', :red), 'Colorize with :red'
  assert_equal "\e[32mmruby-yyjson\e[m", JSON.colorize('mruby-yyjson', :green), 'Colorize with :green'
  assert_equal "\e[33mmruby-yyjson\e[m", JSON.colorize('mruby-yyjson', :yellow), 'Colorize with :yellow'
  assert_equal "\e[34mmruby-yyjson\e[m", JSON.colorize('mruby-yyjson', :blue), 'Colorize with :blue'
  assert_equal "\e[35mmruby-yyjson\e[m", JSON.colorize('mruby-yyjson', :magenta), 'Colorize with :magenta'
  assert_equal "\e[36mmruby-yyjson\e[m", JSON.colorize('mruby-yyjson', :cyan), 'Colorize with :cyan'
  assert_equal "\e[37mmruby-yyjson\e[m", JSON.colorize('mruby-yyjson', :white), 'Colorize with :white'
  assert_equal "\e[90mmruby-yyjson\e[m", JSON.colorize('mruby-yyjson', :gray), 'Colorize with :gray'

  assert_raise(TypeError, 'Raise TypeError for unknown color') { JSON.colorize('mruby-yyjson', :unknown) }

  assert_equal "\e[32mHello, World!\e[m", JSON.colorize('Hello, World!', :green), 'Colorize specific string with :green'
  assert_equal "\e[90mTest String\e[m", JSON.colorize('Test String', :gray), 'Colorize specific string with :gray'
end

assert('JSON.#colorize_generate') do
  assert_equal <<~JSON.chomp, JSON.colorize_generate({ 'mruby' => 'yyjson', foo: [nil, true, 100] })
    {
      \e[34m"mruby"\e[m: \e[32m"yyjson"\e[m,
      \e[34m"foo"\e[m: [
        \e[90mnull\e[m,
        true,
        100
      ]
    }
  JSON
end
