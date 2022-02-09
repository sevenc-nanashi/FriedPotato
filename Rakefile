require "zlib"
require "json"
require "digest"

task :seconfig do
  config = JSON.parse File.read("./raw_data/seconfig.json"), symbolize_names: true
  config[:clips].each do |c|
    unless c[:clip][:hash]
      c[:clip][:hash] = Digest::SHA256.hexdigest(File.read("./public" + c[:clip][:url], mode: "rb"))
    end
  end
  pp config
  Zlib::GzipWriter.open("./public/repo/seconfig.gz") do |gz|
    gz.write config.to_json
  end
  puts "seconfig.gz created"
end
