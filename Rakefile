unless File.exist?('mruby')
  system('git clone --depth 1 https://github.com/mruby/mruby/')
end

ENV['MRUBY_CONFIG'] = File.join(__dir__, 'build_config.rb')
ENV['MRUBY_BUILD_DIR'] = File.join(__dir__, 'build')
load "mruby/Rakefile"
