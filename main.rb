require "json"
require "uri"
require "sinatra"
require "fileutils"
require "sinatra/reloader"
require "sinatra/json"
require "http"
require "digest"
require "zlib"
require "yaml"
require "socket"
require "open3"

def python_started?
  begin
    Socket.tcp("localhost", $config.python_port, connect_timeout: 0.1) { }
  rescue Errno::ETIMEDOUT
    return false
  else
    return true
  end
end

$hash_cache = {}

def get_file_hash(path)
  $hash_cache[path] ||= Digest::SHA256.file(path).hexdigest
end

def modify_level!(level, extra)
  name = level[:name]
  if level[:engine][:name] == "wbp-pjsekai"
    level[:engine] = {
      name: "pjsekai",
      version: 4,
      title: "プロセカ（コンバーター）",
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
                hash: get_file_hash("./public/repo/seconfig.gz"),
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
    level[:data][:url] = "/convert/#{level[:name]}"
    level[:data].delete(:hash)
    level[:data][:hash] = get_file_hash("./convert/#{level[:name]}.gz") if File.exists?("./convert/#{level[:name]}.gz")
  elsif level[:engine][:name] == "psekai"
    level[:data][:url] = "/convert/l_#{level[:name]}"
    level[:engine] = JSON.parse(File.read("./convert-engine.json"), symbolize_names: true)
    level[:name] = "l_" + level[:name]

    level[:engine] = JSON.parse(
      File.read("./convert-engine.json")
        .gsub("!name!", level[:name])
        .gsub("!artists!", level[:artists])
        .gsub("!author!", level[:author])
        .gsub("!title!", level[:title]),
      symbolize_names: true,
    )
  else
    level[:data][:url] = "/modify/#{level[:name]}-#{level[:data][:hash]}"
    if File.exists?("dist/modify/#{level[:data][:hash]}.gz")
      level[:data][:hash] = get_file_hash("dist/modify/#{level[:data][:hash]}.gz")
    else
      level[:data].delete(:hash)
    end
  end
  img_name = level[:name].dup
  if extra
    img_name += ".extra"
    level[:title] += " (Extra)"
    level[:name] += ".extra"
  end
  if Dir.exist?("./overrides/#{name}")
    if File.exist?("./overrides/#{name}/thumbnail.png")
      level[:cover][:url] = "/overrides/#{name}/thumbnail.png"
      level[:cover][:hash] = get_file_hash("./overrides/#{name}/thumbnail.png")
    end
    if File.exist?("./overrides/#{name}/bgm.mp3")
      level[:bgm][:url] = "/overrides/#{name}/bgm.mp3"
      level[:bgm][:hash] = get_file_hash("./overrides/#{name}/bgm.mp3")
    end
    if File.exist?("./overrides/#{name}/data.json")
      json_hash = get_file_hash("./overrides/#{name}/data.json")
      Zlib::GzipWriter.open("./dist/data-overrides/#{json_hash}.gz") do |gz|
        gz.write(File.read("./overrides/#{name}/data.json"))
      end
      level[:data][:url] = "/data-overrides/#{json_hash}.gz"
      level[:data][:hash] = get_file_hash("./dist/data-overrides/#{json_hash}.gz")
    end
  end
  if Dir.exist?($config.engine_path)
    level[:engine][:data][:url] = "/engine/data"
    level[:engine][:data][:hash] = get_file_hash($config.engine_path + "/dist/EngineData")
    level[:engine][:configuration][:url] = "/engine/configuration"
    level[:engine][:configuration][:hash] = get_file_hash($config.engine_path + "/dist/EngineConfiguration")
  end
  level[:engine][:skin][:name] = "pjsekai.extended"
  level[:engine][:skin][:data][:url] = "/skin/data"
  skin_data_hash = get_file_hash("./skin/data.json")
  if File.exist?("./dist/skin/#{skin_data_hash}.gz")
    level[:engine][:skin][:data][:hash] = get_file_hash("./dist/skin/#{skin_data_hash}.gz")
  else
    level[:engine][:skin][:data].delete(:hash)
  end

  level[:engine][:skin][:texture][:url] = "/skin/texture"
  level[:engine][:skin][:texture][:hash] = get_file_hash("./skin/texture.png")

  level[:engine][:background] = {
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
      hash: get_file_hash("./public/repo/data.gz"),
      url: "/repo/data.gz",
    },
    image: {
      type: :BackgroundImage,
      url: "/generate/#{img_name}",
    },
    configuration: {
      type: :BackgroundConfiguration,
      hash: get_file_hash("./public/repo/config.gz"),
      url: "/repo/config.gz",
    },
  }
  level[:engine][:effect][:name] = "pjsekai.fixed"
  level[:engine][:effect][:data][:url] = "/repo/seconfig.gz"
  level[:engine][:effect][:data][:hash] = get_file_hash("./public/repo/seconfig.gz")
  if File.exists?("dist/bg/#{img_name}.png")
    level[:engine][:background][:image][:hash] = get_file_hash("dist/bg/#{level[:name]}.png")
  end
end

SEARCH_OPTION = [
  {
    name: "#KEYWORDS",
    placeholder: "#KEYWORDS",
    query: "keywords",
    type: "text",
  },
]

class Config
  KEYS = {
    engine_path: {
      description: "エンジンのパス。",
      default: "../sonolus-pjsekai-engine",
    },
    trace_enabled: {
      description: "TRACEノーツを使用するかどうか。32分スライドが置き換わります。",
      default: false,
    },
    background_engine: {
      description: "背景生成のエンジン。dxruby、pillow、web、noneのいずれかを指定して下さい。",
      default: "web",
    },
    sonolus_5_10: {
      description: "Sonolusがv0.5.10かどうか。",
      default: true,
    },
    port: {
      description: "ポート番号。",
      default: 4567,
    },
    python_port: {
      description: "Pythonのポート番号。",
      default: 4568,
    },
  }

  def initialize
    load
  end

  def method_missing(name, value = nil)
    if name.end_with?("=")
      unless KEYS.key?(name.to_s.chop.to_sym)
        raise "unknown key: #{name}"
      end
      @config[name.to_s.chop.to_sym] = value
      save
    else
      load
      raise "unknown key: #{name}" if @config.key?(name).nil?
      @config[name]
    end
  end

  def save
    File.open("./config.yml", "w") do |y|
      @config.each do |key, value|
        y.puts "# #{KEYS[key][:description]}"
        y.puts "# デフォルト: #{KEYS[key][:default]}"
        y.puts "#{key}: #{value}"
        y.puts
      end
    end
  end

  def load
    @config = if File.exist?("./config.yml")
        YAML.load(File.read("./config.yml"), symbolize_names: true)
      else
        {}
      end
    save_flag = false
    (KEYS.keys - @config.keys).each do |key|
      save_flag = true
      @config[key] = KEYS[key][:default]
    end
    save if save_flag
  end
end

$config = Config.new

set :bind, "0.0.0.0"
set :public_folder, File.dirname(__FILE__) + "/public"
if ENV["RACK_ENV"] == "production"
  set :port, ENV["PORT"]
  FileUtils.cp("./config.production.yml", "./config.yml")
  FileUtils.mkdir_p("engine/dist")
  HTTP.get("https://cdn.discordapp.com/attachments/939861558199197706/943862143063826442/EngineData").body.then do |body|
    File.write("engine/dist/EngineData", body, mode: "wb")
  end
  HTTP.get("https://cdn.discordapp.com/attachments/939861558199197706/943862142904434688/EngineConfiguration").body.then do |body|
    File.write("engine/dist/EngineConfiguration", body, mode: "wb")
  end
else
  set :port, $config.port
end
$level_base = JSON.parse(File.read("base.json"), symbolize_names: true)

get "/" do
  send_file "./public/index.html"
end

get "/info" do
  json ({
    levels: JSON.parse(File.read("./info.json")).then { |i| $config.sonolus_5_10 ? { items: i, search: { options: SEARCH_OPTION } } : i },
    skins: [
      {
        name: "info_bg",
        title: "統計：背景画像数",
        subtitle: Dir.glob("./dist/bg/*.png").size.to_s + "枚",
      },
      {
        name: "info_conv",
        title: "統計：変換された譜面数",
        subtitle: Dir.glob("./dist/conv/*.gz").size.to_s + "個",
      },
    ],
    backgrounds: {
      search: { options: SEARCH_OPTION },
    },
    effects: [],
    particles: [],
    engines: [],
  })
end

get "/tests/:test_id/info" do |test_id|
  json ({
    levels: JSON.parse(File.read("./info_test.json").sub("{test_id}", test_id)).then { |i| $config.sonolus_5_10 ? { items: i, search: { options: SEARCH_OPTION } } : i },
    skins: [],
    backgrounds: [],
    effects: [],
    particles: [],
    engines: [],
  })
end
get "/backgrounds/list" do
  levels = JSON.parse(HTTP.get("https://servers.purplepalette.net/levels/list?" + URI.encode_www_form({ keywords: params[:keywords], page: params[:page] })).body, symbolize_names: true)
  res = {
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
          url: "/repo/config.gz",
        },
      }
    end,
    search: { options: SEARCH_OPTION },
  }
  json res
end

get "/backgrounds/:name" do |name|
  level = JSON.parse(HTTP.get("https://servers.purplepalette.net/levels/#{params[:name]}").body, symbolize_names: true)[:item]
  json ({
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
        url: "/repo/config.gz",
      },
    },
  })
end

get %r{(?:/tests/[^/]+)?/generate/(.+)} do |name|
  unless File.exists?("dist/bg/#{name}.png")
    case $config.background_engine
    when "dxruby"
      $current = name
      eval File.read("./bg_gen/main.rb")
    when "pillow"
      unless python_started?
        Open3.popen2(".venv/Scripts/python.exe ./bg_gen/main.py #{$config.python_port}")
      end
      HTTP.get("http://localhost:#{$config.python_port}/generate/#{name}")
    when "web"
      HTTP.post("https://image-gen.sevenc7c.com/generate/#{name.split(".")[0]}?extra=#{name.include?(".extra")}").then do |res|
        if res.status == 200
          File.write("dist/bg/#{name}.png", res.body, mode: "wb")
        else
          if name.include?(".extra")
            redirect "/repo/background-base-extra.png"
          else
            redirect "/repo/background-base.png"
          end
        end
      end
    when "none"
      if name.include?(".extra")
        redirect "/repo/background-base-extra.png"
      else
        redirect "/repo/background-base.png"
      end
    end
  end
  send_file "dist/bg/#{name}.png"
end

get "/levels/list" do
  ppdata = JSON.parse(
    HTTP.get("https://servers.purplepalette.net/levels/list?" + URI.encode_www_form({ keywords: params[:keywords], page: params[:page].to_i })).body.to_s.gsub('"/', '"https://servers.purplepalette.net/'), symbolize_names: true,
  )
  if params[:keywords].nil? or params[:keywords].empty?
    if ppdata[:items].length == 0
      levels = JSON.parse(
        HTTP.get("https://raw.githubusercontent.com/PurplePalette/PurplePalette.github.io/0f37a15a672c95daae92f78953d59d05c3f01b5d/sonolus/levels/list").body
          .to_s.gsub('"/', '"https://PurplePalette.github.io/sonolus/'), symbolize_names: true,
      )[:items].map do |data|
        data[:data][:url] = "/local/#{data[:name]}/data.gz"
        data[:engine] = JSON.parse(File.read("./convert-engine.json"), symbolize_names: true)
        data[:name] = "l_" + data[:name]

        data
      end
      ppdata[:items] = levels
    end
    ppdata[:pageCount] += 1
  end
  ppdata[:items].each { modify_level!(_1, false) }
  json ppdata
end

get "/tests/:test_id/levels/list" do |test_id|
  ppdata = JSON.parse(
    HTTP.get("https://servers.purplepalette.net/tests/#{test_id}/levels/list?" + URI.encode_www_form({ keywords: params[:keywords], page: params[:page].to_i })).body.to_s.gsub('"/', '"https://servers.purplepalette.net/'), symbolize_names: true,
  )
  ppdata[:items].each { modify_level!(_1, false) }
  json ppdata
end

get %r{(?:/tests/[^/]+)?/levels/(Welcome%21|About|system)} do
  json({ item: JSON.load_file("./unavailable.json") })
end
get %r{(?:/tests/[^/]+)?/levels/([^\.]+)(?:\.(.+))?} do |name, suffix|
  if name.start_with?("l_")
    level_raw = HTTP.get("https://PurplePalette.github.io/sonolus/levels/#{name[2..-1].gsub(" ", "%20")}").body.to_s.gsub('"/', '"https://PurplePalette.github.io/sonolus/')
  else
    level_raw = HTTP.get("https://servers.purplepalette.net/levels/#{name}").body.to_s.gsub('"/', '"https://servers.purplepalette.net/')
  end

  level_hash = JSON.parse(level_raw, symbolize_names: true)
  level = level_hash[:item]
  level_hash[:description] ||= ""
  extra = true if level_hash[:description].include?("#extra") || suffix == "extra"
  modify_level!(level, extra)
  level_hash[:recommended] = [
    {
      name: extra ? level[:name][..-7] : level[:name] + ".extra",
      version: 2,
      title: extra ? "ExtraモードOFF" : "ExtraモードON",
      subtitle: "-",
      cover: {
        type: :LevelCover,
        hash: get_file_hash("./public/repo/extra_#{extra ? "off" : "on"}.png"),
        url: "/repo/extra_#{extra ? "off" : "on"}.png",
      },
      data: {
        type: :LevelData,
        url: "/repo/data.gz",
      },
      engine: {},
    },
  ]
  if File.exists?("dist/bg/#{level[:name]}.png")
    level_hash[:recommended] << {
      name: level[:name] + ".delete-cache",
      version: 2,
      title: "背景キャッシュを削除",
      subtitle: "-",
      cover: {
        type: :LevelCover,
        hash: get_file_hash("./public/repo/delete.png"),
        url: "/repo/delete.png",
      },
      data: {
        type: :LevelData,
        url: "/repo/data.gz",
      },
      engine: {},
    }
  end
  json level_hash
end

get "/effects/pjsekai.fixed" do
  json ({
    "description": "",
    "item": {
      "author": "Sonolus",
      "data": {
        "hash": get_file_hash("./public/repo/seconfig.gz"),
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
  })
end

get %r{(?:/tests/.+)?/convert/(.+)} do |name|
  next send_file "./dist/conv/#{name}.gz" if File.exists?("./dist/conv/#{name}.gz")
  if name.start_with?("l_")
    raw = HTTP.get("https://PurplePalette.github.io/sonolus/repository/levels/#{name[2..]}/level")
  else
    raw = HTTP.get("https://servers.purplepalette.net/repository/#{name}/data.gz").body
  end
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
  send_file "./dist/conv/#{name}.gz"
end

get %r{(?:/tests/.+)?/overrides/(.+)} do |path|
  send_file "./overrides/#{path}"
end

get %r{(?:/tests/([^/]+))?/repo/(.+)} do |name, path|
  redirect "/repo/#{path}"
end

get %r{(?:/tests/([^/]+))?/data-overrides/(.+)} do |name, path|
  send_file "./dist/data-overrides/#{path}"
end

get %r{(?:/tests/([^/]+))?/skin/texture} do |name|
  send_file "./skin/texture.png"
end

get %r{(?:/tests/([^/]+))?/skin/data} do |name|
  hash = get_file_hash("./skin/data.json")
  unless File.exist?("./dist/skin/#{hash}.gz")
    Zlib::GzipWriter.open("./dist/skin/#{hash}.gz") do |gz|
      gz.write(File.read("./skin/data.json", mode: "rb"))
    end
  end
  send_file "./dist/skin/#{hash}.gz"
end

get %r{(?:/tests/([^/]+))?/engine/data} do |name|
  send_file $config.engine_path + "/dist/EngineData"
end
get %r{(?:/tests/([^/]+))?/engine/configuration} do |name|
  send_file $config.engine_path + "/dist/EngineConfiguration"
end

get "/skins/list" do
  <<~JSON
    {
      "pageCount": 1,
      "items": [
        {
          "author": "Sonolus",
          "data": {
              "type": "SkinData",
              "url": "/skin/data"
          },
          "name": "pjsekai.extended",
          "subtitle": "Project Sekai: Colorful Stage!",
          "texture": {
              "type": "SkinTexture",
              "url": "/skin/texture"
          },
          "thumbnail": {
              "type": "SkinThumbnail",
              "url": "https://servers.purplepalette.net/repository/SkinThumbnail/24faf30cc2e0d0f51aeca3815ef523306b627289"
          },
          "title": "Project Sekai",
          "version": 2
        }
      ]
    }
  JSON
end

get "/skins/pjsekai.extended" do
  <<~JSON
    {
      "item": {
        "author": "Sonolus",
        "data": {
            "type": "SkinData",
            "url": "/skin/data"
        },
        "name": "pjsekai.extended",
        "subtitle": "Project Sekai: Colorful Stage!",
        "texture": {
            "type": "SkinTexture",
            "url": "/skin/texture"
        },
        "thumbnail": {
            "hash": "24faf30cc2e0d0f51aeca3815ef523306b627289",
            "type": "SkinThumbnail",
            "url": "https://servers.purplepalette.net/repository/SkinThumbnail/24faf30cc2e0d0f51aeca3815ef523306b627289"
        },
        "title": "Project Sekai",
        "version": 2
      },
      "description": "PjSekai + Trace notes",
      "recommended": []
    }
  JSON
end

get %r{(?:/tests/([^/]+))?/modify/(.+)-(.+)} do |name, level, hash|
  cfg = [[?t, $config.trace_enabled]].filter { |x| x[1] }.map { |x| x[0] }.join
  key = "#{hash}-#{cfg}"
  next send_file "./dist/modify/#{key}.gz" if File.exists?("./dist/modify/#{key}.gz")
  raw = HTTP.get("https://servers.purplepalette.net/repository/#{level}/data.gz").body
  gzreader = Zlib::GzipReader.new(StringIO.new(raw.to_s))
  level_data = JSON.parse(gzreader.read, symbolize_names: true)
  entities = level_data[:entities]
  will_delete = []
  if $config.trace_enabled
    entities.filter { |e| e[:archetype] == 9 }.each do |e|
      next unless e[:data][:values][3] - e[:data][:values][0] == 0.0625 and e[:data][:values][1..2] == e[:data][:values][4..5]
      not_found = false
      entities.find { |e2| e2[:archetype] == 5 and e2[:data][:values] == e[:data][:values][0..2] }.tap do |e2|
        index = entities.find_index(e2)
        end_note = entities.find { |e2| [7, 8].include?(e2[:archetype]) and e2[:data][:values][4] == index }
        next not_found = true unless end_note
        if end_note[:archetype] == 7
          e2[:archetype] = 18
        else
          e2[:archetype] = 19
          e2[:data][:values][3] = end_note[:data][:values][3]
        end
        will_delete << end_note
      end

      will_delete << e unless not_found
    end
    wd_index = will_delete.filter_map { |e| entities.find_index(e) }
    will_delete.each do |e|
      entities.delete(e)
    end
    entities.filter { |e| [7, 9].include?(e[:archetype]) }.each do |e|
      e[:data][:values][-1] -= wd_index.filter { |i| i < e[:data][:values][-1] }.length
    end
  end
  Zlib::GzipWriter.wrap(File.open("./dist/modify/#{key}.gz", "wb")) do |gz|
    gz.write(level_data.to_json)
  end
  send_file "./dist/modify/#{key}.gz"
end

ip = Socket.ip_address_list.find(&:ipv4_private?).ip_address
puts <<~EOS.strip
       \e[91m+---------------------------------------------+\e[m
       \e[91m|            FriedPotatoへようこそ！          |\e[m
       \e[91m+---------------------------------------------+\e[m

       Sonolusを開き、サーバーのURLに以下を入力して下さい：
         \e[97mhttp://#{ip}:#{$config.port}\e[m
       テストサーバーの場合は以下のURLを入力して下さい：
         \e[97mhttp://#{ip}:#{$config.port}/tests/\e[m<テストサーバーID>


       \e[97mCtrl+C\e[m を押すと終了します。

       Created by \e[96m名無し｡(@sevenc-nanashi)\e[m
     EOS
puts
