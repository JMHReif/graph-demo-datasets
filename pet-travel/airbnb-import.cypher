//Test file on s3
WITH "https://s3.amazonaws.com/cdn.neo4jlabs.com/data/petTravel/airbnbApi.json" as url
CALL apoc.load.json(url) YIELD value
UNWIND value.results as result
RETURN result LIMIT 5;

//IN PROGRESS
//import place and category nodes from airbnb api json file
// WITH "https://s3.amazonaws.com/cdn.neo4jlabs.com/data/petTravel/airbnbApi.json" as url
// CALL apoc.load.json(url) YIELD value
// UNWIND value.results as result
// MERGE (p:Place {id: result.id})
//  SET p.name = result.name, p.url = result.listing_url, p.description = result.description, p.type = result.property_type, p.accommodates = result.accommodates, p.lat = result.latitude, p.lon = result.longitude, p.cancellationPolicy = result.cancellationPolicy, p.minNights = result.minimum_nights, p.maxNights = result.maximum_nights, p.imageUrl = result.picture_url.url, p.bedrooms = result.bedrooms, p.beds = result.beds, p.bathrooms = result.bathrooms, p.price = result.price, p.space = result.space, p.rating = result.review_scores_rating, p.cleaningFee = result.cleaning_fee, p.houseRules = result.house_rules, p.neighborhood = result.neighborhood, p.neighborhoodOverview = result.neighborhood_overview, //addressInfo
// RETURN result LIMIT 5;

//hydrate the category nodes and create subcategory paths
// WITH "https://s3.amazonaws.com/cdn.neo4jlabs.com/data/petTravel/airbnbApi.json" as url
// CALL apoc.load.json(url) YIELD value
// WITH value, keys(value) as apiCategories
// UNWIND apiCategories as apiCategory
// MERGE (c:Category {name: apiCategory})
// WITH c, apiCategory, value[apiCategory] as places
// UNWIND places as place
// WITH c, apiCategory, place, place.categories as subcats
// UNWIND subcats as subcat
// MATCH (c:Category {name: apiCategory})
// MATCH (p:Place {id: place.id})
// MERGE (s:Subcategory {name: subcat.alias})
//  SET s.title = subcat.title
// MERGE (c)-[r:CONTAINS]->(s)
// MERGE (s)-[r2:CONTAINS]->(p)
// RETURN * LIMIT 50;

//review graph data model
CALL apoc.meta.graph()