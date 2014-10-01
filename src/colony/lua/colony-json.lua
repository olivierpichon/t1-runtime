local rapidjson = require('rapidjson')
local js_tostring = colony.js_tostring

function is_arr (arr)
  return global.Array:isArray(arr)
end

-- Callback when a default value is parsed in json
function json_read_default(json_state)
  local lua_table = json_state.stack[#json_state.stack]
  if is_arr(lua_table) then
    lua_table[lua_table.length] = ''
  else
    lua_table[json_state.prev_k] = ''
    json_state.on_key = true
  end
end

-- Callback when a null value is parsed in json
function json_read_null(json_state)
  local lua_table = json_state.stack[#json_state.stack]
  if is_arr(lua_table) then
    lua_table[lua_table.length] = js_null
  else
    lua_table[json_state.prev_k] = js_null
    json_state.on_key = true
  end
end

-- Callback when a boolean is parsed in json
function json_read_value(json_state, value)
  json_read_double(json_state, value)
end

-- Callback when a double is parsed in json
function json_read_double(json_state, value)
  local lua_table = json_state.stack[#json_state.stack]
  if is_arr(lua_table) then
    lua_table[lua_table.length] = value
  else
    lua_table[json_state.prev_k] = value
    json_state.on_key = true
  end
end

-- Callback when a string is parsed in json
function json_read_string(json_state, value)
  local lua_table = json_state.stack[#json_state.stack]
  if is_arr(lua_table) then
    lua_table[lua_table.length] = value
  elseif json_state.on_key then
    lua_table[value] = value
    json_state.prev_k = value
    json_state.on_key = false
  else
    lua_table[json_state.prev_k] = value
    json_state.on_key = true
  end
end

-- Callback when the start of an object is parsed in json
function json_read_start_object(json_state)
  local lua_table = json_state.stack[#json_state.stack]
  if lua_table == nil then
    lua_table = js_obj({})
    table.insert(json_state.stack, lua_table)
  else
    local new_table = js_obj({})
    if is_arr(lua_table) then
      lua_table[lua_table.length] = new_table
    else
      lua_table[json_state.prev_k] = new_table
    end
    table.insert(json_state.stack, new_table)
  end
  json_state.on_key = true
end

-- Callback when the end of an object is parsed in json
function json_read_end_object(json_state, value)
  json_state.ret = table.remove(json_state.stack, #json_state.stack)
  -- if parent_table ~= nil then
  --     json_state.lua_table = parent_table
  -- end
  json_state.on_key = true
end

-- Callback when the start of an array is parsed in json
function json_read_start_array(json_state)
  local lua_table = json_state.stack[#json_state.stack]
  if lua_table == nil then
    lua_table = js_arr({},0)
    table.insert(json_state.stack, lua_table)
  else
    local new_arr = js_arr({},0)
    if is_arr(lua_table) then
      lua_table[lua_table.length] = new_arr
    else
      lua_table[json_state.prev_k] = new_arr
    end
    table.insert(json_state.stack, new_arr)
  end
end

-- Callback when the end of an array is parsed in json
function json_read_end_array(json_state, value)
  json_state.ret = table.remove(json_state.stack, #json_state.stack)
  -- if parent_table ~= nil then
  --   json_state.lua_table = parent_table
  -- end
end

-- Parses the string into a lua table
function json_parse(value)

  -- rapidjson will throw an error if non-objects are passed in
  -- this circumvents those errors
  if value == 'true' or value == 'false' or tonumber(value) then
    return value
  end

  -- clear the globals for the next round
  local json_state = {
    stack = {},
    ret = nil,
    on_key = true,
    prev_k = nil
  }

  -- parse the value and set the lua table based off callbacks
  rapidjson.parse(json_state, value)

  -- reference it from here so we can clear the globals for another round
  local lua_table_cpy = json_state.ret

  -- return the parsed object to lua
  return lua_table_cpy

end

-- Checks initial type and recurses through object if it needs to
function json_stringify (value, ...)

  local val_copy = {}     -- copies of hits in the replacer array
  local call_ext = false  -- whether to call an external replacer function
  local replacer = nil    -- replacer function/array if provided
  local spacer = nil      -- spacer to insert if provided

  -- A guard to allow calls to json_stringify(value) with no replacer/spacer
  if arg[1] then
    replacer = arg[1]['replacer']
    spacer = arg[1]['indent']
  end

  if not spacer then
    spacer = ''
  elseif type(spacer) == 'number' then
    spacer = string.rep(' ', spacer)
  else
    spacer = tostring(spacer)
  end
  spacer = string.sub(spacer, 1, 10)

  -- does what stringify does but can be called recursively
  function json_recurse (handler, value)

    if type(value) == 'nil' then
      rapidjson.to_null(handler,value)
    elseif type(value) == 'boolean' then
      rapidjson.to_boolean(handler,value)
    elseif type(value) == 'number' then
      rapidjson.to_number(handler,value)
    elseif type(value) == 'string' then
      rapidjson.to_string(handler,value)
    elseif type(value) == 'table' then
      if global.Array:isArray(value) or (getmetatable(value) and getmetatable(value).buffer) then
        rapidjson.array_start(handler)
        for i=0,value.length-1 do
          if call_ext then replacer(value,i,value[i]) end
          local vt = type(value[i])
          if vt == 'function' or vt == 'userdata' or vt == 'thread' then
            rapidjson.to_null(handler,value)
          else json_recurse(handler,value[i]) end
        end
        rapidjson.array_end(handler)
      else
        local val_copy = {}
        if replacer then
          if type(replacer) == 'function' then
          elseif type(replacer) == 'table' then
            if global.Array:isArray(value) then
            elseif type(value) == 'table' then
              if next(value) then
                for i=0,#replacer do
                  local k = tostring(replacer[i])
                  if value[k] then
                    val_copy[k] = value[k]
                  end
                end
                value = val_copy
              end
            end
          end
        end
        rapidjson.object_start(handler)
        for k, v in pairs(value) do
          local vt = type(v)
          if vt == 'function' or vt == 'userdata' or vt == 'thread' then
          else
            local rep = value
            if call_ext then rep = replacer(value,k,v) end
            if rep then
              if type(k) ~= 'table' then
                json_recurse(handler,tostring(k))
              else
                json_recurse(handler,k)
              end
              json_recurse(handler,v)
            end
          end
        end
        rapidjson.object_end(handler)
      end
    else
      rapidjson.object_start(handler)
      rapidjson.object_end(handler)
    end
  end

  -- if the optional replacer is provided
  if replacer then
    if type(replacer) == 'function' then
      call_ext = true
    elseif type(replacer) == 'table' then
      call_ext = false
      if global.Array:isArray(value) then
      elseif type(value) == 'table' then
        if next(value) then
          for i=0,#replacer do
            local k = tostring(replacer[i])
            if value[k] then
              val_copy[k] = value[k]
            end
          end
          value = val_copy
        end
      end
    end
  end

  local wh = rapidjson.create_writer(spacer)
  local status, err = pcall(json_recurse,wh,value)
  if not status then
    rapidjson.destroy(wh)
    error(err)
  end
  local str = rapidjson.result(wh)
  rapidjson.destroy(wh)
  str = string.gsub(str,'%[null%]','%[%]') -- array workaround
  return tostring(str)

end

-- called by lua_rapidjson.c when a parsing error occurs
function json_error(val,code,offset)

  -- error message starting string
  -- TODO: replicate node messages more closely
  error_msg = {
    'end of input',
    'token ',
    'token ',
    'token ',
    'token ',
    'token ',
    'token ',
    'token ',
    'end of input ',
    'token ',
    'token after ',
    'token ',
    'token ',
    'token ',
    'token ',
    'token ',
  }

  -- format the offset of the value that's failing
  local token = ''
  if val[offset] then
    token = val[offset]
  elseif val[#val-1] then
    token = val[#val-1]
  end

  -- throw a new error
  error(js_new(global.SyntaxError,'Unexpected '..error_msg[code]..token))

end

return {
  parse = json_parse,
  stringify = json_stringify
}
