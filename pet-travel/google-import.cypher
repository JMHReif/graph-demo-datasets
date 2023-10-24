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
WITH place.properties as props
MERGE (p:Place {id: props.place_id})
  SET p.address = props.street, p.city = props.city, p.state = props.state, p.postalCode = props.postcode, p.country = props.country, p.lat = toFloat(props.lat), p.lon = toFloat(props.lon)
WITH p, props, CASE
 WHEN props.name IS NULL THEN props.address_line1
 ELSE props.name
END as placeName
 SET p.name = placeName
WITH p, props, props.datasource.raw as info
WHERE info.description IS NOT NULL
  SET p.description = info.description
WITH p, props, info
WHERE info.website IS NOT NULL
  SET p.website = info.website
WITH p, place.properties.categories as subcats
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