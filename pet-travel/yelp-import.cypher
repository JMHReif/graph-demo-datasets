//Test file on s3
WITH "https://s3.amazonaws.com/cdn.neo4jlabs.com/data/petTravel/yelpApi.json" as url
CALL apoc.load.json(url) YIELD value
RETURN value LIMIT 5;

//import place and category nodes from yelp api json file
WITH "https://s3.amazonaws.com/cdn.neo4jlabs.com/data/petTravel/yelpApi.json" as url
CALL apoc.load.json(url) YIELD value
WITH value, keys(value) as apiCategories
UNWIND apiCategories as apiCategory
WITH value[apiCategory] as places
UNWIND places as place
MERGE (p:Place {id: place.id})
  SET p.name = place.name, p.url = place.url, p.imageUrl = place.image_url, p.phone = p.display_phone, p.lat = toFloat(place.coordinates.latitude), p.lon = toFloat(place.coordinates.longitude), p.reviewCount = place.review_count, p.rating = place.rating, p.address = place.location.address1, p.city = place.location.city, p.state = place.location.state, p.postalCode = place.location.zip_code, p.country = place.location.country
WITH p
RETURN * LIMIT 50;

//fix typo in 1 Brooklyn place
MATCH (p:Place)
WHERE p.city = "Brookyln"
SET p.city = "Brooklyn"
RETURN p;

//hydrate the category nodes and create subcategory paths
WITH "https://s3.amazonaws.com/cdn.neo4jlabs.com/data/petTravel/yelpApi.json" as url
CALL apoc.load.json(url) YIELD value
WITH value, keys(value) as apiCategories
UNWIND apiCategories as apiCategory
MERGE (c:Category {name: apiCategory})
WITH c, apiCategory, value[apiCategory] as places
UNWIND places as place
WITH c, apiCategory, place, place.categories as subcats
UNWIND subcats as subcat
MATCH (c:Category {name: apiCategory})
MATCH (p:Place {id: place.id})
MERGE (s:Subcategory {name: subcat.alias})
 SET s.title = subcat.title
MERGE (c)-[r:CONTAINS]->(s)
MERGE (s)-[r2:CONTAINS]->(p)
RETURN * LIMIT 50;

//review graph data model
CALL apoc.meta.graph();