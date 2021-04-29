//Test query:
WITH 'https://api.themoviedb.org/3/search/movie?api_key=6dbfaa58a3863cad74979fae5d4eb643&query=Lord%20of%20the%20Rings' as url
CALL apoc.load.json(url)
YIELD value
RETURN value;

//Set up params:
:params {apiKey: <your API key here>}

//Set up constraints:
CREATE CONSTRAINT ON (m:Movie) ASSERT m.id IS UNIQUE;
CREATE CONSTRAINT ON (c:Cast) ASSERT c.id IS UNIQUE;
CREATE CONSTRAINT ON (ch:Character) ASSERT ch.id IS UNIQUE;

//Load Movies:
WITH 'https://api.themoviedb.org/3/search/movie?api_key='+$apiKey+'&query=Lord%20of%20the%20Rings' as url
CALL apoc.load.json(url) YIELD value
UNWIND value.results AS results
WITH results
MERGE (m:Movie {movieId: results.id})
  ON CREATE SET m.title = results.title, m.desc = results.overview, m.poster = results.poster_path, m.reviewStars = results.vote_average, m.reviews = results.vote_count
WITH results, m
CALL apoc.do.when(results.release_date = "", 'SET m.releaseDate = null', 'SET m.releaseDate = date(results.release_date)', {m:m, results:results}) YIELD value
RETURN m;

//Load Characters/Actors in Movies:
WITH 'https://api.themoviedb.org/3/movie/' as prefix, '/credits?api_key='+$apiKey as suffix,
["The Lord of the Rings: The Fellowship of the Ring", "The Lord of the Rings: The Two Towers", "The Lord of the Rings: The Return of the King"] as movies
CALL apoc.periodic.iterate('MATCH (m:Movie) WHERE m.title IN $movies RETURN m',
'WITH m CALL apoc.load.json($prefix+m.movieId+$suffix) YIELD value
UNWIND value.cast AS cast
MERGE (c:Cast {id: cast.id})
  ON CREATE SET c.name = cast.name
MERGE (ch:Character {name: cast.character})
MERGE (ch)-[r:APPEARS_IN]->(m)
MERGE (c)-[r1:PLAYED]->(ch)',
{batchSize: 1, iterateList:false, params:{movies:movies, prefix:prefix, suffix:suffix}})
YIELD batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated
RETURN batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated;