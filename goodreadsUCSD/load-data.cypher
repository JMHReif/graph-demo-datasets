//NOTE: This script loads subset of full data set (based on 10k books)
//Total loaded data size:
//92162 nodes
//84006 relationships

CREATE CONSTRAINT FOR (b:Book) REQUIRE b.book_id IS UNIQUE;
CREATE CONSTRAINT FOR (a:Author) REQUIRE a.author_id IS UNIQUE;
CREATE CONSTRAINT FOR (r:Review) REQUIRE r.review_id IS UNIQUE;

//Load 10,000 books
CALL apoc.periodic.iterate(
'CALL apoc.load.json("https://data.neo4j.com/goodreads/goodreads_books_10k.json") YIELD value as book',
'MERGE (b:Book {book_id: book.book_id}) SET b = book',
{batchsize: 10000}
);
//10000 Book nodes

//Load authors from books
CALL apoc.load.json("https://data.neo4j.com/goodreads/goodreads_books_10k.json") YIELD value as book
WITH book
UNWIND book.authors as author
MERGE (a:Author {author_id: author.author_id});
//12371 Author nodes

//Hydrate Author nodes
CALL apoc.periodic.iterate(
'CALL apoc.load.json("https://data.neo4j.com/goodreads/goodreads_book_authors.json.gz") YIELD value as author',
'WITH author MATCH (a:Author {author_id: author.author_id}) SET a = author',
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
CALL apoc.periodic.iterate(
'CALL apoc.load.json("https://data.neo4j.com/goodreads/goodreads_bookReviews_demo.json.gz") YIELD value as review',
'WITH review MERGE (r:Review {review_id: review.review_id}) SET r = review',
{batchsize: 10000}
);
//69791 Review nodes

//Load Review relationships
CALL apoc.periodic.iterate(
'CALL apoc.load.json("https://data.neo4j.com/goodreads/goodreads_reviewRels_demo.json.gz") YIELD value as rel',
'WITH rel MATCH (r:Review {review_id: rel.review_id}) MATCH (b:Book {book_id: rel.book_id}) MERGE (r)-[wf:WRITTEN_FOR]->(b)',
{batchsize: 10000}
);
//69791 WRITTEN_FOR relationships


// To delete all the data:

// // Delete all relationships 
// :auto MATCH ()-[r]-() 
// CALL { WITH r 
// DELETE r 
// } IN TRANSACTIONS OF 50000 ROWS;

// // Delete all nodes
// :auto MATCH (n) 
// CALL { WITH n 
// DETACH DELETE n 
// } IN TRANSACTIONS OF 50000 ROWS;