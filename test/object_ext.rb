assert('Object#to_json') do
  assert_equal 'null', nil.to_json
  assert_equal 'false', false.to_json
  assert_equal 'true', true.to_json
  assert_equal '100', 100.to_json
  assert_equal '0.25', 0.25.to_json
  assert_equal %("mruby-yyjson"), 'mruby-yyjson'.to_json
  assert_equal %("JSON"), :JSON.to_json
  assert_equal %([true,1,"mruby-yyjson"]), [true, 1, 'mruby-yyjson'].to_json
  assert_equal %({"mrb":"yyjson","foo":123,"JSON":"json"}), { 'mrb' => 'yyjson', foo: 123, JSON: 'json' }.to_json
end
