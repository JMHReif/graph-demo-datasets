//NOTE: This script loads subset of full data set (based on 10k books)

CREATE CONSTRAINT FOR (b:Book) REQUIRE b.book_id IS UNIQUE;
CREATE CONSTRAINT FOR (a:Author) REQUIRE a.author_id IS UNIQUE;

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

//Clean up Book properties
:auto MATCH (b:Book)
CALL {
    WITH b
     SET b.ratings_count = toInteger(b.ratings_count),
     b.text_reviews_count = toInteger(b.text_reviews_count),
     b.average_rating = toInteger(b.average_rating)
} in transactions of 20000 rows;
//30000 Book properties updated

//Clean up Author properties
:auto MATCH (a:Author)
CALL {
    WITH a
     SET a.ratings_count = toInteger(a.ratings_count),
     a.text_reviews_count = toInteger(a.text_reviews_count),
     a.average_rating = toInteger(a.average_rating)
} in transactions of 20000 rows;
//30000 Book properties updated

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