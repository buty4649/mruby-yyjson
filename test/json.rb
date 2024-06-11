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
