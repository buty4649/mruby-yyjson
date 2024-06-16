assert('JSON.#[]') do
  assert_equal({"mruby" => "yyjson"}, JSON[%({"mruby":"yyjson"})])
  assert_equal({mruby: "yyjson"}, JSON[%({"mruby":"yyjson"}), symbolize_names: true])

  class TestStringLike
    def to_str
      %("TestStringLike#to_str")
    end
  end
  assert_equal "TestStringLike#to_str", JSON[TestStringLike.new]

  assert_equal %({"mruby":"yyjson"}), JSON[{"mruby" => "yyjson"}]
end

assert('JSON.#dump') do
  assert_equal "null", JSON.dump(nil)
  assert_equal "false", JSON.dump(false)
  assert_equal "true", JSON.dump(true)
  assert_equal "100", JSON.dump(100)
  assert_equal "-100", JSON.dump(-100)
  assert_equal "0.1", JSON.dump(0.1)
  assert_raise(JSON::GeneratorError) { JSON.dump(Float::NAN) }
  assert_raise(JSON::GeneratorError) { JSON.dump(Float::INFINITY) }
  assert_equal %("mruby-yyjson"), JSON.dump("mruby-yyjson")
  assert_equal %("JSON"), JSON.dump(:JSON)
  assert_equal %("JSON"), JSON.dump(JSON)
  assert_equal %("🍣"), JSON.dump("🍣")
  assert_equal %([true,1,"mruby-yyjson"]), JSON.dump([true, 1, "mruby-yyjson"])
  assert_equal %({"mruby":"yyjson","foo":123,"JSON":"json"}), JSON.dump({"mruby" => "yyjson", foo: 123, JSON:"json"})

  assert_raise(JSON::NestingError) do
    a = %w[a b c]; b = a; a[1] = b
    JSON.generate(a)
  end

  class TestWriter
    def write(obj)
      obj
    end
  end
  test_writer = TestWriter.new
  assert_equal test_writer, JSON.dump({mruby: "yyjson"}, test_writer)

  class TestButWirter; end
  assert_raise(TypeError) { JSON.dump({mruby: "yyjson"}, TestButWirter.new) }
end

assert('JSON.#generate') do
  assert_equal "null", JSON.generate(nil)
  assert_equal "false", JSON.generate(false)
  assert_equal "true", JSON.generate(true)
  assert_equal "100", JSON.generate(100)
  assert_equal "-100", JSON.generate(-100)
  assert_equal "0.1", JSON.generate(0.1)
  assert_raise(JSON::GeneratorError) { JSON.dump(Float::NAN) }
  assert_raise(JSON::GeneratorError) { JSON.dump(Float::INFINITY) }
  assert_equal %("mruby-yyjson"), JSON.generate("mruby-yyjson")
  assert_equal %("JSON"), JSON.generate(:JSON)
  assert_equal %("JSON"), JSON.generate(JSON)
  assert_equal %("🍣"), JSON.generate("🍣")
  assert_equal %([true,1,"mruby-yyjson"]), JSON.generate([true, 1, "mruby-yyjson"])
  assert_equal %({"mruby":"yyjson","foo":123,"JSON":"json"}), JSON.generate({"mruby" => "yyjson", foo: 123, JSON:"json"})

  assert_raise(JSON::NestingError) do
    a = %w[a b c]; b = a; a[1] = b
    JSON.generate(a)
  end
end

assert('JSON.#parse') do
  assert_equal nil, JSON.parse("null")
  assert_equal false, JSON.parse("false")
  assert_equal true, JSON.parse("true")
  assert_equal 100, JSON.parse("100")
  assert_equal (-100), JSON.parse("-100")
  assert_equal 0.1, JSON.parse("0.1")
  assert_equal "mruby-yyjson", JSON.parse(%("mruby-yyjson"))
  assert_equal "JSON", JSON.parse(%("JSON"))
  assert_equal "🍣", JSON.parse(%("🍣"))
  assert_equal [true, 1, "mruby-yyjson"], JSON.parse(%([true,1,"mruby-yyjson"]))
  assert_equal({"mruby" => "yyjson"}, JSON.parse(%({"mruby":"yyjson"})))

  assert_equal({mruby: "yyjson"}, JSON.parse(%({"mruby":"yyjson"}), symbolize_names: true))

  assert_raise(JSON::ParserError) { JSON.parse(%({"mruby":)) }
end

assert('JSON.#load') do
  assert_equal nil, JSON.load("null")
  assert_equal false, JSON.load("false")
  assert_equal true, JSON.load("true")
  assert_equal 100, JSON.load("100")
  assert_equal (-100), JSON.load("-100")
  assert_equal 0.1, JSON.load("0.1")
  assert_equal "mruby-yyjson", JSON.load(%("mruby-yyjson"))
  assert_equal "JSON", JSON.load(%("JSON"))
  assert_equal "🍣", JSON.load(%("🍣"))
  assert_equal [true, 1, "mruby-yyjson"], JSON.load(%([true,1,"mruby-yyjson"]))
  assert_equal({"mruby" => "yyjson"}, JSON.load(%({"mruby":"yyjson"})))

  assert_equal({mruby: "yyjson"}, JSON.load(%({"mruby":"yyjson"}), symbolize_names: true))

  assert_raise(JSON::ParserError) { JSON.load(%({"mruby":)) }

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

  assert_equal "TestStringLike#to_str", JSON.load(TestStringLike.new)
  assert_equal "TestReader#read", JSON.load(TestReader.new)
  assert_equal "TestReader#read", JSON.load(TestIOWrapper.new(TestReader.new))
end

assert('JSON.#load_file') do
  skip unless Object.const_defined?(:File)

  assert_equal({"mruby" => "yyjson"}, JSON.load_file("test/fixtures/test.json"))
  assert_equal({mruby: "yyjson"}, JSON.load_file("test/fixtures/test.json", symbolize_names: true))
end

assert('JSON.#pretty_generate') do
  assert_equal <<~JSON.chomp, JSON.pretty_generate({"mruby" => "yyjson", foo:%w[bar baz qux]})
    {
      "mruby": "yyjson",
      "foo": [
        "bar",
        "baz",
        "qux"
      ]
    }
  JSON
end
