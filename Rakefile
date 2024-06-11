unless File.exist?('mruby')
  system('git clone --depth 1 https://github.com/mruby/mruby/')
end

mruby_commit_id = `git -C mruby rev-parse HEAD`.chomp
puts "Using mruby commit id: #{mruby_commit_id}"
puts "================================================"

ENV['MRUBY_CONFIG'] = File.join(__dir__, 'build_config.rb')
ENV['MRUBY_BUILD_DIR'] = File.join(__dir__, 'build')
load "mruby/Rakefile"
