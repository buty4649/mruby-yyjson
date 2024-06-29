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
  class StubGenerator
    def generate(obj)
      assert_equal 'mruby-yyjson', obj, "Expected 'mruby-yyjson' as input to StubGenerator#generate"
      'stub generate'
    end
  end

  stub = lambda do |opts|
    assert_equal({ max_nesting: 19 }, opts, 'Expected options { max_nesting: 19 } for JSON::Generator.new')
    StubGenerator.new
  end

  JSON::Generator.stub(:new, stub) do
    assert_equal 'stub generate', JSON.generate('mruby-yyjson', max_nesting: 19)
  end
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
