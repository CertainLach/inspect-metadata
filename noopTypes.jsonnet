function(types=(import './metadata.json').types.types)
  local this =
    local
      boundedVecs = std.filter(function(type) std.get(type.type, 'path', []) == ['frame_support', 'storage', 'bounded_vec', 'BoundedVec'], types),
      wrappedVec(ty) = ty.type.def.composite.fields[0].type,
      boundedVecIds = std.set(std.map(function(ty) ty.id, boundedVecs)),
      realIds = std.set(std.map(wrappedVec, boundedVecs)),
      boundedMap = {
        ['Lookup%d' % type.id]: 'Lookup%d' % wrappedVec(type)
        for type in boundedVecs
      },
      excludedVecs = 'Excluded BoundedVec wrappers: ' + std.join(', ', std.map(std.toString, boundedVecIds))
    ;

    // TODO:
    // Deduplicate tuples, i.e
    // Type1 = [u8, u8]
    // Type2 = [u8, u8]
    // Type2 should be marked as noop, and forwarded to Type1

    // local
    //   tuples = std.filter(function(type) 'tuple' in type.type.def, types),
    //   tupleDefs = std.foldl(function(map, type) map {
    //     [std.toString(std.map(this.map, type.type.def.tuple))]+: [type.id],
    //   }, tuples, {}),
    //   canonicalTuple(id) = local key = std.toString(std.map(this.map, type.type.def.tuple));
    //   canonicalTuples = {
    //     ['Lookup%d' % tupId]: tupleDefs[def][0]
    //     for def in std.objectFields(tupleDefs)
    //     for tupId in tupleDefs[def][1:]
    //   },
    //   deduplicatedTuples = 'Deduplicated tuples: '
    // ;

    {
      isNoop(id): std.setMember(id, boundedVecIds),
      mapLookup(lookup):
        if lookup in boundedMap then boundedMap[lookup]
        // else if lookup in canonicalTuples then canonicalTuples[lookup]
        else lookup,
      map(id): self.mapLookup('Lookup%d' % id),
    }
  ;
  this
