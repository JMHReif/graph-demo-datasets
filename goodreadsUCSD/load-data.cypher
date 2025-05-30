//NOTE: This script loads subset of full data set (based on 10k books)
//Total loaded data size:
//136989 nodes
//140006 relationships

CREATE CONSTRAINT FOR (b:Book) REQUIRE b.book_id IS UNIQUE;
CREATE CONSTRAINT FOR (a:Author) REQUIRE a.author_id IS UNIQUE;
CREATE CONSTRAINT FOR (r:Review) REQUIRE r.review_id IS UNIQUE;
CREATE CONSTRAINT FOR (u:User) REQUIRE u.user_id IS UNIQUE;

CREATE INDEX FOR (r:Review) ON (r.user_id);

//Load 10,000 books
CALL apoc.load.json("https://data.neo4j.com/goodreads/goodreads_books_10k.json") YIELD value as book
MERGE (b:Book {book_id: book.book_id})
SET b += apoc.map.clean(book, ['authors','similar_books'],[""]);
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

//Load similar books
CALL apoc.load.json("https://data.neo4j.com/goodreads/goodreads_books_10k.json") YIELD value as book
WITH book
MATCH (b:Book {book_id: book.book_id})
WITH book, b
WHERE book.similar_books IS NOT NULL
UNWIND book.similar_books as similarBookId
MATCH (b2:Book {book_id: similarBookId})
MERGE (b)-[r:SIMILAR_TO]->(b2);
//424 SIMILAR_TO relationships

//Load Reviews
CALL apoc.load.json("https://data.neo4j.com/goodreads/goodreads_reviews_dedup.json.gz") YIELD value as review
CALL { WITH review
 MATCH (b:Book) WHERE b.book_id = review.book_id
 WITH review, b
 MERGE (r:Review {review_id: review.review_id}) SET r += apoc.map.clean(review, [],[""])
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
     b.average_rating = toFloat(b.average_rating)
} in transactions of 20000 rows;
//30000 Book properties updated

//Clean up Review properties
MATCH (r:Review)
CALL {
    WITH r
     SET r.date_added = datetime(apoc.date.convertFormat(r.date_added, 'EEE LLL dd HH:mm:ss Z yyyy', 'iso_offset_date_time')),
     r.date_updated = datetime(apoc.date.convertFormat(r.date_updated, 'EEE LLL dd HH:mm:ss Z yyyy', 'iso_offset_date_time')),
     r.started_at = datetime(apoc.date.convertFormat(r.started_at, 'EEE LLL dd HH:mm:ss Z yyyy', 'iso_offset_date_time')),
     r.read_at = datetime(apoc.date.convertFormat(r.read_at, 'EEE LLL dd HH:mm:ss Z yyyy', 'iso_offset_date_time'))
} in transactions of 20000 rows;
//279164 Review properties updated

//Separate User nodes from Review nodes
MATCH (r:Review)
WHERE r.user_id IS NOT NULL
CALL {
    WITH r
    MERGE (u:User {user_id: r.user_id})
    WITH r, u
    MERGE (r)<-[:PUBLISHED]-(u)
} in transactions of 20000 rows;
//44827 User nodes added

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
