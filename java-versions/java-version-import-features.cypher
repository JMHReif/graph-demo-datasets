//Github project source: https://raw.githubusercontent.com/marchof/java-almanac/

//Setup:
CREATE INDEX java_version FOR (j:JavaVersion) ON (j.version);
CREATE INDEX feature FOR (f:Feature) ON (f.title);
CREATE INDEX category FOR (c:Category) ON (c.name);

//Queries:
//1) Load Java versions, along with related features and categories
WITH [1.0,1.1,1.2,1.3,1.4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24] as versions
CALL apoc.periodic.iterate('UNWIND $versions as version RETURN version',
    'CALL apoc.load.json("https://raw.githubusercontent.com/marchof/java-almanac/master/site/data/jdk/versions/"+version+".json")
    YIELD value
    MERGE (j:JavaVersion {version: value.version})
     ON CREATE SET j.name = value.name, j.codeName = value.codename, 
     j.gaDate = date(value.ga),
     j.status = value.status, j.bytecode = value.bytecode, j.vmSpec = value.documentation.vm, 
     j.languageSpec = value.documentation.lang, j.apiSpec = value.documentation.api,
     j.eolDate = date(value.eol)
    WITH value, j 
    WHERE value.features IS NOT NULL 
    UNWIND value.features as feature 
    MERGE (f:Feature {title: feature.title})
    MERGE (j)-[r2:INCLUDES]->(f)
    WITH value, feature, f
    MERGE (c:Category {name: feature.category})
    MERGE (f)-[r3:BELONGS_TO]->(c)',
    {batchSize: 50, iterateList:false, params:{versions:versions}})
YIELD batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated
RETURN batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated;
//Total nodes: 214
//Total rels: 412