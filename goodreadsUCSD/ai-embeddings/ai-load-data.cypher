//NOTE: This script loads subset of full data set (based on 10k books)
//Total loaded data size:
//92162 nodes
//84006 relationships

CREATE CONSTRAINT FOR (b:Book) REQUIRE b.book_id IS UNIQUE;
CREATE CONSTRAINT FOR (a:Author) REQUIRE a.author_id IS UNIQUE;
CREATE CONSTRAINT FOR (r:Review) REQUIRE r.id IS UNIQUE;
CREATE CONSTRAINT FOR (u:User) REQUIRE u.user_id IS UNIQUE;

CREATE INDEX FOR (r:Review) ON (r.user_id);

//Load 10,000 books
CALL apoc.load.json("https://data.neo4j.com/goodreads/goodreads_books_10k.json") YIELD value as book
MERGE (b:Book {book_id: book.book_id})
SET b += apoc.map.clean(book, ['authors'],[""]);
//10000 Book nodes

//Import initial authors for 10k books
CALL apoc.load.json("https://data.neo4j.com/goodreads/goodreads_books_10k.json") YIELD value as book
WITH book
UNWIND book.authors as author
MERGE (a:Author {author_id: author.author_id});
//12371 Author nodes

//Hydrate Author nodes
CALL apoc.periodic.iterate(
'CALL apoc.load.json("https://data.neo4j.com/goodreads/goodreads_book_authors.json.gz") YIELD value as author',
'WITH author MATCH (a:Author {author_id: author.author_id}) SET a += apoc.map.clean(author, [],[""])',
{batchsize: 10000}
);

//Load Author relationships
CALL apoc.load.json("https://data.neo4j.com/goodreads/goodreads_books_10k.json") YIELD value as book
WITH book
MATCH (b:Book {book_id: book.book_id})
WITH book, b
UNWIND book.authors as author
MATCH (a:Author {author_id: author.author_id})
MERGE (a)-[w:AUTHORED]->(b);
//14215 AUTHORED relationships

//Load Reviews
CALL apoc.load.json("https://data.neo4j.com/goodreads/goodreads_reviews_dedup.json.gz") YIELD value as review
CALL { WITH review
 MATCH (b:Book) WHERE b.book_id = review.book_id
 WITH review, b
 MERGE (r:Review {id: review.review_id}) SET r += apoc.map.clean(review, [],[""])
 WITH b, r
 MERGE (b)<-[rel:WRITTEN_FOR]-(r)
} in transactions of 20000 rows;
//69791 Review nodes
//69791 WRITTEN_FOR relationships

//Clean up Book properties
MATCH (b:Book)
CALL {
    WITH b
     SET b.ratings_count = toInteger(b.ratings_count),
     b.text_reviews_count = toInteger(b.text_reviews_count),
     b.average_rating = toInteger(b.average_rating)
} in transactions of 20000 rows;
//30000 Book properties updated

//Clean up Review properties
MATCH (r:Review)
CALL {
    WITH r
     SET r.text = r.review_text,
     r.date_added = datetime(apoc.date.convertFormat(r.date_added, 'EEE LLL dd HH:mm:ss Z yyyy', 'iso_offset_date_time')),
     r.date_updated = datetime(apoc.date.convertFormat(r.date_updated, 'EEE LLL dd HH:mm:ss Z yyyy', 'iso_offset_date_time')),
     r.started_at = datetime(apoc.date.convertFormat(r.started_at, 'EEE LLL dd HH:mm:ss Z yyyy', 'iso_offset_date_time')),
     r.read_at = datetime(apoc.date.convertFormat(r.read_at, 'EEE LLL dd HH:mm:ss Z yyyy', 'iso_offset_date_time'))
     REMOVE r.review_text
} in transactions of 20000 rows;
//249836 Review properties updated

//Add embeddings to Review nodes


//Separate User nodes from Review nodes
MATCH (r:Review)
WHERE r.user_id IS NOT NULL
CALL {
    WITH r
    MERGE (u:User {user_id: r.user_id})
    WITH r, u
    MERGE (r)<-[:PUBLISHED]-(u)
} in transactions of 20000 rows;
//14230 User nodes added

//Load embeddings to Review nodes
LOAD CSV WITH HEADERS FROM "https://data.neo4j.com/goodreads/review_embeddings.psv" as row
FIELDTERMINATOR '|'
CALL {
    WITH row
    MATCH (r:Review {review_id: row.reviewId})
    SET r.embedding = row.embedding
    RETURN r
} in transactions of 1000 rows
WITH r
RETURN count(r);

// To delete all the data:

// // Delete all relationships 
// MATCH ()-[r]-() 
// CALL { WITH r 
// DELETE r 
// } IN TRANSACTIONS OF 50000 ROWS;

// // Delete all nodes
// MATCH (n) 
// CALL { WITH n 
// DETACH DELETE n 
// } IN TRANSACTIONS OF 50000 ROWS;
