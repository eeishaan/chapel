module declareGlobals {
  config var ENABLE_K2 = true;
  config var ENABLE_K3 = true;
  config var ENABLE_K4 = true;
  config var DECOR_VERTICES = true;
  config var ENABLE_PAUSE = false;
  config var ENABLE_PLOTS = false;
  config var ENABLE_VERIF = true;
  config var ENABLE_MDUMP = false;
  config var ENABLE_DEBUG = false;
  config var FIGNUM = 0 ;
  config var ENABLE_PLOT_ROSE  = false;
  config var ENABLE_PLOT_COLOR = false;
  config var ENABLE_PLOT_K3    = false;
  config var ENABLE_PLOT_K3DB  = false;

  union Weight {
    var i : integer;
    var s : string;
/* TMP
    function is_string {
      typeselect (this) {
        when s     return true;
        otherwise  return false;
      }
    }
*/
  }

  record Numbers {
    var totVertices : integer; 
    var maxParallelEdge : integer;
    var numIntEdges : integer; 
    var numStrEdges : integer;
    var maxIntWeight : integer;
  }

  record EndPoints { 
    var start : integer;
    var end : integer;
  }

  class Edges { 
    with Numbers;
    var Cliques : domain(1);
    var cliqueSizes : [Cliques] integer; 
/* TMP
    var VsInClique : [Cliques] (first:integer, last:integer);
*/
    var numEdgesPlaced  : integer;
    var Edges : domain(1); -- 1..numEdgesPlaced
/* TMP
    var edges : [Edges] record { 
                          with EndPoints;
                          var weight :Weight;
                        };
*/
    var numEdgesPlacedInCliques : integer;
    var numEdgesPlacedOutside   : integer;
  }

  class Graph {
    with Numbers; 
    var VertexD  : domain(1);  -- 1..totVertices
    var ParEdgeD : domain(1) ; -- 1..maxParallelEdge

    -- separate integer and string subgraps that
    -- share the above two domains
/* TMP
    var intg = Subgraph(wtype=integer,
                        VertexD=>VertexD,
                        ParEdgeD=>ParEdgeD);
    var strg = Subgraph(wtype=string,
                        VertexD=>VertexD,
                        ParEdgeD=>ParEdgeD);
*/

    function copy(s : Graph) {
      return Graph(VerteD  =s.VertexD,
                   ParEdgeD=s.ParEdgeD);
    }
  }

  class Subgraph {
    type wtype;
    var VertexD : domain(1);
    var ParEdgeD : domain(1); 
    -- sparse matrix index by directed vertex pairs
/* TMP
    var AdjD  : domain sparse (VertexD * VertexD) = nil;
*/
    -- holds count of edges between vertex pairs
    var weights : [AdjD] seq of wtype;
/* TMP
    constructor EndPoints ( (s,e) : AdjD ) {
      start = s;
      end   = e;
    }
*/
/* TMP
    function adjMatrix [i:AdjD] { return weights(i).length; }
*/
  }
}

function main() {
  -- Scalable Data Generator parameters.
  -- Total number of vertices in directed multigraph.
  config var TOT_VERTICES       =  2^8;
  --  Maximum allowed clique size in directed multigraph.
  config var MAX_CLIQUE_SIZE    =   10; 
  -- Max num of parallel edges allowed between two vertices. 
  config var MAX_PARAL_EDGES    =    8; 
  -- Percentage of integer (vs. char string) edge weights.
  config var PERC_INT_WEIGHTS   =  0.6; 
  -- Max allowed integer value in any integer edge weight.
  config var MAX_INT_WEIGHT     =  255;
  -- Initial probability of a link between two cliques.
  config var PROB_INTERCL_EDGES =  0.5; 
  -- Kernel parameters.
  -- Kernel 3: Num of edges in each dim 
  -- in directed subgraph. Valid range: 2 and up, 
  -- though at some point it will recover entire graph.
  config var SUBGR_EDGE_LENGTH  =    3; 
  -- Kernel 4: Clustering search box size.
  config var MAX_CLUSTER_SIZE   =   14; 
  -- Kernel 4: cluster search region within MAX_CLUSTER_SIZE.
  config var ALPHA              =  0.5; 

  writeln('\mHPCS SSCA #2 Graph Analysis Executable Specification:');
  writeln('\nRunning...\n\n\n\n');
  var edges, SOUGHT_STRING;  
  writeln('\nScalable Data Generator - genScalData() beginning execution...\n');
  if ENABLE_VERIF then
    (edges, SOUGHT_STRING) = 
              genScalData( TOT_VERTICES, MAX_CLIQUE_SIZE, MAX_PARAL_EDGES, 
                           PERC_INT_WEIGHTS, MAX_INT_WEIGHT, 
                           PROB_INTERCL_EDGES );
  writeln('\n\tgenScalData() completed execution.\n');
  if ENABLE_VERIF then verifyGenData(edges);

  var G : Graph;
  if ENABLE_K1 {
    writeln('\nKernel 1 - computeGraph() beginning execution...\n');
    var startTime = clock;             -- Start performance timing.
    G = computeGraph( edges, TOT_VERTICES, MAX_PARAL_EDGES, MAX_INT_WEIGHT );
    writeln('\n\tcomputeGraph() completed execution.\n');
    dispEllapsedTime( startTime );      -- End performance timing.
    if ENABLE_VERIF then
      verifComputeGraph( edges, G );
  }

  var startSetInt, maxIntWeight, startSetStr;

  if ENABLE_K2 {
    writeln('\nKernel 2 - sortWeights() beginning execution...\n');
    var startTime = clock; -- Start performance timing.
    
    (startSetInt, maxIntWeight, startSetStr) = sortWeights( G, SOUGHT_STRING );

    writeln('\n\tsortWeights() completed execution.\n');
    dispEllapsedTime( startTime ); -- End performance timing.
    
    if ENABLE_VERIF then
      verifSortWeights(edges, startSetInt, maxIntWeight,
                       startSetStr, SOUGHT_STRING );
  }

  var subGraphs;
  if ENABLE_K3 {
    writeln('\nKernel 3 - findSubGraphs() beginning execution...\n');
    var startTime = clock; -- Start performance timing.
    
    subGraphs = findSubGraphs( G, SUBGR_EDGE_LENGTH, 
                               startSetInt, 
                               startSetStr );
    writeln('\n\tfindSubGraphs() completed execution.\n');
    
    dispEllapsedTime( startTime ); -- End performance timing.
    
    if ENABLE_VERIF then
      verifFindSubGraphs( G, subGraphs, startSetInt, startSetStr, 
                          SUBGR_EDGE_LENGTH );
  }

  if ENABLE_K4 {
    writeln('\nKernel 4 - cutClusters() beginning execution...\n');
    
    if ENABLE_VERIF then
      verPrCutClusters( G );
    var startTime = clock; --  Start performance timing.
    
    -- Find clusters in the graph.
/* TMP
    var (cutG, intVertexRemap, strVertexRemap) 
          = cutClusters( G, MAX_CLUSTER_SIZE, ALPHA );
*/
    
    writeln('\n\tcutClusters() completed execution.\n');
    
    dispEllapsedTime( startTime ); -- End performance timing.
    
    if ENABLE_VERIF then
      verifCutClusters( cutG, intVertexRemap, strVertexRemap );
  }

  writeln('\nHPCS SSCA #2 Graph Analysis Executable Specification:');
  writeln('\nEnd of test.\n\n\n\n') ;
}


function genScalData(totVertices, maxCliqueSize, maxParalEdges,
                     percentIntWeights, 
                     maxIntWeightP, probInterclEdges) {

/* TMP
  use Random only RandomNumbers;
*/
  var random_numbers = RandomNumbers();
  var fedges = Edges();
  with fedges;
  maxIntWeight = maxIntWeightP;

  -- Estimate number of cliques needed and pad by 50%.
  var estTotCliques = 
        ceil( (1.5*totVertices) / ((1.0 + maxCliqueSize) / 2 ));
  Cliques = 1..estTotCliquesd;

  -- Generate random clique sizes.
  cliqueSizes = 
    ceil(maxCliqueSize*random_numbers.generate(estTotCliques));

  -- Sum up vertices in each clique.
/* TMP
  VsInCliques.last = scan cliqueSizes by +;
*/

  -- Find where this is greater than totVertices.
  var totCliques = binsearch(VsInCliquess.last, totVertices);

  -- Truncate cliques to get the right number 
  Cliques = 1..totCliques;

  -- Fix the size of the last clique.  
  cliqueSizes(totCliques) = totVertices - VsInCliques(totCliques-1).last;

  -- Compute new start and end vertices in cliques.
  VsInCliques.last(totCliques)  = totVertices;
  VsInCliques.first = 1 # VsInCliques(1..totCliques-1).last + 1;


  -- create the edges within the cliques
/* TMP
  var AdjDomain : domain [i in Cliques] * (2) =  
                    let k = cliqueSize(i) in (1..k, 1..k);
*/

  -- fill matrix with random numbers
/* TMP
  var cliqueAdjMatrix: [AdjDomain] = 
    reshape(let n = AdjDomain.extent; 
                in ceil(maxParalEdges*random_numbers.generate(n)));
*/

  -- zero out the diagonals 
  [c in Cliques][i in 1..cliqueSize(c)] cliqueAdjMaxtrix(c,i,i) = 0;

  -- build cumulative sum of edge counts by clique and level
/* TMP
  var edgeDomain : domain Cliques * (1..maxParalEdges);
*/
/* TMP
  var edgeCounts: [(c,i) in edgeDomain] =  
        sum ([m in cliqueAdjMatrix(c)] m >=i);
*/
/* TMP
  var edgeStarts: [edgeDomain] = scan edgeCounts by + ;
*/

  numEdgesPlacedInCliques = edgeStarts(edgeDomain.last);

  -- Initialize vertex arrays.
  var intraEdges : [1..numEdgesPlacedInCliques] EndPpoints;

  -- now build tine intra-clique edges
  forall (c,m) in edgeDomain {
    var first = VsInClique(c).first;
/* TMP
    intraEdges[edgeStarts(c,m)..] = 
      [(i,j) in AdjDomain(c)] 
        (if (cliqueAdjMatrix(c,i,j) >= m)
         then (start=i+first, end=j+first));
*/
  }

  -- connect the cliques
  -- build a map from vertex number to the clique it is in
/* TMP
  var toClique: [1..totalVertices];
*/
/* TMP
  forall c in Cliques do
    toClique[VsInClique(c).first..VsInClique(c).last] = c;
*/

  -- the probability of an edge between two cliques
  -- which is related to distance.
  var log2Dist = ceil(log(totVertices,2))-1;

  -- foreach probability level, there are 'up' and 'down' edges
/* TMP
  var bitsDomain : domain(1..totalVertices, 1..log2Dist, -1..1 by 2);
*/
  var bits : [bitsDomain] boole;
/* TMP
  forall ((ix, d, dir), r) in (bitsDomain ,
                               reshape(random_numbers.generate(bitsDomain.extent),
                                       bitDomain)) {
    if (r <= probInterclEdges**d) {
      var jx = mod(ix-1 + dir*2**d,totVertices) + 1;
      bits(ix,d,dir) = toClique(ix) != toClique(jx);
    } else bits(ix,d,dir) = false;
  }
*/

/* TMP
  var offset: [bitsDomain] = scan (if bits then 1 else 0) by +;
*/
  numPlacedOutside = offset(bitsDomain.last);
  var interEdges: [1..numPlacedOutside] EndPoints;
  forall (ix, d, dir) in bitsDomain do
    if (bits(ix,d, dir)) {
/* TMP
      var jx = mod(ix-1 + dir*2**d,totVertices) + 1;
*/
      interEdges(offset(ix,d,dir)) = (start=ix, end=jx);
    }

  -- Compute the final number of edges.
  numEdgesPlaced = numPlacedInCliques + numPlacedOutside;
  Edges = 1..numEdgesPlaced;

/* TMP
  edges:EndPoints = intraEdges # interEdges;
*/


  var sought_stirng : string;

/* TMP
  var strAlphabet: [1..26**2] = 
        reshape([i in 'A'..'Z'][j in 'A'..'Z'] i+j);
*/
  var maxLenAlphabet = strAlphabet.extent;
  var is_str : [Edges] boole;
  forall (e, r1, r2) in (Edges,
                         random_numbers.generate(Edges.extent),
                         random_numbers.generate(Edges.extent)) {
                      
    if (r1 <= percentIntWeights) {
      edges(e).weight.i = ceil(maxIntWeight*r2); 
      is_str(e) = false;
    } else {
      edges(e).weight.s = strAlphabet(ceil(maxLenAlphabet*r2));
      is_str(e) = true;
    }
  }

  var i  = ceil(count(is_str) * random_numbers.next);
  if (i == 0) 
    then error("no strings");
/* TMP
  var j = ([e in Edges] (if is_str(e) then e)) (i);
*/
  var sought_string;
/* TMP
  typeselect (w = edges(j).weight) {
    when s    sought_string = w;
  }
*/

  return (fedges, sought_string);
}


/* TMP
function binsearch(x : [?lo..?hi] , y]) {
  if (hi < lo  ) return lo;
  if (x(hi) > y) return hi;
  if (y <= x(lo) return lo;

  while (lo+1 < hi) {
    assert  x(lo) < y and y <= x(hi) ;

    var mid = (hi+lo)/2;
    if (x[mid] < y) 
      lo = mid;
    else
      hi = mid;
  }
  return hi;
}
*/

function computeGraph(edges , totVertices, maxParalEdges, 
                      maxIntWeight ) : Graph {
  var G = Graph();
/* TMP
  G:Numbers = edges;
*/

/* TMP
  with G only VertexD, ParEdgeD, intg, strg;
*/

  VertexD = 1..totVertices;
  ParEdgeD = 1..maxParalEdge;
/* TMP
  intg.AdjD = [e in edges.edges] (if not e.weight.is_string?
                                  then (e.start, e.end));
  strg.AdjD = [e in edges.edges] (if e.weight.is_string?
                                  then (e.start, e.end));
*/
  forall e in edges.edges do
/* TMP
    typeselect (s = e.weight) {
      when i atomic intg.weights(e.start,e.end) #= s;
      when s atomic strg.weights(e.start,e.end) #= s;
    }
*/

  return G;
}


function sortWeights( G : Graph, soughtString : string ) {

  function Subgraph.select(value) {
/* TMP
    return [e in AdjD] if (weights(e) == value) then EndPoints(e);
*/
  }
/* TMP
  with G only intg, strg;
*/
  var maxWeight = max(intg.weights);
  return (intg.select(maxWeight), maxWeight, strg.select(soughtString));
}


function Graph.findSubGraphs(SUBGR_EDGE_LENGTH : integer,
                             startSetIntVPairs : seq of EndPoints,
                             startSetStrVPairs : seq of EndPoints) 
                            : seq of Graph {
    
  function Subgraph.expandSubGraphs(start, complete:subgraph) {
    var frontier like Adj = (start.start, start.end);
    AdjD = start;
    for k in 2..SUBGR_EDGE_LENGTH {
      frontier = [(_,e) in frontier] complete.AdjD(e,*);
      frontier -= AdjD;
      AdjD += frontier;
    }
    [e in AdjD] weights(e) =  complete.weights(e);
  }

/* TMP
  var subgraphs: [1..(startSetIntVPairs.length+startSetStrVPairs.length)];
*/
  -- Loop over vertex pairs in the int starting set.
/* TMP
  cobegin {
    forall (i,v) in (1.., startSetIntVPairs) {
      subgraphs(i) = copy(this);
      subgraphs(i).intg.expand_subgraph(v, intg);
    }
    forall (i,v) in (startSetIntVPairs+1.., startSetStrVPairs); {
      subgraphs(i) = copy(this);
      subgraphs(i).strg.expand_subgraph(v, strg);
    }
  }
*/
  return subgraphs;
}

function cutClusters(G, cutBoxSize, alpha) {

  function cutClustersCommon( adjMatrix : Subgraph,
                              cutBoxSize, alpha) {
    if cutBoxSize < 1
      then error('cutBoxSize must be a least one.');
    if alpha < 0 or alpha > 1
      then error('alpha must be between 0 and 1 inclusive.');
    var startSearch = ceil(alpha * cutBoxSize); 

/* TMP
    with AdjMatrix only VertexD, AdjD;
*/
/* TMP
    var adjCounts: [v in VertexD] = length(AdjD(v,*) # AdjD(*,v));
*/
/* TMP
     type Set : domain sparse VertexD = nil;
*/
/* TMP
    type Seq : seq of index of VertexD = nill;
*/

    var setG : Set = VertexD;
    var setClusters : Seq;     -- set of nodes in clusters.
    var setN2 : Seq;           -- set of cut nodes between clusters.

    while (setG.length > 0) {
      var setIter :Seq;   -- candidate verticies in cluster
      var iCut = 0;       -- index of best cutting point so far
      var iAdj :Set;      -- snapshot of setAdj at iCut

      {
        var setAdj :Set;    -- vertices adjacent to nodes in setIetr
        var vMin = setG(minloc(adjCounts(setG)));
        var cnCut = totVertices+1;   -- minimum contour number so far.
        for i in 1..cutBoxSize {
/* TMP
          setIter #= vMin;         -- add vMin to the iterating set.
*/
    
          -- Find the sets of vertices that are adjacent to vMin.
          -- Form setAdj by excluding the already accounted for vertices.
          setAdj += AdjD(vMin,*) # AdjD(*,vMin);
          setAdj -= setIter # setN2;

          -- Evaluate this vertex as a cutting point.
          var cn = setAdj.extent;
          if i >= startSearch and cnCut >= cn {
            cnCut = cn;
            iCut = i;
            iAdj = setAdj;
          }
          if (cn == 0) then
            break;            -- The cluster is complete.

          -- Pick the next vertex to be processed from among the adjacent 
          -- vertices, the one which minimizes the adjacency count.
/* TMP
          var cnt: [ setAdj ] ;
*/
          forall v in setAdj {
            -- Find the sets of vertices that are adjacent to v.
            var vAdj like setAdj = setAdj # AdjD(v,*) # AdjD(*,v);
            vAdj -= setIter # setN2;
/* TMP
            cnt[v] = vAdj.extent;
*/
          }
          vMin = minloc(cnt);
        }

        if iCut == 0 {                      -- If no cutting point,
          iCut = cutBoxSize;              -- use the entire cutBox.
          iAdj = setAdj;
        }
      }

/* TMP
      setClusters #= setIter(1..iCut);
      setN2       #= iAdj;
*/
      setG  -= setIter # iAdj;
    }
    return setClusters # setN2;
  }

  var intVertexRemap = cutClustersCommon( G.intg, cutBoxSize, alpha );
  var strVertexRemap = cutClustersCommon( G.strg, cutBoxSize, alpha );
  var cutG = Graph.copy(G);

  function remap(oldg, newg, vertexRemap) {
/* TMP
    var map: [G.VertexD];
*/
/* TMP
    forall (new, old) in (1.., vertexRemap) do 
      map[old] = new;
*/
    newg.AdjD = [ (i,j) in oldg.Adj ] (map(i), map(j));
    
    forall (i,j) in newg.AdjD do
      newg.weights(i,j) = oldg.weights(vertexRemap(i), vertexRemap(j));
  }
  remap(G.intg, cutG.intg, intVertexRemap);
  remap(G.strg, cutG.strg, strVertexRemap);

  return cutG;
}
