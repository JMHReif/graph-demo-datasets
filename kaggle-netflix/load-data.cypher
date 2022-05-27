//WORK IN PROGRESS!

//Create constraints
CREATE CONSTRAINT FOR (p:Production) REQUIRE p.productionId IS UNIQUE;
CREATE CONSTRAINT FOR (g:Genre) REQUIRE g.name IS UNIQUE;
CREATE CONSTRAINT FOR (c:Country) REQUIRE c.iso2Code IS UNIQUE;

//Load Productions
LOAD CSV WITH HEADERS FROM "file:///titles.csv" as row
CALL apoc.merge.node(["Production",apoc.text.capitalize(toLower(row.type))], {productionId: row.id}, {title: row.title, seasons: toFloat(row.seasons), releaseYear: date(row.release_year), description: row.description, runtime: toInteger(row.runtime), rating: row.age_certification, imdbId: row.imdb_id, imdbVotes: toFloat(row.imdb_votes), imdbScore: row.imdb_score, tmdbPopularity: row.tmdb_popularity, tmdbScore: row.tmdb_score}, {}) YIELD node as p
WITH row, p
CALL { 
    WITH row, p
    WITH row, p, split(substring(row.genres, 1, size(row.genres)-2), ", ") AS genres
    UNWIND genres as g
    WITH row, substring(g, 1, size(g)-2) as genre
    WHERE genre <> ""
    MERGE (g:Genre {name: apoc.text.capitalize(genre)})
    MERGE (p)-[r:CATEGORIZED_BY]->(g) 
    RETURN g
}
WITH row, p
CALL {
    WITH row, p
    WITH row, split(substring(row.production_countries, 1, size(row.production_countries)-2), ", ") AS countries
    UNWIND countries as c
    WITH row, substring(c, 1, size(c)-2) as country
    WHERE country <> ""
    MERGE (c:Country {iso2Code: country})
    MERGE (p)-[r2:PRODUCED_IN]->(c)
    RETURN c
}
RETURN count(*);

//Load country names
LOAD CSV WITH HEADERS FROM "file:///wikipedia-iso-country-codes.csv" as row
MATCH (c:Country {iso2Code: row.`Alpha-2 code`})
 SET c.name = row.`English short name lower case`
RETURN count(*);

//Load production people
LOAD CSV WITH HEADERS FROM "file:///credits.csv" as row
CALL apoc.merge.node(["Person",apoc.text.capitalize(toLower(row.role))], {personId: row.person_id}, {name: row.name}, {}) YIELD node as p
WITH row, p
WHERE p.characters <> ""
CALL { 
    WITH row, p
    MERGE (c:Character {name: row.character})
    MERGE (p)-[r:PLAYED]->(c) 
    WITH row, c
    MATCH (pr:Production {productionId: row.id})
    MERGE (pr)-[r2:FEATURES]->(c)
    RETURN pr
}
RETURN count(*);