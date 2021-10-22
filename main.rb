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
  unless File.exists?("dist/bg/#{name}.png")
    $current = name
    eval File.read("./bg_gen/main.rb")
  end
  File.read("dist/bg/#{name}.png", mode: "rb")
end

get "/levels/list" do
  HTTParty.get("https://servers.purplepalette.net/levels/list?" + URI.encode_www_form({ keywords: params[:keywords], page: params[:page] })).body.gsub('"/', '"https://servers.purplepalette.net/')
end

get "/levels/Welcome!" do
  {
    description: "",
    recommended: [],
    item: JSON.parse(File.read("./info.json"), symbolize_names: true)[0],
  }.to_json
end

get "/levels/:name" do |name|
  level_raw = HTTParty.get("https://servers.purplepalette.net/levels/#{name}").body.gsub('"/', '"https://servers.purplepalette.net/')
  level_hash = JSON.parse(level_raw, symbolize_names: true)
  level = level_hash[:item]
  if level_hash[:item][:engine][:name] == "wbp-pjsekai"
    level_hash[:item][:engine] = {
      name: "pjsekai",
      version: 4,
      title: "プロセカ",
      subtitle: "プロジェクトセカイ カラフルステージ!",
      author: "Burrito",
      skin: {
        name: "pjsekai.classic",
        version: 2,
        title: "Project Sekai",
        subtitle: "Project Sekai: Colorful Stage!",
        author: "Sonolus",
        thumbnail: { type: "SkinThumbnail",
                     hash: "24faf30cc2e0d0f51aeca3815ef523306b627289",
                     url: "https://servers.purplepalette.net/repository/SkinThumbnail/24faf30cc2e0d0f51aeca3815ef523306b627289" },
        data: { type: "SkinData",
                hash: "ad8a6ffa2ef4f742fee5ec3b917933cc3d2654af",
                url: "https://servers.purplepalette.net/repository/SkinData/ad8a6ffa2ef4f742fee5ec3b917933cc3d2654af" },
        texture: { type: "SkinTexture",
                   hash: "2ed3b0d09918f89e167df8b2f17ad8601162c33c",
                   url: "https://servers.purplepalette.net/repository/SkinTexture/2ed3b0d09918f89e167df8b2f17ad8601162c33c" },
      },
      effect: {
        name: "pjsekai.fixed",
        version: 2,
        title: "Project Sekai",
        subtitle: "Project Sekai: Colorful Stage!",
        author: "Sonolus",
        thumbnail: { type: "EffectThumbnail",
                     hash: "e5f439916eac9bbd316276e20aed999993653560",
                     url: "https://servers.purplepalette.net/repository/EffectThumbnail/e5f439916eac9bbd316276e20aed999993653560" },
        data: { type: "EffectData",
                hash: "17eb8ab357ad216d05e68a2752847ef4280252b3",
                url: "/repo/seconfig.gz" },
      },
      particle: {
        name: "pjsekai.classic",
        version: 1,
        title: "Project Sekai",
        subtitle: "Project Sekai: Colorful Stage!",
        author: "Sonolus",
        thumbnail: { type: "ParticleThumbnail",
                     hash: "e5f439916eac9bbd316276e20aed999993653560",
                     url: "https://servers.purplepalette.net/repository/ParticleThumbnail/e5f439916eac9bbd316276e20aed999993653560" },
        data: { type: "ParticleData",
                hash: "f84c5dead70ad62a00217589a73a07e7421818a8",
                url: "https://servers.purplepalette.net/repository/ParticleData/f84c5dead70ad62a00217589a73a07e7421818a8" },
        texture: { type: "ParticleTexture",
                   hash: "4850a8f335204108c439def535bcf693c7f8d050",
                   url: "https://servers.purplepalette.net/repository/ParticleTexture/4850a8f335204108c439def535bcf693c7f8d050" },
      },
      thumbnail: {
        type: "EngineThumbnail",
        hash: "e5f439916eac9bbd316276e20aed999993653560",
        url: "https://servers.purplepalette.net/repository/EngineThumbnail/e5f439916eac9bbd316276e20aed999993653560",
      },
      data: {
        type: "EngineData",
        hash: "86773c786f00b8b6cd2f6f99be11f62281385133",
        url: "https://servers.purplepalette.net/repository/EngineData/86773c786f00b8b6cd2f6f99be11f62281385133",
      },
      configuration: {
        type: "EngineConfiguration",
        hash: "55ada0ef19553e6a6742cffbb66f7dce9f85a7ee",
        url: "https://servers.purplepalette.net/repository/EngineConfiguration/55ada0ef19553e6a6742cffbb66f7dce9f85a7ee",
      },
    }
    level_hash[:item][:data][:url] = "/convert/#{level_hash[:item][:name]}"
    level_hash[:item][:data].delete(:hash)
    level_hash[:item][:data][:hash] = Digest::SHA256.hexdigest(File.read("./convert/#{level_hash[:item][:name]}.gz")) if File.exists?("./convert/#{level_hash[:item][:name]}.gz")
  end

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
        "hash": Digest::SHA1.hexdigest(File.read("./public/repo/seconfig.gz", mode: "rb")),
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

get "/convert/:name" do |name|
  # next File.read("./dist/conv/#{name}.gz", mode: "rb") if File.exists?("./dist/conv/#{name}.gz")
  raw = HTTParty.get("https://servers.purplepalette.net/repository/#{name}/data.gz").body
  gzreader = Zlib::GzipReader.new(StringIO.new(raw))
  json = gzreader.read
  gzreader.close
  s = JSON.parse(
    json,
    symbolize_names: true,
  )
  base = {
    entities: [
      {
        archetype: 0,
      },
      {
        archetype: 1,
      },
      {
        archetype: 2,
      },
    ],
  }
  slide_positions = {}
  last_entities = []
  s[:entities][2..].each.with_index(2) do |e, i|
    val = e[:data][:values]
    case e[:archetype]
    when 2
      width = (val[2] + 1) / 2.0
      base[:entities] << {
        archetype: 3,
        data: {
          index: 0,
          values: [
            val[0],
            val[1] + width,
            width,
            0,
          ],
        },
      }
    when 4
      width = (val[3] + 1) / 2.0
      base[:entities] << {
        archetype: 4,
        data: {
          index: 0,
          values: [
            val[1],
            val[2] + width,
            width,
            -1,
          ],
        },
      }
    when 3
      width = (val[2] + 1) / 2.0
      slide_positions[i] = val
      base[:entities] << {
        archetype: 5,
        data: {
          index: 0,
          values: [
            val[0],
            val[1] + width,
            width,
            0,
          ],
        },
      }
    when 5
      slide_positions[i] = val
      width = (val[3] + 1) / 2.0
      base[:entities] << {
        archetype: 6,
        data: {
          index: 0,
          values: [
            val[1],
            val[2] + width,
            width,
          ],
        },
      }
    when 6, 7
      slide_positions[i] = val
      width = (val[3] + 1) / 2.0
      before = [
        val[1],
        val[2] + width,
        width,
      ]
      cursor = val[0]
      while data = slide_positions[cursor]
        if data.length == 3
          break
        end
        cursor = data[0]
      end
      first_index = cursor
      cursor = val[0]
      while data = slide_positions[cursor]
        if data.length == 3
          data = [nil] + data
        end
        width = (data[3] + 1) / 2.0
        position = [data[1], data[2] + width, width]
        last_entities << {
          archetype: 9,
          data: {
            index: 0,
            values: [
              position,
              before,
              -1,
              first_index + 1,
            ].flatten,
          },
        }
        before = position
        cursor = data[0]
      end
      width = (val[3] + 1) / 2.0
      base[:entities] << {
        archetype: e[:archetype] + 1,
        data: {
          index: 0,
          values: [
            val[1],
            val[2] + width,
            width,
            -1,
          ],
        },
      }
    end
  end
  base[:entities] += last_entities
  Zlib::GzipWriter.wrap(File.open("./dist/conv/#{name}.gz", "wb")) do |gz|
    gz.write(base.to_json)
  end
  File.read("./dist/conv/#{name}.gz", mode: "rb")
end
