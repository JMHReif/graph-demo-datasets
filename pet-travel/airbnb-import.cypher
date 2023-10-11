//Test file on s3
WITH "https://s3.amazonaws.com/cdn.neo4jlabs.com/data/petTravel/airbnbApi.json" as url
CALL apoc.load.json(url) YIELD value
UNWIND value.results as result
RETURN result LIMIT 5;

//import place nodes from airbnb api json file
:auto WITH "https://s3.amazonaws.com/cdn.neo4jlabs.com/data/petTravel/airbnbApi.json" as url
CALL apoc.load.json(url,'$.results') YIELD value as result
CALL { WITH result
    MERGE (p:Place {id: result.id})
     SET p.name = result.name, p.url = result.listing_url, p.description = result.description, p.type = result.property_type, p.roomType = result.room_type, p.accommodates = result.accommodates, p.lat = result.latitude, p.lon = result.longitude, p.cancellationPolicy = result.cancellation_policy, p.imageUrl = result.picture_url.url, p.bedrooms = result.bedrooms, p.beds = result.beds, p.bathrooms = result.bathrooms, p.price = result.price, p.space = result.space, p.rating = result.review_scores_rating, p.reviews = result.number_of_reviews, p.cleaningFee = result.cleaning_fee, p.houseRules = result.house_rules, p.neighborhood = result.neighborhood_cleansed, p.neighborhoodOverview = result.neighborhood_overview, p.address = result.street, p.city = result.city, p.state = result.state, p.postalCode = result.zipcode, p.country = result.country, p.countryCode = result.country_code
} in transactions of 1000 rows;
//9999 Place nodes

//hydrate host nodes and create hosted_by relationships
:auto WITH "https://s3.amazonaws.com/cdn.neo4jlabs.com/data/petTravel/airbnbApi.json" as url
CALL apoc.load.json(url,'$.results') YIELD value as result
CALL { WITH result
    MATCH (p:Place {id: result.id})
    WITH result, p
    MERGE (h:Host {id: result.host_id})
     SET h.name = result.host_name, h.about = result.host_about, h.url = result.host_url, h.image = result.host_picture_url, h.hostStart = result.host_since, h.listingsCount = result.host_listings_count, h.location = result.host_location
    WITH result, p, h
    MERGE (p)-[r:HOSTED_BY]->(h)
} in transactions of 1000 rows;
//8814 Host nodes

//hydrate amenity nodes and create provides relationships
:auto WITH "https://s3.amazonaws.com/cdn.neo4jlabs.com/data/petTravel/airbnbApi.json" as url
CALL apoc.load.json(url,'$.results') YIELD value as result
CALL { WITH result
    MATCH (p:Place {id: result.id})
    WITH result, p
    WHERE result.amenities IS NOT NULL
    UNWIND result.amenities as amenity
    MERGE (a:Amenity {name: amenity})
    WITH result, p, a
    MERGE (p)-[r2:PROVIDES]->(a)
} in transactions of 1000 rows;
//126 Amenity nodes
//185040 PROVIDES relationships

//review graph data model
CALL apoc.meta.graph();