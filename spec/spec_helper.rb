require 'bundler/setup'
require 'rspec/isolation'

RSPEC_VERSION = defined?(RSpec::Core::Version::STRING) && RSpec::Core::Version::STRING

Dir['./spec/support/**/*.rb'].map {|f| require f}

def sandboxed(&block)
  begin
    @orig_config = RSpec.configuration
    @orig_world  = RSpec.world
    new_config = RSpec::Core::Configuration.new
    new_config.include(RSpec::Matchers)
    new_world  = RSpec::Core::World.new(new_config)
    RSpec.instance_variable_set(:@configuration, new_config)
    RSpec.instance_variable_set(:@world, new_world)
    object = Object.new
    if RSPEC_VERSION < "2.6"
      object.extend(RSpec::Core::ObjectExtensions)
      object.extend(RSpec::Core::SharedExampleGroup)
    end

    (class << RSpec::Core::ExampleGroup; self; end).class_eval do
      alias_method :orig_run, :run
      def run(reporter=nil)
        @orig_mock_space = RSpec::Mocks::space
        RSpec::Mocks::space = RSpec::Mocks::Space.new
        orig_run(reporter || NullObject.new)
      ensure
        RSpec::Mocks::space = @orig_mock_space
      end
    end

    object.instance_eval(&block)
  ensure
    (class << RSpec::Core::ExampleGroup; self; end).class_eval do
      remove_method :run
      if method_defined?(:orig_run)
        alias_method :run, :orig_run
        remove_method :orig_run
      end
    end

    RSpec.instance_variable_set(:@configuration, @orig_config)
    RSpec.instance_variable_set(:@world, @orig_world)
  end
end

def in_editor?
  ENV.has_key?('TM_MODE') || ENV.has_key?('EMACS') || ENV.has_key?('VIM')
end

RSpec.configure do |c|
  c.include RSpecIsolationSpecMatchers
  c.color_enabled = !in_editor?
  c.filter_run :focused => true
  c.run_all_when_everything_filtered = true
  c.filter_run_excluding :ruby => lambda {|version|
    case version.to_s
    when "!jruby"
      RUBY_ENGINE != "jruby"
    when /^> (.*)/
      !(RUBY_VERSION.to_s > $1)
    else
      !(RUBY_VERSION.to_s =~ /^#{version.to_s}/)
    end
  }
  c.around do |example|
    sandboxed { example.run }
  end
end
