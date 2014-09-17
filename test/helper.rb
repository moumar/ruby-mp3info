if RUBY_VERSION.to_f <= 1.9 || (`ruby -v`.include? "rubinius")
  require 'test/unit'
  TestCase = Test::Unit::TestCase
else
  require 'minitest/autorun'
  TestCase = MiniTest::Test
end

