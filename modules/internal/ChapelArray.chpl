var privatizeLock$: sync int;

pragma "privatized class"
def _isPrivatized(value) param
  return !_local & ((_privatization & value.supportsPrivatization()) | value.requiresPrivatization());

def _newPrivatizedClass(value) {
  privatizeLock$.writeEF(true);
  var n = __primitive("chpl_numPrivatizedClasses");
  var hereID = here.id;
  coforall r in Realms do
    on r {
      coforall loc in r.Locales {
        on loc {
          if hereID != here.id {
            var mine = value.privatize();
            __primitive("chpl_newPrivatizedClass", mine);
            mine.pid = n;
          } else {
            __primitive("chpl_newPrivatizedClass", value);
            value.pid = n;
          }
        }
      }
    }
  privatizeLock$.readFE();
  return n;
}

def _newArray(value) {
  if _isPrivatized(value) then
    return new _array(_newPrivatizedClass(value), value);
  else
    return new _array(value, value);
}

def _newDomain(value) {
  if _isPrivatized(value) then
    return new _domain(_newPrivatizedClass(value), value);
  else
    return new _domain(value, value);
}

def _getDomain(value) {
  if _isPrivatized(value) then
    return new _domain(value.pid, value);
  else
    return new _domain(value, value);
}

def _newDistribution(value) {
  if _isPrivatized(value) then
    return new _distribution(_newPrivatizedClass(value), value);
  else
    return new _distribution(value, value);
}

def _getDistribution(value) {
  if value.type == defaultDist._value.type then
    return defaultDist;
  else if _isPrivatized(value) then
    return new _distribution(value.pid, value);
  else
    return new _distribution(value, value);
}


//
// Support for domain types
//
pragma "has runtime type"
def chpl__buildDomainRuntimeType(dist: _distribution, param rank: int, type idxType = int(32),
                                 param stridable: bool = false) type
  return _newDomain(dist.newArithmeticDom(rank, idxType, stridable));

pragma "has runtime type"
def chpl__buildDomainRuntimeType(dist: _distribution, type idxType) type
 where !__primitive("isEnumType", idxType) && idxType != opaque && idxType != _OpaqueIndex
  return _newDomain(dist.newAssociativeDom(idxType));

pragma "has runtime type"
def chpl__buildDomainRuntimeType(dist: _distribution, type idxType) type
 where __primitive("isEnumType", idxType)
  return _newDomain(dist.newEnumDom(idxType));

pragma "has runtime type"
def chpl__buildDomainRuntimeType(dist: _distribution, type idxType) type
 where idxType == _OpaqueIndex
  return _newDomain(dist.newOpaqueDom(idxType));

// This function has no 'has runtime type' pragma since the idxType of
// opaque domains is _OpaqueIndex, not opaque.  This function is
// essentially a wrapper around the function that actually builds up
// the runtime type.
def chpl__buildDomainRuntimeType(dist: _distribution, type idxType) type
 where idxType == opaque
  return chpl__buildDomainRuntimeType(dist, _OpaqueIndex);

pragma "has runtime type"
def chpl__buildSparseDomainRuntimeType(dist: _distribution, dom: domain) type
  return _newDomain(dist.newSparseDom(dom.rank, dom._value.idxType, dom));

def chpl__convertValueToRuntimeType(dom: domain) type
 where dom._value:BaseArithmeticDom
  return chpl__buildDomainRuntimeType(dom.dist, dom._value.rank,
                            dom._value.idxType, dom._value.stridable);

def chpl__convertValueToRuntimeType(dom: domain) type
 where dom._value:BaseSparseDom
  return chpl__buildSparseDomainRuntimeType(dom.dist, dom._value.parentDom);

def chpl__convertValueToRuntimeType(dom: domain) type
where !dom._value:BaseArithmeticDom && !dom._value:BaseSparseDom
  return chpl__buildDomainRuntimeType(dom.dist, dom._value.idxType);

//
// Support for array types
//
pragma "has runtime type"
def chpl__buildArrayRuntimeType(dom: domain, type eltType) type
  return dom.buildArray(eltType);

def chpl__convertValueToRuntimeType(arr: []) type
  return chpl__buildArrayRuntimeType(arr.domain, arr.eltType);

//
// Support for subdomain types
//
// Note the domain of a subdomain is not yet part of the runtime type
//
def chpl__buildSubDomainType(dom: domain) type
  return chpl__convertValueToRuntimeType(dom);

//
// Support for domain expressions, e.g., [1..3, 1..3]
//
def chpl__buildDomainExpr(x: domain)
  return x;

def chpl__buildDomainExpr(ranges: range(?) ...?rank) {
  for param i in 2..rank {
    if ranges(1).eltType != ranges(i).eltType then
      compilerError("domain has mixed dimensional type");
    if ranges(i).boundedType != BoundedRangeType.bounded then
      compilerError("domain has dimension of unbounded range");
  }
  var d: domain(rank, ranges(1).eltType, chpl__anyStridable(ranges));
  d.setIndices(ranges);
  return d;
}

//
// Support for index types
//
def chpl__buildIndexType(param rank: int, type idxType) type where rank == 1 {
  var x: idxType;
  return x;
}

def chpl__buildIndexType(param rank: int, type idxType) type where rank > 1 {
  var x: rank*idxType;
  return x;
}

def chpl__buildIndexType(param rank: int) type
  return chpl__buildIndexType(rank, int);

def chpl__buildIndexType(d: domain) type
  return chpl__buildIndexType(d.rank, d._value.idxType);

def chpl__buildIndexType(type idxType) type where idxType == opaque
  return _OpaqueIndex;

def isArithmeticDom(d: domain) param {
  def isArithmeticDomClass(dc: BaseArithmeticDom) param return true;
  def isArithmeticDomClass(dc) param return false;
  return isArithmeticDomClass(d._value);
}

def isAssociativeDom(d: domain) param {
  def isAssociativeDomClass(dc: BaseAssociativeDom) param return true;
  def isAssociativeDomClass(dc) param return false;
  return isAssociativeDomClass(d._value);
}

def isEnumDom(d: domain) param {
  def isEnumDomClass(dc: BaseEnumDom) param return true;
  def isEnumDomClass(dc) param return false;
  return isEnumDomClass(d._value);
}

def isOpaqueDom(d: domain) param {
  def isOpaqueDomClass(dc: BaseOpaqueDom) param return true;
  def isOpaqueDomClass(dc) param return false;
  return isOpaqueDomClass(d._value);
}

def isSparseDom(d: domain) param {
  def isSparseDomClass(dc: BaseSparseDom) param return true;
  def isSparseDomClass(dc) param return false;
  return isSparseDomClass(d._value);
}

//
// Support for distributions
//
def distributionType(type dist) type where dist: BaseDist {
  var d: _distribution(dist, dist);
  return d.type;
}

def distributionType(type dist) where !(dist: BaseDist) {
  compilerError("illegal distribution type specifier");
}

def distributionValue(dist) where dist: BaseDist {
  return _newDistribution(dist);
}

def distributionValue(dist) where !(dist: BaseDist) {
  compilerError("illegal distribution value specifier");
}

//
// Distribution wrapper record
//
pragma "distribution"
record _distribution {
  var _value;
  var _valueType;

  pragma "inline"
  def _value {
    if _isPrivatized(_valueType) {
      var tc = _valueType;
      var id = _value;
      var pc = __primitive("chpl_getPrivatizedClass", tc, id);
      return pc;
    } else {
      return _value;
    }
  }

  def ~_distribution() {
    if !_isPrivatized(_valueType) {
      on _value {
        var cnt = _value.destroyDist();
        if cnt == 0 {
          _value.destroyDistributionDescriptor();
          delete _value;
        }
      }
    }
  }

  def clone() {
    return _newDistribution(_value.clone());
  }

  def newArithmeticDom(param rank: int, type idxType, param stridable: bool) {
    var x = _value.newArithmeticDom(rank, idxType, stridable);
    if x.linksDistribution() {
      var cnt = _value._distCnt$;
      _value._doms.append(x);
      _value._distCnt$ = cnt + 1;
    }
    return x;
  }

  def newAssociativeDom(type idxType) {
    var x = _value.newAssociativeDom(idxType);
    if x.linksDistribution() {
      var cnt = _value._distCnt$;
      _value._doms.append(x);
      _value._distCnt$ = cnt + 1;
    }
    return x;
  }

  def newEnumDom(type idxType) {
    var x = _value.newEnumDom(idxType);
    if x.linksDistribution() {
      var cnt = _value._distCnt$;
      _value._doms.append(x);
      _value._distCnt$ = cnt + 1;
    }
    return x;
  }

  def newOpaqueDom(type idxType) {
    var x = _value.newOpaqueDom(idxType);
    if x.linksDistribution() {
      var cnt = _value._distCnt$;
      _value._doms.append(x);
      _value._distCnt$ = cnt + 1;
    }
    return x;
  }

  def newSparseDom(param rank: int, type idxType, dom: domain) {
    var x = _value.newSparseDom(rank, idxType, dom);
    if x.linksDistribution() {
      var cnt = _value._distCnt$;
      _value._doms.append(x);
      _value._distCnt$ = cnt + 1;
    }
    return x;
  }

  def ind2loc(ind) return _value.ind2loc(ind);

  def writeThis(x: Writer) {
    _value.writeThis(x);
  }
}


//
// Domain wrapper record
//
pragma "domain"
pragma "has runtime type"
record _domain {
  var _value;     // stores domain class, may be privatized
  var _valueType; // stores type of privatized domains
  var _promotionType: index(rank, _value.idxType);

  pragma "inline"
  def _value {
    if _isPrivatized(_valueType) {
      var tc = _valueType;
      var id = _value;
      var pc = __primitive("chpl_getPrivatizedClass", tc, id);
      return pc;
    } else {
      return _value;
    }
  }

  def ~_domain () {
    if !_isPrivatized(_valueType) {
      on _value {
        var cnt = _value.destroyDom();
        if cnt == 0 then
          delete _value;
      }
    }
  }

  def dist return _getDistribution(_value.dist);

  def rank param {
    if isArithmeticDom(this) || isSparseDom(this) then
      return _value.rank;
    else
      return 1;
  }

  pragma "inline"
  def these() {
    return _value.these();
  }

  def this(ranges: range(?) ...rank) {
    var d = _value.slice(chpl__anyStridable(ranges), ranges);
    if (d.linksDistribution()) then
      d.dist._distCnt$ += 1;
    return _newDomain(d);
  }

  def this(args ...rank) where _validRankChangeArgs(args, _value.idxType) {
    var ranges = _getRankChangeRanges(args);
    param rank = ranges.size, stridable = chpl__anyStridable(ranges);
    var d = _value.rankChange(rank, stridable, args);
    if (d.linksDistribution()) then
      d.dist._distCnt$ += 1;
    return _newDomain(d);
  }

  def dim(d : int) return _value.dim(d);

  def dimIter(param d, ind) {
    for i in _value.dimIter(d, ind) do yield i;
  }

  def buildArray(type eltType) {
    var x = _value.buildArray(eltType);
    pragma "dont disable remote value forwarding"
    def help() {
      var cnt = _value._domCnt$; // lock
      _value._arrs.append(x);
      _value._domCnt$ = cnt + 1; // unlock
    }
    help();
    return _newArray(x);
  }

  def clear() {
    _value.clear();
  }

  def create() {
    if _value.idxType != _OpaqueIndex then
      compilerError("domain.create() only applies to opaque domains");
    return _value.create();
  }

  def add(i) {
    _value.add(i);
  }

  def remove(i) {
    _value.remove(i);
  }

  def numIndices return _value.numIndices;
  def low return _value.low;
  def high return _value.high;

  def member(i) return _value.member(i);
  def order(i) return _value.order(i);
  def position(i) return _value.position(i);

  def expand(i: _value.idxType ...rank) return expand(i);
  def expand(i: rank*_value.idxType) return _newDomain(_value.expand(i));
  def expand(i: _value.idxType) where rank > 1 return _newDomain(_value.expand(i));

  def exterior(i: _value.idxType ...rank) return exterior(i);
  def exterior(i: rank*_value.idxType) return _newDomain(_value.exterior(i));

  def interior(i: _value.idxType ...rank) return interior(i);
  def interior(i: rank*_value.idxType) return _newDomain(_value.interior(i));

  def translate(i: _value.idxType ...rank) return translate(i);
  def translate(i: rank*_value.idxType) return _newDomain(_value.translate(i));

  def chpl__unTranslate(i: _value.idxType ...rank) return chpl__unTranslate(i);
  def chpl__unTranslate(i: rank*_value.idxType) return _newDomain(_value.chpl__unTranslate(i));

  def setIndices(x) {
    _value.setIndices(x);
    if _isPrivatized(_valueType) {
      var other = _value;
      var id = _value.pid;
      var hereID = here.id;
      coforall r in Realms do
        on r {
          coforall loc in r.Locales {
            on loc {
              if hereID != here.id {
                var tc = _valueType;
                var pc = __primitive("chpl_getPrivatizedClass", tc, id);
                pc.reprivatize(other);
              }
            }
          }
        }
    }
  }

  def getIndices()
    return _value.getIndices();

  def writeThis(f: Writer) {
    f.write(_value);
  }

  // associative array interface

  def sorted() {
    for i in _value.sorted() {
      yield i;
    }
  }
}

def +(d: domain, i: index(d)) {
  return d.translate(i);
}

def +(i, d: domain) where i: index(d) {
  return d.translate(i);
}

def -(d: domain, i: index(d)) {
  return d.chpl__unTranslate(i);
}


//
// Array wrapper record
//
pragma "array"
pragma "has runtime type"
record _array {
  var _value;     // stores array class, may be privatized
  var _valueType; // stores type of privatized arrays
  var _promotionType: _value.eltType;

  def makeAlias(A: []) {
    if _value._arrAlias {
      on _value._arrAlias {
        var cnt = _value._arrAlias.destroyArr();
        if cnt == 0 then
          delete _value._arrAlias;
      }
    }
    _value.makeAlias(A._value);
    _value._arrAlias = A._value;
    _value._arrAlias._arrCnt$ += 1;
  }

  pragma "inline"
  def _value {
    if _isPrivatized(_valueType) {
      var tc = _valueType;
      var id = _value;
      var pc = __primitive("chpl_getPrivatizedClass", tc, id);
      return pc;
    } else {
      return _value;
    }
  }

  def ~_array() {
    if !_isPrivatized(_valueType) {
      on _value {
        var cnt = _value.destroyArr();
        if cnt == 0 then
          delete _value;
      }
    }
  }

  def eltType type return _value.eltType;
  def _dom return _getDomain(_value.dom);
  def rank param return this.domain.rank;

  pragma "inline"
  def this(i: rank*_value.idxType) var where rank > 1
    return _value(i);

  pragma "inline"
  def this(i: _value.idxType ...rank) var where rank > 1
    return _value(i);

  pragma "inline"
  def this(i: _value.idxType) var where rank == 1
    return _value(i);

  //
  // requires dense domain implementation that returns a tuple of
  // ranges via the getIndices() method; domain indexing is difficult
  // in the domain case because it has to be implemented on a
  // domain-by-domain basis; this is not terribly difficult in the
  // dense case because we can represent a domain by a tuple of
  // ranges, but in the sparse case, is there a general
  // representation?
  //
  def this(d: domain) var where d.rank == rank
    return this((...d.getIndices()));

  def this(ranges: range(?) ...rank) var {
    if boundsChecking then
      _value.checkSlice(ranges);
    var d = _dom((...ranges));
    d._value._domCnt$ += 1;
    var a = _value.slice(d._value);
    a._arrAlias = _value;
    a._arrAlias._arrCnt$ += 1;
    return _newArray(a);
  }

  def this(args ...rank) var where _validRankChangeArgs(args, _value.idxType) {
    if boundsChecking then
      _value.checkRankChange(args);
    var ranges = _getRankChangeRanges(args);
    param rank = ranges.size, stridable = chpl__anyStridable(ranges);
    var d = _value.dom.rankChange(rank, stridable, args);
    d._domCnt$ += 1;
    var a = _value.rankChange(d, rank, stridable, args);
    a._arrAlias = _value;
    a._arrAlias._arrCnt$ += 1;
    return _newArray(a);
  }

  pragma "inline"
  def these() var {
    return _value.these();
  }

  def numElements return _dom.numIndices; // assume dom name

  def newAlias() {
    var x = _value.reindex(_value.dom);
    _value.dom._domCnt$ += 1;
    x._arrAlias = _value;
    x._arrAlias._arrCnt$ += 1;
    return _newArray(x);
  }

  def reindex(d: domain) where rank == 1 {
    var x = _value.reindex(d._value);
    d._value._domCnt$ += 1;
    x._arrAlias = _value;
    x._arrAlias._arrCnt$ += 1;
    return _newArray(x);
  }

  def reindex(d: domain) where rank != 1 {
    var x = _value.reindex(d._value);
    d._value._domCnt$ += 1;
    x._arrAlias = _value;
    x._arrAlias._arrCnt$ += 1;
    return _newArray(x);
  }

  def writeThis(f: Writer) {
    f.write(_value);
  }

  // sparse array interface

  def IRV var {
    return _value.IRV;
  }

  // associative array interface

  def sorted() {
    for i in _value.sorted() {
      yield i;
    }
  }
}

//
// Helper functions
//

// computes || reduction over stridable of ranges
def chpl__anyStridable(ranges, param d: int = 1) param {
  for param i in 1..ranges.size do
    if ranges(i).stridable then
      return true;
  return false;
}

// given a tuple args, returns true if the tuple contains only
// integers and ranges; that is, it is a valid argument list for rank
// change
def _validRankChangeArgs(args, type idxType) param {
  def _validRankChangeArg(type idxType, r: range(?)) param return true;
  def _validRankChangeArg(type idxType, i: idxType) param return true;
  def _validRankChangeArg(type idxType, x) param return false;

  def help(param dim: int) param {
    if !_validRankChangeArg(idxType, args(dim)) then
      return false;
    else if dim < args.size then
      return help(dim+1);
    else
      return true;
  }

  return help(1);
}

def _getRankChangeRanges(args) {
  def isRange(r: range(?)) param return 1;
  def isRange(r) param return 0;
  def _tupleize(x) {
    var y: 1*x.type;
    y(1) = x;
    return y;
  }
  def collectRanges(param dim: int) {
    if dim > args.size then
      compilerError("domain slice requires a range in at least one dimension");
    if isRange(args(dim)) then
      return collectRanges(dim+1, _tupleize(args(dim)));
    else
      return collectRanges(dim+1);
  }
  def collectRanges(param dim: int, x: _tuple) {
    if dim > args.size {
      return x;
    } else if dim < args.size {
      if isRange(args(dim)) then
        return collectRanges(dim+1, ((...x), args(dim)));
      else
        return collectRanges(dim+1, x);
    } else {
      if isRange(args(dim)) then
        return ((...x), args(dim));
      else
        return x;
    }
  }
  return collectRanges(1);
}

//
// Support for += and -= over domains
//
def chpl__isDomain(x: domain) param return true;
def chpl__isDomain(x) param return false;

//
// Assignment of domains and arrays
//
def =(a: _distribution, b: _distribution) {
  if a._value == nil then
    return chpl__autoCopy(b.clone());
  else
    halt("distribution assignment is not yet supported");
  return a;
}

def =(a: domain, b: domain) {
  var bc = b;
  for e in a._value._arrs do {
    on e do e.reallocate(bc);
  }
  a.setIndices(bc.getIndices());
  return a;
}

def =(a: domain, b: _tuple) {
  for ind in 1..b.size {
    a.add(b(ind));
  }
  return a;
}

def =(d: domain, r: range(?)) {
  d = [r];
  return d;
}

def =(a: domain, b) {  // b is iteratable
  a._value.clearForIteratableAssign();
  for ind in b {
    a.add(ind);
  }
  return a;
}

pragma "inline" def =(a: [], b : []) where (a._value.canCopyFromHost && b._value.canCopyFromHost) {
	compilerError("GPU to GPU transfers not yet implemented");
}

pragma "inline" def =(a: [], b : []) where (a._value.canCopyFromDevice && b._value.canCopyFromHost) {
	__primitive("copy_gpu_to_host", 
			a._value.data, b._value.data, b._value.eltType, b._value.size);
	return a;
}

pragma "inline" def =(a: [], b : []) where (a._value.canCopyFromHost && b._value.canCopyFromDevice) {
	__primitive("copy_host_to_gpu", 
			a._value.data, b._value.data, b._value.eltType, b._value.size);
	return a;
}

pragma "inline" def =(a: [], b: []) where (a._value.canCopyFromDevice && b._value.canCopyFromDevice) {
  if b._value != nil then
    for (aa,bb) in (a,b) do
      aa = bb;
  return a;
}

pragma "inline" def =(a: [], b) {
  for (aa,bb) in (a,b) do
    aa = bb;
  return a;
}

def =(a: [], b: _tuple) {
  a._value.tupleInit(b);
  return a;
}

def _desync(type t) where t: _syncvar || t: _singlevar {
  var x: t;
  return x.value;
}

def _desync(type t) where !(t: _syncvar|| t: _singlevar) {
  var x: t;
  return x;
}

def =(a: [], b: _desync(a.eltType)) {
  for i in a._dom do
    a(i) = b;
  return a;
}

def by(a: domain, b) {
  var x = a._value.strideBy(b);
  if (x.linksDistribution()) then
    x.dist._distCnt$ += 1;
  return _newDomain(x);
}

//
// index for all opaque domains
//
class _OpaqueIndex { }

//
// Swap operators for arrays and domains
//
pragma "inline" def _chpl_swap(x: [], y: []) {
  for (i,j) in (x.domain, y.domain) do
    x(i) <=> y(j);
}

pragma "inline" def _chpl_swap(x: domain, y: domain) {
  const t = y;
  y = x;
  x = t;
}

//
// reshape function
//
def reshape(A: [], D: domain) {
  var B: [D] A.eltType;
  for (i,a) in (D,A) do
    B(i) = a;
  return B;
}

def linearize(Xs) {
  for x in Xs do yield x;
}

def _callSupportsAlignedFollower(A) param where A: BaseArr
  return A.supportsAlignedFollower();

def _callSupportsAlignedFollower(A) param where !(A: BaseArr)
  return false;

def _callSupportsAlignedFollower() param
  return false;

//
// module support for iterators
//
enum iterator {leader, follower};

def iteratorIndex(ic: _iteratorClass) {
  ic.advance();
  return ic.getValue();
}

pragma "expand tuples with values"
def iteratorIndex(t: _tuple) {
  pragma "expand tuples with values"
  def iteratorIndexHelp(t: _tuple, param dim: int) {
    if dim == t.size then
      return _build_tuple_always_allow_ref(iteratorIndex(t(dim)));
    else
      return _build_tuple_always_allow_ref(iteratorIndex(t(dim)),
                                           (...iteratorIndexHelp(t, dim+1)));
  }

  return iteratorIndexHelp(t, 1);
}

def iteratorIndexType(x) type {
  pragma "no copy" var ic = _getIterator(x);
  pragma "no copy" var i = iteratorIndex(ic);
  _freeIterator(ic);
  return i.type;
}

def _iteratorRecord.writeThis(f: Writer) {
  var first: bool = true;
  for e in this {
    if !first then
      f.write(" ");
    else
      first = false;
    f.write(e);
  }
}

def =(ic: _iteratorRecord, xs) {
  for (e, x) in (ic, xs) do
    e = x;
  return ic;
}

def =(ic: _iteratorRecord, x: iteratorIndexType(ic)) {
  for e in ic do
    e = x;
  return ic;
}

pragma "inline" def _getIterator(x) {
  return _getIterator(x.these());
}

pragma "inline" def _getIterator(ic: _iteratorClass)
  return ic;

pragma "inline" def _getIterator(x: _tuple) {
  pragma "inline" def _getIteratorHelp(x: _tuple, param dim: int) {
    if dim == x.size then
      return tuple(_getIterator(x(dim)));
    else
      return (_getIterator(x(dim)), (..._getIteratorHelp(x, dim+1)));
  }
  if x.size == 1 then
    return _getIterator(x(1));
  else
    return _getIteratorHelp(x, 1);
}

def _getIterator(type t) {
  compilerError("cannot iterate over a type");
}

def _checkIterator(type t) {
  compilerError("cannot iterate over a type");
}

pragma "inline" def _checkIterator(x) {
  return x;
}

pragma "inline"
def _freeIterator(ic: _iteratorClass) {
  __primitive("chpl_free", ic);
}

pragma "inline"
def _freeIterator(x: _tuple) {
  for param i in 1..x.size do
    _freeIterator(x(i));
}

pragma "inline"
pragma "no implicit copy"
def _toLeader(iterator: _iteratorClass)
  return chpl__autoCopy(__primitive("to leader", iterator));

pragma "inline"
def _toLeader(ir: _iteratorRecord) {
  pragma "no copy" var ic = _getIterator(ir);
  pragma "no copy" var leader = _toLeader(ic);
  _freeIterator(ic);
  return leader;
}

pragma "inline"
def _toLeader(x: _tuple)
  return _toLeader(x(1));

pragma "inline"
def _toLeader(x)
  return _toLeader(x.these());

pragma "inline"
pragma "no implicit copy"
def _toFollower(iterator: _iteratorClass, leaderIndex)
  return chpl__autoCopy(__primitive("to follower", iterator, leaderIndex));

pragma "inline"
def _toFollower(ir: _iteratorRecord, leaderIndex) {
  pragma "no copy" var ic = _getIterator(ir);
  pragma "no copy" var follower = _toFollower(ic, leaderIndex);
  _freeIterator(ic);
  return follower;
}



//
// If aligned is passed as an argument (true from alignment version of
// _toFollower on tuple) then grab the aligned version of the array's
// iterator if the array supports aligned followers
//
pragma "inline"
pragma "no implicit copy"
def _toFollower(iterator: _iteratorClass, leaderIndex, param aligned: bool) {
  return chpl__autoCopy(__primitive("to follower", iterator, leaderIndex, aligned));
}

pragma "inline"
def _toFollower(ir: _iteratorRecord, leaderIndex, param aligned: bool) {
  pragma "no copy" var ic = _getIterator(ir);
  pragma "no copy" var follower = _toFollower(ic, leaderIndex, aligned);
  _freeIterator(ic);
  return follower;
}


pragma "inline"
def _toFollower(x, leaderIndex) {
  return _toFollower(x.these(), leaderIndex);
}

pragma "inline"
def _toFollower(x, leaderIndex, param aligned: bool) {
  return _toFollower(x.these(), leaderIndex, aligned);
}

pragma "inline"
def _toFollowerHelp(x: _tuple, leaderIndex, param dim: int) {
  if dim == x.size-1 then
    return (_toFollower(x(dim), leaderIndex),
            _toFollower(x(dim+1), leaderIndex));
  else
    return (_toFollower(x(dim), leaderIndex),
            (..._toFollowerHelp(x, leaderIndex, dim+1)));
}

pragma "inline"
def _toFollower(x: _tuple, leaderIndex) {
  return _toFollowerHelp(x, leaderIndex, 1);
}

//
// The alignment version uses a compiler analysis to pass a tuple of
// types according to whether the arrays in the tuple x have the same
// distribution as the leader or not.  If they do, the component type
// is passed as BaseDist, otherwise as BaseArr.
//
pragma "inline" def _toFollowerHelp(x: _tuple, leaderIndex, type alignment, param dim: int) {
  if dim == x.size-1 {
    type tdim = alignment(dim);
    type tdimp1 = alignment(dim+1);
    if tdim == BaseDist & tdimp1 == BaseDist {
      return (_toFollower(x(dim), leaderIndex, true),
              _toFollower(x(dim+1), leaderIndex, true));
    } else if tdim == BaseDist {
      return (_toFollower(x(dim), leaderIndex, true),
              _toFollower(x(dim+1), leaderIndex));
    } else if tdimp1 == BaseDist {
      return (_toFollower(x(dim), leaderIndex),
              _toFollower(x(dim+1), leaderIndex, true));
    } else {
      return (_toFollower(x(dim), leaderIndex),
              _toFollower(x(dim+1), leaderIndex));
    }
  } else {
    type tdim = alignment(dim);
    if tdim == BaseDist {
      return (_toFollower(x(dim), leaderIndex, true),
              (..._toFollowerHelp(x, leaderIndex, alignment, dim+1)));
    } else {
      return (_toFollower(x(dim), leaderIndex),
              (..._toFollowerHelp(x, leaderIndex, alignment, dim+1)));
    }
  }
}

pragma "inline"
def _toFollower(x: _tuple, leaderIndex, type alignment) {
  return _toFollowerHelp(x, leaderIndex, alignment, 1);
}

