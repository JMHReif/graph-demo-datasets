//Kaggle Netflix with Wikipedia Countries Data Set

//Create constraints
CREATE CONSTRAINT FOR (p:Production) REQUIRE p.productionId IS UNIQUE;
CREATE CONSTRAINT FOR (g:Genre) REQUIRE g.name IS UNIQUE;
CREATE CONSTRAINT FOR (c:Country) REQUIRE c.iso2Code IS UNIQUE;
CREATE CONSTRAINT FOR (p:Person) REQUIRE p.personId IS UNIQUE;
CREATE CONSTRAINT FOR (c:Character) REQUIRE c.name IS UNIQUE;
CREATE CONSTRAINT FOR (i:Imdb) REQUIRE i.imdbId IS UNIQUE;
CREATE CONSTRAINT FOR (t:Tmdb) REQUIRE t.uuid IS UNIQUE;

//Load Productions
LOAD CSV WITH HEADERS FROM "https://raw.githubusercontent.com/JMHReif/graph-demo-datasets/main/kaggle-netflix/titles.csv" as row
CALL apoc.merge.node(["Production",apoc.text.capitalize(toLower(row.type))], {productionId: row.id}, {title: row.title, seasons: toFloat(row.seasons), releaseYear: date(row.release_year), description: row.description, runtime: toInteger(row.runtime), rating: row.age_certification}, {}) YIELD node as p
WITH row, p
CALL { 
    WITH row, p
    WITH row, p, split(substring(row.genres, 1, size(row.genres)-2), ", ") AS genres
    UNWIND genres as g
    WITH row, p, substring(g, 1, size(g)-2) as genre
    WHERE genre <> ""
    MERGE (g:Genre {name: apoc.text.capitalize(genre)})
    MERGE (p)-[r:CATEGORIZED_BY]->(g) 
    RETURN g
}
WITH row, p
CALL {
    WITH row, p
    WITH row, p, split(substring(row.production_countries, 1, size(row.production_countries)-2), ", ") AS countries
    UNWIND countries as c
    WITH row, p, substring(c, 1, size(c)-2) as country
    WHERE country <> ""
    MERGE (c:Country {iso2Code: country})
    MERGE (p)-[r2:PRODUCED_IN]->(c)
    RETURN c
}
RETURN count(row);

//Load Imdb and Tmdb nodes and rels
LOAD CSV WITH HEADERS FROM "https://raw.githubusercontent.com/JMHReif/graph-demo-datasets/main/kaggle-netflix/titles.csv" as row
WITH row
CALL {
    WITH row
    WITH row
    WHERE row.imdb_id <> ""
    MATCH (p:Production {productionId: row.id})
    MERGE (i:Imdb {imdbId: row.imdb_id})
     ON CREATE SET i.imdbVotes = toFloat(row.imdb_votes), i.imdbScore = row.imdb_score
    MERGE (p)-[r:HAS_IMDB]->(i)
}
WITH row
CALL {
    WITH row
    WITH row
    WHERE row.tmdb_popularity <> "" OR row.tmdb_score <> ""
    MATCH (p:Production {productionId: row.id})
    MERGE (t:Tmdb {uuid: apoc.create.uuid()})
     ON CREATE SET t.tmdbPopularity = row.tmdb_popularity, t.tmdbScore = row.tmd_score
    MERGE (p)-[r2:HAS_TMDB]->(t)
}
RETURN count(row);

//Load country names
LOAD CSV WITH HEADERS FROM "https://raw.githubusercontent.com/JMHReif/graph-demo-datasets/main/kaggle-netflix/wikipedia-iso-country-codes.csv" as row
MATCH (c:Country {iso2Code: row.`Alpha-2 code`})
 SET c.name = row.`English short name lower case`
RETURN count(*);

//Load production people
:auto LOAD CSV WITH HEADERS FROM "https://raw.githubusercontent.com/JMHReif/graph-demo-datasets/main/kaggle-netflix/credits.csv" as row
WITH row
CALL {
    WITH row
    MERGE (p:Person {personId: row.person_id})
     SET p.name = row.name
    WITH row, p
    CALL apoc.create.addLabels(p,[apoc.text.capitalize(toLower(row.role))]) YIELD node as person
    RETURN person
} IN TRANSACTIONS OF 20000 ROWS
RETURN count(row);

//Add rel between Production and Person based on role
:auto LOAD CSV WITH HEADERS FROM "https://raw.githubusercontent.com/JMHReif/graph-demo-datasets/main/kaggle-netflix/credits.csv" as row
WITH row
CALL {
    WITH row
    MATCH (p:Person {personId: row.person_id})
    WITH row, p, CASE row.role 
        WHEN "ACTOR" THEN "ACTED_IN" 
        WHEN "DIRECTOR" THEN "DIRECTED" 
        ELSE "UNKNOWN" END as relType
    MATCH (pro:Production {productionId: row.id})
    CALL apoc.merge.relationship(p, relType, {}, {}, pro, {}) YIELD rel as r
    RETURN r
} IN TRANSACTIONS OF 20000 rows
RETURN count(row);

//Add Character nodes and rels
:auto LOAD CSV WITH HEADERS FROM "https://raw.githubusercontent.com/JMHReif/graph-demo-datasets/main/kaggle-netflix/credits.csv" as row
WITH row
WHERE row.character <> ""
CALL {
    WITH row
    MATCH (p:Person {personId: row.person_id})
    MERGE (c:Character {name: row.character})
    MERGE (p)-[r:PLAYED]->(c) 
    WITH row, c
    MATCH (pr:Production {productionId: row.id})
    MERGE (pr)-[r2:FEATURED]->(c)
} IN TRANSACTIONS OF 10000 rows;