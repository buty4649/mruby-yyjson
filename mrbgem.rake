MRuby::Gem::Specification.new('mruby-yyjson') do |spec|
  spec.license = 'MIT'
  spec.authors = 'buty4649@gmail.com'
  spec.summary = 'yyjson bindings for mruby'
  spec.description = 'yyjson bindings for mruby'
  spec.version = '1.0.0'

  spec.add_test_dependency 'mruby-io', core: 'mruby-io'
end
