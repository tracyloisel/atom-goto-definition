path = require 'path'
fs = require 'fs'
_ = require 'lodash'
async = require 'async'

class DefinitionsMap
  constructor: (@base_path, {@regex_map, @language_exts}) ->
    @files_map = {}
    @definitions_map = {}

  build: (base_path, callback) ->
    if _.isFunction base_path
      callback = base_path
      base_path = @base_path

    @buildFileMap base_path, @files_map, =>
      @files_map_build_time = new Date()
      @buildDefinition @files_map, =>
        @definitions_build_time = new Date()
        callback(@files_map)

  buildFileMap: (base_path, files_map, callback) ->
    fs.stat base_path, (err, stats) =>
      return callback() if err

      if stats.isFile()
        ext = path.extname(base_path).toLowerCase().substring(1)
        if ext not in @language_exts
          return callback()
        files_map[base_path] =
          ext: ext
          mtime: stats.mtime.getTime()
        callback()
      else
        fs.readdir base_path, (err, children) =>
          return callback() if err
          async.map children, (child, callback) =>
            @buildFileMap path.join(base_path, child), files_map, callback
          , callback

  buildDefinition: (files_map, callback) ->
    async.map Object.keys(files_map), (file_path, callback) =>
      fs.readFile file_path, encoding: 'utf8', (err, data) =>
        return callback() if err
        item = files_map[file_path]
        async.map @regex_map[item.ext], (regex_str, callback) ->
          regex_str = regex_str.replace(/{word}/g, '([a-zA-Z0-9_]+)')
          regex = new RegExp(regex_str, 'ig')
          results = data.match(regex)
          if results
            async.map results, (result, callback) ->
              regex = new RegExp(regex_str, 'i')
              result = regex.exec(result)
              callback null, result[1]
            , (err, definitions) ->
              callback err, definitions
          else
            callback null, []
        , (err, definitions) ->
          item.definitions = _.uniq(_.flattenDeep(definitions))
          files_map[file_path] = item
          callback()
    , (err) =>
      @buildDefinitionMap()
      callback()

  buildDefinitionMap: ->
    for file_path, {definitions} of @files_map
      for definition in definitions
        if @definitions_map[definition]
          @definitions_map[definition] = _.uniq(@definitions_map[definition], file_path)
        else
          @definitions_map[definition] = [file_path]

module.exports = DefinitionsMap
