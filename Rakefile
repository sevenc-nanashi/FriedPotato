# frozen_string_literal: true
require "zlib"
require "json"
require "yaml"
require "zip"

task :effect do
  clips = YAML.load_file("effect/clips.yml")
  effect_data = {clips: clips}

  clips.each do |clip|
    raise "Missing clip: #{clip}" unless File.exist?("effect/audio/#{clip["filename"]}")
  end
  Zlib::GzipWriter.open("public/repo/EffectData.gz") do |gz|
    gz.write(JSON.dump(effect_data))
  end

  File.delete("public/repo/EffectAudio.zip") if File.exist?("public/repo/EffectAudio.zip")
  Zip::File.open("public/repo/EffectAudio.zip", Zip::File::CREATE) do |zipfile|
    Dir["effect/audio/*"].each do |file|
      zipfile.add(file.sub("effect/audio/", ""), file)
    end
  end

end

task :lint do
  sh "rubocop *.rb"
end
