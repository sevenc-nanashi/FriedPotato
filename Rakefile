require "zlib"
require "json"
require "digest"

task :seconfig do
  config = JSON.parse File.read("./raw_data/seconfig.json"), symbolize_names: true
  config[:clips][-1][:clip][:hash] = Digest::SHA1.hexdigest(File.read("./public/repo/connect.mp3", mode: "rb"))
  Zlib::GzipWriter.open("./public/repo/seconfig.gz") do |gz|
    gz.write config.to_json
  end
  puts "seconfig.gz created"
end
