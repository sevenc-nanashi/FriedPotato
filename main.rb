require "json"
require "uri"
require "sinatra"
require "sinatra/reloader"
require "httparty"

set :bind, "0.0.0.0"
set :public_folder, File.dirname(__FILE__) + "/public"

def levels
  levels = JSON.parse(HTTParty.get("https://servers.purplepalette.net/levels/list?" + URI.encode_www_form({ keywords: params[:keywords], page: params[:page] })).body, symbolize_names: true)
  levels
end

get "/info" do
  {
    levels: levels,
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
  levels.to_json.gsub('"/', '"https://servers.purplepalette.net/')
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
      url: level[:cover][:url],
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
  level_hash.to_json
end
