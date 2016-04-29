path = require 'path'
fs = require 'fs'
_ = require 'lodash'
async = require 'async'
config = require './config.coffee'

regex_map = {}
for k, v of config
  for ext in v.type
    ext = ext.substring(2)
    if regex_map[ext]
      regex_map[ext] = _.uniq(v.regex, regex_map[ext])
    else
      regex_map[ext] = v.regex

directoryTree = (base_path, callback) ->
  item = {path: base_path}

  fs.stat base_path, (err, stats) ->
    return callback null if err

    if stats.isFile()
      ext = path.extname(base_path).toLowerCase().substring(1)
      if ext not in _.keys(regex_map)
        return callback null
      item.ext = ext
      item.mtime = stats.mtime.getTime()
      item.definition = []
      fs.readFile base_path, encoding: 'utf8', (err, data) ->
        return callback null if err
        async.map regex_map[item.ext], (regex_str, callback) ->
          regex_str = regex_str.replace(/{word}/g, '([a-zA-Z0-9_]+)')
          regex = new RegExp(regex_str, 'ig')
          results = data.match(regex)
          if results
            async.map results, (result, callback) ->
              regex = new RegExp(regex_str, 'i')
              result = regex.exec(result)
              callback null, result[1]
            , (err, definition) ->
              callback err, definition
          else
            callback null, []
        , (err, definition) ->
          item.definition = _.uniq(_.flattenDeep(definition))
          callback null, item
    else
      fs.readdir base_path, (err, children) ->
        return callback null if err
        async.map children, (child, callback) =>
          directoryTree path.join(base_path, child), callback
        , (err, children) ->
          return callback null if err
          item.children = _.compact(children)
          if item.children.length
            callback null, item
          else
            callback null

console.time('search')
directoryTree '/', (err, files) ->
  console.log err if err
  console.timeEnd('search')
  fs.writeFile('./data.json', JSON.stringify(files, null, 2) , 'utf-8');
