//Marvel API: https://developer.marvel.com/

//Queries:
//1) Create indexes for improving performance (also adds constraints for unique properties).
:params { marvel_public: "<your public API key here>", marvel_private: "<your private API key here>" };
//If executing in Neo4j Browser, use below syntax
//:params "marvel_public": "<your public API key here>", "marvel_private": "<your private API key here>"

CREATE CONSTRAINT ON (char:Character) ASSERT char.id IS UNIQUE;
CREATE CONSTRAINT ON (cre:Creator) ASSERT cre.id IS UNIQUE;
CREATE CONSTRAINT ON (issue:ComicIssue) ASSERT issue.id IS UNIQUE;
CREATE CONSTRAINT ON (series:Series) ASSERT series.id IS UNIQUE;
CREATE CONSTRAINT ON (story:Story) ASSERT story.id IS UNIQUE;
CREATE CONSTRAINT ON (event:Event) ASSERT event.id IS UNIQUE;

CREATE INDEX ON :Character(name);
CREATE INDEX ON :Character(resourceURI);
CREATE INDEX ON :Creator(resourceURI);
CREATE INDEX ON :ComicIssue(resourceURI);
CREATE INDEX ON :Series(resourceURI);
CREATE INDEX ON :Story(resourceURI);
CREATE INDEX ON :Event(resourceURI);

//2) Load chunks of Characters by name starting with each letter of the alphabet.
WITH apoc.date.format(timestamp(), "ms", 'yyyyMMddHHmmss') AS ts
WITH "&ts=" + ts + "&apikey=" + $marvel_public + "&hash=" + apoc.util.md5([ts,$marvel_private,$marvel_public]) as suffix
CALL apoc.periodic.iterate('UNWIND split("ABCDEFGHIJKLMNOPQRSTUVWXYZ","") AS letter RETURN letter',
'CALL apoc.load.json("http://gateway.marvel.com/v1/public/characters?nameStartsWith="+letter+"&orderBy=name&limit=100"+$suffix) YIELD value
UNWIND value.data.results as results
WITH results, results.comics.available AS comics
WHERE comics > 0
MERGE (char:Character {id: results.id})
  ON CREATE SET char.name = results.name, char.description = results.description, char.thumbnail = results.thumbnail.path+"."+results.thumbnail.extension, 
      char.resourceURI = results.resourceURI
',{batchSize: 1, iterateList:false, params:{suffix:suffix}})
YIELD batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated
RETURN batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated;

//Output:
//╒═════════╤═══════╤═══════════╤═════════════════════╤══════════════════╤═══════════════╤═════════╤═══════════════╤══════════════════════════════════════════════════╤══════════════════════════════════════════════════╤═══════════════╕
//│"batches"│"total"│"timeTaken"│"committedOperations"│"failedOperations"│"failedBatches"│"retries"│"errorMessages"│"batch"                                           │"operations"                                      │"wasTerminated"│
//╞═════════╪═══════╪═══════════╪═════════════════════╪══════════════════╪═══════════════╪═════════╪═══════════════╪══════════════════════════════════════════════════╪══════════════════════════════════════════════════╪═══════════════╡
//│26       │26     │214        │26                   │0                 │0              │0        │{}             │{"total":26,"committed":26,"failed":0,"errors":{}}│{"total":26,"committed":26,"failed":0,"errors":{}}│false          │
//└─────────┴───────┴───────────┴─────────────────────┴──────────────────┴───────────────┴─────────┴───────────────┴──────────────────────────────────────────────────┴──────────────────────────────────────────────────┴───────────────┘
//Total nodes: 1,058


//3) For all of the Characters we just loaded, load all of the related ComicIssue, Series, Story, Event, and Creator objects. I am just populating basic info on each of the nodes here.
WITH apoc.date.format(timestamp(), "ms", 'yyyyMMddHHmmss') AS ts
WITH "&ts=" + ts + "&apikey=" + $marvel_public + "&hash=" + apoc.util.md5([ts,$marvel_private,$marvel_public]) as suffix
CALL apoc.periodic.iterate('MATCH (c:Character) WHERE c.resourceURI IS NOT NULL AND NOT exists((c)<-[:INCLUDES]-()) RETURN c LIMIT 100',
'CALL apoc.util.sleep(2000)
CALL apoc.load.json(c.resourceURI+"/comics?format=comic&formatType=comic&limit=100"+$suffix)
YIELD value WITH c, value.data.results as results WHERE results IS NOT NULL
UNWIND results as result MERGE (comic:ComicIssue {id: result.id})
  ON CREATE SET comic.name = result.title, comic.issueNumber = result.issueNumber, comic.pageCount = result.pageCount, comic.resourceURI = result.resourceURI, comic.thumbnail = result.thumbnail.path+"."+result.thumbnail.extension
WITH c, comic, result
MERGE (comic)-[r:INCLUDES]->(c)
WITH c, comic, result WHERE result.series IS NOT NULL
UNWIND result.series as comicSeries
MERGE (series:Series {id: toInteger(split(comicSeries.resourceURI,"/")[-1])})
  ON CREATE SET series.name = comicSeries.name, series.resourceURI = comicSeries.resourceURI
WITH c, comic, series, result
MERGE (comic)-[r2:BELONGS_TO]->(series)
WITH c, comic, result, result.creators.items as items WHERE items IS NOT NULL
UNWIND items as item
MERGE (creator:Creator {id: toInteger(split(item.resourceURI,"/")[-1])})
  ON CREATE SET creator.name = item.name, creator.resourceURI = item.resourceURI
WITH c, comic, result, creator
MERGE (comic)-[r3:CREATED_BY]->(creator)
WITH c, comic, result, result.stories.items as items WHERE items IS NOT NULL
UNWIND items as item
MERGE (story:Story {id: toInteger(split(item.resourceURI,"/")[-1])})
  ON CREATE SET story.name = item.name, story.resourceURI = item.resourceURI, story.type = item.type
WITH c, comic, result, story
MERGE (comic)-[r4:MADE_OF]->(story)
WITH c, comic, result, result.events.items AS items WHERE items IS NOT NULL
UNWIND items as item
MERGE (event:Event {id: toInteger(split(item.resourceURI,"/")[-1])})
  ON CREATE SET event.name = item.name, event.resourceURI = item.resourceURI
MERGE (comic)-[r5:PART_OF]->(event)',
{batchSize: 20, iterateList:false, retries:2, params:{suffix:suffix}})
YIELD batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated
RETURN batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated;

//Output:
//╒═════════╤═══════╤═══════════╤═════════════════════╤══════════════════╤═══════════════╤═════════╤═══════════════╤════════════════════════════════════════════════╤════════════════════════════════════════════════════╤═══════════════╕
//│"batches"│"total"│"timeTaken"│"committedOperations"│"failedOperations"│"failedBatches"│"retries"│"errorMessages"│"batch"                                         │"operations"                                        │"wasTerminated"│
//╞═════════╪═══════╪═══════════╪═════════════════════╪══════════════════╪═══════════════╪═════════╪═══════════════╪════════════════════════════════════════════════╪════════════════════════════════════════════════════╪═══════════════╡
//│5        │100    │1867       │100                  │0                 │0              │0        │{}             │{"total":5,"committed":5,"failed":0,"errors":{}}│{"total":100,"committed":100,"failed":0,"errors":{}}│false          │
//└─────────┴───────┴───────────┴─────────────────────┴──────────────────┴───────────────┴─────────┴───────────────┴────────────────────────────────────────────────┴────────────────────────────────────────────────────┴───────────────┘


//4) For all of the Series that have not been loaded yet, load the Series.
WITH apoc.date.format(timestamp(), "ms", 'yyyyMMddHHmmss') AS ts
WITH "&ts=" + ts + "&apikey=" + $marvel_public + "&hash=" + apoc.util.md5([ts,$marvel_private,$marvel_public]) as suffix
CALL apoc.periodic.iterate('MATCH (s:Series) WHERE s.resourceURI IS NOT NULL AND not exists(s.startYear) RETURN s LIMIT 100',
'CALL apoc.util.sleep(2000)
CALL apoc.load.json(s.resourceURI+"?limit=100" + $suffix) YIELD value
WITH value.data.results as results WHERE results IS NOT NULL
UNWIND results as result
MERGE (series:Series {id: result.id})
  SET series.startYear = result.startYear, series.endYear = result.endYear, series.rating = result.rating, 
      series.thumbnail = result.thumbnail.path+"."+result.thumbnail.extension', 
{batchSize: 20, iterateList: false, params: {suffix:suffix}})
YIELD batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated
RETURN batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated;

//Output:
//╒═════════╤═══════╤═══════════╤═════════════════════╤══════════════════╤═══════════════╤═════════╤═══════════════╤════════════════════════════════════════════════╤════════════════════════════════════════════════════╤═══════════════╕
//│"batches"│"total"│"timeTaken"│"committedOperations"│"failedOperations"│"failedBatches"│"retries"│"errorMessages"│"batch"                                         │"operations"                                        │"wasTerminated"│
//╞═════════╪═══════╪═══════════╪═════════════════════╪══════════════════╪═══════════════╪═════════╪═══════════════╪════════════════════════════════════════════════╪════════════════════════════════════════════════════╪═══════════════╡
//│5        │100    │292        │100                  │0                 │0              │0        │{}             │{"total":5,"committed":5,"failed":0,"errors":{}}│{"total":100,"committed":100,"failed":0,"errors":{}}│false          │
//└─────────┴───────┴───────────┴─────────────────────┴──────────────────┴───────────────┴─────────┴───────────────┴────────────────────────────────────────────────┴────────────────────────────────────────────────────┴───────────────┘


//5) For all of the Characters (names starting with "A"), hydrate the Event nodes with a few more properties.
WITH apoc.date.format(timestamp(), "ms", 'yyyyMMddHHmmss') AS ts
WITH "&ts=" + ts + "&apikey=" + $marvel_public + "&hash=" + apoc.util.md5([ts,$marvel_private,$marvel_public]) as suffix
CALL apoc.periodic.iterate('MATCH (event:Event) WHERE event.resourceURI IS NOT NULL AND NOT exists(event.start) RETURN DISTINCT event LIMIT 100',
'CALL apoc.util.sleep(2000) CALL apoc.load.json(event.resourceURI+"?limit=100"+$suffix) YIELD value
UNWIND value.data.results as result
MERGE (e:Event {id: result.id})
  SET e.start = result.start, e.end = result.end', {batchSize: 20, iterateList:false, params: {suffix:suffix}})
YIELD batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated
RETURN batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated;

//Output:
//╒═════════╤═══════╤═══════════╤═════════════════════╤══════════════════╤═══════════════╤═════════╤═══════════════╤════════════════════════════════════════════════╤══════════════════════════════════════════════════╤═══════════════╕
//│"batches"│"total"│"timeTaken"│"committedOperations"│"failedOperations"│"failedBatches"│"retries"│"errorMessages"│"batch"                                         │"operations"                                      │"wasTerminated"│
//╞═════════╪═══════╪═══════════╪═════════════════════╪══════════════════╪═══════════════╪═════════╪═══════════════╪════════════════════════════════════════════════╪══════════════════════════════════════════════════╪═══════════════╡
//│3        │56     │273        │56                   │0                 │0              │0        │{}             │{"total":3,"committed":3,"failed":0,"errors":{}}│{"total":56,"committed":56,"failed":0,"errors":{}}│false          │
//└─────────┴───────┴───────────┴─────────────────────┴──────────────────┴───────────────┴─────────┴───────────────┴────────────────────────────────────────────────┴──────────────────────────────────────────────────┴───────────────┘