MRuby::Gem::Specification.new('mruby-yyjson') do |spec|
  spec.license = 'MIT'
  spec.authors = 'buty4649@gmail.com'
  spec.summary = 'yyjson bindings for mruby'
  spec.description = 'yyjson bindings for mruby'
  spec.version = '1.2.0'

  spec.add_test_dependency 'mruby-io', core: 'mruby-io'
  spec.add_test_dependency 'mruby-test-stub', github: 'buty4649/mruby-test-stub', branch: 'main'

  spec.cc.defines += %w[YYJSON_DISABLE_WRITER YYJSON_DISABLE_UTILS]
end
