//Total loaded data size:
//1035 nodes
//3139 relationships

//Create indexes
CREATE INDEX FOR (p:Product) ON (p.productID);
CREATE INDEX FOR (p:Product) ON (p.productName);
CREATE INDEX FOR (c:Category) ON (c.categoryID);
CREATE INDEX FOR (s:Supplier) ON (s.supplierID);
CREATE INDEX FOR (c:Customer) ON (c.customerID);
CREATE INDEX FOR (o:Order) ON (o.orderID);

//Load Products
LOAD CSV WITH HEADERS FROM "https://raw.githubusercontent.com/neo4j-graph-examples/northwind/main/import/products.csv" AS row
MERGE (n:Product {productID: row.productID})
ON CREATE SET n = row,
    n.unitPrice = toFloat(row.unitPrice), 
    n.unitsInStock = toInteger(row.unitsInStock), 
    n.unitsOnOrder = toInteger(row.unitsOnOrder),
    n.reorderLevel = toInteger(row.reorderLevel), 
    n.discontinued = (row.discontinued <> "0");

//Load Categories
LOAD CSV WITH HEADERS FROM "https://raw.githubusercontent.com/neo4j-graph-examples/northwind/main/import/categories.csv" AS row
MERGE (n:Category {categoryID: row.categoryID})
ON CREATE SET n = row;

//Create relationships between Product/Category
MATCH (p:Product),(c:Category)
WHERE p.categoryID = c.categoryID
CREATE (p)-[:PART_OF]->(c);

//Load Suppliers
LOAD CSV WITH HEADERS FROM "https://raw.githubusercontent.com/neo4j-graph-examples/northwind/main/import/suppliers.csv" AS row
MERGE (n:Supplier {supplierID: row.supplierID})
ON CREATE SET n = row;

//Create relationships between Product/Supplier
MATCH (p:Product),(s:Supplier)
WHERE p.supplierID = s.supplierID
CREATE (s)-[:SUPPLIES]->(p);

//Load Customers
LOAD CSV WITH HEADERS FROM "https://raw.githubusercontent.com/neo4j-graph-examples/northwind/main/import/customers.csv" AS row
MERGE (n:Customer {customerID: row.customerID})
ON CREATE SET n = row;

//Load Orders
LOAD CSV WITH HEADERS FROM "https://raw.githubusercontent.com/neo4j-graph-examples/northwind/main/import/orders.csv" AS row
MERGE (n:Order {orderID: row.orderID})
ON CREATE SET n = row;

//Create relationships between Customer/Order
MATCH (c:Customer),(o:Order)
WHERE c.customerID = o.customerID
CREATE (c)-[:PURCHASED]->(o);

//Load Order Details
LOAD CSV WITH HEADERS FROM "https://raw.githubusercontent.com/neo4j-graph-examples/northwind/main/import/order-details.csv" AS row
MATCH (p:Product), (o:Order)
WHERE p.productID = row.productID 
    AND o.orderID = row.orderID
CREATE (o)-[details:ORDERS]->(p)
SET details = row,
    details.quantity = toInteger(row.quantity);