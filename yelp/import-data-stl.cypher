//Constraints:
CREATE CONSTRAINT FOR (b:Business) REQUIRE b.business_id IS UNIQUE;
CREATE CONSTRAINT FOR (c:Category) REQUIRE c.name IS UNIQUE;
CREATE CONSTRAINT FOR (a:Attribute) REQUIRE (a.name, a.attribute) IS NODE KEY;
CREATE CONSTRAINT FOR (u:User) REQUIRE u.user_id IS UNIQUE;
CREATE CONSTRAINT FOR (r:Review) REQUIRE r.review_id IS UNIQUE;

//Load 6439 Business nodes (+ related Category and Attribute)
LOAD CSV WITH HEADERS FROM "file:///yelp_academic_dataset_business.csv" as row
WITH row
WHERE row.city IN ["St. Louis", "Saint Louis","St Louis"]
CALL (row) {
    WITH row, keys(row) as rowKeys
    UNWIND rowKeys as key
    WITH row, key
    WHERE key STARTS WITH 'attributes/'
    WITH row, collect(key)+'categories' as attributeProps
    MERGE (b:Business {business_id: row.business_id})
     SET b += apoc.map.clean(row, attributeProps,[""])
    RETURN b
}
WITH row, b
CALL (row, b) {
    WITH split(row.categories,',') as categories
    UNWIND categories as category
    MERGE (c:Category {name: trim(category)})
    MERGE (b)-[r:SORTED_BY]->(c)
}
RETURN count(b);

//Load 251121 attributes
LOAD CSV WITH HEADERS FROM "file:///yelp_academic_dataset_business.csv" as row
WITH row
WHERE row.city IN ["St. Louis", "Saint Louis","St Louis"]
CALL (row) {
    WITH keys(row) as rowKeys
    UNWIND rowKeys as rowKey
    WITH row, rowKey
    WHERE rowKey STARTS WITH "attributes/"
    WITH row, rowKey, row[rowKey] as keyValue
    WHERE keyValue IS NOT NULL
    WITH row, keyValue,
    CASE keyValue
        WHEN "True" THEN "ATTRIBUTE_TRUE"
        WHEN "False" THEN "ATTRIBUTE_FALSE"
        ELSE THEN "HAS_ATTRIBUTE"
    MATCH (b:Business {business_id: row.business_id})
    MERGE (a:Attribute {name: ltrim(rowKey,"attributes/", attribute: keyValue)})
    MERGE (b)-[r:HAS_ATTRIBUTE]->(a)
    RETURN a
}
RETURN count(a);

//Load 341992 Review nodes
LOAD CSV WITH HEADERS FROM "file:///yelp_academic_dataset_review.csv" as row
MATCH (b:Business {business_id: row.business_id})
CALL (row,b) {
    MERGE (r:Review {review_id: row.review_id})
     SET r = row
    MERGE (r)-[rel:WRITTEN_FOR]->(b)
    MERGE (u:User {user_id: row.user_id})
    MERGE (r)<-[rel2:WROTE]-(u)
    RETURN r as review
} in transactions of 10000 rows
RETURN count(review);

//Load 1760 User nodes
LOAD CSV WITH HEADERS FROM "file:///yelp_academic_dataset_user.csv" as row
CALL (row) {
    MATCH (u:User {user_id: row.user_id})
     SET u += apoc.map.clean(row, ['friends'],[""])
    WITH row, u, row.friends as friendsList
    UNWIND friendsList as friend
    MATCH (f:User {user_id: friend})
    MERGE (u)-[rel:FRIENDS_WITH]->(f)
    RETURN u as user
} in transactions of 10000 rows
RETURN count(user);