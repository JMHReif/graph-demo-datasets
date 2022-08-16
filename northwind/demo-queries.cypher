//Data model
CALL apoc.meta.graph();

//Find some products
MATCH (p:Product)
RETURN p;

//Find some products and related categories
MATCH (p:Product)-[r:PART_OF]->(c:Category)
RETURN *;

//Find relationships for apple product
MATCH (p:Product {productName: "Manjimup Dried Apples"})-[r]-(other)
RETURN *;

//Find out who supplies the apples
MATCH (p:Product {productName: "Manjimup Dried Apples"})-[r:SUPPLIES]-(s:Supplier)
RETURN *;

//Find out who supplies produce
MATCH (c:Category {categoryName: "Produce"})<-[r1:PART_OF]-(p:Product)<-[r:SUPPLIES]-(s:Supplier)
RETURN *;

//List company names of produce suppliers and their products
MATCH (c:Category {categoryName: "Produce"})<-[r1:PART_OF]-(p:Product)<-[r:SUPPLIES]-(s:Supplier)
RETURN s.companyName, collect(p.productName);

//List companies and the categories they supply where one is Produce
MATCH (c:Category)<-[r:PART_OF]-(p:Product)-[r2:SUPPLIES]-(s:Supplier)
WITH s.companyName as company, collect(distinct c.categoryName) as categories
WHERE "Produce" IN categories
RETURN company, categories;

//Find customers who purchased produce products
MATCH (cust:Customer)-[r:PURCHASED]->(o:Order)-[r2:ORDERS]->(p:Product)-[r3:PART_OF]->(c:Category {categoryName:"Produce"})
RETURN DISTINCT cust.contactName as customer, SUM(r2.quantity) AS products
ORDER BY products DESC;