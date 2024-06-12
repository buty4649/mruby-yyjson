assert('JSON.#generate') do
  assert_equal "null", JSON.generate(nil)
  assert_equal "false", JSON.generate(false)
  assert_equal "true", JSON.generate(true)
  assert_equal "100", JSON.generate(100)
  assert_equal "-100", JSON.generate(-100)
  assert_equal "0.25", JSON.generate(0.25)
  assert_equal %("mrb-yyjson"), JSON.generate("mrb-yyjson")
  assert_equal %("JSON"), JSON.generate(:JSON)
  assert_equal %("JSON"), JSON.generate(JSON)
  assert_equal %("🍣"), JSON.generate("🍣")
  assert_equal %([true,1,"mrb-yyjson"]), JSON.generate([true, 1, "mrb-yyjson"])
  assert_equal %({"mrb":"yyjson","foo":123,"JSON":"json"}), JSON.generate({"mrb" => "yyjson", foo: 123, JSON:"json"})

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
  assert_equal 0.25, JSON.parse("0.25")
  assert_equal "mrb-yyjson", JSON.parse(%("mrb-yyjson"))
  assert_equal "JSON", JSON.parse(%("JSON"))
  assert_equal "🍣", JSON.parse(%("🍣"))
  assert_equal [true, 1, "mrb-yyjson"], JSON.parse(%([true,1,"mrb-yyjson"]))
  assert_equal({"mrb" => "yyjson"}, JSON.parse(%({"mrb":"yyjson"})))
end

assert('JSON.#load') do
  assert_equal nil, JSON.load("null")
  assert_equal false, JSON.load("false")
  assert_equal true, JSON.load("true")
  assert_equal 100, JSON.load("100")
  assert_equal (-100), JSON.load("-100")
  assert_equal 0.25, JSON.load("0.25")
  assert_equal "mrb-yyjson", JSON.load(%("mrb-yyjson"))
  assert_equal "JSON", JSON.load(%("JSON"))
  assert_equal "🍣", JSON.load(%("🍣"))
  assert_equal [true, 1, "mrb-yyjson"], JSON.load(%([true,1,"mrb-yyjson"]))
  assert_equal({"mrb" => "yyjson"}, JSON.load(%({"mrb":"yyjson"})))

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

  assert_equal ({"mruby" => "yyjson"}), JSON.load_file("test/fixtures/test.json")
end

assert('JSON.#pretty_generate') do
  assert_equal <<~JSON.chomp, JSON.pretty_generate({"mrb" => "yyjson", foo:%w[bar baz qux]})
    {
      "mrb": "yyjson",
      "foo": [
        "bar",
        "baz",
        "qux"
      ]
    }
  JSON
end
