//1) Setup
CREATE INDEX FOR (c:City) ON (c.name);
CREATE INDEX FOR (c:City) ON (c.location);
CREATE INDEX FOR (c:City) ON (c.population);

CREATE INDEX FOR (y:Country) ON (y.iso2);
CREATE INDEX FOR (y:Country) ON (y.name);

CREATE INDEX FOR (a:AdministrativeRegion) ON (a.name);

//2) Load world cities
:auto USING PERIODIC COMMIT
LOAD CSV WITH HEADERS 
FROM 'https://storage.googleapis.com/meetup-data/worldcities.csv' AS line

MERGE (country:Country {
    name: coalesce(line.country, ''),
    iso2: coalesce(line.iso2, ''),
    iso3: coalesce(line.iso3, '')    
})

MERGE (c:City {
    id: coalesce(line.id, ''),
    name: coalesce(line.city, ''),
    asciiName: coalesce(line.city_ascii, ''),
    adminName: coalesce(line.admin_name, ''),
    capital: coalesce(line.capital, ''),
    location: point({
        latitude: toFloat(coalesce(line.lat, '0.0')),
        longitude: toFloat(coalesce(line.lng, '0.0'))
    }),
    population: coalesce(toInteger(coalesce(line.population, 0)), 0)
})

MERGE (c)-[:IN]->(country);

//3) City links
MATCH (a:City)-[:IN]->(ca:Country), (b:City)-[:IN]->(cb:Country)
WHERE id(a) < id(b)
AND distance(a.location, b.location) < 10000
WITH a, b, ca, cb
MERGE (a)-[r:IS_CLOSE_TO { distance: distance(a.location, b.location) }]->(b)
RETURN count(r);

MATCH (a:City)-[:IN]->(ca:Country), (b:City)-[:IN]->(cb:Country)
WHERE id(a) < id(b)
AND distance(a.location, b.location) < 10000
AND id(ca) < id(cb)
WITH a, b, ca, cb
MERGE (ca)-[r:NEIGHBORS]->(cb)
RETURN count(r);

//4) Administrative units
MATCH (c:City)-[:IN]->(co:Country)
WITH c, co
MERGE (ar:AdministrativeRegion { name: c.adminName })
MERGE (c)-[:IN { role: c.capital }]->(ar)
MERGE (ar)-[:IN]->(co)
RETURN count(ar);