//NOTE: This script loads subset of full data set (based on 50k books)
//Total loaded data size:
//586814 nodes
//794616 relationships

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
CALL apoc.load.json("https://data.neo4j.com/goodreads/goodreads_books_50k.json") YIELD value as book
CALL {
    WITH book
    MERGE (b:Book {id: book.book_id})
    SET b += apoc.map.clean(book, ['authors','similar_books','popular_shelves','series'],[""])
} in transactions of 10000 rows;
//50000 Book nodes

//Import initial authors for 10k books
CALL apoc.load.json("https://data.neo4j.com/goodreads/goodreads_books_50k.json") YIELD value as book
CALL {
    WITH book
    UNWIND book.authors as author
    MERGE (a:Author {author_id: author.author_id})
} in transactions of 10000 rows;
//50755 Author nodes

//Hydrate Author nodes
CALL apoc.periodic.iterate(
'CALL apoc.load.json("https://data.neo4j.com/goodreads/goodreads_book_authors.json.gz") YIELD value as author',
'WITH author MATCH (a:Author {author_id: author.author_id}) SET a += apoc.map.clean(author, [],[""])',
{batchsize: 10000}
);

//Load Author relationships
CALL apoc.load.json("https://data.neo4j.com/goodreads/goodreads_books_50k.json") YIELD value as book
CALL {
    WITH book
    MATCH (b:Book {book_id: book.book_id})
    WITH book, b
    UNWIND book.authors as author
    MATCH (a:Author {author_id: author.author_id})
    MERGE (a)-[w:AUTHORED]->(b)
} in transactions of 10000 rows;
//70089 AUTHORED relationships

//Load similar books
CALL apoc.load.json("https://data.neo4j.com/goodreads/goodreads_books_50k.json") YIELD value as book
CALL {
    WITH book
    MATCH (b:Book {book_id: book.book_id})
    WITH book, b
    WHERE book.similar_books IS NOT NULL
    UNWIND book.similar_books as similarBookId
    MATCH (b2:Book {book_id: similarBookId})
    MERGE (b)-[r:SIMILAR_TO]->(b2)
} in transactions of 10000 rows;
//7911 SIMILAR_TO relationships

//Load Reviews
CALL apoc.load.json("https://data.neo4j.com/goodreads/goodreads_reviews_dedup.json.gz") YIELD value as review
CALL { 
    WITH review
    MATCH (b:Book) WHERE b.book_id = review.book_id
    WITH review, b
    MERGE (r:Review {id: review.review_id}) SET r += apoc.map.clean(review, [],[""])
    WITH b, r
    MERGE (b)<-[rel:WRITTEN_FOR]-(r)
} in transactions of 10000 rows;
//358308 Review nodes

//Clean up Book properties
MATCH (b:Book)
CALL {
    WITH b
     SET b.ratings_count = toInteger(b.ratings_count),
     b.text_reviews_count = toInteger(b.text_reviews_count),
     b.average_rating = toFloat(b.average_rating)
} in transactions of 10000 rows;

//Create Review text property
MATCH (r:Review)
    WHERE r.review_text IS NOT NULL
    AND r.text IS NULL
CALL {
    WITH r
     SET r.text = r.review_text
} in transactions of 10000 rows;

//Clean up Review review_text property
MATCH (r:Review)
    WHERE r.review_text IS NOT NULL
    AND r.text IS NOT NULL
CALL {
    WITH r
     REMOVE r.review_text
} in transactions of 10000 rows;

//Create Book text property
MATCH (b:Book)
    WHERE b.description IS NOT NULL
    AND b.text IS NULL
CALL {
    WITH b
     SET b.text = b.description
} in transactions of 10000 rows;

//Clean up Book description property
MATCH (b:Book)
    WHERE b.description IS NOT NULL
    AND b.text IS NOT NULL
CALL {
    WITH b
     REMOVE b.description
} in transactions of 10000 rows;

//Clean up Review date_added property
MATCH (r:Review)
    WHERE r.date_added IS NOT NULL
    AND apoc.meta.cypher.type(r.date_added) = "STRING"
CALL {
    WITH r
     SET r.date_added = datetime(apoc.date.convertFormat(r.date_added, 'EEE LLL dd HH:mm:ss Z yyyy', 'iso_offset_date_time'))
} in transactions of 1000 rows;

//Clean up Review date_updated property
MATCH (r:Review)
    WHERE r.date_updated IS NOT NULL
    AND apoc.meta.cypher.type(r.date_updated) = "STRING"
CALL {
    WITH r
     SET r.date_updated = datetime(apoc.date.convertFormat(r.date_updated, 'EEE LLL dd HH:mm:ss Z yyyy', 'iso_offset_date_time'))
} in transactions of 1000 rows;

//Clean up Review started_at property
MATCH (r:Review)
WHERE r.started_at IS NOT NULL
    AND apoc.meta.cypher.type(r.started_at) = "STRING"
CALL {
    WITH r
     SET r.started_at = datetime(apoc.date.convertFormat(r.started_at, 'EEE LLL dd HH:mm:ss Z yyyy', 'iso_offset_date_time'))
} in transactions of 1000 rows;

//Remove Review read_at problem properties (invalue year)
MATCH (r:Review)
WHERE r.read_at IS NOT NULL
AND apoc.meta.cypher.type(r.read_at) = "STRING"
AND r.read_at ENDS WITH "0000"
 REMOVE r.read_at
RETURN count(r);
//1 Review nodes updated

//Clean up Review read_at property
MATCH (r:Review)
WHERE r.read_at IS NOT NULL
AND apoc.meta.cypher.type(r.read_at) = "STRING"
CALL {
    WITH r
     SET r.read_at = datetime(apoc.date.convertFormat(r.read_at, 'EEE LLL dd HH:mm:ss Z yyyy', 'iso_offset_date_time'))
} in transactions of 1000 rows;

//Separate User nodes from Review nodes
MATCH (r:Review)
WHERE r.user_id IS NOT NULL
CALL {
    WITH r
    MERGE (u:User {user_id: r.user_id})
    WITH r, u
    MERGE (r)<-[:PUBLISHED]-(u)
} in transactions of 1000 rows;
//127751 User nodes added

//Generate embeddings for Book nodes
CALL apoc.periodic.iterate(
    'MATCH (b:Book WHERE b.description IS NOT NULL AND b.embedding IS NULL)
    RETURN b',
    'WITH collect(b) as books
    CALL apoc.ml.openai.embedding([b in books | b.title+"\n"+b.description],$token) YIELD index, embedding
    CALL db.create.setNodeVectorProperty(books[index], "embedding", embedding);',
    {batchSize:100, params:{token:$token}})
YIELD batches, total, errorMessages
RETURN batches, total, errorMessages;

//Generate embeddings for Review nodes
CALL apoc.periodic.iterate(
    'MATCH (r:Review WHERE r.text IS NOT NULL AND r.embedding IS NULL)
    RETURN r',
    'WITH collect(r) as reviews
    CALL apoc.ml.openai.embedding([r in reviews | r.text],$token) YIELD index, embedding
    CALL db.create.setNodeVectorProperty(reviews[index], "embedding", embedding);',
    {batchSize:100, params:{token:$token}})
YIELD batches, total, errorMessages
RETURN batches, total, errorMessages;

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