//NOTE: This script loads subset of full data set (based on 10k books)
//Also creates embeddings with OpenAI model text-embedding-3-small

//Parameter for OpenAI API token
:params {token:"<YOUR API KEY HERE>"}

CREATE CONSTRAINT book_id IF NOT EXISTS FOR (b:Book) REQUIRE b.id IS UNIQUE;
CREATE CONSTRAINT author_id IF NOT EXISTS FOR (a:Author) REQUIRE a.author_id IS UNIQUE;
CREATE CONSTRAINT review_id IF NOT EXISTS FOR (r:Review) REQUIRE r.id IS UNIQUE;
CREATE CONSTRAINT user_id IF NOT EXISTS FOR (u:User) REQUIRE u.user_id IS UNIQUE;

CREATE INDEX review_user IF NOT EXISTS FOR (r:Review) ON (r.user_id);
CREATE VECTOR INDEX `book-descriptions` IF NOT EXISTS
FOR (b:Book) ON b.embedding
OPTIONS {indexConfig: {
 `vector.dimensions`: 1536,
 `vector.similarity_function`: 'cosine'
}};
CREATE VECTOR INDEX `review-text` IF NOT EXISTS
FOR (r:Review) ON r.embedding
OPTIONS {indexConfig: {
 `vector.dimensions`: 1536,
 `vector.similarity_function`: 'cosine'
}};

//Load books
CALL apoc.load.json("https://data.neo4j.com/goodreads/goodreads_books_10k.json") YIELD value as book
CALL (book) {
    MERGE (b:Book {id: book.book_id})
    SET b += apoc.map.clean(book, ['authors','similar_books','popular_shelves','series'],[""])
} IN TRANSACTIONS OF 10000 ROWS;

//Import initial authors for 10k books
CALL apoc.load.json("https://data.neo4j.com/goodreads/goodreads_books_10k.json") YIELD value as book
CALL (book) {
    UNWIND book.authors as author
    MERGE (a:Author {author_id: author.author_id})
} IN TRANSACTIONS OF 10000 ROWS;

//Hydrate Author nodes
CALL apoc.periodic.iterate(
'CALL apoc.load.json("https://data.neo4j.com/goodreads/goodreads_book_authors.json.gz") YIELD value as author',
'WITH author MATCH (a:Author {author_id: author.author_id}) SET a += apoc.map.clean(author, [],[""])',
{batchsize: 10000}
);

//Load Author relationships
CALL apoc.load.json("https://data.neo4j.com/goodreads/goodreads_books_10k.json") YIELD value as book
CALL (book) {
    MATCH (b:Book {id: book.book_id})
    UNWIND book.authors as author
    MATCH (a:Author {author_id: author.author_id})
    MERGE (a)-[w:AUTHORED]->(b)
} IN TRANSACTIONS OF 10000 ROWS;

//Load similar books
CALL apoc.load.json("https://data.neo4j.com/goodreads/goodreads_books_10k.json") YIELD value as book
CALL (book) {
    MATCH (b:Book {id: book.book_id})
    WHERE book.similar_books IS NOT NULL
    UNWIND book.similar_books as similarBookId
    MATCH (b2:Book {id: similarBookId})
    MERGE (b)-[r:SIMILAR_TO]->(b2)
} IN TRANSACTIONS OF 10000 ROWS;

//Load Review nodes
CALL apoc.load.json("https://data.neo4j.com/goodreads/goodreads_reviews_dedup.json.gz") YIELD value as review
CALL (review) {
    MATCH (b:Book {id: review.book_id})
    MERGE (r:Review {id: review.review_id})
} IN TRANSACTIONS OF 10000 ROWS;

//Hydrate Review properties
CALL apoc.load.json("https://data.neo4j.com/goodreads/goodreads_reviews_dedup.json.gz") YIELD value as review
CALL (review) {
    MATCH (r:Review {id: review.review_id}) SET r += apoc.map.clean(review, [],[""])
} IN TRANSACTIONS OF 10000 ROWS;

//Load Review relationships
CALL apoc.load.json("https://data.neo4j.com/goodreads/goodreads_reviews_dedup.json.gz") YIELD value as review
CALL (review) {
    MATCH (b:Book {id: review.book_id})
    MATCH (r:Review {id: review.review_id})
    MERGE (b)<-[rel:WRITTEN_FOR]-(r)
} IN TRANSACTIONS OF 10000 ROWS;

//Clean up Book properties
MATCH (b:Book)
CALL (b) {
     SET b.ratings_count = toInteger(b.ratings_count),
     b.text_reviews_count = toInteger(b.text_reviews_count),
     b.average_rating = toFloat(b.average_rating)
} IN TRANSACTIONS OF 10000 ROWS;

//Create Review text property
MATCH (r:Review)
    WHERE r.review_text IS NOT NULL
    AND r.text IS NULL
CALL (r) {
     SET r.text = r.review_text
} IN TRANSACTIONS OF 10000 ROWS;

//Clean up Review review_text property
MATCH (r:Review)
    WHERE r.review_text IS NOT NULL
    AND r.text IS NOT NULL
CALL (r) {
     REMOVE r.review_text
} IN TRANSACTIONS OF 10000 ROWS;

//Create Book text property
MATCH (b:Book)
    WHERE b.description IS NOT NULL
    AND b.text IS NULL
CALL (b) {
     SET b.text = b.description
} IN TRANSACTIONS OF 10000 ROWS;

//Clean up Book description property
MATCH (b:Book)
    WHERE b.description IS NOT NULL
    AND b.text IS NOT NULL
CALL (b) {
     REMOVE b.description
} IN TRANSACTIONS OF 10000 ROWS;

//Clean up Review date_added property
MATCH (r:Review)
    WHERE r.date_added IS NOT NULL
    AND apoc.meta.cypher.type(r.date_added) = "STRING"
CALL (r) {
     SET r.date_added = datetime(apoc.date.convertFormat(r.date_added, 'EEE LLL dd HH:mm:ss Z yyyy', 'iso_offset_date_time'))
} IN TRANSACTIONS OF 1000 ROWS;

//Clean up Review date_updated property
MATCH (r:Review)
    WHERE r.date_updated IS NOT NULL
    AND apoc.meta.cypher.type(r.date_updated) = "STRING"
CALL (r) {
     SET r.date_updated = datetime(apoc.date.convertFormat(r.date_updated, 'EEE LLL dd HH:mm:ss Z yyyy', 'iso_offset_date_time'))
} IN TRANSACTIONS OF 1000 ROWS;

//Clean up Review started_at property
MATCH (r:Review)
WHERE r.started_at IS NOT NULL
    AND apoc.meta.cypher.type(r.started_at) = "STRING"
CALL (r) {
     SET r.started_at = datetime(apoc.date.convertFormat(r.started_at, 'EEE LLL dd HH:mm:ss Z yyyy', 'iso_offset_date_time'))
} IN TRANSACTIONS OF 1000 ROWS;

//Remove Review read_at problem properties (invalue year)
MATCH (r:Review)
WHERE r.read_at IS NOT NULL
AND apoc.meta.cypher.type(r.read_at) = "STRING"
AND r.read_at ENDS WITH "0000"
 REMOVE r.read_at
RETURN count(r);

//Clean up Review read_at property
MATCH (r:Review)
WHERE r.read_at IS NOT NULL
AND apoc.meta.cypher.type(r.read_at) = "STRING"
CALL (r) {
     SET r.read_at = datetime(apoc.date.convertFormat(r.read_at, 'EEE LLL dd HH:mm:ss Z yyyy', 'iso_offset_date_time'))
} IN TRANSACTIONS OF 1000 ROWS;

//Separate User nodes from Review nodes
MATCH (r:Review)
WHERE r.user_id IS NOT NULL
CALL (r) {
    MERGE (u:User {user_id: r.user_id})
    MERGE (r)<-[:PUBLISHED]-(u)
} IN TRANSACTIONS OF 1000 ROWS;

//Generate embeddings for Book nodes
CALL apoc.periodic.iterate(
    'MATCH (b:Book WHERE b.description IS NOT NULL AND b.embedding IS NULL)
    RETURN b',
    'WITH collect(b) as books
    CALL apoc.ml.openai.embedding([b in books | b.title+"\n"+b.description],$token,{model: "text-embedding-3-small"}) YIELD index, embedding
    CALL db.create.setNodeVectorProperty(books[index], "embedding", embedding);',
    {batchSize:100, params:{token:$token}})
YIELD batches, total, errorMessages
RETURN batches, total, errorMessages;

//Generate embeddings for Review nodes
MATCH (r:Review)
WITH COUNT(r) AS total
UNWIND range(0, total-1, 100) AS batchStart
CALL() {
  MATCH (r:Review WHERE r.text IS NOT NULL AND r.embedding IS NULL)
  LIMIT 100
  WITH collect(r.text) AS batch, collect(r) AS reviewsList
  CALL genai.vector.encodeBatch(batch, "OpenAI", { token: $token, model: "text-embedding-3-small" }) YIELD index, vector
  CALL db.create.setNodeVectorProperty(reviewsList[index], "embedding", vector)
} IN TRANSACTIONS OF 1 ROW;
// //Generate embeddings for Review nodes (batched by 1000, run multiple times)
// MATCH (r:Review WHERE r.text IS NOT NULL AND r.embedding IS NULL)
// LIMIT 1000
// WITH collect(r) AS reviewsList,
//      count(*) AS total,
//      100 AS batchSize
// UNWIND range(0, total-1, batchSize) AS batchStart
// CALL (reviewsList, batchStart, batchSize) {
//     WITH [review IN reviewsList[batchStart .. batchStart + batchSize] | review.text] AS batch
//     CALL genai.vector.encodeBatch(batch, 'OpenAI', { token: $token, model: "text-embedding-3-small" }) YIELD index, vector
//     CALL db.create.setNodeVectorProperty(reviewsList[batchStart + index], 'embedding', vector)
// } IN CONCURRENT TRANSACTIONS OF 1 ROW;

// To delete all the data:
// // Delete all relationships 
// MATCH ()-[r]-() 
// CALL { WITH r 
// DELETE r 
// } IN TRANSACTIONS OF 10000 ROWS;

// // Delete all nodes
// MATCH (n) 
// CALL { WITH n 
// DETACH DELETE n 
// } IN TRANSACTIONS OF 10000 ROWS;