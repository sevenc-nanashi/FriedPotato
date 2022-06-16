require "zlib"
require "json"
require "digest"
require "http"
require "stringio"

task :seconfig do
  config = JSON.parse File.read("./raw_data/seconfig_additional.json"), symbolize_names: true
  config_base = JSON.parse(
    Zlib::GzipReader.wrap(
      StringIO.new(
        HTTP.get("https://servers.sonolus.com/pjsekai/repository/EffectData/b98f36f0370dd5b4cdaa67d594c203f07bbed055").body.to_s
      )
    ).read.gsub('"/', '"https://servers.sonolus.com/pjsekai/'),
    symbolize_names: true,
  )

  config.each do |c|
    unless c[:clip][:hash]
      c[:clip][:hash] = Digest::SHA1.file("./public" + c[:clip][:url]).hexdigest
    end
  end
  config_base[:clips] += config
  Zlib::GzipWriter.open("./public/repo/seconfig.gz") do |gz|
    gz.write config_base.to_json
  end
  puts config_base
  puts "seconfig.gz created"
end

task :lint do
  sh "rubocop *.rb"
end
