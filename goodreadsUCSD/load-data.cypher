//Work in Progress!

CREATE CONSTRAINT FOR (b:Book) REQUIRE b.book_id IS UNIQUE;
CREATE CONSTRAINT FOR (a:Author) REQUIRE a.author_id IS UNIQUE;
CREATE CONSTRAINT FOR (r:Review) REQUIRE r.review_id IS UNIQUE;

//Load books
CALL apoc.load.json("file:///goodreads_books_only.json") YIELD value
MERGE (b:Book {book_id: value.book_id})
 SET b = value;

//Load authors

//Load reviews