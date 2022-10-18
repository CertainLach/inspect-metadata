local
  metadata = import '../metadata.json',
  base = importstr './base.ts',
  types = metadata.types.types
;

local
  typeNames = (import '../typeNames.jsonnet')(types=types, mangleSchema='js'),
  humanTypeNames = (import '../typeNames.jsonnet')(types=types),
  noopTypes = (import '../noopTypes.jsonnet')(types=types)
;

local
  genCodeForFields(fields) =
    if std.length(fields) == 1 then typeNames.get(fields[0].type)
    else if std.all(std.map(function(f) std.objectHas(f, 'name'), fields)) then '{\n%s\n}' % std.join('\n', std.map(
      function(field)
        '\t%s: %s,' % [field.name, typeNames.get(field.type)]
      , fields
    ))
    else '[%s]' % std.join(', ', std.map(function(f) typeNames.get(f.type), fields)),
  genWriteCodeForFields(fields) =
    if std.length(fields) == 1 then '\twrite_%s(out, fields);' % typeNames.get(fields[0].type)
    else if std.all(std.map(function(f) std.objectHas(f, 'name'), fields)) then std.join('\n', std.map(
      function(field)
        '\twrite_%s(out, fields.%s)' % [typeNames.get(field.type), field.name]
      , fields
    ))
    else std.join('\n', std.mapWithIndex(function(i, f) '\twrite_%s(out, fields[%d])' % [typeNames.get(f.type), i], fields)),
  genCodeForType(type) =
    assert !noopTypes.isNoop(type.id);
    |||
      /**
       * Type #%d: %s
       */
    ||| % [type.id, humanTypeNames.get(type.id)] +
    ('type %s = ' % typeNames.get(type.id)) +
    (
      if std.objectHas(type.type.def, 'primitive') then 'Primitive_%s' % type.type.def.primitive
      else if std.objectHas(type.type.def, 'sequence') then '%s[]' % typeNames.get(type.type.def.sequence.type)
      else if std.objectHas(type.type.def, 'variant') && std.objectHas(type.type.def.variant, 'variants') then (
        '\n' + std.join(' |\n', std.map(
          function(variant)
            if std.objectHas(variant, 'fields') then '{ %s: %s }' % [variant.name, genCodeForFields(variant.fields)]
            else '"%s"' % variant.name
          , type.type.def.variant.variants
        ))
      )
      else if std.objectHas(type.type.def, 'variant') then 'never'
      else if std.objectHas(type.type.def, 'array') then 'FixedSizeArray<%s, %d>' % [typeNames.get(type.type.def.array.type), type.type.def.array.len]
      else if std.objectHas(type.type.def, 'tuple') then '[%s]' % std.join(', ', std.map(typeNames.get, type.type.def.tuple))
      else if std.objectHas(type.type.def, 'composite') && std.objectHas(type.type.def.composite, 'fields') then genCodeForFields(type.type.def.composite.fields)
      else if std.objectHas(type.type.def, 'composite') then '{}'
      else if std.objectHas(type.type.def, 'compact') then typeNames.get(type.type.def.compact.type)
      else 'error: ' + std.manifestJsonEx(type.type, '  ')
    ) + ';\n' +
    ('const write_%s = (out: Buf, value: %s) => ' % [typeNames.get(type.id), typeNames.get(type.id)]) +
    (
      if std.objectHas(type.type.def, 'primitive') then 'writePrimitive_%s(out, value)' % type.type.def.primitive
      else if std.objectHas(type.type.def, 'sequence') then '{\n\twriteCompactPrimitive_u32(out, value.length);\n\tfor(const item of value) write_%s(out, item)\n}' % typeNames.get(type.type.def.sequence.type)
      else if std.objectHas(type.type.def, 'variant') && std.objectHas(type.type.def.variant, 'variants') then (
        '{\n' + std.join('else ', std.map(
          function(variant)
            if std.objectHas(variant, 'fields') then 'if(typeof value === "object" && "%s" in value) {\n\twritePrimitive_u8(out, %d);\n\tconst fields = value.%s;\n%s\n} ' % [variant.name, variant.index, variant.name, genWriteCodeForFields(variant.fields)]
            else 'if(value === "%s") writePrimitive_u8(out, %d);\n' % [variant.name, variant.index]
          , type.type.def.variant.variants
        ))
        + 'else throw new Error("unreachable")\n}'
      )
      else if std.objectHas(type.type.def, 'variant') then '{ throw new Error("unreachable"); }'
      else if std.objectHas(type.type.def, 'array') then '{ for(let i = 0; i < %d; i++) write_%s(out, value[i]); }' % [type.type.def.array.len, typeNames.get(type.type.def.array.type)]
      else if std.objectHas(type.type.def, 'tuple') then '{\n%s\n}' % std.join('\n', std.mapWithIndex(function(i, id) '\twrite_%s(out, value[%d]);' % [typeNames.get(id), i], type.type.def.tuple))
      else if std.objectHas(type.type.def, 'composite') && std.objectHas(type.type.def.composite, 'fields') then '{\n\tconst fields = value;\n%s\n}' % genWriteCodeForFields(type.type.def.composite.fields)
      else if std.objectHas(type.type.def, 'composite') then '{}'
      else if std.objectHas(type.type.def, 'compact') then 'writeCompact_%s(out, value)' % typeNames.get(type.type.def.compact.type)
      else 'error: ' + std.manifestJsonEx(type.type, '  ')
    ) + ';' +
    if std.objectHas(type.type.def, 'primitive') && (
      type.type.def.primitive == 'u32' ||
      type.type.def.primitive == 'u64' ||
      type.type.def.primitive == 'u128'
    ) then '\nconst writeCompact_%s = (out: Buf, value: %s) => writeCompactPrimitive_%s(out, value);' % [typeNames.get(type.id), typeNames.get(type.id), type.type.def.primitive] else '' + if std.objectHas(type.type.def, 'tuple') && std.length(type.type.def.tuple) == 0 then '\nconst writeCompact_%s = write_%s' % [typeNames.get(type.id), typeNames.get(type.id)] else ''
;

base +
std.join('\n\n', std.map(genCodeForType, std.filter(function(ty) !noopTypes.isNoop(ty.id), types))) +

local callId = std.filter(function(type) std.get(type.type, 'path', []) == ['quartz_runtime', 'Call'], types)[0].id;
|||

  /**
   * Convinient aliases
   */
  export type Call = %s;
  export const writeCall = write_%s;
||| % [typeNames.get(callId), typeNames.get(callId)]
