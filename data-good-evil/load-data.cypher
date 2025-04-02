//Set up
CREATE CONSTRAINT FOR (p:Product) REQUIRE p.productId IS UNIQUE;
CREATE CONSTRAINT FOR (c:Customer) REQUIRE c.customerId IS UNIQUE;
CREATE CONSTRAINT FOR (o:Order) REQUIRE (o.orderId, o.orderDate, o.orderTime) IS UNIQUE;
CREATE CONSTRAINT FOR (c:City) REQUIRE (c.cityName) IS UNIQUE;
CREATE CONSTRAINT FOR (g:GroceryProduct) REQUIRE g.productId IS UNIQUE;
CREATE INDEX FOR (o:Order) ON (o.transactionId);

//Create Customer node
LOAD CSV WITH HEADERS FROM 'file:///coffee-shop/customer.csv' AS row
WITH row WHERE row.customer_id = "548"
MERGE (c:Customer {customerId: row.customer_id})
  SET c.birthYear = row.birth_year, c.gender = row.gender, c.loyaltyCardNumber = row.loyalty_card_number, c.customerName = row.`customer_first-name`, c.birthDate = date(row.birthdate), c.customerEmail = row.customer_email, c.customerSince = date(row.customer_since)
MERGE (s:Store {storeId: row.home_store})
MERGE (c)-[rel:HAS_HOME_STORE]->(s)
RETURN *;

//Create customer's coffee shop orders
LOAD CSV WITH HEADERS FROM 'file:///coffee-shop/201904salesreciepts.csv' AS row
WITH row WHERE row.customer_id = "548"
CALL (row) {
  MERGE (o:Order {orderId: row.transaction_id, orderDate: date(row.transaction_date), orderTime: localtime(row.transaction_time)})
  ON CREATE SET o.transactionId = randomUUID(),
    o.inStore = row.instore_yn, o.staffId = row.staff_id
  WITH row, o
  MERGE (p:Product {productId: row.product_id})
  MERGE (o)-[r:CONTAINS]->(p)
  SET r.order = row.order,
    r.itemNumber = toInteger(row.line_item_id),
    r.quantity = toInteger(row.quantity),
    r.itemTotal = toFloat(row.line_item_amount),
    r.unitPrice = toFloat(row.unit_price),
    r.promo = row.promo_item_yn
  WITH row, o
  MERGE (s:Store {storeId: row.sales_outlet_id})
  MERGE (o)-[r:ORDERED_FROM]->(s)
  WITH row, o
  MATCH (c:Customer {customerId: row.customer_id})
  MERGE (c)-[r:BOUGHT]->(o)
}
RETURN count(row);

//Hydrate coffee shop Store properties
LOAD CSV WITH HEADERS FROM 'file:///coffee-shop/sales_outlet.csv' AS row
WITH row WHERE row.sales_outlet_id = "3"
MATCH (s:Store {storeId: row.sales_outlet_id})
 SET s.type = row.sales_outlet_type,
    s.address = row.store_address,
    s.telephone = row.store_telephone,
    s.postalCode = row.store_postal_code,
    s.longitude = row.store_longitude,
    s.latitude = row.store_latitude,
    s.managerId = row.manager,
    s.neighborhood = row.Neighborhood
MERGE (c:City {cityName: row.store_city})
MERGE (s)-[rel:LOCATED_IN]->(c)
MERGE (st:StateProvince {region: row.store_state_province})
MERGE (c)-[rel2:IN]->(st)
RETURN *;

//Create coffee shop products
LOAD CSV WITH HEADERS FROM 'file:///coffee-shop/product.csv' AS row
MATCH (p:Product {productId: row.product_id})
 SET p.productName = row.product,
        p.productDescription = row.product_description,
        p.unitOfMeasure = row.unit_of_measure,
        p.retailPrice = row.current_retail_price,
        p.promo = row.promo_yn
MERGE (t:Type {type: row.product_type})
MERGE (p)-[r1:SORTED_BY]->(t)
MERGE (c:Category {category: row.product_category})
MERGE (t)-[r2:ORGANIZED_IN]->(c)
MERGE (g:Group {group: row.product_group})
MERGE (c)-[r3:PART_OF]->(g);

//Create generation and birthyear nodes
LOAD CSV WITH HEADERS FROM 'file:///coffee-shop/generations.csv' AS row
MERGE (g:Generation {name: row.generation})
MERGE (y:BirthYear {year: row.birth_year})
MERGE (y)-[rel:FALLs_IN]->(g)
RETURN count(*);

//Connect Customer birthyear to generation
MATCH (c:Customer)
MATCH (b:BirthYear WHERE b.year = c.birthYear)
MERGE (c)-[rel:BORN_IN]->(b);

//Connect Generations in order
LOAD CSV WITH HEADERS FROM 'file:///coffee-shop/generations.csv' AS row
WITH collect(DISTINCT row.generation) as generations
WITH generations, size(generations) as length
UNWIND range(1,length+1) as index
MATCH (g:Generation {name: generations[index-1]})
MATCH (g2:Generation {name: generations[index]})
MERGE (g)-[r:NEXT]->(g2)
RETURN *;

//Update Customer with grocery-sales properties
LOAD CSV WITH HEADERS FROM 'file:///grocery-sales/customers.csv' AS row
WITH row WHERE row.CustomerID = "7923"
MATCH (c:Customer)
  SET c.address = row.Address
MERGE (city:City {cityId: row.CityID})
MERGE (c)-[rel:LIVES_IN]->(city)
RETURN *;

//Hydrate City info
LOAD CSV WITH HEADERS FROM 'file:///grocery-sales/cities.csv' AS row
MATCH (c:City)
WHERE c.cityId = row.CityID
OR c.cityName = row.cityName
 SET c.cityId = row.CityID, c.cityName = row.CityName
RETURN *;

//Add grocery orders
LOAD CSV WITH HEADERS FROM 'file:///grocery-sales/sales.csv' AS row
WITH row WHERE row.CustomerID = "7923"
MATCH (c:Customer)
MERGE (o:Order {transactionId: row.TransactionNumber})
 SET o.orderId = row.SalesID, o.salesDate = row.SalesDate,
    o.staffId = row.SalesPersonID
MERGE (c)-[rel:BOUGHT]->(o)
MERGE (p:GroceryProduct {productId: row.ProductID})
MERGE (o)-[r:CONTAINS]->(p)
 SET r.quantity = toInteger(row.Quantity),
    r.itemTotal = toFloat(row.TotalPrice),
    r.discount = row.Discount
RETURN count(row);

//Update Grocery sales date
MATCH (o:Order)-[rel]->(g:GroceryProduct)
WHERE o.salesDate IS NOT NULL
WITH o, split(o.orderDate, ' ') as dateParts
 SET o.orderTime = time(dateParts[1]), o.orderDate = date(dateParts[0])
RETURN count(o);

//Load GroceryProducts and Categories
LOAD CSV WITH HEADERS FROM 'file:///grocery-sales/products.csv' AS row
MATCH (p:GroceryProduct {productId: row.ProductID})
 SET p.productName = row.ProductName,
     p.retailPrice = toFloat(row.Price),
     p.resistant = row.Resistant,
     p.containsAllergens = row.IsAllergic,
     p.shelfLifeDays = toFloat(row.VitalityDays)
MERGE (c:GroceryCategory {categoryId: row.CategoryID})
MERGE (p)-[r:SORTED_BY]->(c);

//Hydate GroceryCategories
LOAD CSV WITH HEADERS FROM 'file:///grocery-sales/categories.csv' AS row
MATCH (c:GroceryCategory {categoryId: row.CategoryID})
 SET c.category = row.CategoryName;

//Add Netflix titles and genres
LOAD CSV WITH HEADERS FROM 'file:///kaggle-netflix/titles.csv' AS row
WITH row
WHERE row.id IN ["tm178201","tm72140","ts20648","tm811691","ts81918","ts82867","ts75357","ts272134","ts91039","tm823355","ts90789","tm918962","tm919082","tm820338","ts222333","tm858869","ts240807"]
MERGE (t:Title {titleId: row.id})
 SET t:$(apoc.text.upperCamelCase(row.type)), t.title = row.title, t.description = row.description, t.releaseYear = row.release_year, t.ageCertification = row.age_certification, t.runtime = row.runtime, t.seasons = toFloat(row.seasons), t.imdbScore = toFloat(row.imdb_score), t.tmdbPopularity = toFloat(row.tmdb_popularity), t.tmdbScore = toFloat(row.tmdb_score)
WITH row, t, split(row.genres,', ') as genres
UNWIND genres as genre
MERGE (g:Genre {genre: apoc.text.upperCamelCase(btrim(genre,"[']"))})
MERGE (t)-[r:IN]->(g)
RETURN count(row);

//Connect Customer to netflix data
MATCH (c:Customer)
MATCH (t:Title)
MERGE (c)-[r:WATCHED]->(t)
RETURN count(*);

//LEFT OFF HERE!
//2. Explore what's interesting, what's good and bad (outline scenarios in Notes app)

// //Exploration query
// MATCH (c:Customer)-[rel]-{0,5}(other)
// RETURN * LIMIT 100;