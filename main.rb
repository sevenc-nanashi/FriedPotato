require "json"
require "uri"
require "sinatra"
require "sinatra/reloader"
require "httparty"
require "digest"
require "zlib"

# Make seconfig.json

config = JSON.parse File.read("./raw_data/seconfig.json"), symbolize_names: true
config[:clips][-1][:clip][:hash] = Digest::SHA1.hexdigest(File.read("./public/repo/connect.mp3", mode: "rb"))
Zlib::GzipWriter.open("./public/repo/seconfig.gz") do |gz|
  gz.write config.to_json
end

set :bind, "0.0.0.0"
set :public_folder, File.dirname(__FILE__) + "/public"

get "/info" do
  {
    levels: JSON.parse(File.read("./info.json")),
    skins: [],
    backgrounds: [],
    effects: [],
    particles: [],
    engines: [],
  }.to_json
end

get "/backgrounds/list" do
  levels = JSON.parse(HTTParty.get("https://servers.purplepalette.net/levels/list?" + URI.encode_www_form({ keywords: params[:keywords], page: params[:page] })).body, symbolize_names: true)
  {
    pageCount: levels[:pageCount],
    items: levels[:items].map do |level|
      {
        name: level[:name],
        version: 2,
        title: level[:title],
        subtitle: "#{level[:artists]} / #{level[:author]}",
        thumbnail: {
          type: :BackgroundThumbnail,
          url: "https://servers.purplepalette.net" + level[:cover][:url],
        },
        data: {
          type: :BackgroundData,
          url: "/repo/data.gz",
        },
        image: {
          type: :BackgroundImage,
          url: "/generate/#{level[:name]}",
        },
        configuration: {
          type: :BackgroundConfiguration,
          url: "/repo/config",
        },
      }
    end,
  }.to_json
end

get "/backgrounds/:name" do |name|
  level = JSON.parse(HTTParty.get("https://servers.purplepalette.net/levels/#{params[:name]}").body, symbolize_names: true)[:item]
  {
    description: level[:description],
    recommended: [],
    item: {
      name: level[:name],
      version: 2,
      title: level[:title],
      subtitle: "#{level[:artists]} / #{level[:author]}",
      thumbnail: {
        type: :BackgroundThumbnail,
        url: "https://servers.purplepalette.net" + level[:cover][:url],
      },
      data: {
        type: :BackgroundData,
        url: "/repo/data.gz",
      },
      image: {
        type: :BackgroundImage,
        url: "/generate/#{level[:name]}",
      },
      configuration: {
        type: :BackgroundConfiguration,
        url: "/repo/config",
      },
    },
  }.to_json
end

get "/generate/:name" do |name|
  unless File.exists?("dist/#{name}.png")
    $current = name
    eval File.read("./bg_gen/main.rb")
  end
  File.read("dist/#{name}.png", mode: "rb")
end

get "/levels/list" do
  HTTParty.get("https://servers.purplepalette.net/levels/list?" + URI.encode_www_form({ keywords: params[:keywords], page: params[:page] })).body.gsub('"/', '"https://servers.purplepalette.net/')
end

get "/levels/:name" do |name|
  level_raw = HTTParty.get("https://servers.purplepalette.net/levels/#{name}").body.gsub('"/', '"https://servers.purplepalette.net/')

  level_hash = JSON.parse(level_raw, symbolize_names: true)
  level = level_hash[:item]
  level_hash[:item][:engine][:background] = {

    name: level[:name],
    version: 2,
    title: level[:title],
    subtitle: "#{level[:artists]} / #{level[:author]}",
    thumbnail: {
      type: :BackgroundThumbnail,
      hash: level[:cover][:hash],
      url: level[:cover][:url],
    },
    data: {
      type: :BackgroundData,
      hash: Digest::SHA1.hexdigest(File.read("./public/repo/data.gz", mode: "rb")),
      url: "/repo/data.gz",
    },
    image: {
      type: :BackgroundImage,
      url: "/generate/#{level[:name]}",
    },
    configuration: {
      type: :BackgroundConfiguration,
      hash: Digest::SHA1.hexdigest(File.read("./public/repo/config.gz", mode: "rb")),
      url: "/repo/config.gz",
    },

  }
  level_hash[:item][:engine][:effect][:name] = "pjsekai.fixed"
  level_hash[:item][:engine][:effect][:data][:url] = "/repo/seconfig.gz"
  level_hash[:item][:engine][:effect][:data][:hash] = Digest::SHA1.hexdigest(File.read("./public/repo/seconfig.gz", mode: "rb"))
  if File.exists?("dist/#{level[:name]}.png")
    level_hash[:item][:engine][:effect][:data][:hash] = Digest::SHA1.hexdigest(File.read("dist/#{level[:name]}.png", mode: "rb"))
  end
  level_hash.to_json
end

get "/effects/pjsekai.fixed" do
  {
    "description": "",
    "item": {
      "author": "Sonolus",
      "data": {
        "hash": "173a9113716f0edc13f0f3e4a0458ef84525a0aa",
        "type": "EffectData",
        "url": "/repo/seconfig.gz",
      },
      "name": "pjsekai.fixed",
      "subtitle": "Project Sekai: Colorful Stage!",
      "thumbnail": {
        "hash": "e5f439916eac9bbd316276e20aed999993653560",
        "type": "EffectThumbnail",
        "url": "https://servers.purplepalette.net/repository/EffectThumbnail/e5f439916eac9bbd316276e20aed999993653560",
      },
      "title": "Project Sekai",
      "version": 2,
    },
    "recommended": [],
  }.to_json
end
