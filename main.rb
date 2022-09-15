# frozen_string_literal: true
require "json"
require "uri"
require "sinatra"
require "fileutils"
require "sinatra/json"
require "http"
require "digest"
require "zlib"
require "yaml"
require "socket"
require "open3"
require "sinatra/namespace"
# require "async"

class Config
  KEYS = {
    engine_path: {
      description: "エンジンのパス。",
      default: "../sonolus-pjsekai-engine"
    },
    trace_enabled: {
      description: "TRACEノーツを使用するかどうか。32分スライドが置き換わります。",
      default: false
    },
    background_engine: {
      description: "背景生成のエンジン。dxruby、pillow、web、noneのいずれかを指定して下さい。",
      default: "web"
    },
    sonolus_5_10: {
      description: "Sonolusがv0.5.10かどうか。",
      default: true
    },
    port: {
      description: "ポート番号。",
      default: 4567
    },
    python_port: {
      description: "Pythonのポート番号。",
      default: 4568
    },
    public: {
      description: "公開サーバーモードで起動するか。",
      default: false
    }
  }.freeze

  def initialize
    load
  end

  def method_missing(name, value = nil)
    if name.end_with?("=")
      raise "unknown key: #{name}" unless KEYS.key?(name.to_s.chop.to_sym)
      @config[name.to_s.chop.to_sym] = value
      save
    else
      load
      raise "unknown key: #{name}" if @config.key?(name).nil?
      @config[name]
    end
  end

  def respond_to_missing?(name, _priv)
    if name.end_with?("=")
      @config.key?(name.to_s.chop.to_sym)
    else
      @config.key?(name)
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
    @config =
      if File.exist?("#{__dir__}/config.yml")
        YAML.safe_load(
          File.read("#{__dir__}/config.yml"),
          symbolize_names: true
        )
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

class Integer
  def zfill(length)
    self.to_s.rjust(length, "0")
  end
end

$config = Config.new

def python_started?
  Socket.tcp("localhost", $config.python_port, connect_timeout: 0.1).close
rescue Errno::ETIMEDOUT
  false
else
  true
end

def start_python
  Open3.popen2(
    { "PORT" => $config.python_port.to_s },
    "../.venv/Scripts/python.exe ./main.py",
    chdir: "bg_gen_python"
  )
end

def load_datafile(path)
  data = File.read("./data/#{path}.json")
  data.gsub!(/"!import:(.+?)"/) do |match|
    File.read("./data/#{Regexp.last_match[1]}")
  end
  JSON.parse(data, symbolize_names: true)
end

def load_engine()
  base = load_datafile("engines/frpt-pjsekai.extended")
  if Dir.exist?($config.engine_path)
    base[:data][:url] = "/engine/data"
    base[:data][:hash] = get_file_hash($config.engine_path + "/dist/EngineData")
    base[:configuration][:url] = "/engine/configuration"
    base[:configuration][:hash] = get_file_hash(
      $config.engine_path + "/dist/EngineConfiguration"
    )
  end
  base[:skin][:name] = "frpt-pjsekai.extended"
  base[:skin][:data][:url] = "/skin/data"
  skin_data_hash = get_file_hash("./skin/data.json")
  if File.exist?("./dist/skin/#{skin_data_hash}.gz")
    base[:skin][:data][:hash] = get_file_hash(
      "./dist/skin/#{skin_data_hash}.gz"
    )
  else
    base[:skin][:data].delete(:hash)
  end

  base
end

if ENV["DOCKER"] == "true"
  $config.public = true
  $config.engine_path = "./engine"
  $config.background_engine = "web"
end
require "sinatra/reloader" unless $config.public
$hash_cache = {}
OFFICIAL_CHARACTERS =
  JSON
    .parse(
      HTTP
        .get(
          "https://sekai-world.github.io/sekai-master-db-diff/gameCharacters.json"
        )
        .body
        .to_s,
      symbolize_names: true
    )
    .to_h { |c| [c[:id], c] }
OUTSIDE_CHARACTERS =
  JSON
    .parse(
      HTTP
        .get(
          "https://sekai-world.github.io/sekai-master-db-diff/outsideCharacters.json"
        )
        .body
        .to_s,
      symbolize_names: true
    )
    .to_h { |c| [c[:id], c] }

def get_file_hash(path)
  $hash_cache[path] ||= Digest::SHA256.file(path).hexdigest
end

def format_artist(level, locale)
  if locale == "ja"
    "作詞：#{level[:lyricist]}  作曲：#{level[:composer]}  編曲：#{level[:arranger]}"
  else
    "Lyrics: #{level[:lyricist]}  Music: #{level[:composer]}  Arrangement: #{level[:arranger]}"
  end
end

def modify_level!(level, extra, server)
  name = level[:name]
  modifier = ""
  extra_name = nil
  if server == :official
    level[:name] = level[:name].sub("pjsekai-", "frptp-level-")

    bgm_id = level[:bgm][:url].split("/")[-1].split(".")[0]
    level[:data][:url] = "/shift/#{level[:name]}"
    level[:bgm][:hash] = get_file_hash(
      "./dist/bgm/#{bgm_id}.mp3"
    ) if File.exist?("./dist/bgm/#{bgm_id}.mp3")
    level[:bgm][:url] = "/bgm/#{bgm_id}"
  elsif level[:engine][:name] == "wbp-pjsekai"
    level[:name] = "frpt-" + level[:name]

    level[:useBackground] = {}
    level[:data][:url] = "/convert/#{level[:name]}"
    extra_name = " @ Converter"

    level[:data].delete(:hash)
    level[:data][:hash] = get_file_hash(
      "./convert/#{level[:name]}.gz"
    ) if File.exist?("./convert/#{level[:name]}.gz")
  elsif level[:engine][:name] == "psekai"
    level[:name] = "frpt-" + level[:name]

    level[:data][:url] = "/convert/l_#{level[:name]}"
    level[:name] = "l_" + level[:name]
    extra_name = " @ Old server"
  else
    level[:data][:url] = "/modify/#{level[:name]}-#{level[:data][:hash]}"
    if File.exist?("dist/modify/#{level[:data][:hash]}.gz")
      level[:data][:hash] = get_file_hash(
        "dist/modify/#{level[:data][:hash]}.gz"
      )
    else
      level[:data].delete(:hash)
    end
  end
  # img_name = level[:name].dup
  if extra && server != :official
    # img_name += ".extra"
    modifier += "e"
    level[:title] += " (Extra)"
    level[:name] += ".extra"
  end
  level[:engine] = load_engine
  level[:engine][:title] += extra_name if extra_name

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
      level[:data][:hash] = get_file_hash(
        "./dist/data-overrides/#{json_hash}.gz"
      )
    end
  end

  level[:useBackground][:useDefault] = false
  level[:useBackground][:item] = {
    name: "frpt-bg-#{level[:name]}",
    version: 2,
    title: level[:title],
    subtitle: "#{level[:artists]} / #{level[:author]}",
    thumbnail: {
      type: :BackgroundThumbnail,
      hash: level[:cover][:hash],
      url: level[:cover][:url]
    },
    data: {
      type: :BackgroundData,
      hash: get_file_hash("./public/repo/data.gz"),
      url: "/repo/data.gz"
    },
    image: {
      type: :BackgroundImage,
      url:
        "/generate/#{level[:name].delete_suffix(".extra")}_#{level[:cover][:hash]}-#{modifier}"
    },
    configuration: {
      type: :BackgroundConfiguration,
      hash: get_file_hash("./public/repo/config.gz"),
      url: "/repo/config.gz"
    }
  }

  if server == :official
    name = level[:name].split("-")[2]
    level[:useBackground][:item][:image][:url] = level[:useBackground][:item][
      :image
    ][
      :url
    ].sub("frptp-level-", "official--").sub("_", "_" + name)
    level[:useBackground][:item][:image][:hash] = get_file_hash(
      "dist/bg/#{name}-#{modifier}.png"
    ) if File.exist?("dist/bg/#{name}-#{modifier}.png")
  else
    level[:useBackground][:item][:image][:hash] = get_file_hash(
      "dist/bg/#{level[:cover][:hash]}-#{modifier}.png"
    ) if File.exist?("dist/bg/#{level[:cover][:hash]}-#{modifier}.png")
    level[:name] = "frpt-" + level[:name]
  end
end

SEARCH_OPTION = [
  {
    name: "#KEYWORDS",
    placeholder: "#KEYWORDS",
    query: "keywords",
    type: "text"
  }
].freeze

set :bind, "0.0.0.0"
set :show_exceptions, development?
set :public_folder, File.dirname(__FILE__) + "/public"
if ENV["RACK_ENV"] == "production"
  set :port, ENV["PORT"]
else
  set :port, $config.port
end
$level_base = JSON.parse(File.read("base.json"), symbolize_names: true)

get "/" do
  send_file "./public/index.html"
end

get "/info" do
  resp = {
    levels: {
      items: JSON.parse(File.read("./info_old.json"), symbolize_names: true),
      search: {
        options: SEARCH_OPTION
      }
    },
    skins: {
      items: [],
      search: {
      }
    },
    engines: {
      items: [],
      search: {
      }
    },
    backgrounds: {
      items: [],
      search: {
      }
    },
    effects: {
      items: [],
      search: {
      }
    },
    particles: {
      items: [],
      search: {
      }
    }
  }
  if params["localization"] != "ja"
    l = resp[:levels][:items][0]
    l[:title] = "Sorry, but we don't support Sonolus under 0.6.0."
    l[:artists] = "Please update your Sonolus."
  end
  json resp
end

namespace "/sonolus" do
  get "/info" do
    resp = {
      levels: {
        items: JSON.parse(File.read("./info.json"), symbolize_names: true),
        search: {
          options: SEARCH_OPTION
        }
      },
      skins: {
        items: [
          {
            name: "frpt-system",
            title: "統計：背景画像数",
            subtitle: Dir.glob("./dist/bg/*.png").size.to_s + "枚"
          },
          {
            name: "frpt-system",
            title: "統計：変換された譜面数",
            subtitle: Dir.glob("./dist/conv/*.gz").size.to_s + "個"
          }
        ],
        search: {
        }
      },
      backgrounds: {
        items: [],
        search: {
          options: SEARCH_OPTION
        }
      },
      effects: {
        items: [],
        search: {
        }
      },
      particles: {
        items: [],
        search: {
        }
      },
      engines: {
        items: [],
        search: {
        }
      }
    }
    if params["localization"] != "ja"
      l = resp[:levels][:items][0]
      l[:title] = "Welcome to FriedPotato!"
      l[
        :artists
      ] = "The source is open at https://github.com/sevenc-nanashi/FriedPotato"
      l = resp[:levels][:items][1]
      l[:title] = "Tap [More] button below to browse levels..."
    end
    json resp
  end

  get "/backgrounds/list" do
    levels =
      JSON.parse(
        HTTP.get(
          "https://servers-legacy.purplepalette.net/levels/list?" +
            URI.encode_www_form(
              { keywords: params[:keywords], page: params[:page] }
            )
        ).body,
        symbolize_names: true
      )
    res = {
      pageCount: levels[:pageCount],
      items:
        levels[:items].map do |level|
          {
            name: "frpt-bg-" + level[:name],
            version: 2,
            title: level[:title],
            subtitle: "#{level[:artists]} / #{level[:author]}",
            thumbnail: {
              type: :BackgroundThumbnail,
              url:
                "https://servers-legacy.purplepalette.net" + level[:cover][:url]
            },
            data: {
              type: :BackgroundData,
              url: "/repo/data.gz"
            },
            image: {
              type: :BackgroundImage,
              url: "/generate/#{level[:name]}_#{level[:cover][:hash]}-"
            },
            configuration: {
              type: :BackgroundConfiguration,
              url: "/repo/config.gz"
            }
          }
        end,
      search: {
        options: SEARCH_OPTION
      }
    }
    json res
  end

  get %r{/backgrounds/frpt-bg-([^.]+)} do |name|
    level =
      JSON.parse(
        HTTP.get(
          "https://servers-legacy.purplepalette.net/levels/#{name}"
        ).body,
        symbolize_names: true
      )[
        :item
      ]
    json(
      {
        description: level[:description],
        recommended: [],
        item: {
          name: "frpt-bg-" + level[:name],
          version: 2,
          title: level[:title],
          subtitle: "#{level[:artists]} / #{level[:author]}",
          thumbnail: {
            type: :BackgroundThumbnail,
            url:
              "https://servers-legacy.purplepalette.net" + level[:cover][:url]
          },
          data: {
            type: :BackgroundData,
            url: "/repo/data.gz"
          },
          image: {
            type: :BackgroundImage,
            url: "/generate/#{level[:name]}_#{level[:cover][:hash]}-"
          },
          configuration: {
            type: :BackgroundConfiguration,
            url: "/repo/config.gz"
          }
        }
      }
    )
  end

  get "/levels/list" do
    ppdata =
      JSON.parse(
        HTTP
          .get(
            "https://servers-legacy.purplepalette.net/levels/list?" +
              URI.encode_www_form(
                { keywords: params[:keywords], page: params[:page].to_i }
              ).gsub("+", "%20")
          )
          .body
          .to_s
          .gsub('"/', '"https://servers-legacy.purplepalette.net/'),
        symbolize_names: true
      )
    if params[:keywords].nil? || params[:keywords].empty?
      if ppdata[:items].length.zero?
        levels =
          JSON.parse(
            HTTP
              .get(
                "https://raw.githubusercontent.com/PurplePalette/PurplePalette.github.io/0f37a15a672c95daae92f78953d59d05c3f01b5d/sonolus/levels/list"
              )
              .body
              .to_s
              .gsub('"/', '"https://PurplePalette.github.io/sonolus/'),
            symbolize_names: true
          )[
            :items
          ].map do |data|
            data[:data][:url] = "/local/#{data[:name]}/data.gz"
            data[:name] = "l_" + data[:name]

            data
          end
        ppdata[:items] = levels
      end
      ppdata[:pageCount] += 1
    end
    ppdata[:items].each { modify_level!(_1, false, :purplepalette) }
    ppdata[:search] = { options: SEARCH_OPTION }
    json ppdata
  end

  get %r{/(effects|particles|engines|skins)/list} do |type|
    json(
      {
        pageCount: 1,
        items:
          Dir
            .glob("./data/#{type}/*.json")
            .map { |f| load_datafile(f.sub("./data/", "").sub(".json", "")) }
      }
    )
  end

  get %r{/(effects|particles|engines|skins)/(.+)} do |type, name|
    data = load_datafile("#{type}/#{name}")
    json({ item: data, description: data[:description], recommended: [] })
  end
end
get "/tests/:test_id/sonolus/info" do |test_id|
  resp = {
    levels: {
      items:
        JSON.parse(
          File.read("./info_test.json").sub("{test_id}", test_id),
          symbolize_names: true
        ),
      search: {
        options: SEARCH_OPTION
      }
    },
    skins: {
      items: [],
      search: {
      }
    },
    engines: {
      items: [],
      search: {
      }
    },
    backgrounds: {
      items: [],
      search: {
      }
    },
    effects: {
      items: [],
      search: {
      }
    },
    particles: {
      items: [],
      search: {
      }
    }
  }
  if params["localization"] != "ja"
    l = resp[:levels][:items][0]
    l[:title] = "Welcome to FriedPotato!"
    l[
      :artists
    ] = "You're on test server [#{test_id}]. Tap [More] button below to browse levels..."
  end
  json resp
end

get %r{(?:/tests/[^/]+|/official)?/sonolus/levels/frpt-system} do
  item = JSON.load_file("./info_system.json", symbolize_names: true)
  if params["localization"] != "ja"
    item[:title] = "This level is not playable!"
    item[
      :artists
    ] = "This level is only used to show message. Please go back and do something else."
  end
  json({ item: item })
end

get %r{(?:/tests/[^/]+|/pjsekai|/official)?/generate/(.+)_(.+)} do |name, key|
  modifier = key.split("-")[1] || ""
  unless File.exist?("dist/bg/#{key}.png")
    case $config.background_engine
    when "dxruby"
      $current = name
      eval File.read("./bg_gen/main.rb") # rubocop:disable Security/Eval
    when "pillow"
      start_python unless python_started?
      HTTP.get(
        "http://localhost:#{$config.python_port}/generate/#{name}?extra=#{modifier.include?("e")}"
      )
    when "web"
      name += "_#{key}" if name == "l"
      HTTP
        .post(
          "https://image-gen.sevenc7c.com/generate/#{name}?extra=#{modifier.include?("e")}"
        )
        .then do |res|
          if res.status == 200
            File.write("dist/bg/#{key}.png", res.body, mode: "wb")
          elsif modifier.include?("e")
            redirect "/repo/background-base-extra.png"
          else
            redirect "/repo/background-base.png"
          end
        end
    when "none"
      if modifier.include?("e")
        redirect "/repo/background-base-extra.png"
      else
        redirect "/repo/background-base.png"
      end
    end
  end
  send_file "dist/bg/#{key}.png"
end

get "/tests/:test_id/sonolus/levels/list" do |test_id|
  ppdata =
    JSON.parse(
      HTTP
        .get(
          "https://servers-legacy.purplepalette.net/tests/#{test_id}/levels/list?" +
            URI.encode_www_form(
              { keywords: params[:keywords], page: params[:page].to_i }
            ).gsub("+", "%20")
        )
        .body
        .to_s
        .gsub('"/', '"https://servers-legacy.purplepalette.net/'),
      symbolize_names: true
    )
  ppdata[:items].each { modify_level!(_1, false, :purplepalette) }
  ppdata[:search] = { options: SEARCH_OPTION }
  json ppdata
end

get %r{(?:/tests/[^/]+)?/sonolus/levels/frpt-([^.]+)(?:\.(.+))?} do |name, suffix|
  level_raw =
    if name.start_with?("l_")
      HTTP
        .get(
          "https://PurplePalette.github.io/sonolus/levels/#{name[2..].gsub(" ", "%20")}"
        )
        .body
        .to_s
        .gsub('"/', '"https://PurplePalette.github.io/sonolus/')
    else
      HTTP
        .get("https://servers-legacy.purplepalette.net/levels/#{name}")
        .body
        .to_s
        .gsub('"/', '"https://servers-legacy.purplepalette.net/')
    end

  level_hash = JSON.parse(level_raw, symbolize_names: true)
  level = level_hash[:item]
  level_hash[:description] ||= ""
  extra = true if level_hash[:description].include?("#extra") ||
    suffix == "extra"
  modify_level!(level, extra, :purplepalette)
  level_hash[:recommended] = [
    {
      name: extra ? level[:name][..-7] : level[:name] + ".extra",
      version: 2,
      title: extra ? "ExtraモードOFF" : "ExtraモードON",
      subtitle: "-",
      cover: {
        type: :LevelCover,
        hash: get_file_hash("./public/repo/extra_#{extra ? "off" : "on"}.png"),
        url: "/repo/extra_#{extra ? "off" : "on"}.png"
      },
      data: {
        type: :LevelData,
        url: "/repo/data.gz"
      },
      engine: {
      }
    }
  ]
  if File.exist?("dist/bg/#{level[:name]}.png") && !$config.public
    level_hash[:recommended] << {
      name: level[:name] + ".delete-cache",
      version: 2,
      title: "背景キャッシュを削除",
      subtitle: "-",
      cover: {
        type: :LevelCover,
        hash: get_file_hash("./public/repo/delete.png"),
        url: "/repo/delete.png"
      },
      data: {
        type: :LevelData,
        url: "/repo/data.gz"
      },
      engine: {
      }
    }
  end
  json level_hash
end

namespace %r{/(?:official|pjsekai)} do
  namespace "/sonolus" do
    get "/info" do
      resp = {
        levels: {
          items:
            JSON.parse(
              File.read("./info_official.json"),
              symbolize_names: true
            ),
          search: {
            options: SEARCH_OPTION
          }
        },
        skins: {
          items: [],
          search: {
          }
        },
        engines: {
          items: [],
          search: {
          }
        },
        backgrounds: {
          items: [],
          search: {
          }
        },
        effects: {
          items: [],
          search: {
          }
        },
        particles: {
          items: [],
          search: {
          }
        }
      }
      if params["localization"] != "ja"
        l = resp[:levels][:items][0]
        l[:title] = "Welcome to FriedPotato!"
        l[
          :artists
        ] = "You're on Official Charts server (aka. /pjsekai). Tap [More] button below to browse levels..."
      end
      json resp
    end

    get "/levels/list" do
      levels =
        JSON
          .parse(
            HTTP.get(
              "https://sekai-world.github.io/sekai-master-db-diff/musics.json"
            ),
            symbolize_names: true
          )
          .filter { |l| l[:publishedAt] < Time.now.to_i * 1000 }
          .filter do |l|
            if params[:keywords]
              params[:keywords].split.all? do |k|
                l[:title].downcase.include?(k.downcase)
              end
            else
              true
            end
          end
          .sort_by { |l| -l[:publishedAt] }
      vocals =
        JSON.parse(
          HTTP.get(
            "https://sekai-world.github.io/sekai-master-db-diff/musicVocals.json"
          ),
          symbolize_names: true
        )
      json(
        {
          items:
            levels[20 * params[:page].to_i, 20]&.map do |level|
              level_vocals = vocals.filter { |v| v[:musicId] == level[:id] }
              preview_id = level_vocals.first[:assetbundleName]
              {
                name: "group-#{level[:id]}",
                version: 1,
                rating: level_vocals.length,
                title: level[:title],
                artists: format_artist(level, params[:localization]),
                cover: {
                  type: :LevelCover,
                  url:
                    "https://storage.sekai.best/sekai-assets/music/jacket/jacket_s_#{level[:id].zfill(3)}_rip/jacket_s_#{level[:id].zfill(3)}.png"
                },
                engine: {
                  name: "category",
                  title: "-"
                },
                preview: {
                  type: :LevelPreview,
                  url:
                    "https://storage.sekai.best/sekai-assets/music/short/#{preview_id}_rip/#{preview_id}_short.mp3"
                }
              }
            end || [],
          pageCount: (levels.length / 20.0).ceil,
          search: {
            options: SEARCH_OPTION
          }
        }
      )
    end

    get %r{/levels/frptp-level-([^.]+)(\.flick)?} do |name, flick|
      data =
        JSON.parse(
          HTTP
            .get(
              "https://servers.sonolus.com/pjsekai/sonolus/levels/pjsekai-#{name}"
            )
            .body
            .to_s
            .gsub('"/', '"https://servers.sonolus.com/pjsekai/'),
          symbolize_names: true
        )
      modify_level!(data[:item], !!flick, :official)
      level = data[:item]
      if flick
        level[:title] += " (Flick)"
        level[:name] += ".flick"
        level[:useBackground][:item][:image][:url] += "e"
        level[:useBackground][:item][:image][:hash] = (
          if File.exist?("./dist/bg/#{name}.flick.png")
            get_file_hash("./dist/bg/#{name}.flick.png")
          else
            ""
          end
        )
        level[:data][:url] = "/flick/#{name}"
        level[:data][:hash] = (
          if File.exist?("./dist/modify/#{level[:data][:hash]}-f.gz")
            get_file_hash("./dist/modify/#{level[:data][:hash]}-f.gz")
          else
            ""
          end
        )
      end
      data[:recommended] = [
        {
          name:
            (flick ? level[:name][..-7] : level[:name] + ".flick").sub(
              "pjsekai-",
              ""
            ),
          version: 2,
          title:
            (
              if params[:localization] == "ja"
                (flick ? "FlickモードOFF" : "FlickモードON")
              else
                (flick ? "Disable Flick" : "Enable Flick")
              end
            ),
          subtitle: "-",
          cover: {
            type: :LevelCover,
            hash:
              get_file_hash("./public/repo/flick_#{flick ? "off" : "on"}.png"),
            url: "/repo/flick_#{flick ? "off" : "on"}.png"
          },
          engine: {
          }
        }
      ]
      json data
    end
    get %r{/levels/group-([^.]+)} do |name|
      level =
        JSON
          .parse(
            HTTP.get(
              "https://sekai-world.github.io/sekai-master-db-diff/musics.json"
            ),
            symbolize_names: true
          )
          .find { |l| l[:id] == name.to_i }
      vocals =
        JSON
          .parse(
            HTTP.get(
              "https://sekai-world.github.io/sekai-master-db-diff/musicVocals.json"
            ),
            symbolize_names: true
          )
          .filter { |v| v[:musicId] == name.to_i }
      difficulties =
        JSON
          .parse(
            HTTP.get(
              "https://sekai-world.github.io/sekai-master-db-diff/musicDifficulties.json"
            ),
            symbolize_names: true
          )
          .filter { |d| d[:musicId] == name.to_i }
      preview_id = vocals.first[:assetbundleName]
      engine = load_engine

      levels =
        vocals
          .map do |vocal|
            difficulties.reverse.map do |difficulty|
              {
                name:
                  "frptp-level-#{level[:id]}-#{vocal[:id]}-#{difficulty[:musicDifficulty]}",
                version: 1,
                rating: difficulty[:playLevel],
                engine: engine,
                useSkin: {
                  useDefault: true
                },
                useBackground: {
                  useDefault: true
                },
                useEffect: {
                  useDefault: true
                },
                useParticle: {
                  useDefault: true
                },
                title:
                  "#{difficulty[:musicDifficulty].capitalize} - #{vocal[:caption]}",
                artists:
                  vocal[:characters]
                    .map do |c|
                      if c[:characterType] == "game_character"
                        OFFICIAL_CHARACTERS[c[:characterId]]
                      else
                        OUTSIDE_CHARACTERS[c[:characterId]]
                      end
                    end
                    .map do |c|
                      c[:name] || "#{c[:firstName]} #{c[:givenName]}".strip
                    end
                    .join(" & ")
                    .then { |s| s.empty? ? "-" : s },
                author: "",
                cover: {
                  type: :LevelCover,
                  url:
                    "https://storage.sekai.best/sekai-assets/music/jacket/jacket_s_#{level[:id].zfill(3)}_rip/jacket_s_#{level[:id].zfill(3)}.png"
                },
                bgm: {
                  type: :LevelBgm,
                  url:
                    "https://storage.sekai.best/sekai-assets/music/long/#{preview_id}_rip/#{preview_id}.mp3"
                },
                preview: {
                  type: :LevelPreview,
                  url:
                    "https://storage.sekai.best/sekai-assets/music/short/#{preview_id}_rip/#{preview_id}_short.mp3"
                },
                data: {
                  type: :LevelData,
                  url:
                    "/levels/#{level[:id]}.#{vocal[:id]}.#{difficulty[:musicDifficulty]}/data?0.1.0-beta.11"
                }
              }.tap { |l| modify_level!(l, false, :official) }
            end
          end
          .flatten
      json(
        {
          item: {
            name: "group-#{level[:id]}",
            version: 1,
            rating: vocals.length,
            title: level[:title],
            artists: format_artist(level, params[:localization]),
            author: "-",
            cover: {
              type: :LevelCover,
              hash: get_file_hash("./public/repo/folder.png"),
              url: "/repo/folder.png"
            },
            engine: {
              name: "category",
              title: "-"
            },
            preview: {
              type: :LevelPreview,
              url:
                "https://storage.sekai.best/sekai-assets/music/short/#{preview_id}_rip/#{preview_id}_short.mp3"
            }
          },
          description: (params[:localization] == "ja" ? (<<~DESC) : (<<~DESC)),
          作詞：#{level[:lyricist]}
          作曲：#{level[:composer]}
          編曲：#{level[:arranger]}

          追加日時：#{Time.at(level[:publishedAt] / 1000, in: "+09:00").strftime("%Y/%m/%d %H:%M:%S")}
        DESC
          Lyrics: #{level[:lyricist]}
          Music: #{level[:composer]}
          Arrangement: #{level[:arranger]}

          Published at: #{Time.at(level[:publishedAt] / 1000, in: "+00:00").strftime("%m/%d/%Y %H:%M:%S")} (UTC)
        DESC
          recommended: levels
        }
      )
    end
  end

  get "/flick/:name" do |name|
    if File.exist?("./dist/modify/#{name}-f.gz")
      next send_file("./dist/modify/#{name}-f.gz")
    end
    raw =
      HTTP.get(
        "https://servers.sonolus.com/pjsekai/sonolus/levels/pjsekai-#{name}/data"
      ).body
    gzreader = Zlib::GzipReader.new(StringIO.new(raw.to_s))
    level_data = JSON.parse(gzreader.read, symbolize_names: true)
    level_data[:entities].each do |entity|
      next if entity[:archetype] < 3
      val = entity[:data][:values]
      val[0] -= 9
      val[3] -= 9 if [9, 16].include?(entity[:archetype])

      if [3, 7, 10, 14].include? entity[:archetype]
        entity[:archetype] += 1
        entity[:data][:values][3] = -1
      end
    end
    Zlib::GzipWriter.open("./dist/modify/#{name}-f.gz") do |gz|
      gz.write(JSON.dump(level_data))
    end
    send_file("./dist/modify/#{name}-f.gz")
  end

  get %r{/bgm/(.+)} do |name|
    if File.exist?("./dist/bgm/#{name}.mp3")
      next send_file("./dist/bgm/#{name}.mp3")
    end
    Open3.capture2e(
      "ffmpeg",
      "-i",
      "https://storage.sekai.best/sekai-assets/music/long/#{name}_rip/#{name}.mp3",
      "-ss",
      "9",
      "./dist/bgm/#{name}.mp3"
    )
    send_file("./dist/bgm/#{name}.mp3")
  end

  get %r{/generate/(.+?)(\.flick)?} do |name, flick|
    unless File.exist?("dist/bg/#{name}#{flick}.png")
      case $config.background_engine
      when "dxruby"
        eval File.read("./bg_gen/main.rb") # rubocop:disable Security/Eval
      when "pillow"
        start_python unless python_started?
        res =
          HTTP.get(
            "http://localhost:#{$config.python_port}/generate/official-#{name}.png"
          )
        File.write("dist/bg/#{name}.png", res.body, mode: "wb")
      when "web"
        res =
          HTTP.post(
            "https://image-gen.sevenc7c.com/generate/official-#{name}.png?extra=#{!!flick}"
          )
        if res.status == 200
          File.write("dist/bg/#{name}#{flick}.png", res.body, mode: "wb")
        else
          redirect "/repo/background-base.png"
        end
      when "none"
        redirect "/repo/background-base.png"
      end
    end
    send_file("./dist/bg/#{name}#{flick}.png")
  end

  get %r{/shift/frptp-level-(.+?)} do |name|
    if File.exist?("./dist/modify/#{name}.gz")
      next send_file("./dist/modify/#{name}.gz")
    end
    raw =
      HTTP.get(
        "https://servers.sonolus.com/pjsekai/sonolus/levels/pjsekai-#{name}/data"
      ).body
    gzreader = Zlib::GzipReader.new(StringIO.new(raw.to_s))
    level_data = JSON.parse(gzreader.read, symbolize_names: true)
    level_data[:entities].each do |entity|
      next if entity[:archetype] < 3
      val = entity[:data][:values]
      val[0] -= 9
      val[3] -= 9 if [9, 16].include?(entity[:archetype])
    end
    Zlib::GzipWriter.open("./dist/modify/#{name}.gz") do |gz|
      gz.write(JSON.dump(level_data))
    end
    send_file("./dist/modify/#{name}.gz")
  end

  get %r{/(.*)} do |path|
    redirect "/#{path}"
  end
end

get "/effects/pjsekai.fixed" do
  json(
    {
      description: "",
      item: {
        author: "Sonolus",
        data: {
          hash: get_file_hash("./public/repo/seconfig.gz"),
          type: "EffectData",
          url: "/repo/seconfig.gz"
        },
        name: "pjsekai.fixed",
        subtitle: "Project Sekai: Colorful Stage!",
        thumbnail: {
          hash: "e5f439916eac9bbd316276e20aed999993653560",
          type: "EffectThumbnail",
          url:
            "https://servers-legacy.purplepalette.net/repository/EffectThumbnail/e5f439916eac9bbd316276e20aed999993653560"
        },
        title: "Project Sekai",
        version: 2
      },
      recommended: []
    }
  )
end

get %r{(?:/tests/.+)?/convert/(.+)} do |name|
  if File.exist?("./dist/conv/#{name}.gz")
    next send_file "./dist/conv/#{name}.gz"
  end
  raw =
    if name.start_with?("l_")
      HTTP.get(
        "https://PurplePalette.github.io/sonolus/repository/levels/#{name[2..]}/level"
      )
    else
      HTTP.get(
        "https://servers-legacy.purplepalette.net/repository/#{name}/data.gz"
      ).body
    end
  gzreader = Zlib::GzipReader.new(StringIO.new(raw))
  json = gzreader.read
  gzreader.close
  s = JSON.parse(json, symbolize_names: true)
  base = { entities: [{ archetype: 0 }, { archetype: 1 }, { archetype: 2 }] }
  slide_positions = {}
  last_entities = []
  s[:entities][2..]
    .each
    .with_index(2) do |e, i|
      val = e[:data][:values]
      case e[:archetype]
      when 2
        width = (val[2] + 1) / 2.0
        base[:entities] << {
          archetype: 3,
          data: {
            index: 0,
            values: [val[0], val[1] + width, width, 0]
          }
        }
      when 4
        width = (val[3] + 1) / 2.0
        base[:entities] << {
          archetype: 4,
          data: {
            index: 0,
            values: [val[1], val[2] + width, width, -1]
          }
        }
      when 3
        width = (val[2] + 1) / 2.0
        slide_positions[i] = val
        base[:entities] << {
          archetype: 5,
          data: {
            index: 0,
            values: [val[0], val[1] + width, width, 0]
          }
        }
      when 5
        slide_positions[i] = val
        width = (val[3] + 1) / 2.0
        base[:entities] << {
          archetype: 6,
          data: {
            index: 0,
            values: [val[1], val[2] + width, width]
          }
        }
      when 6, 7
        slide_positions[i] = val
        width = (val[3] + 1) / 2.0
        before = [val[1], val[2] + width, width]
        cursor = val[0]
        while data = slide_positions[cursor]
          break if data.length == 3
          cursor = data[0]
        end
        first_index = cursor
        cursor = val[0]
        while data = slide_positions[cursor]
          data = [nil] + data if data.length == 3
          width = (data[3] + 1) / 2.0
          position = [data[1], data[2] + width, width]
          last_entities << {
            archetype: 9,
            data: {
              index: 0,
              values: [position, before, -1, first_index + 1].flatten
            }
          }
          before = position
          cursor = data[0]
        end
        width = (val[3] + 1) / 2.0
        base[:entities] << {
          archetype: e[:archetype] + 1,
          data: {
            index: 0,
            values: [val[1], val[2] + width, width, -1]
          }
        }
      end
    end
  base[:entities] += last_entities
  Zlib::GzipWriter.wrap(File.open("./dist/conv/#{name}.gz", "wb")) do |gz|
    gz.write(base.to_json)
  end
  send_file "./dist/conv/#{name}.gz"
end

get "overrides/:path" do |path|
  send_file "./overrides/#{path}"
end

namespace %r{(?:/tests/([^/]+))?} do
  get %r{/data-overrides/(.+)} do |_name, path|
    send_file "./dist/data-overrides/#{path}"
  end

  get %r{/skin/texture} do |_name|
    send_file "./skin/texture.png"
  end

  get %r{/skin/data} do |_name|
    hash = get_file_hash("./skin/data.json")
    unless File.exist?("./dist/skin/#{hash}.gz")
      Zlib::GzipWriter.open("./dist/skin/#{hash}.gz") do |gz|
        gz.write(File.read("./skin/data.json", mode: "rb"))
      end
    end
    send_file "./dist/skin/#{hash}.gz"
  end

  get %r{/engine/data} do |_name|
    send_file $config.engine_path + "/dist/EngineData"
  end

  get %r{/engine/configuration} do |_name|
    send_file $config.engine_path + "/dist/EngineConfiguration"
  end
end

get %r{(?:/tests/([^/]+))?/modify/(.+)-(.+)} do |_name, level, hash|
  cfg = [["t", $config.trace_enabled]].filter { |x| x[1] }.map { |x| x[0] }.join
  key = "#{hash}-#{cfg}"
  if File.exist?("./dist/modify/#{key}.gz")
    next send_file "./dist/modify/#{key}.gz"
  end
  level_data = nil
  entities = nil
  loop do
    raw =
      HTTP.get(
        "https://servers.purplepalette.net/repository/#{level}/data.gz"
      ).body
    gzreader = Zlib::GzipReader.new(StringIO.new(raw.to_s))
    level_data = JSON.parse(gzreader.read, symbolize_names: true)
    entities = level_data[:entities]
    break if entities[3][:data][:values][0]
  end
  will_delete = []

  if $config.trace_enabled
    entities
      .filter { |e| e[:archetype] == 9 }
      .each do |e|
        unless (e[:data][:values][3] - e[:data][:values][0] - 0.0625 < 0.01) &&
                 (e[:data][:values][1..2] == e[:data][:values][4..5])
          next
        end
        not_found = false
        entities
          .find do |e2|
            e2[:archetype] == 5 and
              e2[:data][:values] == e[:data][:values][0..2]
          end
          .tap do |e3|
            index = entities.find_index(e3)
            end_note =
              entities.find do |e2|
                [7, 8].include?(e2[:archetype]) and
                  e[:data][:values][4] == index
              end
            next not_found = true unless end_note
            if end_note[:archetype] == 7
              e3[:archetype] = 18
            else
              e3[:archetype] = 19
              e3[:data][:values][3] = end_note[:data][:values][3]
            end
            will_delete << end_note
          end

        will_delete << e unless not_found
      end
    wd_index = will_delete.filter_map { |e| entities.find_index(e) }
    will_delete.each { |e| entities.delete(e) }
    entities
      .filter { |e| [7, 9].include?(e[:archetype]) }
      .each do |e|
        e[:data][:values][-1] -= wd_index
          .filter { |i| i < e[:data][:values][-1] }
          .length
      end
  end
  Zlib::GzipWriter.wrap(File.open("./dist/modify/#{key}.gz", "wb")) do |gz|
    gz.write(level_data.to_json)
  end
  send_file "./dist/modify/#{key}.gz"
end

get %r{/(?:tests/(?:[^/]+)|official)/(.+)} do |path|
  redirect "/#{path}", 301
end

unless $config.public
  ip = Socket.ip_address_list.find(&:ipv4_private?).ip_address
  puts <<~MESSAGE.strip
         \e[91m+---------------------------------------------+\e[m
         \e[91m|            FriedPotatoへようこそ！          |\e[m
         \e[91m+---------------------------------------------+\e[m

         Sonolusを開き、サーバーのURLに以下を入力して下さい：
           \e[97mhttp://#{ip}:#{$config.port}\e[m
         テストサーバーの場合は以下のURLを入力して下さい：
           \e[97mhttp://#{ip}:#{$config.port}/tests/\e[m<テストサーバーID>


         \e[97mCtrl+C\e[m を押すと終了します。

         Created by \e[96m名無し｡(@sevenc-nanashi)\e[m
       MESSAGE
  puts
end
