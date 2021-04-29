//OpenOpus API: https://api.openopus.org

//Import queries:
//1) Create indexes for improving performance (also adds constraints for unique properties).
CREATE CONSTRAINT ON (c:Composer) ASSERT c.id IS UNIQUE;
CREATE CONSTRAINT ON (w:Work) ASSERT w.id IS UNIQUE;
CREATE CONSTRAINT ON (g:Genre) ASSERT g.id IS UNIQUE;
CREATE CONSTRAINT ON (p:Performer) ASSERT p.id IS UNIQUE;

CREATE INDEX ON :Composer(completeName);
CREATE INDEX ON :Work(title);
CREATE INDEX ON :Genre(type);
CREATE INDEX ON :Performer(name);

//2) Load chunks of Composers by name starting with each letter of the alphabet.
CALL apoc.periodic.iterate('UNWIND split("ABCDEFGHIJKLMNOPQRSTUVWXYZ","") AS letter RETURN letter',
    'CALL apoc.load.json("https://api.openopus.org/composer/list/name/"+letter+".json") YIELD value 
    WHERE value.status.rows > 0 
    UNWIND value.composers as composer 
    MERGE (c:Composer {id: composer.id}) 
        ON CREATE SET c.name = composer.name, c.completeName = composer.complete_name, 
        c.birthDate = date(composer.birth), c.deathDate = coalesce(date(composer.death),""), 
        c.musicEra = composer.epoch, c.portrait = composer.portrait',
    {batchSize: 1, iterateList:false})
YIELD batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated
RETURN batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated;
//Total nodes: 220

//3) For all of the Composers just loaded, load all of the related Work and Genre objects.
CALL apoc.periodic.iterate('MATCH (c:Composer) WHERE NOT exists((c)<-[:WROTE]-()) RETURN c',
'CALL apoc.load.json("https://api.openopus.org/work/list/composer/"+c.id+"/genre/all.json")
YIELD value WITH c, value WHERE value.status.rows > 0
UNWIND value.works as work 
MERGE (w:Work {id: work.id})
  ON CREATE SET w.title = work.title, w.subtitle = work.subtitle, 
  w.popular = (CASE when work.popular = "1" THEN true ELSE false END), 
  w.recommended = (CASE when work.recommended = "1" THEN true ELSE false END)
MERGE (g:Genre {type: work.genre})
MERGE (w)-[r2:CLASSIFIED_IN]->(g)
WITH c, w
MERGE (c)-[r:WROTE]->(w)',
{batchSize: 50, iterateList:false})
YIELD batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated
RETURN batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated;
//Total nodes: 25,410
//Total rels: 100,740

//Test query:
//MATCH (c:Composer {name: 'Beethoven'})-[r:WROTE]-(w:Work)-[r2:CLASSIFIED_IN]-(g:Genre {type: 'Orchestral'})
//WHERE w.title STARTS WITH 'Symphony'
//RETURN *