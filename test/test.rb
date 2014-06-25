require 'phantomjs'

def before(rails_args = nil)
  `ps ax|grep rails|grep 5505|grep -v grep`.each_line do |line|
    `kill -9 #{line.split.first} 2> /dev/null`
  end

  `rm -rf #{File.expand_path("../app/tmp/pids/server.pid", __FILE__)}`

  spawn "cd #{File.expand_path("../app", __FILE__)} && #{rails_args} rails s -e development -p 5505"

  sleep 3
end

def after
  `ps ax|grep rails|grep 5505|grep -v grep`.each_line do |line|
    `kill -9 #{line.split.first} 2> /dev/null`
  end
end

def test_1
  before "use_queue=true queue_workers=1"
  result = Phantomjs.run File.expand_path("../phantom-test-1.js", __FILE__), '20', '1'
  after
  
  result
end

def test_2
  before "use_queue=true queue_workers=1"
  result = Phantomjs.run File.expand_path("../phantom-test-1.js", __FILE__), '10', '2'
  after
  
  result
end

def test_3
  before "use_queue=true queue_workers=3"
  result = Phantomjs.run File.expand_path("../phantom-test-1.js", __FILE__), '300', '1'
  after
  
  result
end

def test_4
  before "use_queue=true queue_workers=15"
  result = Phantomjs.run File.expand_path("../phantom-test-1.js", __FILE__), '10', '2'
  after
  
  result
end

def test_5
  before "use_queue=false"
  result = Phantomjs.run File.expand_path("../phantom-test-1.js", __FILE__), '100', '1'
  after
  
  result
end

def test_5
  before "use_queue=false"
  result = Phantomjs.run File.expand_path("../phantom-test-1.js", __FILE__), '2', '1'
  after
  
  result
end

def test_6
  before "use_queue=false"
  result = Phantomjs.run File.expand_path("../phantom-test-1.js", __FILE__), '50', '2'
  after
  
  result
end

test_1_result = test_1.include?('true')
test_2_result = test_2.include?('true')
test_3_result = test_3.include?('true')
test_4_result = test_4.include?('true')
test_5_result = test_5.include?('true')
test_6_result = test_6.include?('true')

if test_1_result && test_2_result && test_3_result && test_4_result && test_5_result && test_6_result
  puts "\n\nSuccess!\n\n"
else
  puts "\n\nFailed...\n\n"

  puts "test_1_result = #{test_1_result}"
  puts "test_2_result = #{test_2_result}"
  puts "test_3_result = #{test_3_result}"
  puts "test_4_result = #{test_4_result}"
  puts "test_5_result = #{test_5_result}"
  puts "test_6_result = #{test_6_result}"
end