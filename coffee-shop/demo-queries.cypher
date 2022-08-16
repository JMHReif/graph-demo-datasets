//Data Model
CALL apoc.meta.graph();

//Find some products
MATCH (p:Product)
RETURN p;

//Find a product and relationships
MATCH (p:Product {productName: "Latte"})-[r]->(other)
RETURN *;

//Find products in Coffee category
MATCH (c:Category {category: "Coffee"})<-[r:ORGANIZED_IN]-(t:Type)<-[r2:SORTED_BY]-(p:Product)
RETURN * LIMIT 50;

//Find products with orders and their type
MATCH (o:Order)-[r:CONTAINS]->(p:Product)-[r2:SORTED_BY]->(t:Type)
RETURN DISTINCT t.type, count(p) as count
ORDER BY count DESC;

//Let's say we have a new premium brewed coffee...
//We might want to offer it to our customers who order those types of products most

//Find customers who ordered premium brewed coffee
MATCH (t:Type {type: "Premium brewed coffee"})<-[r:SORTED_BY]-(p:Product)<-[r2:CONTAINS]-(o:Order)-[r3:BOUGHT]-(c:Customer)
RETURN * LIMIT 100;

//Find customers who ordered most premium brewed coffee
MATCH (t:Type {type: "Premium brewed coffee"})<-[r:SORTED_BY]-(p:Product)<-[r2:CONTAINS]-(o:Order)-[r3:BOUGHT]-(c:Customer)
RETURN c.firstName, c.email, count(t) as count
ORDER BY count DESC;