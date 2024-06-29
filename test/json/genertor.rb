assert('JSON::Generator') do
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
