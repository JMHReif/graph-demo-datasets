//Test file on s3
WITH "https://s3.amazonaws.com/cdn.neo4jlabs.com/data/petTravel/googleApi.json" as url
CALL apoc.load.json(url) YIELD value
RETURN value LIMIT 5;

//import place and category placeholder nodes from google api json file
WITH "https://s3.amazonaws.com/cdn.neo4jlabs.com/data/petTravel/googleApi.json" as url
CALL apoc.load.json(url) YIELD value
WITH value, keys(value) as apiCategories
UNWIND apiCategories as apiCategory
WITH value[apiCategory] as places
UNWIND places as place
MERGE (p:Place {id: place.properties.place_id})
  SET p.address = place.properties.street, p.city = place.properties.city, p.state = place.properties.state, p.postalCode = place.properties.postcode, p.country = place.properties.country, p.lat = toFloat(place.properties.lat), p.lon = toFloat(place.properties.lon)
WITH p, place, CASE
 WHEN place.properties.name IS NULL THEN place.properties.address_line1
 ELSE place.properties.name
END as placeName
 SET p.name = placeName
WITH p, place, placeName, place.properties.categories as subcats
UNWIND subcats as subcat
MERGE (c:Category {name: subcat})
MERGE (p)-[r:PART_OF]->(c)
RETURN * LIMIT 50;

//hydrate the category nodes and create subcategory paths
MATCH (subcats:Category)<-[:PART_OF]-(p:Place)
WHERE subcats.name CONTAINS "."
WITH subcats, p, split(subcats.name,".") as subcat
WITH subcat, p, apoc.coll.pairsMin(subcat) as pairs
UNWIND pairs as pair
MERGE (c:Category {name: pair[0]})
MERGE (s:Subcategory {name: pair[1]})
MERGE (c)-[r:CONTAINS]->(s)
MERGE (s)-[r2:CONTAINS]->(p)
RETURN * LIMIT 30;

//delete the placeholder relationships to categories
MATCH (subcats:Category)<-[temp:PART_OF]-(p:Place)
DELETE temp
WITH subcats
WHERE subcats.name CONTAINS "."
DETACH DELETE subcats;

//review graph data model
CALL apoc.meta.graph();