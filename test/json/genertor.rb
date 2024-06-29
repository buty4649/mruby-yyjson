assert('JSON::Generator#generate') do
  def nesting_array(count)
    return [] if count == 0

    [nesting_array(count - 1)]
  end

  assert('with default options') do
    g = JSON::Generator.new

    assert_equal 'null', g.generate(nil), 'nil'
    assert_equal 'false', g.generate(false), 'false'
    assert_equal 'true', g.generate(true), 'true'
    assert_equal '100', g.generate(100), 'Integer'
    assert_equal '-100', g.generate(-100), 'Integer'
    assert_equal '0.1', g.generate(0.1), 'Float'
    assert_raise(JSON::GeneratorError, 'Float::NAN') { g.generate(Float::NAN) }
    assert_raise(JSON::GeneratorError, 'Float::INFINITY') { g.generate(Float::INFINITY) }
    assert_equal %("mruby-yyjson"), g.generate('mruby-yyjson'), 'String'
    assert_equal %("JSON"), g.generate(:JSON), 'Symbol'
    assert_equal %("JSON"), g.generate(JSON), 'Class'
    assert_equal %("🍣"), g.generate('🍣'), 'Emoji'
    assert_equal %([true,1,"mruby-yyjson"]), g.generate([true, 1, 'mruby-yyjson']), 'Array'

    # default max_nesting is 19
    assert_raise(JSON::NestingError, 'NestingError for deeply nested array') do
      g.generate(nesting_array(20))
    end
  end

  assert('with max_nesting option') do
    # 0 is unlimited
    assert_nothing_raised('No error for max_nesting: 0 with deeply nested array') do
      JSON::Generator.new(max_nesting: 0).generate(nesting_array(100))
    end

    assert_raise(JSON::NestingError, 'NestingError for max_nesting: 9 with 10 levels of nesting') do
      JSON::Generator.new(max_nesting: 9).generate(nesting_array(10))
    end

    assert_raise(ArgumentError, 'ArgumentError for max_nesting: -1') do
      JSON::Generator.new(max_nesting: -1).generate(nesting_array(10))
    end

    assert_raise(TypeError, 'TypeError for max_nesting: true') do
      JSON::Generator.new(max_nesting: true).generate(nesting_array(10))
    end
  end
end

assert('JSON::Generator.colorize') do
  assert_equal "\e[31mmruby-yyjson\e[m", JSON::Generator.colorize('mruby-yyjson', :red)
  assert_equal 'mruby-yyjson', JSON::Generator.colorize('mruby-yyjson', :unknown)
end

assert('JSON::Generator#escape') do
  g = JSON::Generator.new

  assert_equal '"\\n"', g.escape("\n"), 'Escape newline character'
  assert_equal '"\\r"', g.escape("\r"), 'Escape carriage return character'
  assert_equal '"\\t"', g.escape("\t"), 'Escape tab character'
  assert_equal '"\\f"', g.escape("\f"), 'Escape form feed character'
  assert_equal '"\\b"', g.escape("\b"), 'Escape backspace character'
  assert_equal '"\""', g.escape('"'), 'Escape double quote character'
  assert_equal '"\\\"', g.escape('\\'), 'Escape backslash character'
  assert_equal "\"\\'\"", g.escape("'"), 'Escape single quote character'
  assert_equal '"\\u0000"', g.escape("\u0000"), 'Escape null character'
  assert_equal '"\\u001f"', g.escape("\u001f"), 'Escape unit separator character'
  assert_equal '"A"', g.escape('A'), 'Escape printable character'
  assert_equal '"Hello, World!"', g.escape('Hello, World!'), 'Escape string with printable characters'
  assert_equal '"Hello\\nWorld\\t\\u0001"', g.escape("Hello\nWorld\t\u0001"), 'Escape mixed characters'
  assert_equal '"\"Quoted\""', g.escape('"Quoted"'), 'Escape string with double quotes'
  assert_equal '"\\u0007"', g.escape("\a"), 'Escape bell character'
  assert_equal '"\\u000b"', g.escape("\v"), 'Escape vertical tab character'
  assert_equal '"\\u000e"', g.escape("\u000e"), 'Escape shift out character'
end
