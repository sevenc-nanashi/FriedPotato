require "zlib"
require "json"
require "digest"

task :seconfig do
  config = JSON.parse File.read("./raw_data/seconfig.json"), symbolize_names: true
  config[:clips].each do |c|
    unless c[:clip][:hash]
      c[:clip][:hash] = Digest::SHA1.file("./public" + c[:clip][:url]).hexdigest
    end
  end
  pp config
  Zlib::GzipWriter.open("./public/repo/seconfig.gz") do |gz|
    gz.write config.to_json
  end
  puts "seconfig.gz created"
end

task :lint do
  sh "rubocop *.rb"
end
