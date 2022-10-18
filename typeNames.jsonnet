function(types=(import './metadata.json').types.types, mangleSchema='human')

  local noopTypes = (import './noopTypes.jsonnet')(types=types);

  local
    mangleHuman = {
      pathSep: '::',
      paramsStart: '<',
      paramsSep: ', ',
      paramsEnd: '>',
      tupleStart: '(',
      tupleEnd: ')',

      vec(ty): '%s[]' % ty,
      array(ty, len): '%s[%d]' % [ty, len],
      compact(ty): 'Compact<%s>' % ty,
    },
    mangleJs = {
      pathSep: '__',
      paramsStart: 'Of$',
      paramsSep: '$$',
      paramsEnd: '$Fo',
      tupleStart: 'Tuple' + self.paramsStart,
      tupleEnd: self.paramsEnd,

      vec(ty): 'Vec_$%s' % ty,
      array(ty, len): 'Array%d_$%s' % [len, ty],
      compact(ty): 'Compact_$%s' % [ty],
    },
    mangle = if mangleSchema == 'js' then mangleJs else if mangleSchema == 'human' then mangleHuman else error 'unknown schema: %s' % mangleSchema
  ;

  local
    formatPath(type) =
      local justPath = if 'path' in type then std.join('::', type.path);
      local justParams = if 'params' in type then '<' + std.join(', ', [
        '%%%s%%' % [noopTypes.map(param.type)]
        for param in type.params
        if param.type != null
      ]) + '>' else '';
      if justPath != null then justPath + (if justParams != '<>' then justParams else ''),
    alternatePath(name) =
      local nameParams = std.splitLimit(name, '<', 1),
            justName = nameParams[0],
            params = if std.length(nameParams) != 1 then '<' + nameParams[1],
            segments = std.split(justName, '::');

      std.flatMap(std.id, [
        local path = std.join('::', segments[i:]);
        std.prune([path, if params != null then path + params])
        for i in std.reverse(std.range(0, std.length(segments) - 1))
      ]);


  local candidates = {
    ['Lookup%d' % type.id]:
      local pathNameInit = formatPath(type.type),
            pathName = if pathNameInit != null then std.strReplace(std.strReplace(pathNameInit, '::pallet::', '::'), '::storage::bounded_vec::', '::');
      std.prune((if pathName != null then alternatePath(pathName) else []) + [
        if 'primitive' in type.type.def then type.type.def.primitive,
        if 'sequence' in type.type.def then mangle.vec('%%%s%%' % noopTypes.map(type.type.def.sequence.type)),
        if 'array' in type.type.def then mangle.array('%%%s%%' % noopTypes.map(type.type.def.array.type), type.type.def.array.len),
        if 'tuple' in type.type.def then '(%s)' % std.join(', ', std.map(function(t) '%%%s%%' % noopTypes.map(t), type.type.def.tuple)),
        if 'compact' in type.type.def then mangle.compact('%%%s%%' % noopTypes.map(type.type.def.compact.type)),

        // Fallback naming, if every other name is conflicting
        if 'tuple' in type.type.def then 'Lookup%d(%s)' % [type.id, std.join(', ', std.map(function(t) '%%%s%%' % noopTypes.map(t), type.type.def.tuple))],
        if pathName != null then 'Lookup%d::%s' % [type.id, pathName],
        'Lookup%d' % type.id,
      ])
    for type in types
    if !noopTypes.isNoop(type.id)
  };

  local
    defAmounts = std.foldl(function(a, b) a + { [k]+: 1 for k in b }, std.objectValues(candidates), {}),
    ambigous = std.set([name for name in std.objectFields(defAmounts) if defAmounts[name] > 1]),
    warning = 'Ambigous names: ' + std.join(', ', ambigous);

  local chosenNames = {
    [id]: local names = std.filter(function(name) !std.setMember(name, ambigous), candidates[id]);
         assert std.length(names) >= 1 : 'no possible name in ' + candidates[id];
         names[0]
    for id in std.objectFields(candidates)
  };

  local replaceInName(name) =
    local idxs = std.findSubstr('%', name);
    if std.length(idxs) > 0 then
      replaceInName(
        local pat = name[idxs[0] + 1:idxs[1]];
        name[:idxs[0]] + chosenNames[pat] + name[idxs[1] + 1:]
      )
    else name;

  local finalNames = {
    [id]: std.foldl(function(str, rep) std.strReplace(str, rep[0], rep[1]), [
      ['::', mangle.pathSep],
      ['<', mangle.paramsStart],
      ['>', mangle.paramsEnd],
      [', ', mangle.paramsSep],
      ['(', mangle.tupleStart],
      [')', mangle.tupleEnd],
    ], replaceInName(chosenNames[id]))
    for id in std.objectFields(chosenNames)
  };

  std.trace(warning, {
    get(id): $.lookup('Lookup%d' % id),
    lookup(name): finalNames[noopTypes.mapLookup(name)],
  })
