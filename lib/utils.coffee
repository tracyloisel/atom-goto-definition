_ = require 'lodash'

class Utils
  constructor: (@config) ->
    @regex_map = @getRegexMap(@config)
    @language_exts = Object.keys(@regex_map)

  getRegexMap: (config) ->
    regex_map = {}
    for k, v of config
      for ext in v.type
        ext = ext.substring(2)
        if regex_map[ext]
          regex_map[ext] = _.uniq(v.regex, regex_map[ext])
        else
          regex_map[ext] = v.regex
    return regex_map

module.exports = Utils
