path = require 'path'
fs = require 'fs'
_ = require 'lodash'
async = require 'async'

class DefinitionMap
  constructor: (@base_path, {@regex_map, @language_exts}) ->
    @file_map = {}
    @definition_map = {}

  build: (base_path, callback) ->
    if _.isFunction base_path
      callback = base_path
      base_path = @base_path

    @buildFileMap base_path, @file_map, =>
      @file_map_build_time = new Date()
      @buildDefinition @file_map, =>
        @definition_build_time = new Date()
        callback(@file_map)

  buildFileMap: (base_path, file_map, callback) ->
    fs.stat base_path, (err, stats) =>
      return callback() if err

      if stats.isFile()
        ext = path.extname(base_path).toLowerCase().substring(1)
        if ext not in @language_exts
          return callback()
        file_map[base_path] =
          ext: ext
          mtime: stats.mtime.getTime()
        callback()
      else
        fs.readdir base_path, (err, children) =>
          return callback() if err
          async.map children, (child, callback) =>
            @buildFileMap path.join(base_path, child), file_map, callback
          , callback

  buildDefinition: (file_map, callback) ->
    async.map Object.keys(file_map), (file_path, callback) =>
      fs.readFile file_path, encoding: 'utf8', (err, data) =>
        return callback() if err
        item = file_map[file_path]
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
          file_map[file_path] = item
          callback()
    , (err) =>
      @buildDefinitionMap()
      callback()

  buildDefinitionMap: ->
    for file_path, {definitions} of @file_map
      for definition in definitions
        if @definition_map[definition]
          @definition_map[definition] = _.uniq(@definition_map[definition], file_path)
        else
          @definition_map[definition] = [file_path]

module.exports = DefinitionMap
